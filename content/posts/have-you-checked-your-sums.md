+++
title = "Have you checked your sums?"
date = 2023-10-26
slug = "have-you-checked-your-sums"

[extra]
feature_image = "/images/2025/12/Hubert_Robert_-_View_of_Ripetta_-_WGA19603.jpg"
authors = ["LambdaClass"]
+++

## Introduction

There has recently been a growing interest in zk-SNARKs (zero-knowledge, succinct, non-interactive arguments of knowledge) due to their capabilities in decentralized private computations and scaling blockchains. These constructions involve a protocol between two parties, a prover and a verifier, where the former attempts to convince the latter of the validity of a given statement. Sometimes, the prover tries to do this without revealing sensitive information. We want the work needed for the verifier to check the statement to be significantly smaller than just doing it himself. For example, we would like to delegate an expensive computation to an untrusted server (for which we do not have the necessary resources) and be able to verify the correctness of the computation using a smartphone. The zero-knowledge property allows us to prove the possession of some secret (such as a private key or the preimage of some hash) without giving that information to the verifier. At the heart of these constructions, we have polynomials and can reduce the statement to some relation between polynomials. For example, [STARKs](/lambdaworks-or-how-we-decided-to-created-our-zksnarks-library-and-a-stark-prover/) uses univariate polynomials and the FRI protocol to prove the correctness of a given computation. The sumcheck protocol, which involves polynomials in several variables, can be used to build SNARKs.

