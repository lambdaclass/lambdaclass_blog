+++
title = "Continuous Read-Only Memory Constraints: An implementation using Lambdaworks"
date = 2024-12-02
slug = "continuous-read-only-memory-constraints-an-implementation-using-lambdaworks"

[extra]
math = true
feature_image = "/images/2025/12/Joseph_Vernet_bundet_til_masten.jpg"
authors = ["LambdaClass"]
+++

## Introduction

When we first explored the world of STARKs, one of the most confusing concepts we encountered was constraints. We kept asking ourselves: How is it possible to summarize highly complex relationships between trace values using just a few polynomials? It wasn’t until we started implementing some examples that we truly understood the clever, almost magical techniques employed in this domain.

In this post, we aim to share part of that journey, explaining the insights we’ve gained in a hands-on, practical manner. We firmly believe that the best way to learn is through doing, and we’ll guide you through a concrete example: implementing the constraints for Cairo’s non-deterministic continuous read-only memory using the Lambdaworks library. These constraints are detailed in Section 9.7 of the [Cairo whitepaper](https://eprint.iacr.org/2021/1063).

We won’t explain the basic concepts from the protocol, as we assume that if you’re reading this, you already have some understanding of the STARK protocol, the idea of an execution trace, and the purpose of defining constraints. For a deeper understanding or to reinforce some concepts, check out [diving DEEP-FRI](/diving-deep-fri/), [FRI from scratch](/how-to-code-fri-from-scratch/) and [Stone prover](/overview-of-the-stone-prover/)

## What is a Continuous Read-Only Memory?

So, what do we mean by "continuous, non-deterministic, read-only memory"?

The definition from the paper is as follows:

> **9.7.1 Definition**  
>  **Definition 4.** A memory access is a pair $(a, v)\in \mathbb{F}^2$ where $a$ represents an address and $v$ represents the value of the memory at a. A list of memory accesses $(a_i, v_i)$ for $i \in [0, n)$ ($1 \leq n \leq P$) is said to form a _read-only memory_ if for all $i, j \in [0, n)$, if $a_i = a_j,$ then $v_i = v_j$ . It is said to be _continuous_ if the set ${a_i: i \in [0, n)}$ equals $[m_0, m_1)$ for some $m_0, m_1 \in \mathbb{F}$ that satisfy $m_1 = m_0 + t$ for a natural number $t < P$ . In particular, for a given continuous read-only memory list of accesses, we can define a function $f: [m_0, m_1) \to \mathbb{F}$ such that $f(a_i) = v_i$ for all $i \in [0, n)$. Any function $m: \mathbb{F} → \mathbb{F}$ extending $f$ is said to be a memory function for the list of memory accesses.

Let’s simplify this long and complex definition. Imagine a trace with two columns and $n$ rows. The rows represent each step of execution. The first column indicates the memory address accessed during that step, and the second column indicates the value retrieved from that address.

For a memory to be **read-only** , the same addresses must always have the same value. If two rows in the trace reference the same address, the value in those rows must be the same.

For example, consider the following trace:

Address | Value  
---|---  
1 | 56  
3 | 34  
5 | 97  
4 | 25  
5 | 41  
3 | 34  
  
This trace is invalid because address 5 has two different values: 97 in the first occurrence and 41 in the second. This is not allowed in read-only memory.

For a memory to be **continuous** , every memory address from the starting point (e.g., address 1) to the last address must appear at least once.

The trace is also invalid in the example above because there is no entry for address 2.

Then, to validate a trace, we need to ensure:

        * **Read-only property** : The same address always maps to the same value.
        * **Continuity property** : Every memory address in the range appears at least once.

It’s worth noting that addresses can appear multiple times in any order.

The hard part is figuring out how to transform these two conditions into equations, which can then be expressed as polynomials.

Like any engineering problem, there are trade-offs: keeping the trace simple can make the constraints more complex, and using more straightforward constraints can require adding more information to the trace.

If we examine the conditions mentioned earlier, it becomes clear that validating them would be easier if the rows were sorted by address. For example, it’s challenging for a human to determine if a sequence like $(7, 5, 12, 4, 5, 11, 9, 10, 4, 4, 11, 7, 8)$ is continuous, but much more straightforward if we sort it: $(4, 4, 5, 5, 7, 7, 8, 9, 10, 11, 11, 12)$.

For this reason, Cairo’s VM adds two additional columns to the trace: the sorted versions of the address and value columns.

For example:

address $(a)$ | value $(v)$ | sorted_address $(a')$ | sorted_value $(v')$  
---|---|---|---  
1 | 56 | 1 | 56  
5 | 14 | 1 | 56  
3 | 25 | 2 | 34  
3 | 25 | 3 | 25  
4 | 44 | 3 | 25  
1 | 56 | 4 | 44  
2 | 34 | 5 | 14  
  
Although this duplicates the trace columns, it significantly simplifies verifying the continuity and read-only properties, as we’ll see next.

However, adding these two columns introduces a new challenge: We need a way to verify that the new columns are permutations of the original ones. We'll handle this with **Permutation Constraints** (spoiler alert: this requires the prover to add another column to the trace).

Thus, by adding these new columns, validating the memory properties boils down to proving these simpler way constraints:

        * **Continuity Constraint**
        * **Single Value Constraint**
        * **Permutation Constraints**

## Constraints

### Continuity Constraint

Our first constraint will ensure that memory addresses form a continuous range without gaps. For instance, if address 5 appears, addresses 4 and 6 must also appear to maintain continuity.

A valid example of continuous memory:

sorted_addresses $(a')$ | sorted_values $(v')$  
---|---  
... | ...  
100 | 42  
101 | 17  
102 | 35  
103 | 22  
104 | 88  
... | ...  
  
An invalid example:

sorted_addresses $(a')$ | sorted_values $(v')$  
---|---  
... | ...  
100 | 42  
101 | 17  
103 | 22  
104 | 88  
... | ...  
  
Here, address 102 is missing, breaking continuity.

To check continuity, we examine the sorted address column, ensuring that the difference between consecutive addresses is always 0 (if they are the same) or 1 (if they are consecutive). The following Cairo constraint captures this:

$$(a_{i+1}^\prime - a_i^\prime )(a_{i+1}^\prime - a_i^\prime - 1) = 0 \text{ for all } i \in [0,n - 1]$$

Where $a_i^\prime$ represents the address in the $i$-th row of the sorted address column, and $v'_i$ represents the corresponding value.

In this equation:

        * The first factor, $(a'_{i+1} - a'_i)$ equals zero when addresses are the same.
        * The second factor, $(a'_{i+1} - a'_i - 1)$ equals zero when addresses differ by 1.

Since the product must equal zero, the addresses must be identical or differ by exactly 1, ensuring continuity.

Here’s how this is implemented in Rust:  
add code
    
    fn evaluate(
        &self,
        frame: &Frame<F, F>,
        transition_evaluations: &mut [FieldElement<F>],
        _periodic_values: &[FieldElement<F>],
        _rap_challenges: &[FieldElement<F>],
    ) {
        transition_evaluations
            .get_mut(self.constraint_idx())
            .map(|transition_eval| {
                let first_step = frame.get_evaluation_step(0);
                let second_step = frame.get_evaluation_step(1);
    
                let a_sorted_0 = first_step.get_main_evaluation_element(0, 2);
                let a_sorted_1 = second_step.get_main_evaluation_element(0, 2);
    
                let res = (a_sorted_1 - a_sorted_0)
                    * (a_sorted_1 - a_sorted_0 - FieldElement::<F>::one());
                *transition_eval = res;
            });
    }
    

where:
    
    let first_step = frame.get_evaluation_step(0); 
    

gives us access to the first row of the trace and
    
    let a_sorted_0 = first_step.get_main_evaluation_element(0, 2); //a'_0
    

will give access to the second third column which is element 2

Then the equation looks kike
    
    let res = (a_sorted_1 - a_sorted_0)
    * (a_sorted_1 - a_sorted_0 - FieldElement::<F>::one());
    
    *transition_eval = res;
    

### Single-Value Constraint

This constraint ensures that each memory address has a single, consistent value. Even if the same address is accessed multiple times, the value must always remain the same.  
A valid example:

Address | Value  
---|---  
... | ...  
101 | 17  
101 | 17  
104 | 88  
... | ...  
  
An invalid example:

Address | Value  
---|---  
... | ...  
101 | 17  
101 | 42  
102 | 88  
... | ...  
  
Here, address 101 has two different values, violating the constraint.

With an analogous logic to the one used in the continuity constraint, the Cairo paper defines the single-value constraint as:

$$(v_{i+1}^\prime - v_i^\prime )(a_{i+1}^\prime - a_i^\prime - 1) = 0 \quad \text{for all } i \in [0, n - 1]$$

In this equation:

        * The first factor, $(v'_{i+1} - v'_i)$ ensures that the values for identical addresses are the same.
        * The second factor, $(a'_{i+1} - a'_i - 1)$ ensures this check only applies to identical addresses.

Here’s the implementation in Rust
    
    fn evaluate(
        &self,
        frame: &Frame<F, F>,
        transition_evaluations: &mut [FieldElement<F>],
        _periodic_values: &[FieldElement<F>],
        _rap_challenges: &[FieldElement<F>],
    ) {
        transition_evaluations
            .get_mut(self.constraint_idx())
            .map(|transition_eval| {
                let first_step = frame.get_evaluation_step(0);
                let second_step = frame.get_evaluation_step(1);
    
                let a_sorted_0 = first_step.get_main_evaluation_element(0, 2);
                let a_sorted_1 = second_step.get_main_evaluation_element(0, 2);
                let v_sorted_0 = first_step.get_main_evaluation_element(0, 3);
                let v_sorted_1 = second_step.get_main_evaluation_element(0, 3);
    
                let res = (v_sorted_1 - v_sorted_0)
                    * (a_sorted_1 - a_sorted_0 - FieldElement::<F>::one());
                *transition_eval = res;
            });
    }
    

As with the continuity constraint, we extract the relevant rows and elements:
    
    let a_sorted_0 = first_step.get_main_evaluation_element(0, 2); // a'_i
    let a_sorted_1 = second_step.get_main_evaluation_element(0, 2); // a'_{i+1}
    let v_sorted_0 = first_step.get_main_evaluation_element(0, 3); // v'_i
    let v_sorted_1 = second_step.get_main_evaluation_element(0, 3); // v'_{i+1}`
    

The evaluation results ensure that if two addresses are equal, their corresponding values are consistent.

### Permutation Constraint

Now that we know that $a'$ and $v'$ represent a continuous read-only memory, we must prove that $a'$ and $v'$ are a permutation of the original $a$ and $v$ columns. We'll achieve this using an interactive protocol:

First, the verifier sends the prover two random field elements $z, \alpha \in \mathbb{F}$, known as _challenges_. One detail to remember is that if we work with a small field $\mathbb{F}$, these elements should be sampled from an extension field, so all the following permutation constraints will be over the extension.

**Note:** In practice, the protocol is not interactive; instead, the [Fiat-Shamir heuristic](https://en.wikipedia.org/wiki/Fiat%E2%80%93Shamir_heuristic) is used to obtain random values, enabling a non-interactive approach.

secondly, using these challenges, the prover constructs an auxiliary column $p$, which is added to the main trace table. This column is computed as:

$$ \begin{align} p_0 &= \frac {z - (a_0 + \alpha v_0)} {z - (a'_0 + \alpha v'_0)},  
\ \newline  
p_1 &= \frac {z - (a_0 + \alpha v_0)} {z - (a'_0 + \alpha v'_0)} \cdot \frac {z - (a_1 + \alpha v_1)} {z - (a'_1 + \alpha v'_1)} = p_0 \cdot \frac {z - (a_1 + \alpha v_1)} {z - (a'_1 + \alpha v'_1)},  
\ \newline  
p_2 &= p_1 \cdot \frac {z - (a_2 + \alpha v_2)} {z - (a'_2 + \alpha v'_2)}. \end{align}$$

Continuing with this procedure we get:

$$p_{i+1} = p_i \cdot \frac {z - (a_{i+1} + \alpha v_{i+1})} {z - (a_{i+1}^\prime + \alpha v_{i+1}^\prime )} \text{ with } i \in {0, \ldots, n - 2}$$

For example, if the main trace table is:

$a$ | $v$ | $a'$ | $v'$  
---|---|---|---  
2 | 10 | 0 | 7  
0 | 7 | 0 | 7  
0 | 7 | 1 | 20  
1 | 20 | 2 | 10  
  
then the table with the auxiliary column $p$ will look like this:

$a$ | $v$ | $a'$ | $v'$ | $p$  
---|---|---|---|---  
2 | 10 | 0 | 7 | $\frac {z - (2 + \alpha 10)} {z - (0 + \alpha 7)}$  
0 | 7 | 0 | 7 | $\frac {z - (2 + \alpha 10)} {z - (0 + \alpha 7)} \cdot \frac {z - (0 + \alpha 7)} {z - (0 + \alpha 7)}$  
0 | 7 | 1 | 20 | $\frac {z - (2 + \alpha 10)} {z - (0 + \alpha 7)} \cdot \frac {z - (0 + \alpha 7)} {z - (0 + \alpha 7)} \cdot \frac {z - (0 + \alpha 7)} {z - (1 + \alpha 20)}$  
1 | 20 | 2 | 10 | $\frac {z - (2 + \alpha 10)} {z - (0 + \alpha 7)} \cdot \frac {z - (0 + \alpha 7)} {z - (0 + \alpha 7)} \cdot \frac {z - (0 + \alpha 7)} {z - (1 + \alpha 20)} \cdot \frac {z - (1 + \alpha 20)} {z - (2 + \alpha 10)}$  
  
Looking at the example, let us observe that the last value in column $p$ gives us the product of all the previous ones. Since the values indeed come from a permutation, each factor in the numerator (originated from $a$ and $v$) must appear once in the denominator (originated from $a'$ and $v'$), canceling each other out and resulting in the entire product equaling $1$. For instance, in the table above, the first numerator (orange) cancels out with the last denominator (orange):

$$\frac { {\style{color: orange} {z - (2 + \alpha 10)}}} {\style{color: cyan} {z - (0 + \alpha 7)}} \cdot \frac { \style{color: magenta} {z - (0 + \alpha 7)}} { \style{color: magenta} {z - (0 + \alpha 7)}} \cdot \frac { \style{color: cyan} {z - (0 + \alpha 7)}} { \style{color: lime} {z - (1 + \alpha 20)}} \cdot \frac { \style{color: lime} {z - (1 + \alpha 20)}} { \style{color: orange} {z - (2 + \alpha 10)}} = 1$$

Generalizing it to any trace with $n$ rows, we get the following last value, called _Grand Product_ :

$$p_{n - 1} = \frac {z - (a_0 + \alpha v_0)} {z - (a_0^\prime + \alpha v_0^\prime )} \cdot \frac {z - (a_1 + \alpha v_1)} {z - (a_1^\prime + \alpha v_1^\prime )} \ldots \frac {z - (a_{n - 1} + \alpha v_{n - 1})} {z - (a_{n - 1}^\prime + \alpha v_{ n - 1 }^\prime )}$$

Then, using the randomness of $z$ and $\alpha$ (and the [Schwartz–Zippel Lemma](https://en.wikipedia.org/wiki/Schwartz%E2%80%93Zippel_lemma)), we know that to prove that $a'$ and $v'$ are a permutation of $a$ and $v$, it suffices to check that:  
$$ p_{n-1} = 1$$

In this way, the constraints that guarantee the correct permutation are reduced to two boundary constraints and one transition constraint (you can find them in the [Cairo Paper](https://eprint.iacr.org/2021/1063.pdf), Section 9.7.2):

#### 1\. Initial Value Boundary Constraint:

$$p_0 = \frac {z - (a_0 + \alpha v_0)} {z - (a_0^\prime + \alpha v_0^\prime )}$$ We check that the first value in the auxiliary column is correct.

#### 2\. Final Value Boundary Constraint:

$$p_{n - 1} = 1$$ We check that the Grand Product equals 1.

In our code, these two Boundary Constraints are located in the `boundary_constraints()` function of the `AIR` implementation for `ReadOnlyRAP<F>`. You can see them below, after the comment `//Auxiliary boundary constraints`:
    
    fn boundary_constraints(
        &self,
        rap_challenges: &[FieldElement<Self::FieldExtension>],
    ) -> BoundaryConstraints<Self::FieldExtension> {
        let a0 = &self.pub_inputs.a0;
        let v0 = &self.pub_inputs.v0;
        let a_sorted0 = &self.pub_inputs.a_sorted0;
        let v_sorted0 = &self.pub_inputs.v_sorted0;
        let z = &rap_challenges[0];
        let alpha = &rap_challenges[1];
    
        // Main boundary constraints
        let c1 = BoundaryConstraint::new_main(0, 0, a0.clone());
        let c2 = BoundaryConstraint::new_main(1, 0, v0.clone());
        let c3 = BoundaryConstraint::new_main(2, 0, a_sorted0.clone());
        let c4 = BoundaryConstraint::new_main(3, 0, v_sorted0.clone());
    
        // Auxiliary boundary constraints
        let num = z - (a0 + alpha * v0);
        let den = z - (a_sorted0 + alpha * v_sorted0);
        let p0_value = num / den;
    
        let c_aux1 = BoundaryConstraint::new_aux(0, 0, p0_value);
        let c_aux2 = BoundaryConstraint::new_aux(
            0,
            self.trace_length - 1,
            FieldElement::<Self::FieldExtension>::one(),
        );
    
        BoundaryConstraints::from_constraints(vec![c1, c2, c3, c4, c_aux1, c_aux2])
    }
    

Note that the values of $a$, $a'$, $v$, $v'$ from the first row of the trace must also be known by the verifier to perform the check for the Initial Value constraint. This is a problem we did not have before (the rest of the constraints do not depend on the trace) since the verifier only has access to the commitment of the trace, not its elements. Therefore, this first row must be part of the public input.

#### 3\. Permutation Transition Constraint:

$$(z - (a_{i+1}^\prime + \alpha v_{i + 1}^\prime )) \cdot p_{i+1} - (z - (a_{i+1} + \alpha v_{i+1})) \cdot p_i = 0$$ for all $i \in {0, \ldots, n-2}$.

In this way, we check that each element of $p$ was constructed correctly, with the last element being the Grand Product. In our code, we call this transition constraint `PermutationConstraint`. When implementing its corresponding `evaluate()` function (link), the use of this equation can be seen:
    
    fn evaluate(
        &self,
        frame: &Frame<F, F>,
        transition_evaluations: &mut [FieldElement<F>],
        _periodic_values: &[FieldElement<F>],
        rap_challenges: &[FieldElement<F>],
    ) {
        let first_step = frame.get_evaluation_step(0);
        let second_step = frame.get_evaluation_step(1);
    
        let p0 = first_step.get_aux_evaluation_element(0, 0);
        let p1 = second_step.get_aux_evaluation_element(0, 0);
        let z = &rap_challenges[0];
        let alpha = &rap_challenges[1];
        let a1 = second_step.get_main_evaluation_element(0, 0);
        let v1 = second_step.get_main_evaluation_element(0, 1);
        let a_sorted_1 = second_step.get_main_evaluation_element(0, 2);
        let v_sorted_1 = second_step.get_main_evaluation_element(0, 3);
    
        let res = (z - (a_sorted_1 + alpha * v_sorted_1)) * p1
            - (z - (a1 + alpha * v1)) * p0;
    
        transition_evaluations[self.constraint_idx()] = res;
    }
    

## Summary

By introducing sorted columns and auxiliary columns, we reduce the problem of validating a continuous read-only memory to proving three simpler constraints:

        * Continuity that ensures all memory addresses form a complete range.
        * Single-Value that ensures each address always returns the same value.
        * Permutation that ensures the sorted columns are permutations of the original columns.

These constraints demonstrate the simplicity of STARKs in encoding complex relationships as polynomial equations.
