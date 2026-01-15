+++
title = "Optimizing Sumcheck"
date = 2025-08-28
slug = "optimizing-sumcheck"

[extra]
math = true
feature_image = "/images/2025/12/Prayer-in-the-Mosque---The-Metropolitan-Museum-of-Art.jpg"
authors = ["LambdaClass"]
+++

## Introduction

In this article we review some of the optimizations for the SUMCHECK protocol as discussed in the recent article by Bagad, Dao, Domb and Thaler. The authors tackle the problem of _disproportionate cost of field multiplications_. In many SNARK applications, the sum-check protocol operates over _extension fields_ , which are much larger than their _base fields_. While the actual values being summed or computed are often "small" (e.g., 32-bit integers or elements of the smaller base field), multiplications involving elements from the larger extension field (large-large (ll) multiplications) are significantly more expensive than those within the smaller base field (small-small (ss) multiplications). This cost disparity can be substantial, sometimes orders of magnitude.

## Quick review of the SUMCHECK Protocol

As the reader might already know, the SUMCHECK protocol is a fundamental interactive proof system in verifiable computing and cryptography first introduced by Lund, Fortnow, Karloff, and Nisan around 1990-1991. We will begin by broadly describing its purpose and typical usage and then we'll start looking into details of implementation where some clever observations can lead to an enhanced performance. The reader familiar with the protocol can safely skip the first section; those who want a quick refresher are invited to read.

The primary purpose of the SUMCHECK Protocol is for a _prover (P)_ to convince a _verifier (V)_ that a _large sum of polynomial evaluations_ equals a specified value, without the verifier having to compute the entire sum herself. This sum is typically over all inputs in the _Boolean hypercube_ , $\\{0,1 \\}^l$, for an $l$-variate polynomial $g$.

> The core benefit for the verifier is a drastic reduction in computational work: the verifier could compute the sum by evaluating the polynomial at all $2^n$ possible inputs. However, using the SUMCHECK Protocol, the _verifier ultimately only needs to evaluate the polynomial at a single, randomly chosen point_ in a larger finite field. This random point is selected from a "much bigger space" than just $\\{0,1\ }^l$.

The protocol proceeds through an interactive series of rounds between the prover and the verifier:  
1\. **Initial Claim:** At the start, the prover sends a value, $C_1$, which is claimed to be equal to the desired sum $H$.  
2\. **Iterative Reduction:** The protocol involves $n$ rounds (where $n$ is the number of variables in the polynomial). In each round $j$ (from 1 to $l$):  
\- The _prover sends a univariate polynomial_ , $g_j(X_j)$, which is claimed to represent a partial sum of the original polynomial where the first $j-1$ variables have been "bound" to random values chosen by the verifier in previous rounds, and the $j$-th variable is left free. This process "gets rid of one variable in the sum check" in each round.  
\- The _verifier performs consistency checks_ on the received polynomial, notably checking if the current polynomial is consistent with the value established in the previous round (e.g., $C_1 = g_1(0) + g_1(1)$ in Round 1, and $g_{j - 1}(r_{j - 1}) = g_j(0) + g_j(1)$ in subsequent rounds). The verifier also checks that the degree of $g_j (X_j)$ is not too high.  
\- If checks pass, the _verifier chooses a new random field element, $r_j$_ , and sends it to the prover. This random choice serves to probabilistically verify the polynomial sent by the prover.  
3\. **Final Check:** In the last round ($l$), the prover sends a univariate polynomial $g_l (X_l)$ which should be the original polynomial $g$, evaluated at all the random $r$ values chosen so far for the first $l - 1$ variables. The verifier then picks a final random $r_l$ and directly evaluates the original polynomial $g$ at the complete random point $(r_1, \dots, r_l)$, comparing this result to $g_l(r_l)$. If all checks pass, the verifier accepts the initial sum.

> A significant feature of the protocol is that the _verifier's messages are simply random field elements_ , independent of the input polynomial $g$ (except for needing an upper bound on its degree in each variable and the ability to evaluate it at a random point).