In this post, we will first describe how to encode vectors as multilinear polynomials (similar to how we encoded vectors as univariate polynomials) and how the sumcheck protocols work. We are currently implementing the sumcheck protocol and multilinear polynomials as part of the [learning path of the Sparkling Water Bootcamp](https://github.com/lambdaclass/sparkling_water_bootcamp/tree/main); you can follow the development at [Lambdaworks](https://github.com/lambdaclass/lambdaworks).

## Encoding vectors as multilinear polynomials

A polynomial $p$ in $n$ variables is called multilinear if the degree of each variable $x_i$ is at most one in every term. For example, $p_1 (x_1 , x_2 , x_3 , x_4 ) = x_1 + 2 x_2 + x_1 x_2 x_4 x_3$ is a multilinear polynomial because the power of each $x_i$ is either $0$ or $1$ in each term. The polynomial $p_2 (x_1 , x_2 ) = x_1 x_2^2$ is not, since the degree of $x_2$ is $2$. The total degree of a multilinear polynomial is the highest sum of all the powers of a term (monomial). For $p_1$, this is 4. For multilinear polynomials, the maximum degree is at most $m$.

We will restrict ourselves now to polynomials defined over the set $D = { 0 , 1 }^m$. Given a function $f$ defined over $D$, we can define a multilinear polynomial $p(x_1, x_2, ... , x_m )$ such that $p$ coincides with $f$ over the set $D$, that is $p(x) = f (x)$ for every $x \in D$. Since this polynomial is unique, the polynomial $p$ is called the multilinear extension of $f$.

We can use the multilinear extension to represent a vector $v$ containing $2^m$ elements. Suppose the vector $v$ 's elements belong to some finite field $\mathbb{F}$. We first create the function $f: D \rightarrow \mathbb{F}$, which maps each element of $D$ into an element of $v$. One easy way to do this is by representing the position in the vector $k$ in its bit form. For example, if the vector has 256 elements, we need $8$ variables (bits), and we can define the map as:  
$f(0, 0, 0, 0, 0, 0, 0, 0) = v_0$  
$f(0, 0, 0, 0, 0, 0, 0, 1) = v_1$  
$f(0, 0, 0, 0, 0, 0, 1, 0) = v_2$  
$f(0, 0, 0, 0, 0, 0, 1, 1) = v_3$  
$\vdots$  
$f(1, 1, 1, 1, 1, 1, 1, 1) = v_{255}$  
In general form, we assign to a tuple $(x_0, x_1, ... x_{m - 1} )$ the value corresponding to index $k = x_0 + 2 x_1 + 4x_2 + \dots + 2^{m - 1} x_{ m - 1 }$. Then, we can use the fact that the multilinear extension of $f$ exists and create it by Lagrange interpolation, for example. Thus,  
$p(x_0 , x_1 , ... x_{m - 1} ) = \sum_{ x_0 , ..., x_{ m -1} } f(k) B_k (x_0 , x_1 , ... , x_{ m - 1} )$  
where $B_k$ is the Lagrange basis polynomial, which equals one when $(x_0 , x_1 , ... , x_{ m -1 })$ corresponds to the binary representation of $k$ and zero otherwise. If we represent $k = (k_0, k_1 , ... k_{ m - 1})$ (remember each $k_i$ is either 0 or 1), the function $B_k(x_0, x_1, ... x_{ m - 1 })$ has the explicit expression  
$B_k (x_0 , x_1 , ..., x_{ m - 1}) = \prod ( x_i k_i + (1 - x_i ) (1 - k_i))$

For example, if we have the vector $v = ( 2, 5, 7, 8)$, we have four Lagrange basis polynomials:  
$B_0 (x_0 , x_1 ) = (1 - x_0) (1 - x_1 ) = 1 - x_1 - x_0 + x_1 x_0$  
$B_1 (x_0 , x_1 ) = x_0 (1 - x_1 ) = x_0 - x_0 x_1$  
$B_2 (x_0 , x_1 ) = (1 - x_0 ) x_1 = x_1 - x_0 x_1$  
$B_3 (x_0 , x_1 ) = x_0 x_1$  
and  
$p(x_0 , x_1) = 2 B_0 + 5 B_1 + 7 B_2 + 8 B_3$  
Replacing everything,  
$p(x_0 , x_1) = 2 + 3 x_0 + 5 x_1 - 2 x_0 x_1$

This way, we have encoded our vector as a multilinear polynomial in two variables. We could generally encode a vector of length $n$ as a polynomial in $\lceil{\log_2 (n)} \rceil$ variables. We can then use this encoding to reduce the validity of some calculation to the sum of this polynomial over all possible values of $x_0, x_1 ... x_n$.

## The sumcheck protocol

The sumcheck protocol is an interactive proof introduced in 1992 with a fundamental role in the theory of probabilistic proofs in complexity theory and cryptography, leading to the construction of succinct arguments. One of its essential properties is that the prover can be implemented in a number of operations that scale linearly (that is, its running time is $\mathcal{O} (n)$), which has a better asymptotic complexity than algorithms based on the Fast Fourier Transform ($\mathcal{O} (n \log n)$). It also provides the basis for folding techniques for Pedersen commitments in the discrete logarithm setting. For an in-depth explanation of the protocol, look at [proofs, arguments and zero-knowledge](https://people.cs.georgetown.edu/jthaler/ProofsArgsAndZK.pdf) and [sumcheck arguments and their applications](https://eprint.iacr.org/2021/333.pdf).

The sumcheck protocol yields an interactive proof for statements of the form  
$$\sum_{ x \in H^m } p(x) = S$$  
that is, the sum of all the evaluations of an $m$-variate polynomial over a domain equals $S$. The prover is given the polynomial $p(x)$, and the verifier will send him random challenges, $r_k$, from a set $\mathcal{C}$ and receive polynomials $q_k(x)$, which will allow him to be convinced that the statement is true. The protocol will reduce the workload of the verifier from having to evaluate the $m$-variate polynomial over $\vert H \vert^m$ (for example, if the size of $H$, $\vert H\vert$, is two and we have 16 variables, we need to do $2^{16}$ evaluations) to a single evaluation over a random point over $\mathbb{F}^m$, plus some additional smaller operations.

The protocol proceeds in rounds and works as follows:

        1. The prover sends to the verifier the polynomial  
$$q_k (x) = \sum_{ a_j \in H , j \geq k + 1 } p(r_1, r_2, ..., r_{ k - 1 }, x, a_{ k + 1}, ... a_{m})$$
        2. The verifier checks that $\sum_{a_1 \in H} q_1 (a_1) = S$ and $\sum_{a_k \in H} q_k ( a_k ) = q_{ k - 1 }( r_{k - 1})$.
        3. If all checks pass, the verifier outputs $v = q_m ( r_m )$ and outputs $r_1 , r_2 , ..., r_m , v$.

Let's explain the protocol in simple terms. In the first round, the prover sends the verifier a polynomial $q_1 (x_1 )$ by summing over all possible values of the rest of the variables. This way, the verifier can check the sum by evaluating the polynomial $q_1 (x_1)$ over all its values, which is much faster than summing over all the variables. However, how does the verifier know that the prover did not cheat and send some fake polynomial $q_1 (x_1)$? The verifier sends a random challenge $r_1$, and the prover responds with a new polynomial of one variable, $q_2 (r_1, x_2)$, which is obtained by fixing the first coordinate and summing over all the other variables except $x_2$. If we evaluate $q_1 (r_1 )$, we should get the same as adding over all possible values of $q_2 (x_2 )$ (because $q_1$ was obtained by summing over all values of $x_2$). The verifier always has to do a few evaluations of a univariate polynomial.

If the challenge subset $\mathcal{C}$ is a sampling subset, then the sumcheck protocol satisfies:

a. Completeness.  
b. Soundness, where the soundness error is bounded by $m d/ \vert \mathcal{C} \vert$ (the number of variables, the maximum degree in the polynomial, and the number of elements in the challenge subset).

In many cases, we would like to work with $H^m = \\{ 0,1 \\}^m$, so that $x = (x_1 , x_2 , ... , x_m)$ is the collection of all bitstrings of length $m$ and we can use the encoding for vectors as multilinear polynomials.

To make the sumcheck protocol zero-knowledge, we need to mask the polynomial. We can achieve this by adding a random polynomial.

## Conclusion

In this post, we covered the sumcheck protocol, which is at the heart of some SNARKs. It allows the verifier to check that the sum of the evaluations of some multivariate polynomial over a set is equal to some number by delegating most of the computational burden to the prover. The protocol involves a number of rounds equal to the number of variables, where the prover sends at each round a univariate polynomial, and the verifier responds by sending a random challenge. The verifier's highest cost is involved in evaluating the multivariate at one random point, significantly less than trivial verification. In an upcoming post, we will cover how to implement the sumcheck protocol from scratch.
