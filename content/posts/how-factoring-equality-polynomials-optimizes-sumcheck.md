+++
title = "How factoring equality polynomials optimizes sumcheck"
date = 2025-09-25
slug = "how-factoring-equality-polynomials-optimizes-sumcheck"

[extra]
feature_image = "/images/2025/12/Jean-Leon_Gerome_Pollice_Verso.jpg"
authors = ["LambdaClass"]
+++

## Introduction

In this article we will continue our study and analysis of the work by Bagad, Dao, Domb and Thaler,''Speeding up SUMCHECK'' regarding optimizations for the SUMCHECK protocol applied to polynomials that are products of multilinear polynomials. It is now time to dive into specificity: since equality polynomials are widely used in cryptographic environments, a great deal of interest is order.

## Once upon a time...

The reader of this article surely must have surely come across equality polynomials (also known as ''eq polynomials'') - polynomials that evaluate to zero at all points of their domain but one, where they evaluate to one. In the usual real analysis jargon, they also known as indicator functions for points in the cartesian space. Recalling the role of multilinear polynomials in one and several variables, equality polynomials can be obtained by multiplying together "smaller ones". Concretely, suppose $\mathbb{F}$ is a field and let $\omega \in \mathbb{F}^\ell$: this is

$$\omega = (\omega_1, \omega_2, \ldots, \omega_\ell)$$

for $\omega_i \in \mathbb{F}$. Suppose now that we partition $\omega$ in blocks; for instance, suppose we want to split it into three blocks, say

$$\omega = (\omega_L,\omega_C,\omega_R)$$

where $L,C,R$ are a partition of $[\ell] = \\{1,2,\ldots \ell \\}$ such that $$l < c < r \quad \forall\ l \in L, c\in C, r\in R$$. These subsets indicate the indices involved in each ''chunk'' of $\omega$. If the reader needs some help visualizing this, just think

$$\omega = (2,3,4,2,5,5) = ((2,3), (4,2), (5,5))$$

for $L = \\{1,2\\}, C = \\{3,4}, R = \\{5,6\\}$.

> The good thing about block partitioning points is that it is compatible with factorization of equality polynomials: $$\omega = (\omega_L ,\omega_R )\implies eq_\omega (x) = eq_{\omega_L}(x_L ) eq_{\omega_R} (x_R )$$ for $x = (x_L,x_R)$, a block partition of the variable $x$.

This is of course absolutely compatible with the tensor nature of the interpolation basis of multilinear polynomials, and comes as no surprise. One extra observation comes handy and will play a crucial role, especially when summing evaluations of polynomials defined over finite fields. Whenever a polynomial $f$ can be block-factored as shown above, then its integral (i.e. the sum of its evaluations) can be done sequentially, or in other words: there is a clever way of reordering the domain of evaluation we can take advantage of. Specifically, suppose $x\in\mathbb{F}^\ell$ and that

$$f(x) = f_L (x_L ) f_R (x_R )$$

then **the sum over all $x$ can be indexed according to any of its blocks** :

$$\sum\limits_{x\in\mathbb{F}^\ell } f(x) = \sum\limits_{ x\in\mathbb{F}^\ell } f_L (x_L ) f_R (x_R ) = \sum\limits_{ x_R\in\mathbb{F}^R }\sum\limits_{ x_L\in\mathbb{F}^L } f_L (x_L ) f_R (x_R )$$

where by fixing the index in the outer sum, the factors involving that very index can be taken out of the inner sum (i.e. distributive law in reverse), so

$$\sum\limits_{ x\in\mathbb{F}^\ell } f(x) = \sum\limits_{ x_R\in\mathbb{F}^R } f_R (x_R ) \sum\limits_{ x_L\in\mathbb{F}^L } f_L (x_L )$$

> This sort of ideas will be the ones we'll discuss and exploit: fixing $X_R$ will allow to pre-compute sums over $X_L$ where $X_R$ is considered as a parameter: in this sense, the latter sum is pre-computed and then re-used whenever the parameter $X_R$ is invoked.

**If the reader is wondering what is the name of the game: the name of the game is accumulate, accumulate, accumulate (but cleverly).**

## Ideas(ideas)

