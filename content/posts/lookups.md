+++
title = "If you don't know, look it up or how to create lookup tables for zero knowledge proofs"
date = 2023-11-02
slug = "lookups"

[extra]
math = true
feature_image = "/images/2025/12/Hubert_Robert_-French_-_A_Hermit_Praying_in_the_Ruins_of_a_Roman_Temple_-_Google_Art_Project.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["cryptography"]
+++

## Introduction

ZK-SNARKs (zero-knowledge succinct, non-interactive arguments of knowledge) and STARKs (scalable transparent arguments of knowledge) are powerful cryptographic constructions with applications in decentralized private computing and blockchain scaling. They allow one party, the prover, to show that he carried a computation correctly to a second party, the verifier, in a way that is both memory and time-efficient. In other words, the prover can submit a short proof (more concise than sending all the values involved in the calculation), which can be verified in less time than we would need for the independent re-execution of the computation. These constructions rely on encoding the information as polynomials, committing to them (via a polynomial commitment scheme, such as FRI or KZG), and showing that certain relationships hold between polynomials. For an introduction to these concepts, see our previous posts on [STARKs](/diving-deep-fri/), [Plonk](/all-you-wanted-to-know-about-plonk/), [Groth 16](/groth16/) or the [introductory videos by Dan Boneh](https://zkhack.dev/whiteboard/) at zkhack.

The first step is transforming code into a system of polynomial equations over a finite field. This is known as arithmetization, and typical arithmetization schemes are R1CS (rank one constraint system), Plonkish, and AIR (algebraic intermediate representation). Some operations are expensive to arithmetize, which can lead to signficant costs for the prover. Lookup arguments are a powerful technique that helps us solve this problem by having a precomputed table of values (it can also be dynamic). In this blog post, we will cover the basics of lookup arguments and describe the PlookUp scheme. The topic has been discussed in the ongoing [Sparkling Water Bootcamp](https://github.com/lambdaclass/sparkling_water_bootcamp/blob/main/README.md), where we will provide an implementation of the different lookups in our library, [Lambdaworks](https://github.com/lambdaclass/lambdaworks).

## Examples and working principle

Suppose we want to check that a variable $a$ has to be in a prescribed range, such as a `u8`. One simple yet ineffective way to do so is to express $a$ in its binary form $a_0 a_1 a_2 a_3 a_4 a_5 a_6 a_7$ and check that:

        1. Every variable is boolean $a_i (1 - a_i ) = 0$
        2. $a = \sum a_k 2^k$

This approach makes us add several additional constraints, which scale proportionally with the number of bits. Another approach could be showing that the number is contained in the list of all valid values for the variable. This is an example of a lookup operation. The first lookup arguments depended on the table size (we paid the price both for the lookup operations we did and for the whole table). At the same time, newer constructions make us pay the price only for the number of lookup operations (plus some preprocessing). If we have to do just a few lookup operations, then using these arguments does not pay off (we could accept having more constraints). Still, as the number or complexity of the operations increases, it makes sense to support lookups.

We can prove bitwise operations using lookup tables. For example, for the exclusive or between two bytes $a$ and $b$, $c = a \oplus b$, we can use the arithmetic constraints to represent the operations,  
$a_i (1 - a_i ) = 0$  
$b_i (1 - b_i ) = 0$  
$a_i + b_i - 2a_i b_i - c_i = 0$  
We could also have a list with all possible combinations, $a$, $b$, and $c$. Given that each byte takes 256 different values ($2^8$), we could have a table listing all valid input/output trios ($2^{ 16 } = 65536$) and check that our $(a , b, c)$ are in that list.

To prove inclusion, we will use tricks similar to those we applied for the [permutation arguments](/all-you-wanted-to-know-about-plonk/). We will first reduce the claim of our tuple $(a , b , c)$ being in table $\mathcal{T}$ to a relationship between two vectors. We will show that, for every component in the vector $f$, there exists some component in the vector $t$ such that $f_i = t_k$. We can zip the table into a single vector by performing a random folding of the columns,  
$t = col_0 (\mathcal{T}) + \zeta col_1 (\mathcal{T}) + \zeta^2 col_2 (\mathcal{T})$  
We can reduce our tuple $(a, b , c)$ to the vector $f$ by doing the same operation,  
$f = a +\zeta b + \zeta^2 c$

To be able to apply a kind of permutation argument, we should know the number of times every element in $f$ appears in $t$, which can be something problematic. Instead, we can work with randomized differences over sorted vectors. This method was introduced in the [PlookUp paper](https://eprint.iacr.org/2020/315.pdf). We build a vector $s$, which results from concatenating the vectors $f$ and $t$ and sorting them by the order they appear in $t$. If the set of non-zero consecutive differences in $s$ is the same as $t$, then this proves that $f$ has all its values in the set given by $t$. If the values of $t$ appear more than once in $f$, the consecutive differences will yield $0$ for equal elements, thus eliminating them from the checks. The randomized differences avoid having to check the initial values,  
$\Delta s_i = s_i + \beta' s_{i + 1}$  
$\Delta t_i = t_i + \beta' t_{i + 1}$  
In the case of randomized differences, even if the consecutive elements are the same, the difference will be non-zero. However, we know that the differences will be multiples of $1 + \beta'$, which allows us to identify them. The check involves two bivariate polynomials, $F$ and $G$,  
$F = (1 + \beta')^n \prod (\gamma' + f_j) \prod (\gamma' (1 + \beta' ) + \Delta t_i )$  
$G = \prod (\gamma' (1 + \beta' ) + \Delta s_i )$  
If these two polynomials are the same, we have proven that all the values of $f$ are contained in the set given by $t$.  
As in the permutation check, it is useful to define the vector $z$, defined by:  
$$z_0 = 1$$  
$$z_i = \prod \frac{(1 + \beta')(\gamma' + f_i )(\gamma'(1 + \beta') + \Delta t_i )}{(\gamma' (1 + \beta' ) + s_{2i - 1} + \beta' s_{2i } )(\gamma' (1 + \beta' ) + s_{2i} + \beta' s_{2i + 1} )}$$  
We can then interpolate the values of $z$ to obtain the polynomial $z (x)$ which must satisfy the conditions:

        1. $z (x = 1) = 1$
        2. $z (x = g^N ) = 1$
        3. $z(x) U(x) - z(gx) V(x) = 0$