Before jumping under the hood, let's talk notation. For brevity and to make our life easier, we will simplify notations when the number of variables and involved dimensions are clear from the context. In this article we concentrate in polynomials in $\ell$ variables $X_1, X_2,\ldots X_{\ell}$, but for simplicity we adopt

$$f(X_1, X_2 , \ldots X_{\ell}) = f(X)$$

as standard notation. When these $\ell$ variables get partitioned, we also use a single letter to denote its limbs, say we split $X$ in three parts

$$(X_1, X_2 ,\ldots X_{\ell}) = (Y_1 , Y_2, \ldots Y_{i - 1},X_i, x^\prime_{i + 1},\ldots x^\prime_{\ell})$$

we simply use $(Y, X_i , x^\prime)$ to reduce cumbersome indexing.

### The setting

The authors focus on a specific setting for the SUMCHECK, useful in various contexts: they narrow their attention to the case where the polynomial $g$ object of the SUMCHECK claim can be written as a product of $d$ multilinear polynomials

$$g(X) = \prod\limits_{k = 1}^d p_k(X)$$

where by multilinear polynomial we mean a $\ell$ variate polynomial such that each of its monomials has the following feature: each variable is raised to a power which is either 0 or 1. These polynomials are of great use and appear throughout field theory literature in different guises and recently re emerged as useful objects in Ben Diamond and Jim Posen's effort BINIUS. For the unfamiliar reader, we recommend giving a quick read to our self-contained primer on these objects, [Multilinear polynomials: a basic survival guide](/multilinear-polynomials-survival-kit/).

## A closer look

The key observation in the optimizations considered dwells on the realization that the polynomial sent in the $i - th$ round by the prover:

$$s_i (X_i) = \sum\limits_{x^\prime \in \\{0,1\\}^{\ell - i}} \prod\limits_{ k = 1 }^d p(r, X_i ,x^\prime)$$

is indeed a sum of univariate polynomials on the variable $X_i$. The way polynomials are handed over between prover and verifier is usually by means of passing their evaluations on an adequate set. From the evaluations of $s_i$ on a a sufficiently large set, the verifier is able to reconstruct the polynomial. from the data received.

How big should the evaluation set be? Well, this question was answered many many years ago by the Fundamental Theorem of Algebra: for a polynomial $f$ of degree $deg(f)$ it suffices to have $deg(f) + 1$ evaluations to fully reconstruct its coefficients. So the prover needs to send $deg(s_i)_{i + 1}$ evaluations to the verifier, and now the problem becomes sending the elements

$$s_i (u) = \sum\limits_{x^\prime \in \\{0,1\\}^{\ell -i }}\prod\limits_{ k = 1}^d p(r,u,x^\prime)$$

for all $u$ in a set of size at least $deg(s_i)_i+1$.

### The key insight

The key insight is that the elements being summed for each $s_i (u)$, namely

$$\prod\limits_{ k = 1 }^d p_k(r,u,x^\prime)$$

are not only products of evaluations of multilinear factors, but also: there are _different types of evaluations going on_ in each summand:

i. On the one hand, factors $p_k$ are evaluated at $r = (r_1 ,r_2 ,\ldots r_{i - 1})$ in its first $i - 1$ variables - these evaluations involve interaction with the verifier since they employ random elements from a much bigger space than the boolean cube (typically a field extension of the base field) chosen by the verifier. Representation and algebraic manipulation of these challenges take up more memory and time than the demanded by the base field. In the context of BDDT, they involve $\frak{ll}$ and $\frak{ls}$ (large-large and large-small) multiplications.  
ii. On the other hand we have $u$ which is simply a base field element and also the evaluation of the factors $p_k$ at points in the boolean hypercube $\\{0,1\\}^{ \ell - i}$ corresponding to the last $\ell - i$ variables: these evaluations need no interaction with the verifier and crucially, do not involve elements in an extension of the base field. These are considered $\frak{ss}$ multiplications since they are taken to be base field elements.

