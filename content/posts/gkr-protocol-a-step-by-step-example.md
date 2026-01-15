+++
title = "GKR protocol: a step-by-step example"
date = 2025-03-05
slug = "gkr-protocol-a-step-by-step-example"

[extra]
feature_image = "/images/2025/12/Battle_poitiers.jpg"
authors = ["LambdaClass"]
+++

## Introduction

An interactive proof is a protocol between two parties, a prover $\mathcal{P}$ and a verifier $\mathcal{V}$, where the prover attempts to convince the verifier of the validity of a statement. By leveraging randomness and interaction, the verifier can check the statement more efficiently than by doing everything himself. There is always a trivial way in which we can verify a computation: re-execution. This is how blockchains achieve verifiability: each node re-executes transactions and then reaches consensus. However, this is inefficient since every node must repeat the same computations, leading to bottlenecks. Succinct proofs allow us to check computations much faster, avoiding re-execution and solving blockchain scalability issues. For an introduction to interactive proof systems, see [Thaler](https://people.cs.georgetown.edu/jthaler/ProofsArgsAndZK.pdf). One such protocol is the sum-check protocol, proposed by Lund, Fortnow, Karloff, and Nisan in 1992, which is one of the building blocks used by several proof systems.

The [GKR protocol](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/12/2008-DelegatingComputation.pdf) (Goldwasser–Kalai–Rothblum) extends the idea of the [sum-check protocol](/have-you-checked-your-sums/) for efficient verification of arithmetic circuits. The protocol allows a verifier to check that a computation—expressed as a logarithmic‐depth circuit with low-degree gates—has been executed correctly. This is achieved with only $O(\log⁡(n))$ rounds of interaction and a total of $O(\text{poly} \log(n))$ operations.

The key idea of the GKR protocol is that instead of evaluating the entire circuit, it uses the [sum-check](https://people.cs.georgetown.edu/jthaler/sumcheck.pdf) protocol recursively to verify the partial sums that represent the computed value efficiently. This method enables a resource-limited verifier to check computations far larger than what they could perform on their own by leveraging the underlying algebraic structure of the problem. The advantage of the GKR protocol is that one avoids having to commit to intermediate results in the circuit, which is usually the expensive part of many proof systems.

This post will explain how the protocol works with an example. For additional explanations on the protocol, we recommend watching doubly efficient interactive proofs [part 1](https://www.youtube.com/watch?v=db1xAyO4YgM&list=PLUl4u3cNGP61EZllk7zwgvPbI4kbnKhWz&index=3) and [part 2](https://www.youtube.com/watch?v=Ob1fFHAXlJQ&list=PLUl4u3cNGP61EZllk7zwgvPbI4kbnKhWz&index=4) or reading [Thaler's book](https://people.cs.georgetown.edu/jthaler/ProofsArgsAndZK.pdf) or this [short note](https://65610.csail.mit.edu/2024/lec/l12-gkr.pdf). The GKR protocol is used to improve the [LogUp lookup argument](https://eprint.iacr.org/2023/1284). You can take a look at the implementation in [Stwo](https://github.com/starkware-libs/stwo/tree/dev/crates/prover/src/core/lookups).

## Protocol

The goal of this post is to explain the protocol in detail. To do so, we will use a simple example and follow, step by step, everything that both the prover($\mathcal{P}$) and the verifier ($\mathcal{V}$) do.
    
    Note: We will consider the interactive version of the protocol. 
    You can turn it into a non-interactive protocol with the Fiat-Shamir
    transformation. 
    

Let’s begin by describing the computation we wish to prove. We must express the computation as a log-space uniform arithmetic circuit $\mathcal{C}$ of fan-in 2 over a finite field $\mathbb{F}_p$. This means that:

        * The circuit has only two types of gates: addition and multiplication.
        * It is layered so that each gate is connected to only two gates in the previous layer (possibly the same gate).
        * In each layer $i$, the number of gates is $S_i = 2^{k_i}$ where $k_i \in \mathbb{N}$
        * All values are elements of $\mathbb{F_{p}}$

> Let's build a circuit that meets these conditions:  
>  ![circuit_gkr](/images/external/ByBJecQFkl.png)  
>  Figure 1: Diagram of the arithmetic circuit used in the GKR protocol example.
> 
> This circuit models a program that has 2 inputs and two outputs, and we work over the field $\mathbb{F_{23}}$.

#### **The final goal of the protocol is for the prover to provide the outputs of the program to the verifier and convince the verifier that these outputs were computed correctly from the public inputs.**

Recall that both the circuit and the inputs are public.

## Part One: Sharing the Results

We can divide this into several steps:

        1. Output Claim:

The prover $\mathcal{P}$ sends the verifier $\mathcal{V}$ the values claimed to be the circuit outputs. _These values are sent in the form of a function_ $D: {0,1}^{ k_0 } \to \mathbb{F_{p}}$.

> For our example: $k_0 = 1$, so $\mathcal{P}$ sends the linear polynomial $D$ satisfying:
> 
> $$D(0) = 18$$ $$D(1) = 7$$

        2. Random Challenge:

A key resource we’ll use frequently in the protocol is having the verifier select a random point and send it to the prover. The prover must then incorporate this point into their calculations. This prevents the prover from precomputing results and trying to deceive the verifier.

$\mathcal{V}$ picks a random $r_0 \in \mathbb{F}^{ k_0 }$ and send it to $\mathcal{P}$.

> Let's pick $r_0 = 2$

        3. Computing the Multilinear Extension:

Both $\mathcal{V}$ and $\mathcal{P}$ compute $\tilde D(r_0)$, where $\tilde D({x})$ is the multilinear extension of $D$. This is the unique multilinear polynomial over $\mathbb{F_{p}}$ satisfying:  
$$\tilde D(x) = f(x) \ \forall x \in {0, 1}^v$$

This is a $v-$variate polynomial over $\mathbb{F_{p}}$ where $\tilde D({x})$ agrees with $D({x})$ at all boolean-valued (or bitstrings of a given length) inputs. It acts as a distance-amplifying encoding of $D({x})$ because, if another function $D'({x})$ disagrees at even a single input, the extension $\tilde D({x})$ will differ with $\tilde D'({x})$ at almost every point outside the original domain. This is a consequence of the [Schwartz-Zippel lemma](https://en.wikipedia.org/wiki/Schwartz%E2%80%93Zippel_lemma), which states that the probability of choosing a zero of a polynomial at random is $v / \lvert \mathbb{F_p} \rvert$ (which is negligible for a sufficiently large field).

Using Lagrange interpolation, we have:  
$$\tilde f (x_1, \ldots, x_v) = \sum_{w \in {0, 1}^v} f(w) \cdot \chi_w(x_1, \ldots, x_v)$$

where $\chi_w$ are the (multilinear) Lagrange basis polynomials: $$\chi_w(x_1, \ldots, x_v) = \prod_{i = 1}^{v} (x_i \cdot w_i + (1-x_i)(1-w_i))$$

> In our case (with $k_0=1$):
> 
> $$\begin{align} \tilde D(x) &= D(0) : (x \cdot 0 + (1-x)(1-0)) + D(1) : (x \cdot 1 (1 - x)(1 - 1)) \\  
>  &= D(0)\cdot(1-x) + D(1) \cdot x= 18(1-x)+7x\end{align}$$
> 
> Thus:
> 
> $$\tilde D(r_0) = \tilde D(2) = -4 \equiv 19 \text{ mod } (23)$$
> 
> We denote this value by:
> 
> $$\tilde D(r_0) = 19 = m_0.$$

Now, we can see that verifying the program's outputs comes down to checking that:  
$$m_0 = \tilde W_0(r_0)$$

* * *

Before continuing, let's introduce an additional notation. For each layer $i$ of the circuit, we will denote

$$W_i: \{0,1\}^{ k_i } \to \mathbb{F_{p}}$$

to be the function that maps a node’s position to its actual value, let $\tilde W_i(x)$ be its multilinear extension.

> ![Screenshot 2025-02-07 at 5.09.49 PM](/images/external/B1M6_kEtkx.png)

With this notation, the verifier’s task can be seen as checking that

$$D(x) = W_0(x)$$

since $D(x)$ represents the claimed outputs and $W_0(x)$ represents the correct values. Because multilinear extensions are unique, this is equivalent to verifying that:

$$\tilde D(x) = \tilde W_0(x)$$

Finally, by the Schwartz-Zippel lemma, it suffices to check that

$$\tilde D(r_0) = \tilde W_0(r_0)$$

**But wait! The verifier cannot directly access $W(x)$. That is precisely the point of the protocol!**

## Part Two: Modeling the circuit

In this phase, the goal is to verify that the sum of many terms (corresponding to a node's computed value) equals $m_0$.

To do this efficiently, we use the sum-check protocol.

#### Introducing the Wiring Functions

We define two functions that capture the circuit's wiring:

        * **Addition Function**.

This function marks all the addition nodes in layer $i$. It takes as input:

$$x \in \{0,1\}^{k_i + 2k_{i + 1}}$$

which encodes the position $a$ of an addition node in the current layer, along with the positions $b$ and $c$ of the two nodes in the next layer to which it is connected.

The function $\text{Add}_i$ is defined to be 1 when $x = (a,b,c)$ corresponds to a valid addition node with the proper inputs and zero otherwise.

Just like with $\tilde D(x)$, we will need to create the multilinear extension: $\widetilde{\text{Add}}_i(x)$.

> In our circuit:  
>  ![Screenshot 2025-02-07 at 5.15.38 PM](/images/external/SyIm5y4F1x.png)  
>  The output addition node is at position: $$a = (1)$$  
>  And is connected to nodes: $$b: (1,0) \ \ c: (1,1)$$  
>  Since this is the only addition node, we define the function:  
>  $$\text{Add_1}(x) \begin{cases}  
>  1 & \text{if } x = (1,1,0,1,1)\\  
>  0 & \text{if not}.  
>  \end{cases}$$  
>  We then extend this function to a multilinear polynomial, denoted $\widetilde{\text{Add}}_i(x)$:
> 
> $$\widetilde{\text{Add}}_1 (x_1, x_2, x_3, x_4, x_5) = x_1 \cdot x_2 \cdot (1 - x_3) \cdot x_4 \cdot x_5 $$

        * **Multiplication Function**.

Similarly, we define the function $\text{Mult}_0(x)$ for the multiplication nodes and its multilinear extension.

> For the Multiplication node in our first layer:  
>  $$\text{Mult_1}(x) \begin{cases}  
>  1 & \text{if } x = (0,0,0,0,1)\\  
>  0 & \text{if not}.  
>  \end{cases}$$  
>  Its multilinear extension is given by  
>  $$\widetilde{\text{Mult_1}}(x_1, x_2, x_3, x_4, x_5) = (1 - x_1) \cdot (1-x_2) \cdot (1 - x_3) \cdot (1 - x_4) \cdot x_5 $$

Finally, we need to connect these two new functions. For that, we can define a function that “computes” the value of a node in layer $i$ given the values in the next layer:

$$\tilde f^{(i)}(a,b,c) := \widetilde{\text{Add_i}}(a,b,c)\cdot(\tilde W_{i + 1}(b) + \tilde W_{i + 1}(c)) + \widetilde{\text{Mult_i}} \cdot \tilde W_{i + 1}(b) \cdot \tilde W_{i + 1}(c)$$

When this function is evaluated on the values $(a,b,c)$ corresponding to a node in layer $i$, it yields the value of that node.

> In our first layer:  
>  $$\tilde f^{(0)}(0,0,0,0,1) = 18$$ $$\tilde f^{(0)}(1,1,0,1,1) = 7$$

This function is handy, but we can go one step forward and fix $a = r$ and sum over all possible binary assignments for $b$ and $c$, we obtain:

$$\sum_{(b,c) \in \{0,1\}^{ 2k_i }} \tilde f^{(i)}(r,b,c) = \tilde W(r)$$

This new function is now a univariate polynomial!

Let us denote the function with $a$ fixed at $r$ as $\tilde f_r(b,c)^{(i)}$.

* * *

Let's go back a bit and not lose sight of the objective we had. We had reached the point where what we wanted to check was:  
$$\tilde D(r_0) = \tilde W(r_0)$$

or equivalently,

$$\tilde W(r_0) = m_0$$

So, with the new function $\tilde f$ we can think this as:

$$\sum_{(b,c) \in {0,1}^{2k_i}} \tilde f_{r_0}^{(0)}(b,c) = m_0$$

To verify this equality, which implies a lot of additions(operations), we will employ the Sum-Check protocol.

## Part Three: Sum-check

Let's describe, step by step, all the operations performed by the prover and the verifier during this phase to better understand the protocol.

        1. The prover $\mathcal{P}$ builds a new function $g_1(z)$:  
$$g_1(z): \mathbb{F_{p}} \to \mathbb{F_{p}}$$  
$$g_1(z) := \sum_{ (x_2, x_3, ... , x_{ 2k_1 }) \in \{0,1\}^{2k_1 - 1} } \tilde f_{r_0}^{(0)} (z, x_2, ..., x_{2k_1 - 1})$$

In other words, we leave the first coordinate of $x$ in $\tilde f_{r_0}^{(0)} (x)$ as the free variable $z$ and sum over all possible assignments of the remaining coordinates.

Observe that this function satisfies:

$$g_1(0) + g_1(1) = m_0$$

Because $g_1(0)$ sums over all combinations with the first coordinate set to 0, and $g_1(0)$ does so for the first coordinate equal to 1.

> In our case, since $k_1 = 2$ (i.e. there are $2^2$ nodes in layer 2), we have:  
>  $$g_1 (z) = \sum_{ (x_2, x_3, x_4) \in \{0, 1\}^3 } \tilde f_{r_0}^{(0)} (z, x_2, x_3, x_4).$$  
>  $$\begin{align}  
>  f_{ r_0 }^{(0)} (b, c) = & \ 2b_1 (1 - b_2) c_1 c_2 \Big[  
>  (3(1 - b_1)(1 - b_2) + 6(1 - b_1)b_2 + 4b_1(1 - b_2) + 3b_1b_2) \notag \\  
>  & \quad + (3(1 - c_1)(1 - c_2) + 6(1 - c_1)c_2 + 4c_1 (1 - c_2) + 3c_1 c_2 ) \Big] \notag \\  
>  & \- (1 - b_1)(1 - b_2)(1 - c_1)c_2 \notag \\  
>  & \Big[ (3(1 - b_1)(1 - b_2) + 6(1 - b_1)b_2 + 4b_1(1 - b_2) + 3b_1b_2 ) \notag \\  
>  & \quad \times (3(1 - c_1)(1 - c_2) + 6(1 - c_1)c_2 + 4c_1(1 - c_2) + 3c_1c_2) \Big]  
>  \end{align}  
>  $$  
>  Now we have to keep $b_1$ fixed and $b_1,c_1, c_2$ change

$b_2$ | $c_1$ | $c_2$  
---|---|---  
0 | 0 | 0  
0 | 0 | 1  
0 | 1 | 0  
0 | 1 | 1  
1 | 0 | 0  
1 | 0 | 1  
1 | 1 | 0  
1 | 1 | 1  
  
> Due to the multiplicative factors (for example, terms like  
>  $$2b_1(1 - b_2)c_1c_2$$  
>  vanish unless $(c_1 = c_2 = 1)$ in the first term, and similarly in the second term), most combinations will contribute zero. In our case, let’s assume that after substitution, the only nonzero contributions come from:
> 
>         * **Case 1:** When $(b_2, c_1, c_2) = (0, 1, 1)$
>         * **Case 2:** When $(b_2, c_1, c_2) = (0, 0, 1)$  
>  We now analyze these cases separately.

> Case 1: $(b_2, c_1, c_2) = (0, 1, 1)$  
>  $$2b_1 [3(1-b_1)+4b_1+3] \to 2x(x - 6)\to 2x^2 +12x$$  
>  Case 2: $(b_2, c_1, c_2) = (0, 0, 1)$  
>  $$-(1-b_1) [3(1 - b_1)+ 4b_1 ]6 \to -6(1 - x)(3 - 3x + 4x) \to (- 6 + 6x)(x + 3)$$  
>  The sum leads to:  
>  $$g_1(z) = 8z^2 + 24z - 18 \equiv 8z^2 + z - 18$$

The prover sends this polynomial (its low degree allows sending its coefficients directly) to the verifier.

The verifier checks two things:

        * That $g_1$ is indeed a low-degree polynomial.
        * That:

$$g_1(0) + g_1(1) = m_0.$$

> In our example: $$g_1(0) = -18$$ $$g_1(1) = 14$$ $$g_1(0) + g_1(1) = -4 \equiv 19 = m_0.$$

        2. The verifier $\mathcal{V}$ chooses a random value $s_1 \in \mathbb{F_{p}}$ and sends it to the prover $\mathcal{P}$ . The verifier also computes:

$$g_1(s_1) = C_1$$

> We can sample $s_1$ = 3: $$g_1(s_1) = g_1(3) = 8 \cdot 3^2 + 24 \cdot 3 - 18 = 126 \equiv 11.$$

        3. Upon receiving $s_1$, $\mathbb{F_{p}}$ computes $C_1$ and then repeats a similar procedure. The prover defines a new function:

$$g_2(z): \mathbb{F_{p}} \to \mathbb{F_{p}}$$  
$$g_2(z) := \sum_{(x_3, ... , x_{2k_1}) \in \{0,1\}^{2k_1 - 2}} \tilde f_{r_0}^{(0)} (s_1, z, x_3 ..., x_{ 2k_1 - 2})$$

Here, the prover fixes the first variable to $s_1$ and leaves the second variable free (denoted by $z$), summing over the remaining binary assignments.

> We have:  
>  $$g_2(z) = \sum_{(x_3, x_4) \in {0,1}^{2}} \tilde f_{ r_0 }^{(0)} (s_1, z, x_3, x_4)$$  
>  $$g_2(z) = 162x^2 - 288x + 126 \equiv x^2 - 12x + 11.$$

        4. The prover $\mathcal{P}$ sends the coefficients of $g_2(z)$ to the $\mathcal{V}$.

        5. The verifier checks that:

$$g_2(0) + g_2(1) = C_1$$

$$g_2(0) = 0$$

> We must check: $$g_2(1) = 11$$ $$g_2(0) + g_2(1) = 11$$

        6. This procedure is repeated until the verifier receives  
$C_{2k+1}$:

$$C_{ 2k + 1} := \tilde f_{ r_0 }^{(0)} (s_1, s_2, x_3 ..., s_{ 2k_{ i + 1}})$$

**This is the final step of the Sum-Check protocol.** At this point, the verifier would normally query an oracle to compute this value directly; however, in our protocol, the verifier can't evaluate the function directly.

The verifier can build $\widetilde{\text{Add}}$ and $\widetilde{\text{Mult_i}}$ but not to $\tilde W_{i+1}$, which represent the values of the nodes in the immediately preceding layer.

## What Have We Achieved?

In effect, we have reduced the problem of verifying the circuit’s outputs to verifying the values in one layer lower. This reduction is repeated layer by layer until the final layer is reached, which corresponds to the inputs the verifier already knows. This whole idea behind the protocol.

> Let's do the math for our example:
> 
>         * $\mathcal{V}$ samples $s_2 = 2$ and sends it to $\mathcal{P}$.
> 
>         * $\mathcal{V}$ and $\mathcal{P}$ calculate $C_2 = g_2(s_2)$:$$g_2(s_2) = g_2(2) = 2^2 - 12 \cdot 2 + 11 = -9 \equiv 14.$$
> 
>         * $\mathcal{P}$ calulates:$$g_3(z) = \sum_{x_4 \in {0,1}} \tilde {f_{ r_0 }^{(0)} (s_1, s_2, z, x_4)}$$ $$g_3(z) = 90x^2 - 180x + 144 \equiv 21x^2 - 19x + 6$$
> 
>         * $\mathcal{V}$ receives $g_3(z)$ and checks:$$g_3(0) = 8 $$ $$ g_3(1) = 6 $$ $$g_3(0) + g_3(1) = 14$$
> 
>         * $\mathcal{V}$ samples $s_3 = 4$ and sends it to $\mathcal{P}$.
> 
>         * $\mathcal{V}$ and $\mathcal{P}$ calculate $C_3 = g_3(s_3)$:  
>  $$g_3(s_3) = 21 \cdot 4^2 - 19 \cdot 4 + 6 = 266 \equiv 13$$
> 
>         * $\mathcal{P}$ calculates:  
>  $$g_4(z) = \tilde f_{r_0}^{(0)} (s_1, s_2, s_3, z)$$ $$g_4(z) = -288z^2 + 1152x \equiv 11z^2 + 2z$$
> 
>         * $\mathcal{V}$ receives $g_4(z)$ and checks:  
>  $$g_4(0) = 0$$ $$g_4(1) = 13 $$ $$g_4(0) + g_3(1) = 13$$
> 
>         * $\mathcal{V}$ samples $s_4 = 7$ and sends it to $\mathcal{P}$.
> 
>         * $\mathcal{V}$ and $\mathcal{P}$ calculate $C_4 = g_4(s_4)$:  
>  $$g_4(s_4) = 553 \equiv 1$$
> 
>         * $\mathcal{P}$ calulates  
>  $$\tilde f^{(0)}_{r_0}(s_1,s_2,s_3,s_4) = c_4$$  
>  $$\begin{equation}  
>  \begin{aligned}  
>  \tilde{f}^{(0)}(r_1,s_1,s_2,s_3,s_4) := & \\ \widetilde{\text{Add}}_1(r_1,s_1,s_2,s_3,s_4) \cdot (\tilde{W}_2(s_1,s_2) + \tilde{W}_2(s_3,s_4)) \\  
>  & \+ \widetilde{\text{Mult}}_1(r_1,s_1,s_2,s_3,s_4) \cdot \tilde{W}_2(s_1,s_2) \cdot \tilde{W}_2(s_3,s_4)  
>  \end{aligned}  
>  \end{equation}$$

## Part four: Recursion

We reached a stage where the verifier’s goal is to check that

$$\tilde f_{ r_0 }^{(0)} (s_1, s_2, x_3, ..., s_{2k_{i + 1}}) = C_1$$

However, to do so, the verifier would need to know:

$$\tilde W_2(s_1, s_2, ... , s_{k + 1})$$ $$\tilde W_2(s_{ k + 1}, ... , s_{ 2k + 1})$$

If the verifier were to perform two separate sum-checks for these values, the final workload would be excessive. Instead, the prover makes a single claim at one point. How?

Both parties compute the unique function

$$\ell: \mathbb{F} \to \mathbb{F}^{2k}$$

such that:

$$\ell(0) = (s_1, s_2, ... , s_{k+1})$$ $$\ell(1) = (s_{k + 1}, ... , s_{2k + 1})$$

Then $\mathcal{P}$ sends the function:  
$$q = \tilde W_2 \circ \ell : \mathbb{F} \to \mathbb{F}.$$

to the verifier. Notice that:

$$q(0) = \tilde W_2(s_1, s_2, ... , s_{k+1})$$ $$q(1) = \tilde W_2(s_{k+1}, ... , s_{2k+1})$$

Thus, by knowing $q(x)$, the verifier can recover the necessary values $q(0)$ and $q(1)$ to complete the final evaluation in the Sum-Check protocol.

So, with $q(x)$, $\mathcal{V}$ can use $q(0)$ and $q(1)$ to do the last evaluation in the sumcheck protocol.

But how does the verifier know that $q(x)$ is correct? Again, $\mathcal{V}$ samples a random element $r∗ \in \mathbb{F}$ and computes

$$r_1 = \ell (r^*)$$

Then, $\mathcal{P}$ and $\mathcal{V}$ compute:

$$m_1 = q(r_1)$$

Now, the prover’s task is to convince the verifier that:

$$\tilde W_2(r_1) = m_1$$

This claim is analogous to our initial verification step:

$$\tilde D(r_0) = m_0$$

where $\tilde D(x)$D encoded the output values and now $\tilde W_2(x)$ encodes the values of the nodes in the immediately preceding layer.

Thus, the remaining task is to apply the same Sum-Check protocol to this new layer.

> For our circuit:
> 
>         * $\mathcal{P}$ and $\mathcal{V}$ calculate:  
>  $$\ell(0) = (s_1, s_2) = (3, 2)$$ $$ \ell(1) = (s_3, s_4) = (4, 7)$$ $$\ell(x) = (s_1(1-x) + s_3x, s_2(1-x) + s_4x) = (3(1-x) + 4x, 2(1-x) + 7x).$$
>         * $\mathcal{P}$ sends $q= \tilde W_1 \circ \ell : \mathbb{F} \to \mathbb{F}.$  
>  $$q(x) = -20x^2 -52x - 12 \equiv 3x^2 + 17x + 11$$
>         * $\mathcal{V}$ checks $\tilde f_{r_0}^{(0)} (s_1, s_2, s_3, s_4) = c_4$ using $q(x)$
>         * $\mathcal{V}$ sends $\mathcal{P}$ a random $r^* \in \mathbb{F}$  
>  $$r^* = 6$$
>         * $\mathcal{V}$ and $\mathcal{P}$ calculate:  
>  $$r_1 = \ell (6) = (9, 32) \equiv (9,9)$$ $$m_1 = q(6) = 14.$$
>         * Now $\mathcal{P}$ needs to convice $\mathcal{V}$ that:  
>  $$\sum_{(b, c) : \in {0, 1}^{2 \cdot 1}} f_{r_1}^{(1)} (b, c) = m_1$$
>         * $\mathcal{P}$ calculates $g_1(z)$ and sends it to $\mathcal{V}$ :  
>  $$g_1(z) = \sum_{x_2 \in {0, 1}} f_{r_1}^{(1)} (z, x_2)$$ $$g_1(z) = 2z^2 + 7z + 14$$
>         * $\mathcal{V}$ checks $g_1(0) + g_1(1) = m_1$:  
>  $$ g_1(0) = 14 $$ $$ g_1(1) = 0 $$ $$ g_1(0) + g_1(1) = 14$$
>         * $\mathcal{V}$ samplse $s_1 = 12$ and sends it to $\mathcal{P}$.
>         * $\mathcal{V}$ and $\mathcal{P}$ calculates $C_1 = g_1(s_1)$:  
>  $$g_1(12) = 2 \cdot 12^2 + 7 \cdot 12 + 14 = 386 \equiv 18$$
>         * $\mathcal{P}$ calculates $g_2(z)$ and send it to $\mathcal{V}$:  
>  $$g_2(z) = \tilde f_{r_1}^{(1)} (s_1, z)$$ $$g_2(z) = 9z^2 + z +4$$
>         * $\mathcal{V}$ checks $g_2(0) + g_2(1) = C_1$:  
>  $$g_2(0) = 4$$ $$g_2 (1) = 14$$ $$ g_2(0) + g_2(1) = 18$$
>         * $\mathcal{V}$ samples $s_2 = 5$ and sends it to $\mathcal{P}$.
>         * $\mathcal{V}$ and $\mathcal{P}$ calculate $C_2 = g_2(s_2)$:  
>  $$C_2 = g_2(5) = 4$$
>         * $\mathcal{P}$ and $\mathcal{V}$ calculate:  
>  $$ \ell(0) = s_1 = 12$$ $$ \ell(1) = s_2 = 5$$ $$\ell(x) = -7x + 12$$
>         * $\mathcal{P}$ sends $q= \tilde W_1 \circ \ell : \mathbb{F} \to \mathbb{F}.$  
>  $$q(x) = 3(1 - (-7x + 12) ) + (-7x +12)$$
>         * $\mathcal{V}$ checks $f_{r_1}^{(1)}(s_1,s_2) = c_2$ using $q(x)$
>         * $\mathcal{V}$ sends $\mathcal{P}$ a random $r^* \in \mathbb{F}$  
>  $$r^* = 17$$
>         * $\mathcal{V}$ and $\mathcal{P}$ calculate:  
>  $$r_2 = \ell (17) = 8$$ $$m_2 = q(17) = 10$$
>         * Finally, $\mathcal{V}$ calculates $\tilde W_2(x)$ and checks $\tilde W_2(r_2) = m_2$  
>  $$W_2(0) = 3$$ $$W_2(1) = 1$$ $$\tilde W_2(x) = 3(1 - x) + x$$ $$\tilde W_2(8) = 10$$

## Last part: repeat

Well, everything is almost ready! We just need to repeat this procedure once per layer. Finally, $W_d(x)$ is the function that maps the program's inputs, which we will use to verify the sum-check of layer $d-1$. If this check is correct, it means that all the previous ones are also correct, so we can confidently say that the computation was executed correctly.

## Conclusion:

In summary, the GKR protocol elegantly reduces the problem of verifying the output of a complex arithmetic circuit into a series of simpler verifications that recursively move from the output layer to the input layer. Each step relies on algebraic properties—most notably, the uniqueness of multilinear extensions and the Schwartz–Zippel lemma—to ensure that a resource-limited verifier can efficiently confirm the correctness of the computation. This protocol illustrates the power of interactive proofs and lays the foundation for more advanced cryptographic applications such as zero-knowledge proofs.
