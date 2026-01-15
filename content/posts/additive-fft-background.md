+++
title = "Additive FFT: background"
date = 2025-06-17
slug = "additive-fft-background"

[extra]
feature_image = "/images/2025/12/Jacques-Louis_David_-_The_Coronation_of_Napoleon_-1805-1807-.jpg"
authors = ["LambdaClass"]
+++

**Warning** : This post is more math heavy than other articles.

## Introduction

In this article we continue our study of [towers of binary fields](/the-fields-powering-binius/), motivated by the proposal of Diamond and Posen for a complete protocol working over fields of [characteristic 2](https://en.wikipedia.org/wiki/Characteristic_\(algebra\)), [BINIUS](https://www.binius.xyz/). Previously we covered basic arithmetic of field elements in a tower of binary fields, namely Wiedemann's iterative quadratic extension of $\mathbb{F_2}$. We address the problem of evaluating and interpolating polynomials with coefficients in such fields, with cryptographic applications in mind. Devising a smart and efficient algorithm for doing polynomial evaluations will open the door for efficient implementation of Reed-Solomon encoding in characteristic 2, which is a crucial building block for polynomial commitments.

## On the general problem of polynomial multiplication

Once we covered the structure of the Wiedemann's binary tower, it is natural to wonder how functions over this tower can be evaluated or multiplied together. To our goals, this is important since polynomial evaluation over a cleverly selected subset of the base field (for example, the $n$-th roots of unity) is the ground for encoding messages using Reed-Solomon techniques; in this light, the problem of polynomial evaluation is _very close_ the problem of Reed-Solomon encoding.

A recollection of an efficient method for multiplication of polynomials comes to mind: the [Fast Fourier Transform](https://github.com/lambdaclass/lambdaworks/tree/main/crates/math/src/fft) algorithm. It employs the celebrated scheme

$$\text{ evaluate }\implies\text{ multiply }\implies \text{ interpolate}$$

In more technical terms for the acquainted reader, "polynomial evaluation" stands for "take the FFT of the polynomial", multiply means "**pointwise** multiply their FFT's" and interpolate says "take the inverse FFT of the result". This general scheme allows us to bypass the computational cost of multiplying two polynomials and applying the distributive law, as in highschool. These "evaluation" and "interpolation" steps usually involve matrix multiplication; whenever we evaluate a polynomial $f$ in the powers if a primitive $n$-th root of unity and $n$ is a power of 2, a recursive algorithm is available and all this can be done quickly, say $\mathcal{O}(n\log(n))$. Obviously this has to be one of the most recorded facts of the history of mathematics; literature abounds.

So what about applying the FFT here? Well, there's a catch. In the context of finite fields "roots of unity" may not readily exist, or finding a sufficient number of them might require working in much larger and more complex extension fields.**This fundamental limitation renders the standard FFT either impractical or very slow for these specific field types.**

## A general framework for towers of extensions in positive characteristic

To overcome this, we look into the work of David Cantor, ["On Arithmetical Algorithms over Finite Fields"](https://www.sciencedirect.com/science/article/pii/0097316589900204) from 1989. There he develops an analogue of the FFT that operates on **additive subgroups** of the base field instead of multiplicative ones; since now we are dealing with additions instead of multiplication of group elements, this scheme is usually coined "Additive FFT". Cantor finds an analogue of the roots of unity and proceeds to break down the problem into a smaller one that can be solved recursively, just like in the classical FFT case. The good piece good news is that these additive subgroups are no other than than $\mathbb{F_p}$-vector subspaces, closely related to the familiar subfields that appear in Wiedemann's work and [Diamond and Posen's proposal](https://eprint.iacr.org/2023/1784).

The crucial object for the construction of the Additive FFT is the notion of **linearized polynomial** ; they are a special class of polynomials that exhibit very interesting properties due to their "linear" nature with respect to addition and scalar multiplication in the base finite field. **A linearized polynomial is such that all its monomials have a degree that is a power of $q$, that is $q^r$** ; this is a polynomial of the form (check the appendix at the end for more)

$$L(x) = \sum_{ i = 0 }^d a_i x^{ q^i }$$

where $a_i \in F_q$ (in this discussion, assume $p$ is a prime number and $q = p^n$ for some natural number $n$) The main property of this polynomials is that since we're working modulo $p$, **behave just like linear transformations, in the standard linear algebra sense**. This is, they satisfy for any $u, v \in F_{ q^n }$ and $c \in F_q$:

        * $L(u + v) = L(u) + L(v)$
        * $L(cu) = cL(u)$

Whenever we have a linearized polynomial $L$, the set of its roots (zeros) _forms a vector space over $\mathbb{F_q}$_ (called Kernel):

$$Ker(L) = \{v \in \mathbb{F_{ q^n }} : L(v) = 0 \}\subset \mathbb{F_{ q^n }}$$

fact that stems from the general theory of linear algebra; this means that linear combinations of roots are still roots of $L$. Lastly, the very form (along with the linearity just discussed) of linearized polynomials offers a very neat property: composition of linearized polynomials is again linearized. _This is the backbone of Cantor's description of towers of fields in positive characteristic_.

## Towers of extensions in prime characteristic

To be concise, we will concentrate on a very simple yet important example that will drive our understanding of Cantor's Additive FFT effort; for this fix a prime $p$ and if $\tilde{F}$ is the [algebraic closure](https://en.wikipedia.org/wiki/Algebraic_closure) (for example, the complex numbers $\mathbb{C}$ are the algebraic closure of the real numbers $\mathbb{R}$) of $\mathbb{F_p}$, take the linearized polynomial

$$S(t) = t^p - t$$

From the basic definitions discussed above, we get tons of objects:

        * Consider then succesive compositions of $S$ with itself, obtaining the collection of linearized polynomials

$$S_{m} (t) = S\circ S\cdots\circ S (t) = S(S_{ m - 1}(t))$$

        * For notational convenience, set $W_1 = Ker(S) = \mathbb{F_p}$ and $W_m = Ker(S_m)$: the collection of roots of $S_m$
        * This is where all the clockwork comes to life, since for all $m$ the following are true:
        1. $W_{ m - 1}\subset W_m$
        2. $S: W_m \rightarrow W_{ m - 1}$ is a surjective function
        3. $W_{ m - 1}$ has [codimension](https://en.wikipedia.org/wiki/Codimension) 1 in $W_m$

This last subitem plays a very important role in the structure of Cantor's idea: it means that **if we picture $W_m$ like a chocolate bar, then it can be also thought as the union of exactly $p$ disjoint copies of $W_{ m - 1}$** : draw a rectangle and call it $W_m$ and then split it into $p$ pieces of equal shape and size. Each one of those is a copy of $W_{ m - 1}$!

Once equipped with this (very) brief summary, here's where the good stuff comes. A key observation is that whenever $m=p^k$, since we work modulo $p$ we have a very neat shape for the linearized polynomials involved:

$$S_{ p^k } (t) = t^{ p^{ p^k } } - t$$

They are said to be **sparse** in the sense that they only have few coefficients; this comes useful when computing the complexity of polynomial division later on. The set of its roots form a field of exactly $p^{ p^k }$ elements, and so recalling the itemized list of properties, what we obtain is then a tower of extensions of $\mathbb{F_p}$:

$$W_0 \subset W_p \subset W_{ p^2 }\subset\ldots W_{ p^k }\subset\ldots $$

in which every step we have degree $p$ field extensions $[W_{ p^k } : W_{ p^{ k - 1} }] = p$. Surjectivity of the map $S:W_{ p^k }\rightarrow W_{ p^{ k-1 }}$ implies that for each $k\geq 1$ and each $u_{ k - 1}\in W_{ p^{k - 1 }}$there always exists an element $u_k\in W_{ p^k } - W_{ p^{ k - 1 }}$ such that

$$S(u_k) = u_{ k - 1}$$

and this will bring a very familiar result.

Setting $p=2$ we recover Wiedemann's tower of binary fields:

$$W_0 \subset W_2\subset W_{ 2^2 }\subset\ldots W_{ 2^{ 2^k }}\subset\ldots $$

which we recognize by acknowledging the equivalence of notation $$W_{ 2^{ 2^k }} = \mathcal{T_k}$$

Furthermore, the surjectivity of the map $S$ allows to find generators and basis for each of the levels of the tower. Explicitly,

        * The first generator of the tower is set to be 1.
        * The second generator is an element $u_0$ satisfying $$S(u_0) = 1$$ Notice that this is equivalent to $u_0$ being a root of $X^2 + X + 1$. It is easy to check that since this polynomial has no roots in $\mathbb{F_2}$, then $u_0 \notin\mathbb{F_2}$.
        * The third generator is then defined as $$S( u_1 ) = u_0$$ This implies $u_1^2 + u_1 = u_0$ or equivalently $u_1^2 + u_1 + u_0 = 0$. Again, this implies that $u_1$ is a root of $X^2 + X + u_0 \in \mathcal{T_1} [X]$. It is easy to check that this polynomial has no roots in $\mathcal{T_1}$ and so $u_1\notin\mathcal{T_1}$.
        * For $k > 1$, the rest of the elements are defined by the recursive relation $$S( u_k ) = u_{ k - 1}$$ and also, a field-theoretic relation $u_k^2 + u_k + u_{ k - 1} = 0$.

Building upon these generators, Cantor then defines basis elements $y_m$ according to the base-$2$ (binary) expansion of $m$, mimicking what was naturally exploited in element field multiplication in Wiedemann's binary tower. Explicitly, if we write down $m$'s binary expansion

$$m = m_k 2^k + m_{ k - 1} 2^{ k - 1} + \cdots + m_0 2^0$$

where $m_i \in \{0 , 1 \}$ are the bits of $m$, then:

$$y_m = u_0^{ m_0 } u_1^{ m_1 } \cdots u_k^{ m_k }.$$

To get out feet wet, as examples we have

        * **Example Basis Elements:**  
1\. $y_0 = 1$ (for $m = 0$, all $m_i = 0$)  
2\. $y_1 = u_0$ (for $m = 1$, binary is $1_2$, so $m_0 = 1$)  
3\. $y_2 = u_1$ (for $m = 2$, binary is $10_2$, so $m_1 = 1$)  
4\. $y_3 = u_0 u_1$ (for $m = 3$, binary is $11_2$, so $m_0 = 1, m_1 = 1$)  
5\. $y_4 = u_2$ (for $m = 4$, binary is $100_2$, so $m_2 = 1$)  
6\. Generally, $y_{ 2^r } = u_r$ for $r = 0, 1, 2, \ldots$

This explicit basis for $\mathcal{T_k}$ directly corresponds to what Diamond and Posen refer to as the "multilinear basis" for the Wiedemann tower $\mathcal{T_\iota}$. They state that for $\mathcal{T_\iota}$, the set of monomials $${1, X_0, X_1, X_0 \cdot X_1, \ldots, X_0 \cdot \ldots X_{\iota - 1}}$$ forms a basis, with their $X_i$ effectively serving as Cantor's $u_i$. It is important to note that the Wiedemann tower generators in Diamond's paper use a slightly different relation: $$X_{ j + 1}^2 + X_{ j + 1 }X_j + 1 = 0$$

Despite these differences in specific generator relations, the underlying algebraic structure of these iterated quadratic extensions aligns with Cantor's general framework for efficient basis representations and arithmetic.

## How the Additive FFT Works: A Recursive "Divide and Conquer" Strategy for Polynomial Evaluation

The core mechanism of Cantor's Additive FFT is a recursive "divide and conquer" process, mirroring the efficiency principles of a conventional FFT algorithm. Here we will first give a high-level overview for the problem of evaluating a degree $n = p^m$ polynomial $a$ with coefficients in $F_p$. In the following, we'll keep the notations used in the preceding sections.

        * **Setting up the evaluation set: the subspaces ($W_m$):**  
1\. The primary objective is to evaluate the polynomial $a(t)$ of degree at most $n = p^m$ at all the $p^m$ elements of $W_m$; in this sense, the subspace $W_m$ plays the role of the $n$-th roots of unity form the classical FFT algorithm.  
2\. Crucially, $W_m$ can be partitioned into $p$ smaller, disjoint "cosets" of $W_{ m - 1}$ This allows for a hierarchical decomposition of the problem just like the case in the classical setting when $n$ is a power of 2. Being more specific, we know that $S$ is a $\mathbb{F_p}$-linear map that surjects $W_m$ onto $W_{ m - 1}$, and that this image has codimension 1. This ensures that there exists an element $u\in W_m$ such that  
$$W_m = \langle u\rangle \oplus W_{ m - 1}$$

since $\mathbb{F_p}$ has exactly $p$ elements then  
$$W_m = \bigcup\limits_{ \alpha\in\mathbb{F_p } } \left(\alpha\cdot u + W_{ m - 1}\right)$$

where this union is disjoint and each subset is simply a translate of $W_{m - 1}$. For simplicity, we'll adopt the following notation:  
$$\alpha\cdot u + W_{ m - 1} = W_{ m - 1}^\alpha$$  
and observe that this set has exactly $p^{ m - 1}$ elements, since $W_{ m - 1}$ is the set of roots of $S_{ m - 1} (t)$, which has degree $p^{ m - 1}$.

        * **The Recursive Step: Breaking Down the Problem:**

          1. Now in order to evaluate $a(t)$ on $W_m$ it would suffice to know the values of $a(t)$ at each of the cosets $W_{ m - 1 }^\alpha$. Since these cosets have $p^{ m - 1}$ elements, it would be awesome if we could reduce this problem to the problem of evaluating a polynomial $b_\alpha$ of _strictly smaller degree_ than $deg(a)$ on $W_{ m - 1}^\alpha$; ideally $deg(b_\alpha ) < p^{ m - 1}$.

          2. In order to get hold of one such $b_\alpha$ the following observations come in handy:  
a. $W_{ m - 1}$ is the set of roots of the $p^{ m - 1}$ degree polynomial $S_{ m - 1} (t)$  
b. a translate of this polynomial will vanish on $W_{ m - 1}^\alpha$:  
$$S_{ m - 1 }^\alpha (t) = S_{ m - 1}( t - \alpha\cdot u)$$  
don't trust us, check it yourself.  
c. the Fundamental Theorem of Algebra states then that the remainder of the quotient of $a$ by $S_{ m - 1}^\alpha$ is a polynomial of degree strictly less than $p^m$ and that  
$$a(t) = Q(t) s_{ m - 1}^\alpha (t) +b_\alpha (t)$$  
holds. In particular, whenever $w\in W_{ m - 1 }^\alpha$,

$$a(w) = Q(w)\cdot 0 + b_\alpha (w)$$

and this means $a\equiv b_\alpha$ on $W_{m-1}^\alpha$.

          3. The algorithm then **recursively calls itself** to evaluate each $b_\alpha (t)$ on its corresponding smaller subspace $W_{ m - 1 }^\alpha$.

        * **The Base Case:**  
1\. This recursive decomposition continues until the polynomials $b_i (t)$ reach a degree of 0, meaning they become constants.  
2\. These resulting constants are the desired functional values of the original polynomial $a(t)$ at the points in $W_m$

### The Reverse Process: Interpolation

Cantor also outlines the inverse operation, known as **interpolation**. If the values of a polynomial are known for all points within $W_m$, one can reverse the steps of the Additive FFT algorithm to reconstruct the coefficients of the original polynomial. This inverse process involves similar division and summation techniques, executed in reverse order.

### Computational Cost and Efficiency

Cantor rigorously analyzes the computational complexity of his algorithm, categorizing operations into two types:  
\- **A-operations (Addition-like):** These operations have a computational cost comparable to additions within the underlying field $F$.  
\- **M-operations (Multiplication-like):** These operations have a computational cost comparable to multiplications within the underlying field $F$.

For evaluating a polynomial of degree $<n = p^m$ at all points of $W_m$:  
1\. The total number of A-operations is approximately $O(n (\log n)^{ 1 + \log_p ((p + 1) /2) })$. For $p = 2$, this simplifies to roughly $O(n (\log n)^{ 1.585 })$.  
2\. The total number of M-operations is approximately $O(n \log n)$.

## Summary

In summary, vector subspaces are the "domains" over which the Additive FFT operates. The algorithm recursively divides them and uses the linear properties of linearized polynomials (and the Frobenius automorphism) to relate evaluations across different subspaces, allowing for efficient multipoint evaluation and interpolation.

## Appendix - Proofs and ideas

Here we sum up most of the proofs, definitions and technicalities around linearized polynomials that are mentioned throughout the text. We begin by the first definitions and deduce some of the properties employed.

**Definition (Linearized polynomial)** A linearized polynomial over a finite field $F_q$ has the general form:  
$$L(x) = \sum_{ i = 0 }^d a_i x^{ q^i }$$  
where $a_i \in F_q$

Here we collect some of their the main properties as an itemized list; most of these are easily provable facts and could serve as encouraging exercises (and also a reminder of how important basic linear algebra really is):  
\- **They are Linear Transformations:** If $L(x)$ is a linearized polynomial with coefficients in $F_q$, the mapping $x \mapsto L(x)$ is a **linear transformation** from $F_{ q^n }$ to itself, considering this extension as $n-$ dimensional vector space over $F_q$. This means that for any $u, v \in F_{ q^n }$ and $c \in F_q$:

        * $L(u + v) = L(u) + L(v)$

        * $L(cu) = cL(u)$

(This property stems from characterization of the field of $q$ elements as the [splitting field](https://en.wikipedia.org/wiki/Splitting_field) of the polynomial $X^{q} - X$.) Since $L$ is a linear map, then the set of its roots **forms a vector space over $\mathbb{F_q}$** :

$$Ker(L) = \{v\in\mathbb{F_{ q^n }} : L(v) = 0 \} \subset \mathbb{F_{ q^n }}$$

        * **The uncanny effects of composition:** Usually, composition of polynomials produces a new polynomial and not much else can be said in the general setting. But since linearized polynomials can be seen as linear maps, there are some astonishing consequences:

          1. Right from their definition, linearized polynomials can be viewed as ordinary polynomials pre-composed with $x^q$. This is, there's a correspondence between linearized polynomials over $F_q$ and "ordinary" polynomials in $F_q [x]$. To a linearized polynomial $L(x) = \sum_{ i = 0 }^d a_i x^{ q^i }$, we associate a "$q$-conventional" polynomial $l(y) = \sum_{ i = 0}^d a_i y^i$.
          2. Also from their definition and the linearity property, we see that the composition of two linearized polynomials is also a linearized polynomial. This binary operation is non-commutative but is distributive respect to polynomial addition.
          3. If we interpret composition as a non-commutative multiplication, then an analogue of a division concept can be devised: we will say that $L$ symbolically divides $M$ if there exists a linearized polynomial $R$ such that  
$$M(X) = L\circ N(X)$$
          4. Not only this, but there's also a very remarkable link between linearized polynomials, symbolic divisibility and their $q$-Conventionals: $L(x)$ symbolically divides $M(x)$ if and only if $\ell(y)$ divides $m(y)$ in the ordinary sense.
          5. A linearized polynomial $L(x)$ is compositionally irreducible if and only if its associated $q$-conventional polynomial $l(y)$ is irreducible over $F_q$. It's important to note that a compositinally irreducible linearized polynomial is _always_ reducible in the ordinary sense (it has the factor $x$).
        * **Regarding the construction of towers of extensions,** succesive compositions of the linearized polynomial $S(t) = t^p - t$ with itself

$$S_{m} (t) = S\circ S\cdots\circ S (t) = S(S_{ m - 1} (t))$$

yield subsets in which the algorithm is defined on. From the general theory of linear maps we know that if whenever the composition $F\circ G$ of linear maps $F,G$ is possible, then

$$Ker(G)\subset Ker(F\circ G);$$

in our context this gives an incidence relation between the corresponding kernels: $$Ker(S_{ m - 1 })\subset Ker(S\circ S_{ m - 1 }) = Ker(S_m)$$

This is, $W_{ m - 1} \subset W_m$. From this relation we also see that $S(W_m )\subset W_{ m - 1 }$ since

$$S_{ m - 1 }(S(W_m ))=S_m (W_m ) = 0$$

So we can consider the restriction of $S$ to $W_m$ and look at it as an [endomorphism](https://en.wikipedia.org/wiki/Endomorphism) $S : W_m\rightarrow W_m$. The incidence relation and the dimension theorem for linear maps yields

$$\dim(W_{ m - 1 }) \leq \dim(W_m ) = \dim(Ker(S)) + \dim(S( W_m )) \leq 1 + \dim(W_{ m - 1})$$

Since $S_{ m - 1}$ and $S_m$ have different degrees, they can't have the same roots in $\tilde{F}$, so their kernels as linear maps are different. This implies

$$W_{ m - 1}\neq W_m \implies \dim(W_m) = 1 + \dim(W_{ m - 1})$$

and since $\dim(W_1) = 1$ we have as conclusions that $\dim(W_m ) = m$ and that $S$ surjects $W_m$ onto $W_{ m - 1}$.

### Cantor's basis theorem

One of the pillars of Cantor's contributions is what in his paper is coined as "Theorem 1.1", in which he proves that a certain set is a basis over $\mathbb{F}_p$ of its algebraic closure. In order to state the theorem, we need to make the following observations. Fix your favourite prime $p$ and consider the collection of $u_j \in\tilde{F}$ defined by $S$ in the following fashion:

$$S(u_j ) = u_{ j - 1 },\quad u_j \in W_{ j +1 } - W_j$$  
Then  
a. each positive integer $m$ has an expansion in base $p$: this is, there exist a non-negative integer $k$ and integers $0\leq m_i \leq p - 1$ with $0\leq i\leq k$ such that  
$$m = \sum\limits_{ i = 0}^k m_i p^i \quad\text{with }\quad m_k\neq 0$$

To symbolize this, we write $E(m) = [m_0 m_1 \cdots m_k ]$ and we may think of this vector of exponents as the image of $m$ through an "expansion map"  
b. Let $\gamma_m$ be the first non zero entry in $[m]^p$.  
c. Set $y_0 = 1$ and for positive $m$, define  
$$y_m = \textbf{u}^{ E(m) } = u_0^{ m_0 }\cdot u_1^{ m_1 }\cdot u_k^{ m_k }$$  
and observe that in particular  
$$y_{ p^r } = u_r$$

It turns out that the collection $\{y_0, y_1, \ldots \}$ has _very nice_ properties, that come summarized in the following theorem

**Theorem(Cantor's 1.11 Theorem):** In the same context as the conversation above  
1\. $\{y_0 , y_1 ,\ldots y_m \}$ is a basis for $W_{ m + 1}$ and $y_m \in W_{ m + 1} - W_m$.  
2\. When $m\geq 1$, then  
$$S(y_m ) - \gamma_m y_{ m - 1} \in W_{ m - 1}$$  
3\. the full collection $\{y_0 , y_1 , \ldots \}$ is a basis for $\tilde{F}$.

This specific basis is important for theoretical purposes, but it also may be convenient to consider basis for $W_m$ with nice properties respect to $S$; we have already encountered one such, the one defined by the $u$'s. Set

$$\mathcal{U_m} = \{u_0 ,u_1 ,\ldots, u_{ m - 1} \}$$

as a basis for $W_m$. Now for each $x\in W_m$ there exist unique $\alpha_i \in\mathbb{F_p}$ such that

$$x = \sum\limits_{ i = 0 }^{ m - 1 } \alpha_i u_i$$

By considering $0\leq \alpha_i \leq p - 1$ then we obtain a "replacement map" that is able to interpret $x$ as an integer, by

$$x\in W_m \longmapsto R(x) = \sum\limits_{ i = 0}^{ m - 1} \alpha_i p^i\in [0, p^m - 1]$$

An enduring reader will notice that this map is the inverse of the "expansion map" that appeared earlier. One good property of this particular choice of basis is that

$$\alpha = R(x)\implies \lfloor \alpha /p \rfloor = R(S(x))$$

This fact will become handy when the time to describe the FFT algorithm comes.