> **This observation gives the following idea: if it were possible to de-couple such evaluations then there might be some margins for improving performance: evaluations not depending on the interaction with the verifier could be done offline as part of a pre-processing phase, and then the ones involving the random challenges could be tackled online...**

The good news is that Bagad, Dao Domb and Thaler succesfully pursue this stream of ideas by cleverly employing (once again) the notion of interpolation: a polynomial can be expressed as a sum of **basis interpolation polynomials** that can be **precomputed** and more importantly, defined on an arbitrary large enough subset of the **base field** ; then evaluations on any desired challenge can be computed evaluating these auxiliary polynomials instead of the original polynomial instead.

To see how this decoupling can be done, let's go for a very very simple example. Suppose that we are asked by a verifier to evaluate a polynomial $f$ at a random challenge $r$. For concreteness, let

$$f(x) = 2x^2 - 3x + 1$$

Here's how we use interpolation to perform the task: since $f$ has degree 2, we need at least 3 points to evaluate $f$. Let's pick the set  
$${\\{0, 1, 2\\}}$$

First, we need to find the value of our polynomial $f(x)$ at each of these points.

        * $f(0) = 2(0)^2 - 3(0) + 1 = \mathbf{1}$
        * $f(1) = 2(1)^2 - 3(1) + 1 = 0$
        * $f(2) = 2(2)^2 - 3(2) + 1 = 8 - 6 + 1 = \mathbf{3}$

Secondly, we build the Lagrange basis for the set $\\{0, 1, 2\\}$: it has three degree 2 polynomials

$$\\{L_0 ,L_1 ,L_2 \\}$$  
that work just as the canonical basis: each basis polynomial $L_j(x)$ has the special property that

$$L_i (j) = 1\quad\text{ if } j = i,\quad L_i (j) = 0\quad\text{ if } j\neq i,$$

Lagrange's formula for producing such polynomials is well known and produces

        * **$L_0(x)$:** (associated with $x_0 = 0$):$$L_0(x) =0.5x^2 - 1.5x + 1$$
        * **$L_1(x)$:** (associated with $x_1 = 1$):$$L_1(x) = -x^2 + 2x$$
        * **$L_2(x)$:** (associated with $x_2 = 2$):$$L_2(x) = 0.5x^2 - 0.5x$$

These three polynomials form the **Lagrange basis** for the set $\\{0, 1, 2\\}$.

Finally, the Lagrange polynomial is constructed as a weighted sum of these basis polynomials, where each weight is the value of the function at the corresponding point. We have

$$f(x) = f(0) \cdot L_0 (x) + f(1) \cdot L_1 (x) + f(2) \cdot L_2(x)$$  
This is

$$f(x) = \mathbf{1} \cdot (0.5x^2 - 1.5x + 1) + \mathbf{0} \cdot (-x^2 + 2x) + \mathbf{3} \cdot (0.5x^2 - 0.5x)$$

Now we're ready to observe that $f$ can be expressed as a combination of polynomials (that are **independent of the choice of $r$** and that are auxiliary respect to $f$) with weights being evaluations of $f$ at base field point chosen by the prover. In this sense, the computation of these scalars is also independent of the interaction with the verifier and can be done in a pre-processing phase.

It is only at this stage that the verifier hands the random challenge $r$ and **the prover computes $f(r)$ not by evaluating $f$ itself but evaluating the basis polynomials $L_i$** at $r$:

$$f(r) = f(0) L_0 (r) + f(1) L_1(r) + f(2) L_2(2)$$

> **The take away is:** evaluation of $f$ on the random challenges will be deflected to evaluation of auxiliary polynomials that can be precomputed and will concentrate the heavier computational burden.

Of course, this idea can be extrapolated to multivariate polynomials by the use of tensor products of univariate Lagrange bases. For instance, suppose we need to evaluate the polynomial

$$f(Y_1, Y_2) = Y_1 (2 + Y_2 )^2$$

