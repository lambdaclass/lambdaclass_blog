+++
title = "How does Basefold polynomial commitment scheme generalize FRI"
date = 2024-02-09
slug = "how-does-basefold-polynomial-commitment-scheme-generalize-fri"

[extra]
feature_image = "/images/2025/12/Psyche_aux_enfers.jpg"
authors = ["LambdaClass"]
+++

## Introduction

[lambdaworks](https://github.com/lambdaclass/lambdaworks) is a library designed to provide efficient proof systems. We want it to support state of the art provers and associated primitives so that people can use them to build new applications. Among those primitives we have polynomial commitment schemes (PCS). These are a powerful cryptographic tool that allows us to bind ourselves to a given polynomial by means of a small data structure (such as the root of a Merkle tree or a point over an elliptic curve) and prove its evaluations at some points. Polynomial commitment schemes consist of the following five algorithms:

        * Setup: given a security parameter, $\lambda$, it generates the public parameters (pp) for the PCS.
        * Commit: taking the pp and a polynomial, $p$, outputs a commitment to the polynomial $\mathrm{cm}(p)$.
        * Open: given the pp, a polynomial $p$ and a commitment to $p$, $\mathrm{cm}(p)$, checks whether $\mathrm{cm}(p)$ is the commitment to $p$.
        * Prove evaluation: given the pp, a polynomial $p$, a point $z$ and a claimed evaluation $v$, outputs a proof $\pi$ that the $p(z) = v$.
        * Verify evaluation: given the pp, the commitment to $p$, the proof $\pi$, the point $z$ and the claimed value $v$, checks whether the evaluation proof is valid.

Polynomial commitment schemes are one of the basic building blocks of modern SNARKs. Some commitment schemes require a trusted setup (such as [KZG](/mina-to-ethereum-bridge/)), while others are transparent (such as FRI, Brakedown and IPA). Different PCS offer trade-offs between evaluation proof sizes, evaluation times, security assumptions, and other algebraic properties (for example, being additively homomorphic).

[Basefold](https://eprint.iacr.org/2023/1705.pdf) generalizes the [FRI commitment scheme](/how-to-code-fri-from-scratch/) to other codes different from Reed-Solomon. These codes need to have certain properties, though. This post will discuss the basics of coding theory and explain how basefold works.

## Coding theory

Error-correcting codes are ways of representing data so that we can recover the information even if parts of it were corrupted. We do this by introducing redundancy, and the message can be recovered even if parts of the redundant data are corrupted. There is a trade-off between maximizing error correction and redundancy: codes with higher redundancy should be able to tolerate a higher number of errors.

A code of block length $n$ over an alphabet $\Sigma$ is a subset of $\Sigma^n$. In our case, we will be interested in codes where the alphabet $\Sigma$ is some finite field $\mathbb{F}$ and $\vert \Sigma \vert = q$.

The rate of a code of dimension $k$ and block size $n$ is given by $\rho = k / n$ and is a measure of the amount of redundancy introduced in the code.

Given a code, the Hamming distance, $d$, between two code words is given by the number of positions they differ at. The relative distance is the ratio between the distance and the block length, $\delta = d / n$.

A code over $\Sigma^n$ of dimension $k$ and distance $d$ is called an $(n , k , d )_{\Sigma}$ - code. A linear code is such that any linear combination of codewords results in a codeword (that is, if $c_0$ and $c_1$ are the encoding of $m_0$ and $m_1$, then $\alpha_0 c_0 + \alpha_1 c_1$ is also a codeword, specifically, the codeword associated with $\alpha_0 m_0 + \alpha_1 m_1$).

For linear codes, the encoding function can be represented as a vector-matrix product using a generator matrix, $G$, that is  
$\mathrm{Enc}(v) = v . G$

For example, Reed-Solomon codes use a Vandermondian matrix with points $\alpha_0, \alpha_1, ... , \alpha_{n - 1}$:  
$$\begin{align}  
V(\alpha_0 , \alpha_1 , ... , \alpha_{n - 1}, k)_{i,j} = \alpha_j^i  
\end{align}$$

Reed-Solomon codes work by interpreting the message as the coefficients of a degree $k - 1$ polynomial. If the message is $(m_0 , m_1 , ... , m_{k - 1})$, we can think of them as $m_0 + m_1 x + ... + m_{k - 1} x^{ k - 1}$ and provide the evaluations over $n$ distinct points. Since the polynomial is at most of degree $k - 1$, it has at most $k - 1$ zeros, making two different codewords coincide at most in $k - 1$ places, so $d = n - k + 1$. Codes which satisfy $d = n - k + 1$ are called maximum distance separable codes.

## Basefold

[Basefold](https://www.youtube.com/watch?v=OuKUqPbHLQ0) works with foldable linear codes. Remember that we can represent linear codes via the generator matrix, $G$. The generator matrix, $G_{k , n}$ of the foldable linear $(n, k, d )$ - code has the following block matrix structure:  
$$G_{k,n} = \begin{bmatrix}  
G_{k/2,n/2} & G_{k/2,n/2} \\  
G_{k/2,n/2} T_{k/2,n/2} & G_{k/2,n/2}T^\prime_{k/2,n/2}  
\end{bmatrix}$$  
where $G_{k/2,n/2}$ is the generator matrix of the foldable linear $[n/2, k/2, d^\prime ]_\Sigma$-code.

For example, Reed-Solomon codes satisfy this property, when instantiated over a multiplicative subgroup of size $n = 2^m$ (we also assume that $\rho = 2^{- \beta}$). If we choose a generator $g$ of the subgroup and represent the points as $\{ 1, g, g^2 , ... g^{m - 1} \}$, we have  
$$G_{k,n} = \begin{bmatrix}  
1 & 1 & 1 & 1 & \dots & 1 \\  
1 & g & g^2 & g^3 & \dots & g^{m - 1} \\  
1 & g^2 & g^4 & g^6 & \dots & g^{2(m - 1)} \\  
1 & g^3 & g^6 & g^9 & \dots & g^{3(m - 1)} \\  
\vdots & \vdots & \vdots & \vdots & \ddots & \vdots \\  
1 & g^{k - 1} & g^{2(k - 1)} & g^{3(k - 1)} & \dots & g^{(k - 1) (m - 1)}  
\end{bmatrix}$$

Let's reorder the matrices rows by placing first all the even-numbered rows, in increasing order, followed by all the odd-numbered rows. We get,  
$$G_{k,n} = \begin{bmatrix}  
1 & 1 & 1 & 1 & \dots & 1 \\  
1 & g^2 & g^4 & g^6 & \dots & g^{2(m - 1)} \\  
1 & g^4 & g^8 & g^{12} & \dots & g^{4(m - 1)} \\  
\vdots & \vdots & \vdots & \vdots & \ddots & \vdots \\  
1 & g & g^2 & g^3 & \dots & g^{m - 1} \\  
1 & g^3 & g^6 & g^9 & \dots & g^{3(m - 1)} \\  
1 & g^5 & g^{10} & g^{15} & \dots & g^{15(m - 1)} \\  
\vdots & \vdots & \vdots & \vdots & \ddots & \vdots \\  
1 & g^{k - 1} & g^{2(k - 1)} & g^{3(k - 1)} & \dots & g^{(k - 1) (m - 1)}  
\end{bmatrix}$$

We can see that the lower block (the odd rows) looks a bit similar to the upper block, except that most columns are shifted by a similar amount. For example, column one there is a factor $g$ missing, column two, a factor $g^2$, column three, $g^3$ and so on. We have therefore broken the matrix into upper and lower parts. We need to break each part into right and left parts.

If $g$ is a generator of a group of order $m$, then $\omega = g^2$ is a generator of a subgroup of order $m/2$. As soon as we have something like $\omega^{m/2}$ we wrap back to $1$. This breaks the upper half into two identical matrices, which correspond to $G_{k/2, n/2}$. In the lower half, the diagonal matrices are:  
$T_{ii} = g^i$  
$T^\prime_{ii} = g^{m/2} g^i$  
But $g^{m/2} = - 1$, so $T = - T^\prime$.

We see that linear foldable codes generalize this property we had in Reed-Solomon codes. There are, however, no restrictions on the generator matrices, other than fulfilling the foldable linear code definition. This lets us choose the diagonal matrices $T, T^\prime$ more freely and be able to use non FFT-friendly fields (this makes basefold PCS field-agnostic). In basefold, they set the matrices $T = - T^\prime$, and their elements are sampled at random from the multiplicative group of the base field. We can construct the generator matrices inductively, by choosing $G_0$ and $T_0 , T_0^\prime$ and get $G_1$, which, together with $T_1 , T_1^\prime$ leads to $G_2$, etc. To encode a message $v$, we just have to do $v.G_d$. We can also encode $v$ in a recursive fashion,

        1. If $d = 0$, $\mathrm{enc}_0 ( v ) = v.G_0$
        2. Otherwise, split $v = (w_0 , w_1)$ in the first and second halves. Let $c_0 = \mathrm{enc}( w_0 )$, $c_1 = \mathrm{enc}( w_1 )$, $t = \mathrm{diagonal}(T)$ and compute $\mathrm{enc}(v) = (m_0 + m_1 \times t , m_0 - m_1 \times t)$, where $\times$ is the componentwise (Hadamard) product.

The evaluation of a multilinear polynomial $p$ at $z$ can be turned into an evaluation check of $p$ at a random point via the [sumcheck protocol](/have-you-checked-your-sums/). FRI works in a similar way: the last value sent in FRI corresponds to the encoding of a random evaluation of the polynomial of the first round. Therefore, a PCS can be constructed by using a Merkle tree commitment to the encoding of some polynomial $p$. During evaluation, prover and verifier run in parallel the proximity test and the sumcheck protocol using the same set of challenges. The verifier can check that the evaluation of the polynomial corresponds to the last message of the prover in the proximity test.

Basefold's proximity test works in the same way as FRI. We have a commit phase where the prover commits to lists of codewords/evaluations and a query phase, where the verifier checks the consistency between the codewords. During the commitment phase,

        1. The prover starts with $\pi_d$, the encoding of some polynomial.
        2. For i = $d - 1$ to $0$  
a. Samples $\alpha_i$ from the verifier.  
b. For every $j$ in $n_i$ the prover computes the line $l_j (x)$ passing through $(T_i [j,j] , \pi_{i+1} [j])$ and $(-T_i [j,j] , \pi_{i+1} [j + n_i ])$ and sets $\pi_i [j] = l(\alpha_j )$  
c. The prover commits to $\pi_i$.

This commit phase is, in fact, identical to FRI. We start with the evaluations of the composition polynomial, $f$ (which is the Reed-Solomon encoding of the polynomial) and to which we committed previously. We sample the folding challenge $\alpha_i$ and then obtain the following function, $l(x) = (f(x_0 ) + f( - x_0 ))/2 + x (f( x_0 ) - f( - x_0))/2x_0$. We can see that $l(x_0 ) = f( x_0 )$ and $l( - x_0) = f (- x_0 )$, which is essentially the line passing through those two points.

During the query phase,

        1. The verifier samples an index $i$ in $[0, n_d - 1]$.
        2. For $j = d - 1$ to $0$,  
a. Queries $\pi_{j + 1} [i]$ and $\pi_{j + 1} [i + n_i / 2]$  
b. Computes the line $l_i(x)$ passing through those two points.  
c. Checks that $\pi_j [i] = l(\alpha_j )$  
d. If $j > 0$ and $i > n_{i - 1}$, set $i = i - n_{i - 1}$.
        3. Finally, check whether $\pi_0$ is a valid codeword using the generator matrix $G_0$.

To reduce the soundness error, the verifier can query more indexes, as we did in FRI. We are only lacking the evaluation protocols (prove and verify). To construct it, we need to use the sumcheck protocol, together with the proximity test.

At the start of the protocol, the verifier has access to $\pi_d$, the encoding of the polynomial, the evaluation point, $z$ and the claimed evaluation, $v$. The protocol proceeds as follows:

        1. The prover sends the univariate polynomial $h_d (x) = \sum_b f(b,x) eq_z (b,x)$ to the verifier.
        2. For $i = d - 1$ to $0$,  
a. The prover runs the commit phase steps 2.a, 2.b, 2.c.  
b. If $i > 0$, the prover sends $h_i = \sum_b f(b,x, r_i , ... , r_{d - 1} ) eq_z (b,x, r_i , ... , r_{d - 1} )$.
        3. The verifier:  
a. Checks query phase of the proximity test.  
b. Performs all the checks in the sumcheck protocol  
c. Verifies that $\mathrm{enc_0} (h_1 ( r_0 ) / eq_z (r_0 , ... r_{d - 1} )) = \pi_0$

We see that the evaluation protocol basically consists of the sumcheck and proximity tests run concurrently.

## Conclusion

This post discussed a new commitment scheme, basefold, which generalizes FRI. The main advantanges over FRI are that the new commitment works better with multilinear polynomials and is field agnostic. The construction can be instantiated with any foldable linear code. These are codes whose generator matrix has a given block structure. We will be adding this new commitment scheme to lambdaworks in the coming future and compare its performance with other constructions.
