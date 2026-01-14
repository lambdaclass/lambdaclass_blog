+++
title = "An introduction to circle STARKs"
date = 2024-07-25
slug = "an-introduction-to-circle-starks"

[extra]
feature_image = "/content/images/2025/12/Raphae--l_au_Vatican_-Louvre_INV_8365-.jpg"
authors = ["LambdaClass"]
+++

## Introduction

Scalable, transparent arguments of knowledge (STARKs) have gained widespread attention due to their applications in verifiable computing and blockchain scalability. We can use STARKs to generate a short string that attests to the integrity of a computation and a verifier can verify it very fast. The steps to generate a STARK proof consist of the following:

        1. Represent the computation as a system of polynomial constraints/equations. This could be the Algebraic Intermediate Representation (AIR) or Plonkish arithmetization. We will use AIR for the remainder of the post.
        2. Obtain the execution trace for the program.
        3. Interpret each column of the execution trace as the evaluations of a univariate polynomial over some smooth domain $D$ (this step is called interpolation).
        4. Evaluate the trace polynomials over a larger and disjoint domain $D_0$ and build a Merkle tree using the evaluations.
        5. Enforce the constraints on the trace polynomials.
        6. To ensure that the constraints are satisfied, divide each polynomial in step 5 by the vanishing polynomial on the set where the constraints hold. The constraints are fulfilled if the result of the division is a polynomial.
        7. If there are many polynomials, get random values from the verifier to perform a linear combination; with high probability the constraints hold if the result is a polynomial.
        8. Evaluate the resulting function over $D_0$ and build a Merkle tree from those evaluations.
        9. To show that the evaluations belong to a polynomial of at most degree $n$ (and not a higher degree or rational function), apply the [FRI protocol](/how-to-code-fri-from-scratch/).

The efficiency of STARKs depends on working over smooth fields, where we can use the radix-2 Cooley-Tukey Fast Fourier Transform (FFT) to perform fast interpolation and evaluation. We say that the field is smooth if $p - 1 = 2^m c$, where $m$ is sufficiently large and $c$ is an odd number. Examples of fields having this property are STARK-252, $2^{64} - 2^{32} + 1$ (sometimes called Mini-Goldilocks or oxfoi prime), $2^{31} - 2^{27} + 1$ (Baby Bear).