It has degree 1 as polynomial in $Y_1$ and degree 2 as polynomial in $Y_2$. We will consider now interpolating $f$ over the grid $\\{0,1,2\\}^2$; the next step is to find bivariate polynomials that play the same role as the univariate Lagrange polynomials. It is no wonder that if we consider the univariate basis

$$\\{L_0 ,L_1 ,L_2\\}$$

and define $L_{i,j} (Y_1 ,Y_2) = L_i (Y_1) L_j (Y_2)$ then the collection

$$\mathcal{L} = \\{L_{i,j}: (i,j)\in\\{0,1,2\\}^2\\}$$

will verify

$$L_{i,j} (a,b) = 1\quad\text{ if }, (a,b) = (i,j),\quad L_{i,j}(a,b) = 0\quad\text{ if }, (a,b)\neq (i,j)$$

and so

$$f(Y_1,Y_2) = \sum\limits_{(i,j)\in \\{0,1,2\\}^2} f(i,j) L_{i,j}(Y_1, Y_2)$$

## Pushing forward

So the previous discussion will come to fruition within the SUMCHECK protocol at the time of interpreting

$$\prod\limits_{ k = 1}^d p_k(r,X_i ,x^\prime)$$

for fixed $x^\prime$ in the boolean hypercube $\\{0,1\\}^{ \ell - i}$ and $u$ in a convenient subset of the base field as the evaluation of the polynomial

$$F_{u,x^\prime} (Y_1 ,Y_2 ,\ldots,Y_{i - 1}) = \prod\limits_{k = 1}^d p_k(Y,u,x^\prime)$$

at the random challenge $r = (r_1 ,r_2 ,\ldots r_{ i - 1})$. Again, for simplicity we will adopt the more reasonable notation

$$F(Y) = \prod\limits_{ k = 1}^d p_k(Y,u,x^\prime)$$

Also at this point, we will generically suppose that each of the factors $p_k$ factors indeed include $X_i$ as a variable; in that case, the polynomial $s_i (X_i)$ that the prover needs to evaluate has degree $d$ and therefore we need a subset of at least $d + 1$ elements to evaluate such a polynomial.

For concreteness, suppose we pick a subset $U_d$ in the base field with $d + 1$ points. We will then consider the grid

$$G_g = U_d\times\cdots\times U_d = U_d^i$$

to build our Lagrange multivariate polynomials $L_v(Y)$ with $v\in G_d$. For simplicity, we are ommiting $i$ from the notation in the grid.\medskip

**Now interpolating $F$ with the multivariate Lagrange basis will transform this $F$ into a sum indexed by a grid of points $v\in G_d$ with small coordinates, weighted with coefficients being the evaluations of $F$ at base field elements**

$$F(Y) = \sum\limits_{v\in G_d} F(v) L_v (Y)$$

Now at the time of looking at $s_i (u)$, remember that we need to sum over the hypercube of the last $\ell - 1$ coordinates and that $u$ is now the evaluation of the $X_i$ variable. The point here is that we realize that **the sum over the hypercube interacts nicely with the sum coming from the interpolation: we will now make explicit the dependence of F with $u$ and $x^\prime$**

$$s_i (u) = \sum\limits_{x^\prime \in \\{0,1\\}^{ \ell - i}} F_{u,x^\prime }(r) = \sum\limits_{x^\prime \in \\{0,1\\}^{ \ell - i}} \sum\limits_{v\in G_d} F_{ u,x^\prime } (v) L_v(r) = \sum\limits_{v\in G_d} \left(\sum\limits_{ x^\prime\in \\{0,1\\}^{ \ell - i}} F_{u,x^\prime}(v)\right) L_v(r)$$

From this expression we are able to see why this strategy works: the desired values $s_i(u)$ to be sent to the verifier are simply linear combinations of precomputed interpolation polynomials involving large multiplications (since they depend on the random challenges) weighted by sums indexed by the hypercube, of pre-computed evaluations over base field grid vectors, this is, _small_ coefficients.

The coefficients in this linear combination are termed **accumulators** , mainly because they are a sum. For each fixed $v\in G_d$ and $u$, then