We're now ready to dive into the optimizations proposed by BDDT. The starting point is a sum-check protocol over a polynomial of the form $$g(X) = \tilde{eq}(w, X) \cdot p(X)$$ where $p(X)$ is itself a product of $d$ multilinear polynomials. This makes $g(X)$ a polynomial of degree $d+1$. In each round $i$ of the sum-check protocol, the prover must send a univariate polynomial $s_i (X)$, which is the sum of $g(X)$ over the remaining variables. To define this polynomial, the prover needs to compute $d + 2$ of its evaluations.

The authors take up on the work by Angus Gruen and take it even further. Briefly, **Gruen's key idea** is to leverage the special structure of the equality polynomial, $\tilde{eq}$. This polynomial can be decomposed into a product:  
$$\tilde{eq}(w, (r_1 , ..., r_{i - 1}, X_i, x_{i + 1}, ..., x_l )) = \underbrace{\tilde{eq}(w_{[<i]}, r_{[<i]}) \cdot \tilde{eq}(w_i, X_i) }_ \text{ Linear part l_i(X) } \cdot \underbrace{\tilde{eq}(w_{[>i]}, x')}_ \text{Remaining part}$$

The effect of this decomposition is that the round polynomial, $s_i (X_i)$ originally defined as the sum over $x^\prime$ now looks like a product:

\begin{equation}  
\begin{split}  
s_i (X_i) &=\sum\limits_{x'}g(r,X_i,x') = \sum\limits_{x'}eq(r,X_i,x')p(r,X_i,x') \newline  
&= \sum\limits_{x'}eq_{w<i}(r)eq_{w_i}(X_i)eq_{w>i}(x')p(r,X_i,x') \newline  
&= eq_{w<i}(r)eq_{w_i}(X_i)\left(\sum\limits_{x'}eq_{w>i}(x')p(r,X_i,x')\right)  
\end{split}  
\end{equation}

The round polynomial now is a product of **a linear factor $l_i(X_i)$}** , namely

$$l_i(X_i) = eq_{w<i} (r) eq_{w_i} (X_i)$$  
that depends on the challenges from previous rounds ($r_{[<i]}$) and the current variable ($X_i$) and **a degree-$d$ factor, $t_i(X_i)$:**

$$t_i(X_i) = \sum\limits_{x'}eq_{w>i}(x')p(r,X_i,x')$$

which contains the actual summation, including the product of the $p_k$ polynomials and the remaining part of the $\tilde{eq}$ polynomial. The polynomial to be calculated by the prover at the $i-th$ round is then  
$$s_i(X_i) = l_i(X_i) \cdot t_i(X_i)$$

The reader might be asking what is the benefit of thinking of $s_i$ in this way.

> Instead of computing $d + 2$ evaluations of the complex polynomial $s_i(X)$ (degree $d + 1$), the prover now only needs to compute $d + 1$ evaluations of the simpler polynomial $t_i(X)$ (degree $d$). One of these evaluations, $t_i(1)$, can be derived from the protocol's consistency check ($s_i(0) + s_i(1) = C_{i - 1}$), so in practice, only $d$ sums are explicitly calculated.

In summary, Gruen reduces the degree of the polynomial that the prover must perform the most work on, saving the cost of one full evaluation in each round of the protocol. **BDDT's key idea is to re-apply the separability property of the $\tilde{eq}$ polynomial, but this time on the remaining variables being summed over ($x'$)** , combined with their previous proposal of deflecting the evaluation of $p$ at the random challenges to the evaluation of Lagrange interpolation polynomials. In broad strokes, the novel work goes like

        1. **Variable Splitting:** They divide the set of remaining variables $x'$ into two parts of proper length, which we for now call $x_L$ (left) and $x_R$ (right).
        2. **Nested Summation:** Thanks to this split, the sum to compute $t_i(u)$ can be rewritten as a nested sum: $$t_i(u) = \sum_{x_R} \tilde{eq}(w_R, x_R) \cdot \left( \sum_{x_L} \tilde{eq}(w_L, x_L) \cdot \prod_{k=1}^{d} p_k(r,u,x_L,x_R) \right)$$

**This rewriting is the core of the optimization. The prover can now first compute the inner sum (over $x_L$) and then use those results for the outer sum (over $x_R$).**

> This "sum-splitting" technique yields very significant benefits in terms of time and, above all, memory.

        * **Drastic Memory Reduction:** The standard method would require precomputing and storing a table with the evaluations of $\tilde{eq}(w, x)$ for all $x$—a table of size $2^l$. BDDT's optimization **eliminates the need for this giant table**. Instead, the prover only needs to precompute tables for the evaluations of $\tilde{eq}$ over the halves of the variables ($x_L$ and $x_R$), which are of size $\approx 2^{l/2}$. Moving from a memory requirement of $O(2^l)$ to $O(2^{ l/2 })$ is an exponential improvement and makes much larger problems feasible.
        * **Reduced Computational Cost (Time):** By avoiding multiplications with the large $\tilde{eq}$ table, the prover saves a considerable number of operations. The paper estimates this optimization reduces the cost by roughly $N$ multiplications between large field elements, where $N = 2^l$ is the size of the summation domain. The sums are processed over smaller domains iteratively, which improves memory locality and computational efficiency.

This optimization is applied during the first $l/2$ rounds of the protocol. For the remaining rounds, the benefit diminishes, and the algorithm switches back to a standard method.

## Organization beats time

The fact that the authors propose a combination of Gruen's strategy and their own ideas from _SmallValues_ optimization implies that there is special care to be taken at the time of evaluating the polynomials $l_i$ and $t_i$. At round $i$ the data sent to the verifier

$$s_i (u) = l_i (u) t_i (u)$$

has a part which is more computationally demanding: the computation of $t_i(u)$ for $u$ in an appropiately large set. So far, the only definition available for this polynomial is given by

$$t_i(u) = \sum_{x_R} \tilde{eq}(w_R, x_R) \cdot \left( \sum_{ x_L } \tilde{eq}(w_L, x_L) \cdot \prod_{k = 1}^{d} p_k(r,u,x_L,x_R) \right)$$

and still needs some clarification. How are the parts of $x'$ defined? How is this sum performed? How does it relate to the SmallValues optimization the authors worked out previously?

It needs to be stressed that this description is conceptually sound and contains the key ideas involved in this optimization. In addition, it must me mentioned that at this level, the block partition of the remaining vectors $x'$ and the factoring of the equality polynomials is a **dynamic** factor: the length of $x'$ is $\ell-i$ at round $i$ and so in absolute terms, the lengths of $x_L$ and $x_R$ will vary from round to round.

While this is enough for a coffee table conversation, it leaves something to be desired from the algorithmic perspective, especially if some gains are to be expected.

### The need for an optimality parameter

In order to maneuver between conceptual clarity and efficient computation, authors define an optimality parameter called $l_0$ - carefully chosen to minimize the prover's total time. Its selection is based on a cost trade-off:

        * **Cost of optimized rounds ($i \le l_0$)** : This cost (primarily `sl` multiplications) grows exponentially with $l_0$, as the size of the accumulators is on the order of $O((d + 1)^{l_0})$.
        * **Cost of standard rounds ($i > l_0$)**: This cost (primarily `ll` multiplications) decreases as $l_0$ increases, because there are fewer ''expensive'' rounds to execute.

The optimal value for $l_0$ is the one where these two costs are balanced. The paper provides a formula to estimate this optimal point for Algorithm 4, which depends on the polynomial's structure (the number of factors, $d$) and the relative costs of hardware operations (the ratio $\kappa$ between the cost of an `ll` and an `ss` multiplication). The optimal switchover point $l_0$ can be estimated by the following formula:

$$l_0 = \frac{\log\left(\frac{\kappa \cdot d^2}{2(d - 1)}\right)}{\log(d + 1)}$$  
where:

        * $d$ is the number of multilinear factors.
        * $\kappa$ is the factor difference in cost between a large-large (`ll`) and a small-small (`ss`) multiplication. The authors use $\kappa = 30$ for their estimations and provide a deeper background for that choice (the reader is encouraged to seek for details in the original article!)

This parameter controls in a strict sense the regime in which the SUMCHECK protocol works at any given stage:

        * **If $i \le l_0$** : You are in the ''optimized phase''. The protocol uses the pre-computed accumulators to compute the prover's message very quickly.
        * **If $i > l_0$**: You have crossed the threshold. The protocol switches to a more standard algorithm (like Algorithm 5) for the remaining rounds, as the benefit of the pre-computation has ended.

Now we are able to take a further look at the block partition of $x'$. The implementation of the author's optimization is based in a static partition of these points in terms of the optimization parameter $\ell_0$ and the number of variables $\ell$. This partition is named

$$x' = (x_{in}, x_{out})$$

works in the same way as the dynamic one but allows for an efficient computation since lengths are now constant. They represent a fixed split of the variables that are not in the $l_0$-round prefix.

        * $x_{in}$ is the set of variables over which the ''inner sum'' is calculated.
        * $x_{out}$ is the set of variables over which the ''outer sum'' iterates.

> The $l$ total variables of the polynomial are divided into three disjoint groups whose union forms the complete set of variables:

        1. **Pre-computation Prefix $\beta$** : The first $l_0$ variables.
        2. **Set $x_{in}$** : The next $\lfloor l/2 \rfloor$ variables
        3. **Set $x_{out}$** : The final $\lfloor l/2 \rfloor - l_0$ variables

Therefore, $x_{in}$ and $x_{out}$ **together form a partition** of the set of variables that do not belong to the pre-computation prefix (i.e., the pre-computation suffix). The sum of their sizes is $(\lfloor l/2 \rfloor) + (\lfloor l/2 \rfloor - l_0)$, which is approximately $l - l_0$, the total size of the pre-computation suffix.

Now that we have settled the notation and parameters involved, lets see how their algorithm actually computes the desires values in the round $i$.

### The effect of block description in the pre-computation phase

In order to compute $t_i (u)$ - the authors make use of the SmallValue optimization - it allows to compute the evaluation at random challenges sent by the verifier of a product of multilinear polynomials. As we mentioned in an earlier post, this is done by deflecting the burden of evaluation to multivariate Lagrange polynomials defined over a grid of points with coefficients in the base field - and evaluate those polynomials. The desired evaluation is now a sum weighted by pre-computed coefficients called accumulators, which depend on the grid and the product.

For concreteness, recall the definition of $t_i$

$$t_i(u) = \sum\limits_{x'} \tilde{eq}(w_{>i}, x') \cdot \prod_{k = 1}^{d} p_k(r,u,x')$$

The SmallValues optimization allows a re-writing of this as

$$t_i(u) = \sum\limits_{v\in G_i} \left(\sum_{x'} \tilde{eq}(w_{>i}, x') \cdot \prod_{k=1}^{d} p_k(v,u,x')\right)\cdot L_v(r) $$

where

        1. $G_i$ is an adequate interpolation grid of points in the base field. Specifically, if $g$ is a product of $d$ multilinear polynomials not counting the eq factor, setting $U_d = {\infty, 0, 1, \dots, d - 1}$ then $$G_i = U_d^{ i - 1 }\quad i\geq 2\quad\text{and}\quad G_1 = \emptyset$$
        2. The polynomials $L_v$ are the $i - 1$ variate Lagrange interpolation polynomials associated with the grid $G_i$ - it is those polynomials that end up being evaluated at the challenges $r_1,\ldots r_{ i - 1}$. For $i = 1$ we set $L_1 = 1$.
        3. Authors fancy to collect the $\lvert G_i\rvert$ values of the polynomials $L_v(r)$ in a single $\lvert G_i\rvert$-long vector indexed by the points in the grid, in a single challenge vector $R_i$
        4. The sum between parenthesis in the last line is the definition of the **accumulators $A_i(v,u)$** \- simply the coefficients needed to express, in terms of the Lagrange interpolation polynomials, the value of $t_i(u)$. Authors express this as an ''inner product'' between the challenge vector and an accumulator vector, also indexed by $v$: $$t_i(u) = \sum\limits_{ v\in G_i} R_i (v)A_i (v,u)$$

Now is time to let the power of block partitioning shine and do its magic: the sum over $x'$ now can be take in two steps:

$$A_i(v, u) = \sum_{x_{out}} \tilde{eq}(w_{out}, x_{out}) \sum_{x_{in}} \tilde{eq}(w_{in}, x_{in}) \prod_{k = 1}^{d} p_k(v, u, x_{in}, x_{out})$$

Don't panic, we're there already. Consider now the prefix $\beta = (v,u)$ and call $E_{in} [x_{in}] =eq(w_{in},x_{in})$. The last inner sum is then parametrized by $\beta$ and $x_{out}$ and shall be called temporary accumulator $tA[\beta]$.

$$tA[\beta] = \sum_{x_{in} \in \\{0,1\\}^{ l/2 }} E_{in}[x_{in}] \cdot \prod_{k = 1}^{d} p_k(\beta, x_{in}, x_{out})$$

Now that we have baptized the proper objects, we can describe how the algorithm works.

#### Logic and Algorithmic Steps:

The core idea is a form of **memoization**. Instead of calculating the entire sum for each accumulator, it calculates the innermost sum once and reuses the result: really, the effecto of the block partitioning.

        1. **Outer Iteration over $x_{out}$** : The algorithm has a main loop that iterates over all possible assignments of the variables in the $x_{out}$ segment.
        2. **Inner Sum Calculation** : Inside that loop, for a fixed value of $x_{out}$, the algorithm computes the innermost sum. This sum is over all assignments of $x_{in}$ and depends on the prefix $\beta$ (which generalizes $(v,u,y)$) and the current $x_{out}$.  
a. For each prefix $\beta$, it computes $\sum_{x_{in}} E_{in}[x_{in}] \cdot \prod p_k(\beta, x_{in}, x_{out})$.  
b. The result of this inner sum for each $\beta$ is stored in a **temporary accumulator** called $tA[\beta]$.
        3. **Distribution to Final Accumulators** : Once all the $tA$ values have been computed for the current $x_{out}$, the algorithm distributes them to the final accumulators $A_i(v,u)$. This is done in the following way:  
a. It iterates over each prefix $\beta$ and its corresponding value in $tA[\beta]$.  
b. Using the mapping function `idx4` (defined in A.5), it determines which final accumulators $(i, v, u)$ this prefix $\beta$ contributes to.  
c. It adds the value of $tA[\beta]$ to the appropriate final accumulator, weighted by the outer `eq-poly` factor, $E_{out,i}$.

### Classification and distribution mechanism

We discussed this method when we studied BDDT's SmallValue optimization, but it is nice to refresh the reader how this is performed. The role of the _idx4_ classification algorithm is to act as an intelligent **''dispatcher'' or ''router''** during the pre-computation phase. Its function is to determine which final accumulators $A_i(v,u)$, possibly from different rounds, should be updated with an intermediate result that has just been computed.

_Procedure 9_ (the pre-computation engine for Algorithm 6) is designed for high efficiency. Instead of calculating each accumulator $A_i(v,u)$ separately, it iterates over all possible prefixes $\beta$ of length $l_0$ and computes a single value for each: the temporary accumulator $tA[\beta]$.

The problem is that a single value $tA[\beta]$ (calculated, for example, for the prefix $\beta=(0,1,0)$) can be part of the calculation for:

        * The accumulator for **Round 1** : $A_1(u=0)$.
        * The accumulator for **Round 2** : $A_2(v=(0), u=1)$.
        * The accumulator for **Round 3** : $A_3(v=(0,1), u=0)$.

The question that _idx4_ answers is: given a $\beta$, what are all the ''addresses'' $(i, v, u)$ of the final accumulators to which this $tA[\beta]$ must be sent?

> Its logic consists of "decomposing" the prefix $\beta$ for each round $i$ (from 1 to $l_0$) and checking if it meets the required structure. For a prefix $\beta$ to be valid for an accumulator of round $i$, the part of the prefix corresponding to the future variables (the vector $y$) **{must be binary (containing only 0s and 1s)**. The fact that the polynomial $g$ has an $eq$ factor ends up greatly simplyfing this distribution step, since a very little number of precomputed products/sums are involved in the construction of the accumulators.

### Intuitive Example

Imagine $l_0 = 3$ and the computed prefix is $\beta = (0, 1, 0)$. _idx4_ would do the following:

        1. **Does it contribute to Round 1 ($i = 1$)?**  
a. $u=\beta_1=0$.  
b. The remainder is $y = (\beta_2, \beta_3) = (1,0)$.  
c. Since $y$ is binary, **Yes**. _idx4_ generates the tuple _$(i=1, v=(), u = 0, y = (1,0))$_.
        2. **Does it contribute to Round 2 ($i = 2$)?**  
a. $v = (\beta_1) = (0)$.  
b. $u = \beta_2 = 1$.  
c. The remainder is $y=(\beta_3)=(0)$.  
d. Since $y$ is binary, **Yes**. _idx4_ generates the tuple $(i=2, v=(0), u=1, y=(0))$.
        3. **Does it contribute to Round 3 ($i = 3$)?**  
a. $v = (\beta_1, \beta_2) = (0,1)$.  
b. $u=\beta_3=0$.  
c. The remainder, $y$, is empty.  
d. **Yes**. _idx4_ generates the tuple $(i = 3, v = (0,1), u = 0, y = ())$.

In contrast, if $\beta = (2, 1, 0)$, it would only contribute to Round 1. For Rounds 2 and 3, the $v$ part of the prefix would contain a `2`, which is not a binary value and thus is not part of the sum over the Boolean hypercube that defines the accumulators for those rounds.

## A small example before you fall off the chair

To fix ideas, we will now walk through an example with small, concrete numbers. If you will, grab a piece of paper and some coffee and double check the computations as we move along the initial rounds.

### Setup

We will use a polynomial of **6 variables** while keeping the optimization rounds at **$l_0 = 2$**. This change allows us to have a non-empty $x_{out}$ in Round 2, thus showing the complete interaction between temporary and final accumulators.

Consider the polynomial

$$g(X) = \tilde{eq}(w, X) \cdot (X_1 + X_3 + X_5 + 1) \cdot (X_2 + X_4 + X_6 + 2)$$

and $eq$ is the equality polynomial for the vector $w = (1, 0, 1, 1, 0, 1)$. Considering $l_0 = 2$ then only rounds 1 and 2 are optimized. As the author's choice of interpolation set, we will stick to $U_2 = \\{\infty, 0, 1 \\}$. The prover needs to compute $t_2(u)$ for $u \in \hat{U_2} = \\{\infty, 0\\}$.

### Getting the partitioning straight

Since $\ell_0=2$, the 6 variables are partitioned as follows:

        * **The pre-computation prefix** $\beta = (X_1, X_2)$ and its ''eq'' companion $w_L=(w_1, w_2)=(1,0)$
        * **The pre-computation suffix** $(X_3, X_4, X_5, X_6)$ is then split as  
a. **$x_{in}$ (size $l/2 = 3$)** : $(X_3, X_4, X_5)$. Its `eq` vector is $w_{in} = (w_3, w_4, w_5) = (1,1,0)$.  
b. **$x_{out}$ (size $l/2 - l_0 = 1$)** : $(X_6)$. Its `eq` vector is $w_{out} = (w_6) = (1)$.

### The first round

The prover needs to compute the values of

$$s_1 (X_1) = l_1 (X_1) t_1 (X_1)$$

at $\infty$ and $0$. Remember that the linear factor $l_i (X_i)$ is defined as:  
$$l_i(X_i) = \underbrace{\tilde{eq}(w_{[<i]}, r_{[<i]})}_ {\text{past challenges}} \cdot \underbrace{\tilde{eq}(w_i, X_i)}_ {\text{current variable}}$$

So in round 1 $i = 1$ the set of past challenges $r_{[<1]}$ is empty. By convention, a product over an empty set is 1. Therefore, the first factor of the formula is simply 1. This means that

$$l_1 (X_1) = 1 \cdot \tilde{eq}(w_1, X_1) = \tilde{eq}(1, X_1) = X_1$$

This implies that $l_1 (\infty) = 1$ and $l_1 (0) = 0$ so the good news is that we don't need to compute $t_1 (0)$. Let's get to work and see how the leading coefficient of $t_1$ is computed.

According to Algorithm 6,  
$$t_1(u) = \langle R_1, A_1(u) \rangle = A_1(u) \quad (\text{since } R_1=[1])$$

Therefore, the task reduces to calculating the final accumulator $A_1(\infty)$ and this is where the temporary accumulators come into play. Since the optimization parameter is $\ell_0 = 2$ then

        * for this first round the prefixes $\beta$ we will be interested in taking in account are $$\beta = (\infty,0)\quad\text{and}\quad \beta = (\infty,1)$$
        * then the **suffix** is split into $x_{in}=(X_3,X_4,X_5)$ and $x_{out}=(X_6)$ and since the **`eq` vectors** are $w_{in} = (1,1,0)$ and $w_{out} = (1)$, we have $$E_{out,1}(1,0) = 0\quad\text{and}\quad E_{out,1}(1,1) = 1$$ so we won't be computing the temporary acumulator for $x_6 = 0$ (it gets multiplied by zero).

For completeness, we include here a small table with the precomputation in this case:

**Temporary Accumulators for $x_6 = 1$**

$u$ | $y_2$ | $p_1 = u + 2$ | $p_2 = y_2 + 4$ | **$tA [u,y_2]$**  
---|---|---|---|---  
$\infty$ | 0 | 1 | 4 | $1 \cdot 4 = 4$  
$\infty$ | 1 | 1 | 5 | $1 \cdot 5 = 5$  
0 | 0 | 2 | 4 | $2 \cdot 4 = 8$  
0 | 1 | 2 | 5 | $2 \cdot 5 = 10$  
  
So let's compute the outer loop for $x_6 = 1$. Now the inner weight of the product is given by $$E_{in} (w_{in},x_{in})$$ so the only term in the inner sum is the one corresponding to $x_{in} = (1,1,0)$ and so

$$tA[\infty,0] = p_1 (\infty,0,1,1,0,1) \cdot p_2 (\infty,0,1,1,0,1) = 1\cdot 4 = 4$$

and

$$tA[\infty,1] = p_1(\infty,1,1,1,0,1)\cdot p_2(\infty,1,1,1,0,1) = 1\cdot 5 = 5$$

which implies that

$$A_1(\infty) = 1\cdot tA[\infty,0] + 1\cdot tA[\infty,1] = 4 + 5 = 9$$  
and so, the prover sends

$$s_1 (\infty) = 1\cdot 9 = 9\quad\text{and }\quad s_1(0) = 0$$

### The second round

Firstly, we tackle the linear factor $l_2 (X_2)$. This factor comes from the `eq` over the prefix variables $(X_1, X_2)$ evaluated at $(r_1, X_2)$:  
$$l_2(X_2) = \tilde{eq}((w_1, w_2), (r_1, X_2)) = \tilde{eq}(1, r_1) \cdot \tilde{eq}(0, X_2) = r_1 \cdot (1-X_2)$$

and obviously

$$l_2(\infty) = - r_1\quad\text{and}\quad l_2(0) = r_1$$

Now comes the tough part of computing $t_2(X_2)$. Since this is computed via the SmallValue optimization, it involves combining the evaluations at the random challenge $r_1$ of the Lagrange interpolation polynomials using the pre-computed accumulators: this ends up being a sum of products and the authors usually show this as an inner product $$t_2(u) = \langle R_2, A_2(u) \rangle$$ where the challenge vector $R_2$ depends on $r_1$ and $U_2 = \\{\infty, 0, 1\\}$, and is calculated as:

        * $R_2[\infty] = (r_1 - 0)(r_1 - 1) = r_1(r_1 - 1)$
        * $R_2[0] = \frac{r_1 - 1}{0 - 1} = 1 - r_1$
        * $R_2[1] = \frac{r_1 - 0}{1 - 0} = r_1$

> The challenge vector is then **$R_2 = (r_1 (r_1 - 1), 1 - r_1, r_1)$**.

We will now compute the values $A_2(v,u)$ for $v,u \in U_2$ by following the logic of Procedure 9, which iterates over $x_{out} = (X_6)$; again, since

$$E_{out,2} (1,X_6) = X_6$$

we only need to take in account the case $x_6 = 1$. Also the computation of temporary accumulators $tA$ in this case benefits from what we already learned in the first round: the sum still collapses for $x_{in} = (1,1,0)$ For completeness we include

**Temporary Accumulators for $x_6 = 1$**

$v$ | $u$ | $p_1 = v+2$ | $p_2 = u+4$ | **$tA[v,u]$**  
---|---|---|---|---  
$\infty$ | $\infty$ | 1 | 1 | $1 \cdot 1 = 1$  
$\infty$ | 0 | 1 | 4 | $1 \cdot 4 = 4$  
0 | $\infty$ | 2 | 1 | $2 \cdot 1 = 2$  
0 | 0 | 2 | 4 | $2 \cdot 4 = 8$  
1 | $\infty$ | 3 | 1 | $3 \cdot 1 = 3$  
1 | 0 | 3 | 4 | $3 \cdot 4 = 12$  
  
We are now in position of constructing a table with the final accumulators involved in this round. Since the prover needs to send evaluations at $\infty$ and $0$, we only compute the accumulators

$$A_2(\infty,\infty),, A_2(0,\infty),, A_2(1,\infty),, A_2(\infty,0),, A_2(0,0),\text{and}, A_2(1,0)$$

Remember: the $E_{out,2}$ and $E_{in}$ weights eliminate most of the sums in the definition

$$A_2 (v,u) = \sum\limits_{x_{out}} E_{out,2} \sum\limits_{x_{in}} E_{in}[x_{in}] p_1 (v,u,x_{in},x_{out}) p_2 (v,u,x_{in},x_{out})$$

which reduces to

$$A_2(v,u) = p_1(v,u,1,1,0,1) p_2(v,u,1,1,0,1)$$

This drastic reduction in cases is a clear example of how this approach to computing the round polynomials works: block partitioning the eq factor collected by $t_i$ causes much of the sum to vanish and yields very few nontrivial summands contributing to the accumulators.

For completeness, here's a table showing the final accumulators

### Final Accumulator Values for Round 2

**$A_2(v,u)$** | **$u=\infty$** | **$u=0$** | **$u=1$**  
---|---|---|---  
**$v=\infty$** | 1 | 4 | (not needed)  
**$v=0$** | 2 | 8 | (not needed)  
**$v=1$** | 3 | 12 | (not needed)  
  
In this round, we combine the challenge vector using the accumulators as weights to produce the evaluations of $t_2(u)$:

\begin{itemize}

        * **Computation of $t_2(0)$:**  
\begin{align*}  
t_2(0) &= \sum_{v \in U_2} R_2[v] \cdot A_2(v, 0) \newline  
&= r_1(r_1 - 1) \cdot A_2(\infty, 0)) + (1 - r_1)\cdot A_2(0, 0) + r_1 \cdot A_2(1, 0) \newline  
&= r_1(r_1 - 1) \cdot 4 + (1 - r_1) \cdot 8 + r_1 \cdot 12  
\end{align*}
        * **Computation of $t_2(\infty)$**  
\begin{align*}  
t_2(\infty) &= \sum_{v \in U_2} R_2[v] \cdot A_2(v, \infty) \newline  
&= (r_1(r_1 - 1) \cdot A_2(\infty, \infty)) + ((1 - r_1)\cdot A_2(0, \infty)) + (r_1 \cdot A_2(1, \infty)) \newline  
&= (r_1(r_1-1) \cdot 1) + ((1 - r_1) \cdot 2) + (r_1 \cdot 3)  
\end{align*}

Finally, the prover send the following values to the verifier

$$s_2(\infty) = l_2(\infty)\cdot t_2(\infty)\quad\text{and}\quad s_2(\infty) = l_2(\infty)\cdot t_2(\infty)$$

(an actual prover replaces the challenge $r_1$ and produces a numerical output to hand in to the verifier and this is it for the first two rounds)

## Rounds After $l_0$

Once the optimized rounds using pre-computation are finished, the algorithm switches its strategy for the remainder of the protocol.

        * **Transition Phase (Round $l_0 + 1$)**  
The objective of this single round is to switch from the ''fast mode'' of pre-computation to the ''standard'' linear mode. The prover computes the evaluations of the polynomials $p_k$ with the first $l_0$ variables already fixed to the challenges $(r_1, \dots, r_{l_0})$. The result of this phase is the creation of the data arrays (called $P_k$) that will be used in the final rounds.
        * **Final Phase (Rounds $l_0+2$ to $l$)**  
From this point on, the protocol follows the standard linear sum-check algorithm (similar to Algorithm 1 or 5). In each of these rounds:  
i. The prover uses the current arrays $P_k$ to compute and send its message.  
ii. It receives a new challenge $r_i$.  
iii. It uses the challenge to combine pairs of entries in the arrays, **halving their size** and preparing everything for the next round.

This halving process continues until the last round, where the arrays are so small that the problem is reduced to a single final check.