One of the main advantages of STARKs is that we can work over "small fields" (their size is smaller than needed for cryptographic security), reducing the overhead needed to represent variables in the execution trace/virtual machine. We can then sample randomness from an extension field to achieve cryptographic security. [Binius](https://eprint.iacr.org/2023/1784) shows how we can represent variables with zero overhead using binary fields.

In this post we will provide an explanation of [Circle STARKs](https://eprint.iacr.org/2024/278.pdf), how we can use the circle group to access very fast modular arithmetic and why we need certain properties to be able to perform STARKs over the circle group. To do so, we need to develop the circle analogues of classical STARKs: bivariate polynomials, smooth domains, circle codes, vanishing polynomials, FFT and FRI. While many things seem quite close to their classical analogues, there are some subtleties that arise and special limits or points where we should be careful. If you want to see how these primitives are implemented, you can check [Starkware's prover Stwo](https://github.com/starkware-libs/stwo/tree/dev), [Polygon's Plonky3](https://github.com/Plonky3/Plonky3/tree/main/circle/src) and [Vitalik's python implementation](https://github.com/ethereum/research/tree/master/circlestark). If you need a recap on classical STARKs, see [post 1](/diving-deep-fri/) and [post 2](/how-to-code-fri-from-scratch/).

## Mersenne primes

Mersenne primes have the form $2^p - 1$, where $p$ is prime ($2^p - 1$ is not always prime for every prime $p$). They have nice reduction formulae (since $2^p \equiv 1 \pmod{2^p - 1}$) and lead to very fast modular arithmetic (which in turn is crucial to performance in STARKs). Some Mersenne primes are:

        * $2^2 -1 = 3$
        * $2^3 - 1 = 7$
        * $2^5 - 1 = 31$
        * $2^7 - 1 = 127$
        * $2^{31} - 1 = 2147483647$
        * $2^{61} - 1$
        * $2^{127} - 1$

The problem with using Mersenne primes with STARKs is that $p - 1 = 2c$, where $c$ is odd, meaning that they are not smooth. This way, we cannot perform interpolation efficiently using the FFT. A way to circumvent this is to have the interpolation domain live in a quadratic extension of a Mersenne prime, as explained [here](https://eprint.iacr.org/2023/824.pdf). However, this approach is not well suited for constraint evaluations (quotient computations), limiting performance for traces frequently encountered in zkvms.

This shortcomings can be avoided by switching to the circle curve $x^2 + y^2 = 1$ over the field given by the Mersenne prime. The circle, equipped with the operation inherited from the rotation group over the field, is a cyclic group. Moreover, the number of elements is equal to $q + 1$. For a Mersenne prime, this means that $q + 1 = 2^p$.

Mersenne primes satisfy also that $q \equiv 3 \pmod {4}$, which implies that $x^2 + 1$ is irreducible over $q$. We will have $i$ satisfy $i^2 = -1$ and work with extensions $F$ of $F_q$. To keep with the notation of the paper, $F(i)$ is a quadratic extension of the base field $F$.

## Polynomials

We will denote $F[x]^d$ the univariate polynomials of degree at most $d$ and $F[x,y]^d$ the bivariate polynomials of degree at most $d$. For example, $x + 2x^5 + x^{34}$ is in $F_q [x]^{36}$ but $x^{56} + 1$ is not. Similarly, $1 + x y^2 + x^{34} + y^{35} + x^{12} y^{12}$ is in $F_q [x,y]^{64}$ but not $x^{32} y^{34} + x^{12} + 25$.

In circle STARKs, we will work with bivariate polynomials modulo $x^2 + y^2 - 1$. Since $y^2 = x^2 - 1$, we can always express a polynomial $F[x,y]^d$ as  
$f(x,y) = f_0 (x) + y f_1 (x)$  
which we call the canonical representation of the polynomial. As an example, say we have the polynomial  
$p(x,y) = x + 4 y^3 + 5 x^2 y^5 + x y^6$  
We can replace $y^2 = x^2 - 1$ and get  
$p(x,y) = x + 4 y (x^2 - 1) + 5x^2 y (x^2 - 1)^2 + x (x^2 - 1)^3$  
From this, we get that  
$f_0 (x) = x + x (x^2 - 1)^3$  
$f_1 (x) = 4 (x^2 - 1) + 5x^2 (x^2 - 1)^2$

This decomposition is useful to compute the circle FFT and FRI. Something nice about $f_0 (x)$ and $f_1 (x)$ is that they are both univariate, which will lead to additional simplicity and performance for the subsequent steps (the only thing we need to be careful about is the structure of the squaring map for $x$. Instead of having $x \rightarrow x^2$ we have $x \rightarrow 2x^2 - 1$).

## The circle group

Circle points are pairs $(x_0 , y_0)$ (with coordinates in the field $F$) satisfying the equation $x_0^2 + y_0^2 = 1$. We can induce a group structure by considering the following operation,  
$(x_0 , y_0 ) \cdot (x_1 , y_1 ) = (x_0 x_1 - y_0 y_1 , x_0 y_1 + x_1 y_0 )$  
If we fix $P = (P_x , P_y)$ we can define the rotation by $P$, $T_P (x , y) = (x_0 P_x - y_0 P_y , x_0 P_y + P_x y_0 )$. This operation is important when we need to evaluate transition constraints. For example, if we want to check that we are computing a Fibonacci sequence, we need to show that $a_{n + 2} = a_{n + 1} + a_{n}$. If we have the trace polynomial $t(x)$, we can get the next element to $x$ just by multiplying by $\omega$, the generator of the interpolation domain and have the Fibonacci constraint be $t(\omega^2 x) = t(\omega x) + t(x)$. If we choose $P$ as the generator of the (circle) interpolation domain, we can use the same idea to write these constraints.

Inverses can be calculated pretty straightforward: if $P = (x , y)$, then $-P = (x, -y)$.

An important map is the square mapping, $\pi (x,y) = (x^2 - y^2 , 2xy) = (2x^2 - 1, 2xy)$. We can see that the first component depends only on $x$. The square map produces a two-to-one reduction when acting over subgroups or special cosets (called twin position cosets). Operations over the circle are implemented here in [Stwo](https://github.com/starkware-libs/stwo/blob/dev/crates/prover/src/core/circle.rs).

To learn more about the domains over the circle or types of cosets, see [Plonky3's implementation](https://github.com/Plonky3/Plonky3/blob/main/circle/src/domain.rs).

## Circle codes

The circle code is obtained by evaluating a polynomial $f(x,y)$ over a proper subset $D$ of the circle group over $F_q$. It can be proven that there is a one-to-one correspondence with Reed-Solomon codes (basically, circle codes are Reed-Solomon codes).

## Vanishing polynomials

In classical STARKs, we need to compute the vanishing polynomials over a set to then produce quotients. We need to find what these vanishing polynomials will look like in circle STARKs. The interesting result is that vanishing polynomials will be univariate, $v(x)$. Vanishing polynomials of order $n$ can be computed efficiently in $\log (n)$ operations: a squaring, a doubling and a subtraction by one. The vanishing polynomials are:  
$v_1 (x) = x$  
$v_2 (x) = 2x^2 - 1$  
$v_3 (x) = 2(x^2 - 1)^2 - 1$  
$v_4 (x) = 2((x^2 - 1)^2 - 1)^2 - 1$  
$v_5 (x) = 2(((x^2 - 1)^2 - 1)^2 - 1)^2 - 1$

You can check how to evaluate the vanishing polynomials in [Stwo](https://github.com/starkware-libs/stwo/blob/be265626f064ac1fcc82b1bf13e28f83023a505a/crates/prover/src/core/constraints.rs#L11-L34).

As in the case of classical STARKs, if $v_H (x)$ and $v_J (x)$ are vanishing polynomials over the sets $H$ and $J$, the quotient $v_H (x) / v_J (x)$ is a vanishing polynomial over $H \backslash J$. This way, we can compute efficiently constraints that apply over $H \backslash J$.

## Circle FFT

The inverse FFT takes a vector of evaluations and produces the coordinates of a polynomial over some basis. The FFT takes the coordinates over the basis and produces a set of evaluations. We are used to the monomial basis, $1, x, x^2 , x^3 , ... x^n$, but there are other options available. In the case of the circle FFT, the basis looks more complicated, but remember that what we want is just to encode values into polynomials and then evaluate them over a larger domain. For an FFT involving $n$ elements, let $j_0 j_1 j_2 \dots j_{n - 1}$ be the binary decomposition of $0 \leq k \leq n - 1$, that is $k= j_0 + 2j_1 + 4j_2 + \dots 2^{n - 1} j_{n - 1}$. The $k$-th basis polynomial is given by:  
$b_k (x , y) = y^{j_0} v_1 (x)^{j_1} v_2 (x)^{j_2} \dots v_{n - 1} (x)^{j_{ n - 1} }$  
To clarify the expression, here we have the first basis polynomials,  
$b_0 (x) = 1$  
$b_1 (x) = y$  
$b_2 (x) = v_1 (x) = x$  
$b_3 (x) = y v_1(x) = x y$  
$b_4 (x) = v_2 (x) = 2x^2 - 1$  
$b_5 (x) = y v_2 (x) = y( 2x^2 - 1)$  
$b_6 (x) = v_1 (x) v_2 (x) = x (2x^2 - 1)$

If we need to evaluate a polynomial of degree $n$ over $\beta n$ points $\beta \geq 2$, we can zero-pad the polynomial with no problem.

In the first step of the FFT, we use the split of the canonical representation of the polynomial, $p(x, y) = f_0 (x) + y f_1 (x)$. The following steps deal with a univariate polynomial $f_j (x)$, where we can apply the even-odd decomposition, taking into account that the square mapping follows the circle operation. In other words,  
$f_{j,e} (2x^2 - 1) = (f_j (x) + f_j (- x))/2$  
$f_{j,o} (2x^2 - 1) = (f_j (x) - f_j (- x))/2x$

We can continue breaking everything down until we can solve the FFT directly, using the [butterflies](https://github.com/starkware-libs/stwo/blob/dev/crates/prover/src/core/fft.rs).

The twiddle factors for the first step are different from those used on the second.

## Other changes in circle STARKs

When we impose the constraints on the trace polynomials and compute the quotients, we arrive at the composition polynomial. Its degree depends on the maximum degree of the constraints, and we may need to split it in several chuncks. In the univariate case, we can do this decomposition as follows:  
$p(x) = p_0 (x) + x^{n + 1} p_1 (x) + x^{2n + 2} p_2 (x)$  
Each $p_k (x)$ has a degree at most $n$. In circle STARKs, decompose into functions $q_1 , q_2 , ... q_d$ and a parameter $\lambda$ such that  
$p = \lambda v_H (x) + \sum_k v_{ H } q_k / v_{ H_k }$  
where the $H_k$ are disjoint twin cosets of size $n$ and their union yields $H$. The additional parameter $\lambda$ is needed because of the dimension gap discussed on the paper.

Circle FRI faces some modifications with respect to classical FRI. First, we need to decompose the function to which we will apply FRI as $f = g + \lambda v_n (x)$. This decomposition is crucial to ensure that the function spaces halve at every folding step, reaching the space of constant functions at the end of the protocol. The folding follows a similar procedure to the one we encountered in the circle FFT; after the first folding, we have to deal with univariate functions and the square mapping $x \rightarrow 2x^2 - 1$.

## Summary

Circle STARKs have shown [amazing performance](https://x.com/StarkWareLtd/status/1807776563188162562) by leveraging Mersenne primes, which have the fastest known finite field arithmetic. They are able to work around the non-smooth structure of fields defined over Mersenne primes by moving to the circle group but closely follow their classical STARKs analogues (albeit with some subtleties). Luckily, most of these subtleties are hidden from developers and circle STARKs, together with efficient lookups (such as those based on LogUp and GKR), can help improve the performance of general-purpose zkvms.