$$\sum\limits_{x^\prime \in \\{0,1\\}^{ \ell - i}} F(v) = \sum\limits_{x^\prime \in \\{0,1\\}^{ \ell - 1}} \prod\limits_{ k = 1}^d p_k(v,u,x^\prime) = A_i(v,u)$$

None of these depend on interactions with the verifier and can be conveniently hanldled offline. The number of accumulators to be computed depends on the degree of the polynomial $s_i (X_i)$ to be sent, and that problem can be addressed generically by assuming it's a degree $d$ polynomial or by refining at each round deciding how many factors indeed contain the interesting variable.

### Optimizing the pre-computation phase

Now much work can be done still in the pre-computation phase, due to the nature of the indexing of the elements in the grid and the structure of the coefficients. Authors propose an algorithm coined $idx4$ - simply a selection rule. Its function is to determine which accumulators $A_i (v,u)$ a product term contributes to, allowing that term to be calculated only once and then reused efficiently.

> **The Goal: Reusing Calculations.** Instead of re-calculating all products for each accumulator, the optimization involves computing each $P$ just once and then distributing it to all corresponding accumulators. The $idx4$ function is the mechanism that decides "where each product $P$ goes".

You can think of $idx4$ as a pattern matching or deconstruction function. Its job is to take an evaluation prefix $\beta$ and see how many valid accumulator patterns it fits into.

        * **Input:** A prefix $\beta = (\beta_1, \dots, \beta_{l})$, where each $\beta_j$ belongs to the set of evaluation points $U_d$.
        * **Process** : For each round $i$ (from $1$ to $l$), $idx4$ tries to decompose $\beta$ into three parts that match the structure of an accumulator $A_i (v,u)$: 
          1. $v = (\beta_1, \dots, \beta_{i-1})$: The prefix corresponding to the challenges from previous rounds.
          2. $u = \beta_i$: The evaluation point for the current round $i$.
          3. $y = (\beta_{i+1}, \dots, \beta_{l})$: The suffix of the prefix.
        * **The Key Selection Condition:** The selection rule is simple: the deconstruction for a given round $i$ is only valid if the suffix $y$ is composed **exclusively of binary values (0s and 1s)**. If any element in $y$ is non-binary then the prefix $\beta$ does not contribute to any accumulator for round $i$.
        * **Output:** The function returns a set of all valid tuples $(i, v, u, y)$ that could be formed from the input $\beta$.

This selection process is carried out within the pre-computation phase, the typical flow being as follows:

        1. The algorithm iterates over every possible evaluation prefix $\beta \in (U_d)^{l}$.
        2. For a given $\beta$, it computes the product term $P = \prod_{ k = 1 }^{d} p_k(\beta, x'')$.
        3. It calls the function $idx4(\beta)$ to get the set of destination indices $\mathcal{I}$.
        4. Finally, it iterates over each tuple $(i, v, u, y)$ in $\mathcal{I}$ and adds the value of $P$ to the corresponding accumulator $A_i (v,u)$.

## Choices for interpolation

Our article expanded on the general principles of decoupling the different types of evaluations via Lagrange interpolation. However, BDDT dive deeper into the details and slightly modify the interpolation basis involved to exploit the fact that the factors of $g$ are indeed, _multilinear_ polynomials.

The variant of Lagrange interpolation presented by the authors reconstructs a polynomial of degree $d$ using its evaluations at $d$ distinct points plus its leading (highest-degree) coefficient, instead of the typical $d + 1$ evaluations. This leading coefficient is termed the _evaluation at infinity_ and is denoted as $s(\infty)$.

The formula used for interpolation then becomes:  
$$s(X) = a \cdot \prod_{ k = 1}^{d} (X - x_k ) + \sum_{k = 1}^{d} s(x_k ) \cdot \mathcal{L_{ \\{x_i\\},k}} (X)$$

