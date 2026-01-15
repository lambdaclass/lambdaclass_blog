+++
title = "Whirlaway: Multilinear STARKs using WHIR as polynomial commitment scheme"
date = 2025-08-29
slug = "whirlaway-multilinear-starks-using-whir-as-polynomial-commitment-scheme"

[extra]
feature_image = "/images/2025/12/Reception-of-le-gran-conde.jpg"
authors = ["LambdaClass"]
+++

## Introduction

Ethereum has been quickly evolving to become the financial backend of the World. Research and development in zero-knowledge proofs have allowed Ethereum to scale with rollups, by batching transactions off-chain and then posting an update of the accounts together with a cryptographic proof attesting to the validity of the transactions. While progress has been impressive, there remain still some challenges related to the rise of quantum computers (which would break elliptic curve cryptography, now a core primitive in Ethereum), increasing decentralization, and simplifying the protocol to reduce attack surface and possible bugs.

Ethereum presented in Devcon 2024 the roadmap for [Lean Ethereum](https://leanroadmap.org/) to research, define specifications, develop, test and deploy the future of Ethereum, which would allow the protocol to go on maintenance mode and avoid performing major changes. One of the key problems is related to post-quantum secure aggregatable signatures to replace the (elliptic curve-based) BLS signatures powering Ethereum's consensus. While there are several candidates for post-quantum secure signatures, we should pay attention to those that can provide an efficient aggregation algorithm or whose verification can be proven efficiently using post-quantum secure proof systems. Hash-based signatures using SNARK (succinct, non-interactive argument of knowledge)-friendly hashes (such as Poseidon 2 or Rescue Prime Optimized) appear as promising candidates, since current state of the art provers are able to prove nearly 1,000,000 hashes per second on GPU. An important constraint is related to proof sizes, which should be as small as possible, to reduce the communication footprint between the nodes. Current security analysis shows that proof sizes targeting 128 bits of security using FRI are larger, which is why a different candidate is needed. [WHIR](https://eprint.iacr.org/2024/1586.pdf) provides a good candidate, even though it may be slower in concrete terms compared to FRI. It is not surprising, then, that the roadmap contains at least 4 elements in its roadmap targeting the primitives for post-quantum secure aggregatable signatures using succinct arguments of knowledge:

        * Poseidon cryptanalysis initiative.
        * Hash-based multisignatures
        * Minimal zero-knowledge virtual machines (to handle proof aggregation)
        * Formal verification of virtual machines and specification of proof systems.

In this post, we will cover the basics of WHIR used to prove the execution of a virtual machine as described by means of an algebraic intermediate representation (AIR). The way to derive the non-interactive argument of knowledge will be in a standard way, first by a polynomial interactive oracle proof, instantiating the oracle proof using a polynomial commitment scheme and using the Fiat-Shamir transformation. Later posts will focus on signature schemes and virtual machines. You can see the presentation of [WHIR at ethresearch](https://ethresear.ch/t/whir-for-ethereum/22938) for further references, as well as the [WHIR paper](https://eprint.iacr.org/2024/1586.pdf). For the specification of Whirlaway, see the [repo](https://github.com/TomWambsgans/Whirlaway/tree/master), as well as [whir-p3](https://github.com/tcoratger/whir-p3/tree/main/src/whir/pcs).

## Multilinear polynomials

A polynomial in $m$-variables is called multilinear if, in every monomial, the highest power of each indeterminate, $x_i$ is at most 1.

Given a set of evaluations of a function $f$ over $H^m$, there is a unique multilinear polynomial $\hat{f}$ over $H^m$ such that $\hat{f} (x) = f(x)$ for every $x \in H^m$. We can represent the same multilinear polynomial using different basis, the two most common being the monomial basis ($1, x_0, x_1, x_0 x_1, x_2, x_0 x_2, ...$) and the Lagrange basis over $H^m$. For simplicity, we will henceforth take $H = {0 , 1}$. These are defined as follows,  
$\chi_k (x) = \mathrm{eq} ( k_b , x) = \prod_i ( k_{b,i} x_i + (\left\k_{b,i} - 1)(x_i - 1))$  
where $k_b$ is the binary decomposition of $k$, that is $k = \sum_i k_{b,i} 2^i$. The multilinear extension, give the evaluations of $f$ over $\{0, 1\}^m$,  
$\hat{f} (x) = \sum_{b \in \{0,1\}^m } f(b) \mathrm{eq} (b , x) = \sum_k f_k \chi_k (x)$

We can easily check that we can evaluate $\hat{f} (x)$ at any point by evaluating the Lagrange polynomials $\chi_k (x)$ and performing a scalar product between the vector of evaluations of $f$ and the vector of Lagrange basis polynomials,  
$\hat{f} (z) = \sum_k f_k \chi_k (z) = f^t \cdot \chi$

We can find a way of seeing a multilinear polynomial as a univariate polynomial by a suitable transformation. Given a polynomial in the multilinear basis,  
$$f(x_0 , x_1 , x_2 , \dots x_{ m - 1 } ) = a_0 + a_1 x_0 + a_2 x_1 + a_3 x_0 x_1 + a_4 x_2 + a_5 x_0 x_2 + a_6 x_1 x_2 + \dots a_{ 2^m - 1 } x_0 x_1 \dots x_{m - 1}$$  
If we let $x_0 = x$, $x_1 = x^2$, $x_2 = x^4$, $\dots$, $x_{m - 1} = x^{ 2^{ m - 1} }$, then  
$$f(x) = a_0 + a_1 x + a_2 x^2 + a_3 x x^2 + a_4 x^4 + a_5 x x^4 + a_6 x^2 x^4 + \dots a_{ 2^m - 1 } x x^2 x^4 ... x^{ 2^{ m - 1 } }$$

Doing all the products, $f( x ) = \sum_j a_j x^j$

WHIR will make use of this transformation from the multilinear monomial basis to the univariate monomial basis. For example, the paper defines $\mathrm{pow} (z, m) = (z , z^2 , ... z^{ 2^{ m - 1 } })$ which is used to evaluate the multilinear polynomial to $f(z)$.

## Sumcheck protocol

The sumcheck protocol is an important building block for designing efficient interactive proofs. The sumcheck protocol is applied to proving statements of the form  
$\sum_{x \in H^\ell} f(x) = S$  
where $f(x)$ is a multivariate polynomial in $\ell$ variables and $H$ is a set (typically, ${0, 1}$). In other words, we want to show that the sum of the evaluations of $f$ over all the values in $H^\ell$ is equal to $S$. While this seems a bit restrictive or convoluted, computations can be reduced to some instance of this protocol via a suitable transformation. For example, the evaluation of the multilinear extension of a function at $z$ can be written precisely in this form, when using the Lagrange basis polynomials,  
$\hat{f} (z) = \sum_{b \in \{0,1\}^m } f(b) \mathrm{eq} (b , z)$  
The protocol allows the prover to convince the verifier that the sum is $S$ by sending to the verifier $\mathcal{O} (\ell)$ elements, and having the latter perform $\mathcal{O} (\ell)$ operations, plus a single evaluation to $f$ at a random point $(r_0, r_1, ... r_{ \ell - 1})$. We can then compile this to a non-interactive succinct argument of knowledge using the Fiat-Shamir transformation and using a polynomial commitment scheme (PCS) to grant oracle access to $f(r_0, r_1, ... r_{ \ell - 1})$ to the verifier.

The sumcheck protocol can be used several times to reduce complex claims into simpler ones, such as in [Spartan](https://eprint.iacr.org/2019/550). We can also combine several sumchecks into a single one by batching them using random linear combinations. For example, say we want to prove that:  
$\sum_{x \in H^\ell} f_1 (x) = S_1$  
$\sum_{x \in H^\ell} f_2 (x) = S_2$  
We can have the verifier sample random scalars $\alpha_1, \alpha_2$ and we can run the sumcheck over  
$\sum_{x \in H^\ell} \left( \alpha_1 f_1 (x) + \alpha_2 f_2 (x) \right) = \alpha_1 S_1 + \alpha_2 S_2$  
This reduces the amount of elements that the prover needs to send to the verifier and the amount of work involved compared to running the two instances separately.

## Overview of the protocol

In AIR, we have a set of polynomial constraints, such as:

        * $f_0 (x_7) = x_7 - a_k$ and which is valid for the first row. This is a boundary constraint.
        * $f_1 (x_0, x_1, x_2, y_0, y_1, y_2) = x_0 x_1 x_2 - y_1 y_2 y_3$ which should be valid for all consecutive rows, except the last one. This is an example of a transition constraint.
        * $f_2 (x_3) = x_3 (x_3 - 1)$ and valid over all rows, asserts that $x_3$ is a boolean variable. This constraint enforces a consistency condition.

Constraints are given by a multivariate polynomial with a set over which the constraint applies. The degree of the constraint (equal to the highest degree of the monomials) is important since it provides information on the number of points where we need to evaluate in order to fully determine the composition polynomial.

In ordinary STARKs, we can check the validity of the constraints by

        1. Interpolating the trace columns to obtain (univariate) trace polynomials.
        2. Composing the trace polynomials with the constraint polynomials.
        3. Dividing each constraint by the corresponding zerofier.
        4. Use FRI to show that the result is close to a low-degree polynomial.

If we want to use multivariate polynomials, we need to perform some changes on how the protocol works. We will go step-by-step to show how everything works.

We will start with the trace table, $T$. We suppose that the trace has $2^n$ rows and $2^m$ columns. We can always pad tables not fulfilling this condition, or leverage the ideas of [jagged PCS](https://eprint.iacr.org/2025/917) to avoid padding. The table has $2^{n + m}$ elements, which we can view as evaluations of a polynomial $f_{trace}$ over $\{0, 1\}^{n + m}$. In Whirlaway, the elements are stored in row-major order.

The trace is committed as a single multilinear polynomial using WHIR as a polynomial commitment scheme. We will reduce all the polynomial checks to a single evaluation of this polynomial, which we can prove thanks to the polynomial commitment scheme.

We can always get the columns from the trace polynomial by multiplying with a suitable polynomial, in a similar way as we could recover the column from the flattened vector using a suitable matrix-vector product. The computation is correct if we can show that each of the constraint polynomials vanishes on the corresponding set. Suppose we need to show that $f_{16} (X_3 ) = X_3 (X_3 - 1) = 0$ for all rows, where $X_3$ indicates that we need to evaluate this polynomial using column 3. We call this polynomial $c_3 (x)$, where $c_3 ( j_b ) = c_{3j}$, where $j_b$ is the binary representation of $j$, with $j = 0, 1, ... 2^n - 1$. The validity of the constraint is equal to showing that $c_3 (x) (c_3 (x) - 1) = 0$ for all the valid values of $x = j_b$.

We apply a variant of the sumcheck protocol, called the zerocheck to show that all the evaluations are zero over the set:  
$$\sum_{ x \in \{0,1\}^{n}} \mathrm{eq} (\tau,x) c_3(x) (c_3 (x) - 1) = 0$$  
where $\tau$ is sampled at random by the verifier. Eventually, after applying the sumcheck protocol, the verifier is left with the check $\mathrm{eq} (\tau,r) c_3(r) (c_3 (r) - 1) = v_r$. The verifier can compute $\mathrm{eq} (\tau,r)$ efficiently, since it is a linear product of $n$ terms. For $c_3 (r)$, the verifier can query the oracle and he can finally carry out the multiplications. Showing that the evaluation is valid can be done using the PCS, but the problem is how does he know that $c_3 (r)$ is correct, given that the prover committed to $f_{trace} (x)$ and not to the individual columns?

The core idea is that we can run another instance of the sumcheck protocol, linking the trace polynomial with the columns and reducing the checks to a single point.

### Small detour - Spartan

Whirlaway is a proof system based on [SuperSpartan for AIR](https://solvable.group/posts/super-air/#fnref:1), but we can gain an intuition on how it works by looking at other multivariate proof systems, such as Spartan. While there are some differences, the core principles remain similar. We will start with R1CS, which is a common way of representing circuits, where we have matrices $A, B, C$ (from $\mathbb{F}^{n \times m}$) and a vector $z = (w, 1, u)$, where $w$ is the witness vector, and $u$ is the instance vector such that  
$Az \circ Bz - Cz = 0$  
where $\circ$ denotes the Hadamard (component-wise) product of vectors. We can transform this into an instance of the sumcheck protocol, by noting the following:  
$$F (x) = \left( \sum_y A(x,y) z(y)\right) \left( \sum_y B(x,y) z(y)\right) - \left( \sum_y C(x,y) z(y)\right)$$  
$$\sum_x \mathrm{eq} (\tau , x) F(x) = 0$$  
We can have the prover do the work and provide $a(x) = \sum_y A(x,y) z(y)$, $b(x) = \sum_y B(x,y) z(y)$ and $c(x) = \sum_y C(x,y) z(y)$. The zerocheck can be reduced to  
$$\mathrm{eq} (\tau, r_x) F(r_x) = v_x = \mathrm{eq} (\tau, r_x) (a (r_x ) b (r_x) - c( r_x ))$$  
The prover can then show that $a (r_x ), b (r_x ), c( r_x )$ are correct by running the following sumchecks:  
$$\sum_y A(r_x , y) z(y) = a (r_x )$$  
$$\sum_y B(r_x , y) z(y) = b (r_x )$$  
$$\sum_y C(r_x , y) z(y) = c (r_x )$$

All these can be combined into a single check by taking random linear combinations,  
$$\sum_y \left(\alpha A(r_x , y) + \beta B(r_x , y) + \gamma C( r_x , y ) \right) z(y) = \alpha a (r_x ) + \beta b (r_x ) + \gamma c (r_x )$$

This avoids working with one large sumcheck and breaks it into one working with a linear combination of the columns and another with a linear combination of the rows. This idea is exploited in Whirlaway to first perform a zerocheck with the columns and then reducing the evaluation of the columns to the evaluation of the trace polynomial.

* * *

**Steps in the protocol:**

        1. Commit to the trace
        2. Compute the trace columns that are necessary to evaluate the transition constraints, $c_k^{up}$ and $c_k^{down}$.
        3. Perform a zerocheck with those columns and the polynomial constraints, which reduces the verifier's task to evaluating $c_k^{up}$ and $c_k^{down}$ at the random point $\delta$.
        4. Batch the evaluation claims for all the columns and perform the inner sumcheck.
        5. Find the multilinear extension of the columns' evaluations, evaluates at $z$ and checks that this matches the opening of the commitment to the trace at the point $(z, \delta)$.

## WHIR

WHIR is an interactive oracle proof of proximity to constrained Reed-Solomon codes. FRI is also an interactive oracle proof of proximity, but to Reed-Solomon codes. We can transform WHIR into a polynomial commitment scheme in the same way we transformed FRI into a PCS, via committing to the codewords using Merkle trees.

Before jumping into the actual protocol, we will begin with the definitions of error correcting codes.

**Definition (error-correcting code)** : An error-correcting code of length $n$ over an alphabet $A$ is a subset of $A^n$. In particular, a linear code over a finite field $\mathbb{F}$ is a subspace of $\mathbb{F}^n$.

Linear codes are important because they allow for efficient encoding, and linear combination of codewords results in a codeword.

**Definition (interleaved code)** : Given a code $C \subseteq A^n$, the $m$ -interleaved code is the code $C^m \subseteq { (A^m ) }^n$. Each element of a codeword is now an element of $A^m$.

### 1\. Smooth Reed-Solomon Codes

Given a finite field $\mathbb{F}$, a degree $d = 2^m$ and an evaluation domain $\mathcal{L} \subseteq \mathbb{F}^\star$, that must be a multiplicative _coset_ whose order $n$ is a power of two, we define  
$$RS \left[\mathbb{F}, \mathcal{L}, m \right] = \{ f: \mathcal{L} \to \mathbb{F} : / : \exists g \in \mathbb{F}^{ \leq d - 1} \left[X\right] : s.t. : f(x) = g(x) : \forall x \in \mathcal{L} \}.$$  
In other words, it represent all the evaluations that come from a polynomial of small degree. In proof systems, the prover claims that a funtion $f$ (or a its evaluations) is in $RS\left[\mathbb{F}, \mathcal{L}, m\right]$ to convince the verifier that $f$ is polynomial, showing that the function is close to a polynomial of degree $d - 1$.

> Let's recall what is a _coset_ : For example, in Stark101 we have a trace of one column of length 1023, so we define as an evaluation domain a subgroup $G \subseteq \mathbb{F}^\star$ with order $|G| = 1024$. Then we interpolate and want to extend the domain eigth times larger (blowup factor 8), creating a Reed-Solomon error correction code. We take a subgroup $H \subseteq \mathbb{F}^\star$ with $|H| = 8192$, and define as the LDE the _coset_ of $H$ $$wH = \{ w \cdot h_1, \ldots, w \cdot h_{8192} \}$$ with $w$ the generator of $\mathbb{F}^\star$.

### 2\. Multilinear Reed-Solomon Codes:

Equivalently, such Reed–Solomon codes can be viewed as evaluations of multilinear polynomials in m variables:

$$\begin{align*}  
RS\left[\mathbb{F}, \mathcal{L}, m\right] &= \{ f: \mathcal{L} \to \mathbb{F} : / : \exists g \in \mathbb{F}^{ < d} [X] : s.t. : f(x) = g(x) : \forall x \in \mathcal{L} \} \\  
&= \{ f: \mathcal{L} \to \mathbb{F} : / : \exists \hat f \in \mathbb{F}^{\leq 1} [X_0, \ldots, X_{m-1}] : s.t. : f(x) = \hat f(x^{ 2^{0} }, x^{ 2^{1} }, \ldots, x^{ 2^{ m - 1 } }) : \forall x \in \mathcal{L}\}  
\end{align*}$$

**Example:** If $m =3$, $2^m - 1 = 7$ and $2^{m - 1} = 4$. We can represent a univariate polynomial $g$ of degree $7$ as a 3-variable polynomial $\hat f$. Indeed we just need three variables $X_0, X_1, X_2$, since $x_0 \cdot x_1 \cdot x_2 = x^1 \cdot x^2 \cdot x^4 = x^7.$ And in the other way, if we have a 3-variable polynomial $\hat f$, we can represent it as a univariate polynomial $g$ of degree $7$: The maximum degree obtained is in $x_0 \cdot x_1 \cdot x_2 = x^7.$ For example, the polynomial $$g(x) = a_0 + a_3x^3 + a_6x^6$$  
is equivalent to the polynomial  
$$\hat f(x_0, x_1, x_2) = a_0 x_0 + a_1 x_0 x_2 + a_2 x_1 x_2$$

### 3\. Constrained Reed–Solomon Code:

It is a Smooth Reed-Solomon Code with an additional constraint. Given a weight polynomial $\hat w \in \mathbb{F} \left[Z, X_1, \ldots, X_m \right]$ and a target $\sigma \in \mathbb{F}$, we additionaly ask  
$$ \sum_{b \in \{0, 1 \}^m} \hat w(\hat f(b), b) = \sigma.$$

This can help enforce a particular evaluation of the polynomial (which reduces the number of codewords that could simultaneously be close to $f$ and fulfill the condition) or show that the polynomial has zeros over some set.

#### Why do we use this?

Given an evaluation point $r = (r_1, \ldots, r_m) \in \mathbb{F}^m$, we want to additionally constrain that $$\hat f (r) = \sigma.$$  
So if we choose  
$$\hat w(Z, X_1, \ldots X_m) = Z \cdot eq( (X_1, \ldots, X_m), (r_1, \ldots, r_m)),$$  
then we have  
$$ \sigma = \sum_{b \in \{0, 1 \}^m} \hat w(\hat f(b), b) = \sum_{b \in \{0, 1 \}^m} \hat f(b) \cdot eq( b, r) = \hat f(r).$$

## WHIR Protocol

### Preliminary notations

        * $\rho := \frac{ 2^m }{n}$ is the _rate of the code_ , where $n = |\mathcal{L}|$ and $m$ is the number of variables.
        * $\mathcal{L}^{ (i) } = \{x^i : x \in \mathcal{L} \}$. Since $\mathcal{L}$ is smooth, if $i$ is a power of two, then $|\mathcal{L}^{(i)}| = |\mathcal{L}| / i.$
        * $k > 1$ is the _folding parameter_.

### The basic idea

Each WHIR iteration will reduce the task of testing  
$$f \in C = CRS\left[\mathbb{F}, \mathcal{L}, m, \hat w, \sigma \right]$$  
to the task of testing  
$$f \in C^\prime = CRS\left[\mathbb{F}, \mathcal{L}^{(2)}, m - k, \hat w^\prime , \sigma^\prime \right],$$  
where the size of the domain decreases from $n$ to $n/2$, and the number of variables decreases from $m$ to $m - k$.

The WHIR protocol has $M = m/k$ of these WHIR iterations, reducing the proximity test for  
$$C^{(0)} = C$$  
to a proximity test for  
$$C^{ (M) } = CRS\left[\mathbb{F}, \mathcal{L}^{ (2^M) }, O(1), \hat w^{ (M) }, \sigma^{ (M) } \right].$$

_Obs._ $O(1)$: It doesn't depend on $m$ or $k$.

### Protocol Steps

#### 1\. Sumcheck rounds

The Prover and Verifier apply $k$ rounds of the sumcheck protocol for the claim  
$$\sum_{b \in \{0, 1 \}^m} \hat w(\hat f(b), b) = \sigma.$$

The protocol starts with  
$$ \hat w (Z, X) = Z \cdot eq(X, r)$$  
where $\hat f(r) = \sigma$.

The Prover sends the univariate round polynomials $h_1, \ldots k_k$, by fixing in each round the first variable and summing over the rest.

The Verifier samples $\alpha_1, \ldots, \alpha_k \in \mathbb{F}$, and checks $h_1 (0) + h_1 (1) = \sigma$ and $h_j(0) + h_j(1) = h_{j - 1}(\alpha_{j - 1})$.

This reduces the intitial claim to the claim  
$$\sum_{b \in \{0, 1 \}^{ m - k}} \hat w^\prime (\hat f(\alpha_1, \ldots, \alpha_k, b_{k +1 }, \ldots b_m), (\alpha_1, \ldots, \alpha_k, b_{k + 1}, \ldots b_m)) = h_k(\alpha_k),$$

In simpler notation:  
$$\sum_{b \in \{0, 1 \}^{ m - k}} \hat w^\prime(\hat f(\alpha, b), \alpha, b) = h_k (\alpha_k),$$

#### 2\. Send folded function

The Prover sends a function $g: \mathcal{L}^{(2)} \to \mathbb{F}$. In the honest case, $$\hat g(X) = \hat f(\alpha, X),$$ then $\hat g \in \mathbb{F}^{\leq 1} \left[X_1, \ldots, X_{ m - k}\right]$, and $g$ represents the evaluations of $\hat g$ on the domain  
$$ g(x) = \hat f(\alpha_1^{ 2^0 }, \ldots, \alpha_k^{ 2^k }, x^{ 2^{ k + 1}}, \ldots, x^{ 2^m } ) : \forall x \in \mathcal{L}^{(2)}.$$

#### 3\. Out-of-domain sample and evaluation

The Verifier samples and sends $z_0 \in \mathbb{F}$. The prover evaluates and sends $y_0 = \hat g(z_0)$.

_Abuse of notation:_ We denote $\hat g(z_0) = \hat g(z_0^{ 2^0 }, z_0^{ 2^1 }, \ldots, z_0^{ 2^{ m - k - 1}})$.

The out-of-domain sampling essentially forces the prover to choose one of the possible polynomials within a list of polynomials associated with the oracle.

#### 4\. Shift queries and combination randomness

The Verifier samples and sends $z_1, \ldots, z_t \in \mathcal{L}^{ (2^k) }$, where $t$ is the number required in this WHIR iteration, determined by the security parameter $\lambda$. Then for each $i \in \{1, \ldots t\}$, the Verifier queries f and obtains  
$$y_i = \text{Fold}(f, \alpha) (z_i)$$  
Then, the Verifier samples and sends $\gamma \in \mathbb{F}$.

**What is the Fold function?**

Folding of Reed–Solomon codes is a method for lowering the complexity of a code at a relatively small cost and lies at the core of IOPPs for Reed–Solomon codes.

Given $f: \mathcal{L} \to \mathbb{F}$ and $a \in \mathbb{F}$ we define $\text{Fold}(f, a): \mathcal{L}^{(2)} \to \mathbb{F}$ as follows: For each $z \in \mathcal{L}^{(2)}$

$$\text{Fold}(f, a) (z) = \frac{f(x) + f(- x)}{2} + a \cdot \frac{f(x) - f(- x)}{2x},$$

where $x$ is the point in $\mathcal{L}$ such that $z = x^2 = (- x)^2$.

Now, given a vector $\alpha = (\alpha_1, \ldots, \alpha_k) \in \mathbb{F}^k,$ we denote  
$$\text{Fold}(f, \alpha): \mathcal{L}^{ (2^{k}) } \to \mathbb{F}$$  
to the recursive folding on each of the entries in $\alpha$. That is:

$$\text{Fold}(f, (\alpha_j, \ldots, \alpha_k)) = \text{Fold}(\text{Fold}(f, \alpha_j), (\alpha_{j+1}, \ldots, \alpha_k))$$

_Example:_ If $k = 3$, then  
$$\text{Fold}(f, (\alpha_1, \alpha_2, \alpha_3)) = \text{Fold}(\text{Fold}(f, \alpha_1), (\alpha_2, \alpha_3))$$

Let's say $\text{Fold}(f, \alpha_1) = f_1$. Then,

$$\text{Fold}(\text{Fold}(f, \alpha_1), (\alpha_2, \alpha_3)) = \text{Fold}(f_1, (\alpha_2, \alpha_3)) = \text{Fold}(\text{Fold}(f_1, \alpha_2), \alpha_3)$$

Let's say $\text{Fold}(f_1, \alpha_2) = f_2$. Then,

$$\text{Fold}(\text{Fold}(f_1, \alpha_2), \alpha_3) = \text{Fold}(f_2, \alpha_3)$$

So in conclusion,  
$$\begin{align}  
\text{Fold}(f, (\alpha_1, \alpha_2, \alpha_3)) &= \text{Fold}(f_2, \alpha_3) \  
&= \text{Fold}(\text{Fold}(\text{Fold}(f, \alpha_1), \alpha_2), \alpha_3)  
\end{align}$$

#### 6\. Recursive claim

Both Prover and Verifier define the new weight polynomial and target  
$$\hat w^\prime (Z, X) = \hat w(Z, \alpha, X) + Z \cdot \sum_{i = 0}^t \gamma^{i + 1} \cdot \text{eq}(z_i, X)$$  
$$\sigma' = \hat h(\alpha_k) + \sum_{i = 0}^t \gamma^{i+1} \cdot y_i$$

and recurse on the claim that  
$$g \in CRS\left[\mathbb{F}, \mathcal{L}^{(2)}, m - k, \hat w^\prime, \sigma^\prime \right].$$

**Why this weight and this target?**

We want to see how this iteration replace the claim  
$$f \in C = CRS\left[\mathbb{F}, \mathcal{L}, m, \hat w, \sigma\right]$$ to the claim $$g \in C^\prime = CRS\left[\mathbb{F}, \mathcal{L}^{(2)}, m-k, \hat w^\prime, \sigma^\prime\right].$$  
First, note that $\hat w \in \mathbb{F} \left[Z, X_1, \ldots, X_m\right]$ and $\hat w^\prime \in \mathbb{F}\left[Z, X_1, \ldots, X_{ m - k }\right]$.

If the Prover is honest and $f \in C$, why does $g \in C^\prime$?

On one hand, $g \in RS\left[\mathbb{F}, \mathcal{L}^{(2)}, m - k\right]$ because $\hat g \in \mathbb{F}^{\leq 1} \left[X_1, \ldots, X_{ m - k }\right]$ is such that $g(x) = \hat f(\alpha_1^{ 2^0 }, \ldots, \alpha_k^{ 2^k }, x^{ 2^{ k + 1 }}, \ldots, x^{ 2^m } )$.

On the other hand, we need to check the sum constraint: We want to prove that  
$$\sum_{b \in \{0, 1 \}^{ m - k}} \hat w^\prime (\hat g(b), b) = \sigma^\prime .$$  
Let's see:  
$$\sum_{b \in \{0, 1 \}^{ m - k}} \hat w^\prime (\hat g(b), b) = \sum_{b \in \{0, 1 \}^{ m - k}} \hat w(\hat f(\alpha, b), (\alpha, b)) + \hat f(\alpha, b) \sum_{i = 0}^t \gamma^{i + 1} \cdot eq(z_i, b)$$  
$$\sigma^\prime = \hat h(\alpha_k) + \sum_{i = 0}^t \gamma^{ i + 1} \cdot y_i$$

Since  
$$\hat h(\alpha_k) = \sum_{b \in \{0, 1 \}^{ m - k}} \hat w(\hat f(\alpha, b), (\alpha, b)),$$  
we just need to check that  
$$\sum_{i = 0}^t \gamma^{i+1} \cdot y_i = \sum_{b \in \{0, 1 \}^{ m - k}} \hat f(\alpha, b) \cdot \sum_{i = 0}^t \gamma^{i + 1} \cdot eq(z_i, b),$$  
where  
$$\sum_{i = 0}^t \gamma^{i + 1} \cdot y_i = \gamma \cdot \hat f(\alpha, z_0) + \sum_{i = 1}^t \gamma^{i + 1} \cdot \text{Fold}(f, \alpha)(z_i).$$

## Next steps

In upcoming posts, we will be covering several aspects related to the security of WHIR, its use as a proving backend for efficient post-quantum secure signature aggregation and possible improvements to reduce proof size and proving time.