where the polynomials $U(x)$ and $V(x)$ result from the interpolation of the polynomials $F$ and $G$, respectively. These constraints must be added to the constraints of the proof system we are using.

## Plonk and Lookup tables

For a recap of the Plonk protocol, we recommend reading our [previous post](/all-you-wanted-to-know-about-plonk/) or the [Lambdaworks docs](https://github.com/lambdaclass/lambdaworks/tree/main/docs/src/plonk). Plonk's arithmetization used selector variables $q_l , q_r , q_m , q_o , q_c$ to describe the different types of gates, which for a valid execution $(a , b , c)$ should satisfy the following equations:  
$q_l (x) a(x) + q_r (x) b(x) + q_m a(x) b(x) + q_o (x) c(x) + q_c (x) + pi(x) = 0$  
When introducing lookups into Plonk, we add a new selector variable, $q_{lu}$. This variable will equal $1$ when the values of $(a, b, c)$ must be checked to belong to a given table. The other selectors will be zero in that case, which will trivially satisfy the equations for the other types of gates. We recommend following the [PlonkUp paper](https://eprint.iacr.org/2022/086.pdf) for further details.

### Setup and preprocessed input

In Plonk we start with the common preprocessed input, which consists of the selector polynomials, $q_l(x) , q_r (x), q_m (x), q_o (x) , q_C (x)$, plus the copy constraint polynomials $S_{\sigma 1} (x) , S_{\sigma 2} (x) , S_{\sigma 3} (x)$. In the case of lookups, we have more preprocessed information, such as $q_{lu} (x)$, $col_0 (\mathcal{T}) (x) , col_1 (\mathcal{T}) (x) , col_2 (\mathcal{T}) (x)$.

### Round 1 - Committing to an execution of the circuit

Round 1 in the Plonk protocol consists of interpolating the column polynomials $a(x)$, $b(x)$, and $c(x)$ and committing to them. This way, the prover commits to a given execution of the circuit, and he won't be able to change the values of the execution trace.

### Round 2 - Enter Lookups

When we have lookups, we add a new round. We will call it Round 2. Here, the prover will zip the table into a vector and start all the work to prove the lookup arguments. The prover samples the folding coefficient $\zeta$ for the table and wirings and obtains the compressed table and queries,  
$t = col_0 (\mathcal{T}) + \zeta col_1 (\mathcal{T}) + \zeta^2 col_2 (\mathcal{T})$  
$f^\prime = a +\zeta b + \zeta^2 c$  
This last polynomial needs blindings to make them zero-knowledge, following the same recipe from Round 1:  
$f(x) = f^\prime (x) + Z_H (x) (b_7 + b_8x)$  
After that, the prover builds the vector $s$, sorted by $t$. Since this vector's length is greater than the size of the domain $H$ over which we interpolated $t$ and $f$, we break it down into two parts, $h_1$ and $h_2$, and we create the polynomials $h_1 (x)$ and $h_2 (x)$. Two common approaches exist for breaking the polynomial: take the first half and interpolate and then the second half or split into odd and even terms. The second approach needs one check less, so we will adopt that strategy here, following [PlonkUp](https://eprint.iacr.org/2022/086.pdf). Since the polynomials $h_1 (x)$ and $h_2 (x)$ contain information about the witness, we also add blindings to these polynomials.

The round ends with the commitment of the queries's polynomial, $f(x)$, and the parts of the sorted vector $h_1 (x)$, and $h_2 (x)$.

### Round 3 - Computing the permutation and Plookup polynomials

Round 3 involves the calculation of the copy constraint polynomial, $z_1 (x)$, and the Plookup polynomial, $z_2 (x)$. The permutation argument polynomial, $z_1 (x)$ is given by the following three terms:  
$$z_{11} = (b_{14} x^2 + b_{15} x + b_{16} ) Z_H (x)$$  
$$z_{12} = L_{1} (x)$$  
$$z_{13} = \sum L_{i + 1} (x) \prod \frac{(\gamma + \beta \omega^i + a_i )(\gamma + k_1 \beta\omega^i + b_i )(\gamma + k_2 \beta\omega^i + c_i )}{(\gamma + \beta S_{\sigma 1,i} + a_i )(\gamma + k_1 \beta S_{\sigma 2, i} + b_i )(\gamma + k_2 \beta S_{\sigma 3,i} + c_i )}$$  
The first term corresponds to the blinding polynomial, the second is the first Lagrange basis polynomial (it is one if $x = g$ and zero elsewhere), and the third one contains the grand product.

The Plookup polynomial $z_2 (x)$ looks very similar, given by three terms,  
$$z_{21} = (b_{17} x^2 + b_{18} x + b_{19} ) Z_H (x)$$  
$$z_{22} = L_{1} (x)$$  
$$z_{23} = \sum L_{i + 1} (x) \prod \frac{( 1 + \beta' )( \gamma' + f_i )(\gamma'(1 + \beta') + t_i + \beta' t_{i + 1} )}{(\gamma' (1 + \beta' ) + s_{2i - 1} + \beta' s_{ 2i } )(\gamma' (1 + \beta' ) + s_{2i} + \beta' s_{2i + 1} )}$$

These polynomials are best calculated by obtaining the components for the grand product check (in evaluation form) and then interpolating using the fast Fourier transform. The prover commits to these two polynomials.

### Round 4 - Transforming into Quotients

Round 4 computes the linear combination of the constraint polynomial, the copy constraint polynomial, and the Plookup constraints. We have the following constraints:

        1. All the assignments have to satisfy the general gates equations.
        2. The permutation check polynomial $z_1 (x)$ should equal one at the first evaluation point. Using the machinery we learned in STARKs, we could translate the condition as  
$$\frac{z_1 (x) - 1}{x - g^1}$$  
should be a polynomial. We can transform it into a more suitable form (so that all the constraints have the same vanishing polynomial)  
$$L_1 (x) (z_1 (x) - 1)$$
        3. The permutation argument's constraints  
$$\begin{align}  
(\gamma + \beta x + a (x) )(\gamma + k_1 \beta x + b (x) )(\gamma + k_2 \beta (x) + c (x) )z_1 (x) &\- \newline  
(\gamma + \beta S_{\sigma 1} (x) + a (x) )(\gamma + k_1 \beta S_{\sigma 2} (x) + b (x) )(\gamma + k_2 \beta S_{\sigma 3} (x) + c (x) )z_1 (g x)  
\end{align}$$
        4. Enforcing the lookup gates,  
$q_{lu} (x) ( a(x) + \zeta b(x) + \zeta^2 c(x) - f (x) )$
        5. The product check for the Plookup polynomial  
$$\begin{align}  
(1 + \beta')(\gamma' + f(x) )(\gamma'(1 + \beta') + t(x) + \beta' t(g x)) z_2 (x) &\- \newline  
(\gamma' (1 + \beta' ) + h_{1} (x) + \beta' h_{2} (x) )(\gamma' (1 + \beta' ) + h_{2} (x) + \beta' h_1 (gx) )z_2 (g x)  
\end{align}$$
        6. The Plookup polynomial should be equal to one at the first point,  
$L_1 (x) (z_2 (x) - 1)$

All the constraints should hold over the interpolation domain. Each polynomial is divisible then by $Z_H (x)$, and so is the random linear combination of the polynomials. The result is the quotient polynomial, $q (x)$, which is split into three parts, each of at most degree $N + 1$  
$q (x) = q_{lo} (x) + x^{N + 2} q_{mid} (x) + x^{2N + 4} q_{hi} (x)$

The prover commits to each of the parts.

### Round 5 - Evaluations

Round 5 computes the evaluations of several polynomials at a random point $z$ and sends them to the verifier so that he has enough information to check the relationship between the quotient and the original polynomial. The prover samples from the transcript $z$ and computes:

        * $a(z)$
        * $b(z)$
        * $c(z)$
        * $S_{\sigma 1} (z)$
        * $S_{\sigma 2} (z)$
        * $f(z)$
        * $t(z)$
        * $t (gz)$
        * $z_1 (gz)$
        * $z_2 (gz)$
        * $h_1 (gz)$
        * $h_2 (z)$

### Round 6 - Wrapping the proof

Round 6 performs the linearizations and generates the opening proof. So far, the prover has given commitments to polynomials and their evaluations at some point. It's time to link both and produce the evaluation proof. First, the prover computes the linearization polynomial, $r (x)$, which should equal $0$ at $z$. The prover computes the proof for the evaluation of all the polynomials listed in round 5 at $z$,  
$$W_z (x) = \frac{1}{x - z}(r(x) + \sum \alpha^i (p_i(x) - p_i (z)))$$  
He does the same for the polynomials at $gz$,  
$$W_{gz} (x) = \frac{1}{x - gz}(\sum \alpha^i (p_i(x) - p_i (gz)))$$

The prover commits to these quotient polynomials.

All the evaluations at Round 5 give the proof, plus the commitments to all the polynomials from Rounds 1, 2, 3, 4, and 6.

## Conclusion

In this post, we covered the basics of lookup arguments, which let us prove that specific calculations are correct by checking their results in a table that contains all valid input/output relations. These techniques can result in significant savings when we try to prove difficult or expensive operations to arithmetize, such as range checks or bitwise operations (which can be extensively used). We described the working principles of Plookup, which was among the first arguments to be presented. It can be integrated very neatly into the Plonk protocol, but it results in an extra cost since we have the calculation time increases with table size. Recent constructions reduce the cost associated with the size of the table, paying just a price proportional to the number of lookups. In upcoming posts, we will cover how to code the Plookup protocol and newer lookup arguments.