Where:

        * $a$ is the leading coefficient of $s(X)$, also denoted $s(\infty)$.
        * $x_1, \dots, x_d$ are the $d$ distinct evaluation points.
        * $s(x_k)$ is the evaluation of $s(X)$ at the point $x_k$.
        * $\mathcal{L_{ \\{x_i\\},k}}(X)$ is the k-th Lagrange basis polynomial for the set of points $\\{x_1, \dots, x_d\\}$.

Let's cook up an example and show that this actually holds.

### Toy example: Degree 2 Polynomial

Let's take the polynomial $s(X) = 3X^2 - 5X + 2$. In the BDDT approach, to fully encode this polynomial we just need _only 2 evaluations and the leading coefficient_.

        1. **We begin by gathering the necessary information:**
           * **Evaluation at infinity** : The leading coefficient is $a = 3$. Therefore, $s(\infty) = 3$.
           * **Evaluation points** : We choose two distinct points, for example, $x_1 = 0$ and $x_2 = 1$.
           * **Evaluations:**  
a. $s(0) = 3(0)^2 - 5(0) + 2 = 2$  
b. $s(1) = 3(1)^2 - 5(1) + 2 = 0$
        2. **Now we construct the interpolation basis:**
           * The Lagrange basis polynomials for the points ${0, 1}$ are:  
a. $\mathcal{L_1} (X) = \frac{X - 1}{0 - 1} = 1-X$  
b. $\mathcal{L_2} (X) = \frac{X - 0}{1 - 0} = X$
           * The interpolation formula for $d = 2$ is: $$s(X) = s(\infty) \cdot (X - x_1) (X - x_2) + s(x_1)\mathcal{L_1} (X) + s(x_2)\mathcal{L_2} (X)$$
           * Substituting the values:  
$$s(X) = 3 \cdot (X - 0)(X - 1) + 2 \cdot (1 - X) + 0 \cdot (X)$$
           * Simplifying:  
$$s(X) = 3(X^2 - X) + 2 - 2X$$  
$$s(X) = 3X^2 - 3X + 2 - 2X$$  
$$s(X) = 3X^2 - 5X + 2$$  
The result matches the original polynomial.

> For practical purposes, BDDT concentrates on an evaluation set of the form $$U_d = \\{\infty,0,1,2,\ldots d - 1\\}$$ to interpolate a degree $d$ polynomial.

### Calculation of $s(\infty)$ for a Product of Polynomials

The reason why this modification takes place is that leading coefficients of products of polynomials are always easy to compute: the distributive law ensures that

$$s(X) = p(X) q(X) \implies s(\infty) = p(\infty) q(\infty)$$  
this is - the leading coefficient of a product is the product of the leading coefficients. Moreover, for a linear polynomial $p_i(X)$, its leading coefficient can be calculated as the difference of its evaluations at 1 and 0: $p_i(1) - p_i(0)$.

Therefore, the formula is:  
$$s(\infty) = \prod_{i = 1}^{d} p_i(\infty) = \prod_{i = 1}^{d} (p_i (1) - p_i (0))$$

**Example:**

Let $s(X) = p_1(X) \cdot p_2(X)$, where:  
\- $p_1(X) = 2X + 3$  
\- $p_2(X) = 5X - 4$

        1. **Calculate $p_i (\infty)$ for each factor:**
           * $p_1 (\infty) = p_1 (1) - p_1 (0) = (2(1) + 3) - (2(0) + 3) = 5 - 3 = 2$. (The leading coefficient of $p_1$ is 2).
           * $p_2 (\infty) = p_2 (1) - p_2 (0) = (5(1) - 4) - (5(0) - 4) = 1 - (- 4) = 5$. (The leading coefficient of $p_2$ is 5).
        2. **Calculate $s(\infty)$:** $$s(\infty) = p_1(\infty) \cdot p_2(\infty) = 2 \cdot 5 = 10$$
        3. **Verification** :  
Let's multiply the polynomials to find $s(X)$ explicitly: $$s(X) = (2X + 3)(5X - 4) = 10X^2 - 8X + 15X - 12 = 10X^2 + 7X - 12$$

The leading coefficient of $s(X)$ is **10** , which confirms that the rule works perfectly.
