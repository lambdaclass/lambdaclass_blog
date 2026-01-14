+++
title = "LogUp lookup argument and its implementation using Lambdaworks for continuous read-only memory"
date = 2024-12-27
slug = "logup-lookup-argument-and-its-implementation-using-lambdaworks-for-continuous-read-only-memory"

[extra]
feature_image = "/content/images/2025/12/Carl_Blechen_007.jpg"
authors = ["LambdaClass"]
+++

## Introduction

In a [previous post](/continuous-read-only-memory-constraints-an-implementation-using-lambdaworks/), we explained how to define constraints for a **continuous read-only memory** , presenting it as an example to understand how constraints are defined in general. This time, we will continue digging into this example to introduce the [LogUp](https://eprint.iacr.org/2022/1530) construction, adapted to univariate polynomials, and explain how we implemented it.

In what follows, we will assume that you have a notion of the concepts of constraints, a continuous read-only memory, and an idea of how they are implemented. To go deeper into these topics, we recommend reading the previously mentioned post, as this one will be its continuation.

## What is LogUp?

LogUp is a case of a **Lookup Argument**. But what exactly are lookup arguments? They serve as a tool that allows us to prove efficiently that a specific value $v$ belongs to a table of values $T$ without revealing the entire table. This concept is handy for improving the efficiency of arguments for statements that are otherwise quite expensive to arithmetize.

In essence, a lookup argument enables the prover to convince the verifier that every element of a given set $A$ (often represented as a column of a trace table) is contained within another set $T$ (the lookup table). In this way, instead of having to arithmetize many constraints to ensure that $A$ satisfies certain conditions and is in a certain way, we precompute all the valid values that $A$ can have, write them in the table $T$ and then use a lookup argument to prove that all the elements of $A$ belong to $T$ (i.e., they are valid elements). In other words, we achieve to verify the relationship between data while preserving privacy or optimizing computation.

An example of a Lookup argument can be found in the [post mentioned above](/continuous-read-only-memory-constraints-an-implementation-using-lambdaworks/). Let's quickly check what we did there: given two columns, $a$ (addresses) and $v$ (values), we needed to create their corresponding sorted columns $a'$ and $v'$. We used a Lookup argument known as **Grand Product** to prove that they were permutations of the original ones.  
Using two random elements $z$ and $\alpha$, sampled from an extension of $\mathbb{F}$, we constructed an auxiliary column $p$ using:

$$p_{i + 1} = p_i \cdot \frac {z - (a_{i + 1} + \alpha v_{i + 1})} {z - (a^\prime_{i + 1} + \alpha v^\prime_{i + 1})},$$

The goal was to verify that the last element of this column equals one:

$$p_{n - 1} = \prod_{i = 0}^{n - 1} \frac {z - (a_i + \alpha v_i)} {z - (a^\prime_i + \alpha v^\prime_i)} = 1.$$

This guarantees that $a'$ and $v'$ are permutations of $a$ and $v$, ensuring the correctness of the table.

The idea behind **LogUp** is to replace these products with their **logarithmic derivatives** , or more simply, to transform the product into a sum of fractions. This approach reduces the computational effort for both the prover and the verifier. The method gets its name because the logarithmic derivative converts products like $\prod_{i = 1}^n X - y_i$ into sums:

$$\sum_{i = 1}^n \frac{1}{X - y_i}.$$

So, suppose we have a column $a = (a_0, \ldots, a_n)$ from the main trace containing repeated elements and a column $t = (t_0, \ldots, t_m)$ from the lookup table without duplicates, and we want to demonstrate that all the elements of $a$ belong to $t$. In that case, it is enough to prove the equality:

$$\sum_{i = 0}^n \frac{1}{\alpha - a_i} = \sum_{i = 0}^m \frac{m_i}{\alpha - t_i}$$

where $\alpha$ is a random element, and $m_i$ is the multiplicity of $t_i$ in $a$, that is, the number of times $t_i$ appears in $a$.

A natural question might arise at this point: is it still more efficient to replace products with sums, mainly since doing so introduces fractions? We won’t work directly with these fractions, as we'll see later. Instead, we’ll multiply both sides of the equation by the common denominator.

## Continuous read-only memory example

To understand how the constraints of a LogUp argument are written, let's go back to our example of a continuous read-only memory. To follow this example, we recommend accompanying it with the corresponding [implementation made in Lambdaworks](https://github.com/lambdaclass/lambdaworks/blob/logup-mem-example/provers/stark/src/examples/read_only_memory_logup.rs).

### Main Trace

First of all, we need to understand how the columns of the main trace are defined in the case of wanting to use a LogUp argument. We will proceed similarly to what we did in the first post. Given the address column $a$ and the value column $v$ of our memory, we will add three additional columns to the main trace: $a',$ $v'$, and $m$. The $a'$ and $v'$ columns will contain the same values as $a$ and $v$ but will be sorted in ascending order without duplicating values. The column $m$ will represent the multiplicity of these values in the original columns. Since these columns do not have duplicates, they will be smaller. To ensure all columns have the same length and fit into a single table, we will pad $a'$ and $v'$ by repeating their last value and assigning a multiplicity of $0$ to these padded rows in the $m$ column.

Let's see an example. If our original table was:

$a$ | $v$  
---|---  
3 | 30  
2 | 20  
2 | 40  
3 | 30  
1 | 10  
3 | 30  
  
The main trace would become:

$a$ | $v$ | $a'$ | $v'$ | $m$  
---|---|---|---|---  
3 | 30 | 1 | 10 | 2  
2 | 20 | 2 | 20 | 1  
2 | 40 | 2 | 40 | 1  
3 | 30 | 3 | 30 | 2  
1 | 10 | 3 | 30 | 0  
1 | 10 | 3 | 30 | 0  
  
Notice that the original table does not represent a valid read-only memory (since address 2 has two different values, 20 and 40), we can still construct the main trace. Later, the `SingleValueConstraint` transition constraint will ensure that such tables are invalid.

In our implementation, the function `read_only_logup_trace()` handles the construction of the main trace. It returns a `TraceTable` containing the five main columns described above and an auxiliary column initially filled with zeros, which will later be replaced with the appropriate values.
    
    /// Return a trace table with an auxiliary column full of zeros (that will be then replaced with the correct values by the air) and
    /// and the following five main columns: 
    /// The original addresses and values, the sorted addresses and values without duplicates, and
    /// the multiplicities of each sorted address and value in the original ones (i.e., how many times they appear in the original address and value columns).
    pub fn read_only_logup_trace<
        F: IsPrimeField + IsFFTField + IsSubFieldOf<E> + Send + Sync,
        E: IsField + Send + Sync,
    >(
        addresses: Vec<FieldElement<F>>,
        values: Vec<FieldElement<F>>,
    ) -> TraceTable<F, E> {
        // We order the addresses and values.
        let mut address_value_pairs: Vec<_> = addresses.iter().zip(values.iter()).collect();
        address_value_pairs.sort_by_key(|(addr, _)| addr.representative());
        
        //We define the main columns that will be added to the original ones 
        let mut multiplicities = Vec::new();
        let mut sorted_addresses = Vec::new();
        let mut sorted_values = Vec::new();
    
        for (key, group) in &address_value_pairs.into_iter().group_by(|&(a, v)| (a, v)) {
            let group_vec: Vec<_> = group.collect();
            multiplicities.push(FieldElement::<F>::from(group_vec.len() as u64));
            sorted_addresses.push(key.0.clone());
            sorted_values.push(key.1.clone());
        }
    
        // We resize the sorted addresses and values with the last value of each one so they have the
        // same number of rows as the original addresses and values. However, their multiplicity should be zero.
        sorted_addresses.resize(addresses.len(), sorted_addresses.last().unwrap().clone());
        sorted_values.resize(addresses.len(), sorted_values.last().unwrap().clone());
        multiplicities.resize(addresses.len(), FieldElement::<F>::zero());
    
        let main_columns = vec![
            addresses.clone(),
            values.clone(),
            sorted_addresses,
            sorted_values,
            multiplicities,
        ];
    
        // We create a vector of the same length as the main columns full with zeros from de field extension and place it as the auxiliary column.
        let zero_vec = vec![FieldElement::<E>::zero(); main_columns[0].len()];
        TraceTable::from_columns(main_columns, vec![zero_vec], 1)
    }
    

### Auxiliary Trace

Now, let’s see how to construct the auxiliary column. The auxiliary column, which we’ll call $s$, should accumulate the sums of the fractions corresponding to each row of the main table as follows:

$$ \begin{align} s_0 &= \frac {m_0} {z - (a^\prime_0 + \alpha v^\prime_0)} - \frac {1} {z - (a_0 + \alpha v_0)},  
\ \newline  
s_1 &= s_0 + \frac { m_1 } {z - (a^\prime_1 + \alpha v^\prime_1)} - \frac {1} {z - (a_1 + \alpha v_1)} \end{align}$$

And so on, obtaining:

$$s_{i + 1} = s_i + \frac {m_{i + 1}} {z - (a^\prime_{i + 1} + \alpha v^\prime_{i + 1})} - \frac {1} {z - (a_{i + 1} + \alpha v_{i + 1})} \text{ with } i \in {0, \ldots, n - 2}.$$

As an example, if our main trace was:

$a$ | $v$ | $a'$ | $v'$ | $m$  
---|---|---|---|---  
3 | 30 | 1 | 10 | 1  
1 | 10 | 2 | 20 | 2  
2 | 20 | 3 | 30 | 1  
2 | 20 | 3 | 30 | 0  
  
Then, our auxiliary column trace $s$ would look like this:

$a$ | $v$ | $a'$ | $v'$ | $m$ | $s$  
---|---|---|---|---|---  
3 | 30 | 1 | 10 | 1 | $\frac {1} {z - (1 + \alpha 10)} - \frac {1} {z - (3 + \alpha 30)}$  
1 | 10 | 2 | 20 | 2 | $s_0 + \frac {2} {z - (2 + \alpha 20)} - \frac {1} {z - (1 + \alpha 10)}$  
2 | 20 | 3 | 30 | 1 | $s_1 + \frac {1} {z - (3 + \alpha 30)} - \frac {1} {z - (2 + \alpha 20)}$  
2 | 20 | 3 | 30 | 0 | $s_2 + \frac {0} {z - (3 + \alpha 30)} - \frac {1} {z - (2 + \alpha 20)}$  
  
Observe that if the main trace indeed represents a permutation with multiplicities, then the last element of $s$ (that is $s_{n - 1}$) should reflect the accumulation of all sums, canceling each other out and resulting in $0$ (i.e. $s_{n - 1} = 0$). This is analogous to what happens with the Grand Product, where we verify that the final product cancels out and results in 1 (i.e. $p_{n - 1} = 1$). Let's see this in the context of the example from the table above:

$$ \begin{align}  
s_{n - 1} &= {\style{color: orange} {\frac {1} {z - (1 + \alpha 10)}}} - \style{color: cyan} {\frac {1} {z - (3 + \alpha 30)}}  
\newline  
&\+ \style{color: magenta} {\frac {2} {z - (2 + \alpha 20)}} - {\style{color: orange} {\frac {1} {z - (1 + \alpha 10)}}}  
\newline  
&\+ \style{color: cyan} {\frac {1} {z - (3 + \alpha 30)}} - \style{color: magenta} {\frac {1} {z - (2 + \alpha 20)}}  
\newline  
&\+ \frac {0} {z - (3 + \alpha 30)} - \style{color: magenta} {\frac {1} {z - (2 + \alpha 20)}}  
\ \newline  
&= 0  
\end{align}  
$$

Now, let’s see how this is implemented in our code. In Lambdaworks, the construction of the auxiliary trace is handled within the AIR implementation. Specifically, in the implementation of `LogReadOnlyRAP`, you can find the following function `build_auxiliary_trace()`:
    
    fn build_auxiliary_trace(
        &self,
        trace: &mut TraceTable<Self::Field, Self::FieldExtension>,
        challenges: &[FieldElement<E>],
    ) where
        Self::FieldExtension: IsFFTField,
    {
        // Main table
        let main_segment_cols = trace.columns_main();
        let a = &main_segment_cols[0];
        let v = &main_segment_cols[1];
        let a_sorted = &main_segment_cols[2];
        let v_sorted = &main_segment_cols[3];
        let m = &main_segment_cols[4];
    
        // Challenges
        let z = &challenges[0];
        let alpha = &challenges[1];
    
        let trace_len = trace.num_rows();
        let mut aux_col = Vec::new();
    
        // s_0 = m_0/(z - (a'_0 + α * v'_0) - 1/(z - (a_0 + α * v_0)
        let unsorted_term = (-(&a[0] + &v[0] * alpha) + z).inv().unwrap();
        let sorted_term = (-(&a_sorted[0] + &v_sorted[0] * alpha) + z).inv().unwrap();
        aux_col.push(&m[0] * sorted_term - unsorted_term);
    
        // Apply the same equation given in the permutation transition constraint to the rest of the trace.
        // s_{i+1} = s_i + m_{i+1}/(z - (a'_{i+1} + α * v'_{i+1}) - 1/(z - (a_{i+1} + α * v_{i+1})
        for i in 0..trace_len - 1 {
            let unsorted_term = (-(&a[i + 1] + &v[i + 1] * alpha) + z).inv().unwrap();
            let sorted_term = (-(&a_sorted[i + 1] + &v_sorted[i + 1] * alpha) + z)
                .inv()
                .unwrap();
            aux_col.push(&aux_col[i] + &m[i + 1] * sorted_term - unsorted_term);
        }
    
        for (i, aux_elem) in aux_col.iter().enumerate().take(trace.num_rows()) {
            trace.set_aux(i, 0, aux_elem.clone())
        }
    }
    

### Transition constraints

Now, let’s look at how we should define the transition constraints for a continuous read-only memory using LogUp. The first two transition constraints explained in the previous post remain unchanged. That is, we don’t need to make any modifications to `ContinuityConstraint` and `SingleValueConstraint`, as the method for verifying that the memory is read-only and continuous using the $a'$ and $v'$ columns remains the same.

However, modifying the third constraint, called `PermutationConstraint` is essential. This constraint ensures that the auxiliary column $s$ is constructed correctly. It must be checked that $s_i$ satisfies the equation mentioned before:

$$s_{i+1} = s_i + \frac {m_{i+1}} {z - (a^\prime_{i + 1} + \alpha v^\prime_{i + 1})} - \frac {1} {z - (a_{i+1} + \alpha v_{i+1})} \text{ with } i \in {0, \ldots, n - 2}.$$

Since constraints must be expressed without division, we will multiply both sides of the equality by the common denominator. This transforms the constraint into the following form:

$$\begin{align}s_{i+1} &\cdot (z - (a^\prime_{i+1} + \alpha v^\prime_{i+1})) \cdot (z - (a_{i+1} + \alpha v_{i+1})) =  
\ \newline  
&=s_i \cdot (z - (a^\prime_{i+1} + \alpha v^\prime_{i+1})) \cdot (z - (a_{i+1} + \alpha v_{i+1}))  
\ \newline  
&\+ m_{i+1} \cdot (z - (a_{i+1} + \alpha v_{i+1}))  
\ \newline  
&\- (z - (a^\prime_{i+1} + \alpha v^\prime_{i+1}))  
\end{align}$$

Additionally, we will move the left-hand side of the equality to the right, subtracting it so that it can be interpreted as a polynomial in the variables $s$, $a$, $a'$, $v$ and $v'$ that is equal to zero:

$$\begin{align} 0 &=s_i \cdot (z - (a^\prime_{i+1} + \alpha v^\prime_{i+1})) \cdot (z - (a_{i+1} + \alpha v_{i+1}))  
\ \newline  
&\+ m_{i+1} \cdot (z - (a_{i+1} + \alpha v_{i+1}))  
\ \newline  
&\- (z - (a^\prime_{i+1} + \alpha v^\prime_{i+1}))  
\ \newline  
&\- s_{i+1} \cdot (z - (a^\prime_{i+1} + \alpha v^\prime_{i+1})) \cdot (z - (a_{i+1} + \alpha v_{i+1}))  
\end{align}$$

This equation can be found inside the function `evaluate()` in the implementation of `PermutationConstraint`. It is worth mentioning that both the prover and verifier must evaluate the polynomial constraint in the same way. However, we are forced to separate this evaluation into two cases because the `frames` used by each one are of different types.
    
    fn evaluate(
        &self,
        evaluation_context: &TransitionEvaluationContext<F, E>,
        transition_evaluations: &mut [FieldElement<E>],
    ) {
        // In both evaluation contexts, Prover and Verfier will evaluate the transition polynomial in the same way.
        // The only difference is that the Prover's Frame has base field and field extension elements,
        // while the Verfier's Frame has only field extension elements.
        match evaluation_context {
            TransitionEvaluationContext::Prover {
                frame,
                periodic_values: _periodic_values,
                rap_challenges,
            } => {
                let first_step = frame.get_evaluation_step(0);
                let second_step = frame.get_evaluation_step(1);
    
                // Auxiliary frame elements
                let s0 = first_step.get_aux_evaluation_element(0, 0);
                let s1 = second_step.get_aux_evaluation_element(0, 0);
    
                // Challenges
                let z = &rap_challenges[0];
                let alpha = &rap_challenges[1];
    
                // Main frame elements
                let a1 = second_step.get_main_evaluation_element(0, 0);
                let v1 = second_step.get_main_evaluation_element(0, 1);
                let a_sorted_1 = second_step.get_main_evaluation_element(0, 2);
                let v_sorted_1 = second_step.get_main_evaluation_element(0, 3);
                let m = second_step.get_main_evaluation_element(0, 4);
    
                let unsorted_term = -(a1 + v1 * alpha) + z;
                let sorted_term = -(a_sorted_1 + v_sorted_1 * alpha) + z;
    
                // We are using the following LogUp equation:
                // s1 = s0 + m / sorted_term - 1/unsorted_term.
                // Since constraints must be expressed without division, we multiply each term by sorted_term * unsorted_term:
                let res = s0 * &unsorted_term * &sorted_term + m * &unsorted_term
                    - &sorted_term
                    - s1 * unsorted_term * sorted_term;
    
                // The eval always exists, except if the constraint idx was incorrectly defined.
                if let Some(eval) = transition_evaluations.get_mut(self.constraint_idx()) {
                    *eval = res;
                }
            }
    
            TransitionEvaluationContext::Verifier {
                frame,
                periodic_values: _periodic_values,
                rap_challenges,
            } => {
                let first_step = frame.get_evaluation_step(0);
                let second_step = frame.get_evaluation_step(1);
    
                // Auxiliary frame elements
                let s0 = first_step.get_aux_evaluation_element(0, 0);
                let s1 = second_step.get_aux_evaluation_element(0, 0);
    
                // Challenges
                let z = &rap_challenges[0];
                let alpha = &rap_challenges[1];
    
                // Main frame elements
                let a1 = second_step.get_main_evaluation_element(0, 0);
                let v1 = second_step.get_main_evaluation_element(0, 1);
                let a_sorted_1 = second_step.get_main_evaluation_element(0, 2);
                let v_sorted_1 = second_step.get_main_evaluation_element(0, 3);
                let m = second_step.get_main_evaluation_element(0, 4);
    
                let unsorted_term = z - (a1 + alpha * v1);
                let sorted_term = z - (a_sorted_1 + alpha * v_sorted_1);
    
                // We are using the following LogUp equation:
                // s1 = s0 + m / sorted_term - 1/unsorted_term.
                // Since constraints must be expressed without division, we multiply each term by sorted_term * unsorted_term:
                let res = s0 * &unsorted_term * &sorted_term + m * &unsorted_term
                    - &sorted_term
                    - s1 * unsorted_term * sorted_term;
    
                // The eval always exists, except if the constraint idx was incorrectly defined.
                if let Some(eval) = transition_evaluations.get_mut(self.constraint_idx()) {
                    *eval = res;
                }
            }
        }
    }
    

Another noteworthy change is that the polynomial associated with this constraint is now of degree 3. This is easy to understand if we observe that in the zero-equality equation mentioned earlier, there are terms containing the product of three factors, resulting in three variables multiplied together.

It’s worth highlighting that, up until now, both in the previous post and in the other two transition constraints, we had only worked with polynomials of degree 2. This change is reflected in the code in two places. First, we must specify the degree of a transition constraint when defining it:
    
    impl<F, E> TransitionConstraint<F, E> for PermutationConstraint<F, E>
    where
        F: IsSubFieldOf<E> + IsFFTField + Send + Sync,
        E: IsField + Send + Sync,
    {
        fn degree(&self) -> usize {
            3
        }
        
        // ...
    }
    

In the second place, when implementing the AIR, we must specify the degree bound of the composition polynomial. In previous implementations, this number was set equal to the length of the trace. However, it is important to make it twice as large in this case. This ensures that when the prover defines the composition polynomial, she can split it into two parts. If we didn’t do this, the prover and verifier would work with the entire composition polynomial without splitting it, increasing the number of FRI rounds (optimization)
    
    fn composition_poly_degree_bound(&self) -> usize {
        self.trace_length() * 2
    }
    

### Boundary Constraints

Finally, let’s discuss how to define the boundary constraints. All boundary constraints related to the main trace will remain the same: we need to ensure that $a_0$, $a^\prime_0$, $v_0$, and $v^\prime_0$ match the values specified in the public inputs. Additionally, we need to include one more constraint to verify that $m_0$ is correctly defined according to the value described in the public input.

Now, the constraints on the auxiliary trace will change slightly compared to those used in the Grand Product. Following the same logic as we did that time, we must ensure, on one hand, that the first element of the auxiliary column $s$ is correctly constructed—that is, $s_0$ satisfies the equation described earlier in the _Auxiliary Trace_ section. On the other hand, we need to check that the last element $s_{n-1}$ equals zero, ensuring that all terms cancel out and verifying that the trace corresponds to a permutation.
    
    fn boundary_constraints(
        &self,
        rap_challenges: &[FieldElement<Self::FieldExtension>],
    ) -> BoundaryConstraints<Self::FieldExtension> {
        let a0 = &self.pub_inputs.a0;
        let v0 = &self.pub_inputs.v0;
        let a_sorted_0 = &self.pub_inputs.a_sorted_0;
        let v_sorted_0 = &self.pub_inputs.v_sorted_0;
        let m0 = &self.pub_inputs.m0;
        let z = &rap_challenges[0];
        let alpha = &rap_challenges[1];
    
        // Main boundary constraints
        let c1 = BoundaryConstraint::new_main(0, 0, a0.clone().to_extension());
        let c2 = BoundaryConstraint::new_main(1, 0, v0.clone().to_extension());
        let c3 = BoundaryConstraint::new_main(2, 0, a_sorted_0.clone().to_extension());
        let c4 = BoundaryConstraint::new_main(3, 0, v_sorted_0.clone().to_extension());
        let c5 = BoundaryConstraint::new_main(4, 0, m0.clone().to_extension());
    
        // Auxiliary boundary constraints
        let unsorted_term = (-(a0 + v0 * alpha) + z).inv().unwrap();
        let sorted_term = (-(a_sorted_0 + v_sorted_0 * alpha) + z).inv().unwrap();
        let p0_value = m0 * sorted_term - unsorted_term;
    
        let c_aux1 = BoundaryConstraint::new_aux(0, 0, p0_value);
        let c_aux2 = BoundaryConstraint::new_aux(
            0,
            self.trace_length - 1,
            FieldElement::<Self::FieldExtension>::zero(),
        );
    
        BoundaryConstraints::from_constraints(vec![c1, c2, c3, c4, c5, c_aux1, c_aux2])
    }
    

## Summary

In this post, we explore the lookup argument method LogUp, using the example of a continuous read-only memory explained in a previous post. By changing the construction of some columns of the trace table, the permutation transition constraint, and some other small details, we adapted the implementation we already had for that same example using this new method.
