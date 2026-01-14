+++
title = "The fields powering Binius"
date = 2025-06-12
slug = "the-fields-powering-binius"

[extra]
feature_image = "/content/images/2025/12/Jan_Vermeer_-_The_Art_of_Painting_-_Google_Art_Project.jpg"
authors = ["LambdaClass"]
+++

## Introduction

The development of general-purpose zkVMs has made writing verifiable applications easier, by allowing developers to write high-level code and then compiling it to RISC-V or another instruction set architecture (ISA) and running it on top of the virtual machine. The virtual machine then generates a succinct proof of execution using a proof system, such as STARKs or Groth16. Recent advances in proof systems have allowed to reduce proving times, and we are heading towards real-time proving of Ethereum blocks. [Binius](https://www.binius.xyz/) is a proof system that was developed focusing on how to create a technology that is hardware-friendly. Knowing how hardware works, a tailored proof system with really fast mathematics on it can yield significant improvements. [Petra](https://github.com/PetraProver/PetraVM) is the first virtual machine to leverage Binius. What makes Binius special and how does it work?

In this article we will review the basic mathematics behind the Binius protocol, which exploits the boolean hypercube $\mathcal{B_\ell} = \\{0 , 1 \\}^\ell$. We'll concentrate in an elementary description of binary towers and the representation of field elements, as well as addition and multiplication of field elements exploiting their natural relation with circuit level operations. Throughout this article, we will cover some of the ground material from which binary towers emerge and came to life as a technologically interesting object, namely:

        * Diamond and Posen's work from 2023, ["Succint Arguments over Towers of Binary Fields"](https://eprint.iacr.org/2023/1784)
        * David Cantor's seminal 1989 paper ["On Arithmetical Algorithms over Finite Fields"](https://www.sciencedirect.com/science/article/pii/0097316589900204)
        * Wiedemann's 1987 article ["An Iterated Quadratic Extension of GF(2)"](https://www.fq.math.ca/Scanned/26-4/wiedemann.pdf)

For more background material, see our [previous post on Binius part 1](/snarks-on-binary-fields-binius/) and [Binius part 2](/binius-part-2/)

## Field extensions and representation of field elements

In the following discussion, we will fix $\mathbb{F_2} = {0,1}$ as the field with two elements. Finite field extensions of degree $d$ of this field can be characterized as the quotient ring

$$\mathbb{F}_{q} \equiv \mathbb{F}[X]/\langle f(X)\rangle$$

where $f$ is any irreducible polynomial $f \in \mathbb{F_2} [X]$ of degree $d$: this field has exactly $q = 2^d$ elements and consists of all the remainders of polynomial division by $f$. In other words, it consists of polynomials of degree at most $d - 1$ with coefficients in $\mathbb{F_2}$. Also, this extension can be viewed as a vector space of dimension $d$ over the base field $\mathbb{F_2}$ which is a very nice feature. The collection

$$B_q = \\{1 , X , X^2 ,\ldots, X^{d - 1} \\}$$

commonly called "the monomial basis" and upon fixing this basis, an isomorphism identifying such a polynomial with its $\mathbb{F_2}$ coordinates is established. Addition and multiplication of field elements when viewed as polynomials, are performed modulo $f$.

### Example

Consider the polynomial $$f(X) = X^2 + X + 1$$ as an element in $\mathbb{F_2} [X]$. The $f$ is irreducible; if it had a non-trivial factor $g$ then $\deg(g) = 1$ and since $g \in \mathbb{F_2} [X]$ that would force that a root of $g$ be a root of $f$. Since $f$ has no roots in the base field, then we conclude that $f$ is irreducible and

$$\mathbb{F}[X]/\langle X^2+X+1\rangle $$

is indeed a degree 2 extension of $\mathbb{F_2}$; this means that it can be considered as a dimension 2 vector space over the base field. The canonical basis for this vector space is then

$$B_2 = \\{1 , X \\}$$

and all its elements can be listed as linear combinations of elements of $B_2$:

$$\mathbb{F_4} = \\{0 , 1 , X , 1 + X \\}$$

The coordinate Representation of $\mathbb{F_4}$ over $\mathbb{F_2}$ can be viewed in the following table

Polynomial Representation | Coordinate Representation  
---|---  
$0$ | $(0, 0)$  
$1$ | $(1, 0)$  
$X$ | $(0, 1)$  
$1 + X$ | $(1, 1)$  
  
The field operations in the extensions are ring operations in $\mathbb{F_2} [X]$ taken to the quotient field by considering the non-trivial relation $X^2 + X + 1 = 0 \iff X^2 = 1 + X$. **This is sometimes interpreted in a straightforward manner: now $X$ becomes a root of $f$ in the field extension $\mathbb{F_4}$**.

* * *

We observe that the irreducibility of $f$ in the last example was simple since the degree of $f$ was low enough: if $\deg(f)\leq 3$ then $f$ is irreducible over $\mathbb{F}[X] \iff \quad f$ has no roots in $\mathbb{F}$ (this is a theorem in the theory of fields).

**Definition (Quadratic extensions):** Field extensions defined by quotienting by irreducible polynomials of degree 2 are called _quadratic_.

**Definition (Towers of fields):** Whenever there are fields $K,E,F$ such that

$$K,\subset, E\quad\text{ and }\quad E,\subset, F$$

we say that _$E$ is an extension of $K$_ (usually noted $E,\rvert K$) and that _$F$ is an extension of $E$_. Putting these extensions together result in a _tower of extensions_ , and we denote it by $F\rvert\quad E\quad \rvert\quad K$.

It turns out that concatenating field extensions at first sight might seem alien and overly complicated but ultimately, will yield great results.

### Extended example: two constructions of $\mathbb{F_{16}}$

Let's work two different realizations of the field of 16 elements and see how fields are constructed.

**First construction:** $\mathbb{F_{16}}$ as quotient by a degree 4 polynomial:

To construct the field $\mathbb{F_{16}}$ we need to find an irreducible polynomial of degree 4 over the field of two elements, $\mathbb{F_2} = \\{0, 1 \\}$. One such irreducible polynomial is:  
$$p(X) = X^4 + X + 1$$

To verify that this polynomial is irreducible over $\mathbb{F_2}$, we need to check that it has no roots in $\mathbb{F_2}$ **and** that it cannot be factored into the product of two irreducible polynomials of degree 2 over $\mathbb{F_2}$.

        1. **No roots in $\mathbb{F_2}$:**  
\- $p(0) = 0^4 + 0 + 1 = 1 \neq 0$  
\- $p(1) = 1^4 + 1 + 1 = 1 + 1 + 1 = 1 \pmod{2} \neq 0$  
Since $p(X)$ has no roots in $\mathbb{F_2}$, it has no linear factors $(X - a)$ where $a \in \mathbb{F_2}$

        2. **No factorization into two irreducible polynomials of degree 2:**  
The only irreducible polynomial of degree 2 over $\mathbb{F_2}$ is $X^2 + X + 1$. If $X^4 + X + 1$ were reducible into two degree 2 polynomials, it would have to be $(X^2 + X + 1)(X^2 + aX + b)$, where $a, b \in \mathbb{F_2}$.  
Expanding this product:  
$$(X^2 + X + 1) (X^2 + aX + b) = X^4 + (a + 1)X^3 + (b + a + 1)X^2 + (b + a) X + b$$  
Comparing the coefficients with $X^4 + 0X^3 + 0X^2 + 1X + 1$:  
\- Coefficient of $X^3$: $a + 1 = 0 \implies a = 1$  
\- Coefficient of $X^2$: $b + a + 1 = 0 \implies b + 1 + 1 = b = 0$  
\- Coefficient of $X$: $b + a = 1 \implies 0 + 1 = 1$ (This is consistent)  
\- Constant term: $b = 1$  
We have a contradiction since we found $b = 0$ and $b = 1$. Therefore, $X^4 + X + 1$ cannot be factored into two irreducible polynomials of degree 2 over $\mathbb{F_2}$.

Since $p(X) = X^4 + X + 1$ is irreducible of degree 4 over $\mathbb{F_2}$, the quotient ring  
$$\mathbb{F_2} [X] / \langle X^4 + X + 1 \rangle$$  
is a field with $2^4 = 16$ elements.

Elements of this field can be represented as polynomials in $X$ of degree at most 3 with coefficients in $\mathbb{F_2}$; moreover, addition of these elements is done by adding the polynomials coefficient-wise modulo 2 while multiplication is done by multiplying the polynomials **and then** reducing the result modulo $X^4 + X + 1$. This reduction is achieved by repeatedly using the relation $X^4 \equiv -X - 1 \equiv X + 1 \pmod{X^4 + X + 1}$.

For instance, to multiply $\alpha = 1 + X + X^3$ and $\beta = X^2 + X^3$,

$$\alpha\cdot\beta = ( 1 + X + X^3 )\cdot (X^2 + X^3) = X^2 + X^3 + X^3 + X^4 + X^5 + X^6$$

By making use of addition modulo 2 we may eliminate the third powers of $X$ and by the defining relation we may replace all powers of $X$ above 4:

$$\alpha\cdot\beta = X^2 + ( 1 + X ) + X (1 + X) + X^2 ( 1 + X ) = X^2 + 1 + X + X + X^2 + X^2 + X^3$$

and again by addition modulo 2, we obtain $\alpha \cdot \beta = 1 + X^2 + X^3$.

We will see that even if it is straightforward to understand the mechanics of this pattern for multiplication, it is highly non-efficient. We would like to have a different way of representing elements in a field extension such that multiplication could be done fast and efficiently.

**Second construction** : $\mathbb{F_{16}}$ as a sequence of quadratic extensions

In this approach, we will construct the field of 16 elements by realizing a tower of fields which has $\mathbb{F_{16}}$ at the top; we will exploit quadratic extensions and the fact that when polynomials are of low degree (at most 3) their irreducibility can be deduced by looking for roots.

**Step 1: $\mathbb{F_4}$ as an extension of $\mathbb{F_2}$:**

As before, we use the irreducible polynomial $p(t) = t^2 + t + 1$ over $\mathbb{F_2}$. Since extending $\mathbb{F_2}$ is adjoining a root $X_0$ of $f$, we will simply say that

$$\mathbb{F_4} = \mathbb{F_2} (X_0 )$$

and the four elements of this field are simply ${ 0, 1, X_0, 1 + X_0 }$, with $X_0^2 = X_0 + 1$.

**Step 2: $\mathbb{F_{ 16 }}$ as an extension of $\mathbb{F_4}$:**

Since $\mathbb{F_4}$ has 4 elements, we need an irreducible polynomial of degree $2$ over $\mathbb{F_4}$ to construct $\mathbb{F_{16}}$ and grant $[\mathbb{F_{16}} : \mathbb{F_4} ] = 2$ (see here for [degree of an extension](https://en.wikipedia.org/wiki/Degree_of_a_field_extension)); consider the polynomial $$q(t) = t^2 + t + X_0$$ over $\mathbb{F_4}$. To check for irreducibility, we need to see if it has roots in $\mathbb{F_4} = {0, 1, X_0, 1 + X_0}$. So, let's begin checking one by one:

        * $q(0) = 0^2 + 0 + X_0 = X_0 \neq 0$
        * $q(1) = 1^2 + 1 + X_0 = 1 + 1 + X_0 = 0 + X_0 = X_0 \neq 0$
        * $q(X_0) = X_0^2 + X_0 + X_0 = (X_0 + 1) + X_0 + X_0 = X_0 + 1 + 0 = X_0 + 1 \neq 0$
        * \begin{align*}  
q(1 + X_0) &= (1 + X_0)^2 + (1 + X_0) + X_0  
= (1 + X_0^2) + 1 + X_0 + X_0 \newline &= 1 + (X_0 + 1) + 1 + 0 = X_0 + 1 + 1 = X_0 \neq 0  
\end{align*}

Since $q(t)$ has degree 2 and no roots in $\mathbb{F_4}$, it is irreducible over $\mathbb{F_4}$ and the extension obtained by adjoining a root $X_1$ of $q$ yields

$$\mathbb{F_{16}} = \mathbb{F_4} (Y) = \mathbb{F_2} (X_0 ) (X_1 ) = \mathbb{F_2} (X_0 , X_1 )$$

subject to the relations:

        * $X_0^2 = X_0 + 1$ (this comes from the first extension)
        * $X_1^2 = X_1 + X_0$ (this comes from the second extension)

Each step is indeed defined by quotienting by an irreducible polynomial of degree 2, i.e. each step is a _quadratic extension_. More importantly, each element in $\mathbb{F_{16}}$ is a linear combination with coefficients in $\mathbb{F_2}$ of the basis elements

$$\\{ 1 , X_0 ,X_1 ,X_0 \cdot X_1 \\}$$

### A word about coordinates:

Let's work out the coordinate representation of $\mathbb{F_{ 16 }}$ over $\mathbb{F_4}$ and over the base field $\mathbb{F_2}$. The elements of $\mathbb{F_{ 16 }}$ can be written in the form $$a + bX_1$$ where $a, b \in \mathbb{F_4}$. Since each of $a$ and $b$ has 4 choices, there are $4 \times 4 = 16$ elements in $\mathbb{F_{16}}$; also recall that a basis for $\mathbb{F_4}$ over $\mathbb{F_2}$ is $\\{1, X_0 \\}$ and that $\mathbb{F_{16}}$ over $\mathbb{F_4}$ is $\\{1, X_1\\}$.

It is a well known theorem of the theory of fields a basis for the upper field in a tower consists of the multiplication of the basis elements in the lower extensions. But there's a caveat: we will consider ordered basis. This means that in order to show a basis one must not only exhibit a linearly independent subset that spans the vector space, but also we need to make explicit _the order_ in which those elements lie in the basis. This order is needed in order to make available the use of coordinates. Considering the ordered basis above, let's take a look at the elements in $\mathbb{F_{16}}$:

Element in $\mathbb{F_{16}}$ | Coordinates over $\mathbb{F_4}$ | Coordinates over $\mathbb{F_2}$  
---|---|---  
$0$ | $(0, 0)$ | $(0, 0, 0, 0)$  
$1$ | $(1, 0)$ | $(1, 0, 0, 0)$  
$X_0$ | $(X_0, 0)$ | $(0, 1, 0, 0)$  
$1 + X_0$ | $(1 + X_0, 0)$ | $(1, 1, 0, 0)$  
$X_1$ | $(0, 1)$ | $(0, 0, 1, 0)$  
$1 + X_1$ | $(1, 1)$ | $(1, 0, 1, 0)$  
$X_0 + X_1$ | $(X_0, 1)$ | $(0, 1, 1, 0)$  
$(1 + X_0) + X_1$ | $(1 + X_0, 1)$ | $(1, 1, 1, 0)$  
$X_0X_1$ | $(0, X_0)$ | $(0, 0, 0, 1)$  
$1 + X_0X_1$ | $(1, X_0)$ | $(1, 0, 0, 1)$  
$X_0 + X_0X_1$ | $(X_0, X_0)$ | $(0, 1, 0, 1)$  
$(1 + X_0) + X_0 X_1$ | $(1 + X_0, X_0)$ | $(1, 1, 0, 1)$  
$(1 + X_0 ) X_1$ | $(0, 1 + X_0)$ | $(0, 0, 1, 1)$  
$1 + (1 + X_0 ) X_1$ | $(1, 1 + X_0)$ | $(1, 0, 1, 1)$  
$X_0 + (1 + X_0 ) X_1$ | $(X_0, 1 + X_0)$ | $(0, 1, 1, 1)$  
$(1 + X_0) + (1 + X_0 ) X_1$ | $(1 + X_0, 1 + X_0)$ | $(1, 1, 1, 1)$  
  
The way monomial basis are chosen also show how coordinates in succesive basis relate to one another: for instance, suppose we take an element $$\omega=a + bX_1 \in \mathbb{F_{16}} \quad \text{ with } a, b \in \mathbb{F_4}$$ and we represent $\omega$ by its coordinates $(a, b)$. If we now express $a$ and $b$ in terms of the basis $\\{1, X_0 \\}$ over $\mathbb{F_2}$ then we'll be able to find the coordinates of $\omega$ over $\mathbb{F_2}$ by simply concatenating coordinates of $a$ and $b$!

To illustrate what the table is saying, take the element $\omega = X_0 + X_1$. Over $\mathbb{F_4}$, it is $X_0 \cdot 1 + 1 \cdot X_1$, so the coordinates are $$[\omega]^{ \mathbb{F_4} } = ( X_0 , 1)$$.  
Now, $[ X_0 ]^{ \mathbb{F_2} } = (0 , 1)$ and $[1]^{\mathbb{F_2}} = (1,0)$, so

$$[X_0 + X_1]^{ \mathbb{F_2} } = (0, 1, 1, 0)$$

We repeat what we mentioned earlier: whenever a choice of basis is made, there's also a choice of order of the basis elements; mathematically speaking, basis consisting of the same elements but in a different order are different basis. In this exposition, the order is selected folklorically, reading the basis from left to right, aggregating elements as we read matching the succesive extensions. This is not the only way this could be done; as a matter of fact, the reverse ordering is popular among computer scientists.

## Wiedemann towers and the work of Diamond and Posen

What we have just seen in the example of $\mathbb{F_{16}}$ is an instance of a _Wiedemann tower_ : a sequence of field extensions such that each extension is a quadratic extension of the previous one, represented in such a way that a basis of the extension can be obtained by adjoining roots of a certain sequence of irreducible polynomials at the time. In the case just seen, the basis was simply

$$\mathcal{B} = \\{1, X_0 ,X_1 ,X_0 X_1 \\}$$

and the field elements are simply $\mathbb{F_2}$ linear combinations of these symbols: we will commonly view them as polynomials in 2 variables over $\mathbb{F_2}$ in which all the variables appear raised to the first power, at most. These polynomials are usually called "multilinear" in the cryptography context. These type of field extensions and polynomials are central to the work of Ben Diamond and Jim Posen in their proposition for a setting in which zero knowledge protocols can be implemented in characteristic 2 for more efficient performance relying on circuitry-level arithmetical operations: **BINIUS**. The binary tower defined in their work is defined just like an iterative quadratic sequence of extensions, inspired in the work of Wiedemann. To match their notation set $\mathcal{T_0} = \mathbb{F_2}$ and then recursively define

$$\mathcal{T_{ k + 1}} = \mathcal{T_{k}} [X_{ k + 1}]/ \langle f_{ k + 1} \rangle$$

where $f_{ k + 1 } ( X_{ k + 1 }) = X_{ k + 1 }^2 + X_{k} X_{ k + 1 } + 1$; Wiedemann proved that this polynomial is indeed irreducible over $\mathcal{T_k}$ and so it defines $\mathcal{T_{ k + 1}}$ as a quadratic extension of $\mathcal{T_{k}}$. Briefly write down a few extensions

$$\mathbb{F_2} = \mathcal{T_0},\quad \mathbb{F_4} = \mathcal{T_1} , \quad \mathbb{F_{16}} = \mathcal{T_2},\ldots $$

We will usually refer to $\mathcal{T_k}$ as the $k-$th level or extension of $\mathcal{T_0}$; and such a field has exactly $2^{ 2^k }$ elements. In such level, elements are described as polynomials in the set of $k$ variables $\\{X_0 , X_1 , \ldots, X_{ k - 1} \\}$ such that every $X$ is raised to a power at most 1, this is, they are linear combinations over $\mathbb{F_2}$ of multilinear monomials. For simplicity, there is also an extremely convenient way to point to specific monomials and it relates to the binary expansion of the non-negative integers.

To make this clear, suppose we need to find the $n-$th basis element, and we'll call it $y_n$. To do that, we simply expand $n$ in base 2:

$$n = \sum \limits_{ i = 0 } n_i 2^i , \quad \text{ where } n_i \in {0,1}$$

and then set

$$y_n = \prod_{i: n_i = 1} X_i$$

For instance, to obtain the tenth basic element in the Wiedemann tower, first expand in base 2:

$$10 = 0\cdot 2^0 + 1 \cdot 2^1 + 0 \cdot 2^2 + 1\cdot 2^3 , \quad\text{ or more briefly } [10]^2 = [1010]$$

(and you need to remember that it is customary in computer science to start the expansion with the most significant digit and that counts of elements usually start at zero), and then build

$$y_{10} = X_1 X_3$$

This specific ordering of the basis, which we admitted naturally from the conversation is indeed a _lexicographic order_ , and such fact which will allow various things:

        * First of all, it will allow us to eyeball if an elements belongs to a specific subfield of $\mathcal{T_k}$; whenever the coordinate vector associated to a level $k$ element has its last half of coordinates equal to zero, then we know it belongs to $\mathcal{T_{ k - 1}}$
        * This previous fact shows that the tower construction nicely embeds $\mathcal{T_{ k - 1}}$ into $\mathcal{T_k}$ by zero padding in the last half of the coordinate vector. Computationally it has "zero cost" to view elements from a subfield as an element of an extension of that field.

This properties make the Wiedemann towers so suitable for coding and chip-level implementations: there is no mathematical guarantee on arbitrary extensions that we can identify to which subfield an element belongs to. However, in this case and due to the highly structured nature of these fields, that problem can be sometimes quickly solved. Or phrased better: we can easily characterize subfields of the extension.

## Field operations and the issue of multiplication

An interesting aspect of these type of towers is the way coordinates behave under the usual field operations.

### Addition

The relationship between addition in $\mathbb{F_2}$ (which is the operation performed on the coordinates) and the XOR operation is direct and fundamental. Addition of two elements in a finite extension $\mathcal{T_k}$ is performed by adding their corresponding coordinates modulo 2. Since addition modulo 2 is equivalent to the XOR operation, addition is a very fast and efficient bitwise operation in most processor architectures.

### Multiplication

Now here is where things get slippery. Multiplication of field elements can be carried out in different ways according to how those elements are represented. Let's begin with

#### Multiplication the naive way: polynomials with reduction

One of the more straightforward way of multiplying elements in a field extension is by first representing elements as polynomials, then multiplying those polynomials and finally reducing the product modulo the irreducible that defines the extension of $\mathbb{F_2}$.

To illustrate, consider $u,v \in \mathcal{T_2}$. Let's go slowly.

**Multiplication as Polynomials in $X_1$ with Coefficients in $\mathcal{T_1}$:**  
\begin{align*}  
u \cdot v &= ((1 + X_0) + X_1)(X_0 + X_0X_1) \newline  
&= (1 + X_0)X_0 + (1 + X_0)X_0X_1 + X_1X_0 + X_1(X_0X_1) \newline  
&= (X_0 + X_0^2) + (X_0 + X_0^2 ) X_1 + X_0 X_1 + X_0 X_1^2  
\end{align*}

Now, we substitute $X_0^2 = X_0 + 1$ and $X_1^2 = X_1 X_0 + 1$:  
\begin{align*}  
&= (X_0 + X_0 + 1) + (X_0 + X_0 + 1)X_1 + X_0 X_1 + X_0(X_1 X_0 + 1) \newline  
&= (2X_0 + 1) + (2X_0 + 1)X_1 + X_0 X_1 + X_1 X_0^2 + X_0)  
\end{align*}  
Since we are in a field with characteristic 2, $2X_0 = 0$. So,  
\begin{align*}  
&= 1 + X_1 + X_0X_1 + X_1(X_0 + 1) + X_0 \newline  
&= 1 + X_1 + X_0X_1 + X_0X_1 + X_1 + X_0 \newline  
&= 1 + X_0  
\end{align*}  
So, $((1 + X_0 ) + X_1 )(X_0 + X_0 X_1 ) = 1 + X_0$ in $\mathcal{T_2}$.

As the reader may have guessed - this is a lot of work. We'd like to have a more efficient algorithm for multiplication of field elements that draws from the highly structured tower of extensions.

One way of having a systematic approach to field element multiplication is by using a Karatsuba-like technique.

#### Karatsuba-like Multiplication in the Wiedemann Tower

The primary aim of the Karatsuba algorithm, when applied to multiplication of elements in a finite field extension (like the levels of the Wiedemann tower), is to **reduce the number of field multiplications** in the larger field by increasing the number of _field additions_ and _sub-field multiplications_ by exploiting the fact that additions (done through XOR) is computationally cheap.

Specifically, for multiplying two degree-1 polynomials over a subfield, a naive approach would require four multiplications in the subfield. Karatsuba's method achieves this with only **three multiplications** and a few additions in the subfield. This seemingly small reduction becomes significant when applied recursively across many levels of a tower extension, leading to a sub-quadratic asymptotic complexity.

Let's start describing the Karatsuba formula for multiplication of two elements in $\mathcal{T_k}$ (which are polynomials of degree at most 1 in $X_{ k - 1}$ with coefficients in $\mathcal{T_{ k - 1}}$) by stating what the multiplication looks like and then by sharpening our eye:

Suppose that we need to multiply together $$u = \alpha_0 + \alpha_1 X_{ k - 1 }\quad \text{and } \quad v = \beta_0 + \beta_1 X_{ k - 1}$$ with $\alpha_i, \beta_i \in \mathcal{T_{ k - 1}}$ for $i = 0,1$. Then multiplication obeys the distributive law and so the product we're looking for is then

$$u\cdot v = \alpha_1 \beta_1 X_{ k - 1}^2 + (\alpha_0 \beta_1 + \alpha_1 \beta_0) X_{ k - 1} + \alpha_0 \beta_0 $$

        * **Step 1: Compute the three intermediate products in the subfield $\mathcal{T_{ k - 1 }}$.**

This is where the Karatsuba trick reduces multiplications. Instead of computing the four products involving $\alpha_i\beta_j$, we resort to compute three multiplications instead:

        * $P_A = \alpha_0 \beta_0$
        * $P_B = \alpha_1 \beta_1$
        * $P_C = (\alpha_0 + \alpha_1)(\beta_0 + \beta_1)$

and note that in characteristic two these three products suffice to produce the coefficents in $u\cdot v$ since

$$P_A + P_B + P_C = \alpha_0 \beta_1 + \alpha_1 \beta_0 = M$$

We commonly call $M$ the "middle term". These three multiplications and two additions are performed in $\mathcal{T_{ k - 1}}$.

        * **Step 2: Reduce the product using the defining irreducible polynomial.**

Up to this point, the product is given by:

$$P_B X_{ k - 1 }^2 + MX_{ k - 1} + P_A$$

Now the relation $X_{ k - 1 }^2 = X_{ k - 2} X_{ k - 1} + 1$ will yield the final expression for the desired product:

$$u\cdot v= (P_A + P_B) + (M + P_B X_{ k - 2}) X_{ k - 1}$$

This is the final reduction to the canonical polynomial representation of the element. There is something relevant to point out exactly here. How is this computation performed?

        * As mentioned before, the coefficients $P_A + P_B$ and $M + P_B X_{k - 2}$ computed in the subfield $\mathcal{T_{ k - 1}}$.
        * To compute the greater linear combination, we must compute the product

$$(M + P_B X_{ k - 2}) X_{ k - 1}$$

first. The catch is that when considering $\mathcal{T_k}$ as a vector space over $\mathcal{T_0}$, multiplication by $X_{ k - 1}$ is then an automorphism, so the product mentioned above can be obtained by matrix multiplication once we look at the elements in the convenient level of the Wiedemann tower (and here is where the way the subfields are linked together pays dividends). Explicitly, **we first interpret $M + P_B X_{ k - 2}$ as an element of the upper field $\mathcal{T_k}$. In coordinates this fact is expressed by padding the coordinates $[\cdot]^{ k - 1}$ with zeros to obtain its coordinates $[\cdot]^k$:**

$$[M + P_B X_{ k - 2}]^k = [ [M + P_B X_{ k - 2}]^{ k - 1}:, 0,0,\cdots 0]$$

If we consider $M + P_B X_{ k - 2} \in \mathcal{T_k}$ then the product against $X_{ k - 1}$ con be performed in coordinates by matrix multiplication:

$$[(M + P_B X_{ k - 2}) X_{ k - 1 }]^{k} = [M + P_B X_{ k - 2}]^{k} A_{ k - 1}$$

where $A_k$ is the matrix that has **as rows** the coordinates over $\mathcal{T_k}$ of the products of the basis elements of $\mathcal{T_k}$ by $X_{ k - 1}$.

        * The final addition is performed in the top field $\mathcal{T_k}$; in coordinates this is simply done by XOR.

## A quick summary, so far:

        * **Concatenation for Hierarchy:** The key insight of the multilinear basis (as implicitly adopted by Diamond and Posen) is that an element's representation in $\mathcal{T_k}$ is simply the concatenation of its coefficients from $\mathcal{T_{ k - 1}}$. This means you can "unpack" an element into its sub-elements simply by splitting its bit string. This is a "free" operation, involving no computation beyond index manipulation.
        * **Recursive Application:** The Karatsuba algorithm maps perfectly to this recursive structure. This is exactly how the algorithm is designed to work efficiently.
        * **Bitwise XOR for Additions:** All additions are simply bitwise XORs ($\oplus$) on the coordinate vectors. This is exceptionally fast on modern processors, which can perform XOR on entire machine words in a single cycle.
        * **Defined Reductions:** The irreducible polynomials ($X_0^2 = X_0 + 1$, $X_1^2 = X_0 X_1 + 1$, $X_2^2 = X_1 X_2 + 1$) are simple trinomials or binomials in $\mathbb{F_2}$. The reduction step (e.g., $X_1^2 \to X_0 X_1 + 1$) translates into a linear transformation on the coefficient vector that can be done with a few XORs and re-indexing.
        * **Small Coefficients:** Because the field is $\mathbb{F_2}$, all coefficients ($a_0, a_1, \ldots$) are single bits (0 or 1). This simplifies the base multiplications within the $M_1$ function, making it extremely efficient.

## An extended example, by hand

Let's work out the product of two elements in $\mathcal{T_3}$, namely

$$u = X_0 + X_1 X_2 \quad\text{and }\quad v = 1 + X_1 + X_0 X_2$$

using the aforementioned algorithm. Before going any further, and just because we want to avoid the pain of going way too deep in the recursion, we can be practical and cook up the matrix for the "multiplication by $X_0$" map. This matrix is then

$$  
\boxed{  
\begin{matrix}  
0 & 1 \newline  
1 & 1  
\end{matrix}  
}  
$$

and helps building a complete multiplication table; to multiply $\gamma$ by $X_0$ we compute

$$  
[\gamma]^{1} \cdot \boxed{  
\begin{matrix}  
0 & 1 \newline  
1 & 1  
\end{matrix}  
} = [\gamma\cdot X_0 ]^1  
$$

For a full multiplication table covering all possible field element multiplications in $\mathcal{T_1}$, we resort to linearity and the gadget above.

Let's get started. Remember that $\mathcal{T_3}$ is a field with $2^{ 2^3 } = 2^8 = 256$ elements, and as a vector space over $\mathbb{F_2} = \mathcal{T_0}$ is has dimension 8; its multilinear basis is then

$$\\{1, X_0 ,X_1 ,X_0 X_1 ,X_2 ,X_0 X_2 ,X_1 X_2 ,X_0 X_1 X_2 \\}$$

We will carry out the product of $u$ and $v$ in coordinates. First of all,

$$[u]^3 = (0,1,0,0,0,0,1,0) \quad\text{and }\quad [v]^3 =(1,0,1,0,0,1,0,0)$$

are the coordinates of $u$ and $v$ in the multilinear basis for $\mathcal{T_3}$. Before carrying out Karatsuba's algorithm, we will display both set of coordinates in matrix form and hint a partition corresponding to the canonical description of both elements as elements of the last extension in the tower. This is

$$\begin{pmatrix}u\newline \hline v\end{pmatrix}^3 = \begin{pmatrix}  
0 & 1 & 0 & 0 & 0 & 0 & 1 & 0 \newline  
\hline  
1 & 0 & 1 & 0 & 0 & 1 & 0 & 0  
\end{pmatrix}=  
\left(  
\begin{array}{cccc:cccc} % 'c' for centered column, ':' for a dotted vertical line  
0 & 1 & 0 & 0 & 0 & 0 & 1 & 0 \newline  
\hline % Solid horizontal line  
1 & 0 & 1 & 0 & 0 & 1 & 0 & 0  
\end{array}  
\right)  
= \left(  
\begin{array}{c:c} % 'c' for centered column, ':' for a dotted vertical line  
\alpha_0 & \alpha_1 \newline  
\hline % Solid horizontal line  
\beta_0 & \beta_1  
\end{array}  
\right)$$

where we're exploiting the fact that we can write $u$ and $v$ over the previous extension $\mathcal{T_2}$:

$$u = \alpha_0 + \alpha_1 X_2 \quad\text{and }\quad v = \beta_0 + \beta_1 X_2$$

for certain $\alpha_i , \beta_j \in \mathcal{T_2}$. Recall that this field has dimension 4 and that the previous matrix partition already gives us the coordinates over $\mathcal{T_0}$ of the coordinates over $\mathcal{T_2}$! This is the utterly COOL feature of multilinear basis for binary towers! We're now ready to proceed with Karatsuba's algorithm.

        * **First step:** We proceed to compute the products
        1. $P_A = \alpha_0 \beta_0$
        2. $P_B = \alpha_1 \beta_1$
        3. $P_C = (\alpha_0 + \alpha_1) (\beta_0 + \beta_1)$
        4. $P_B X_1$

where **all of these elements belong to and action is done in the subfield $\mathcal{T_2}$.** In order to do this, we need to go one layer deep for each of the products needed. Let's proceed with caution.

i. To calculate $P_A$ we interpret the **coordinates over $\mathcal{T_2}$ in coordinates over $\mathcal{T_0}$** and just as in the previous layer and write

$$\begin{pmatrix}\alpha_0\newline \hline \beta_0\end{pmatrix}^2=\begin{pmatrix}  
0 & 1 & 0 & 0\newline  
\hline % This command draws a solid horizontal line  
1 & 0 & 1 & 0  
\end{pmatrix}=  
\left(  
\begin{array}{cc:cc} % 'c' for centered column, ':' for a dotted vertical line  
0 & 1 & 0 & 0 \newline  
\hline % Solid horizontal line  
1 & 0 & 1 & 0  
\end{array}  
\right)  
= \left(  
\begin{array}{c:c} % 'c' for centered column, ':' for a dotted vertical line  
\alpha_{00} & \alpha_{01} \newline  
\hline % Solid horizontal line  
\beta_{00} & \beta_{01}  
\end{array}  
\right)$$

Applying Karatsuba's algorithm in this scenario requires reaching for the multiplication table we mentioned earlier,

        * $P^\prime_A = \alpha_{00}\cdot\beta_{00}$, which in $\mathcal{T_1}$ coordinates is the product $$\boxed{0, 1}\times \boxed{1, 0}=\boxed{0,1}$$
        * $P^\prime_B = \alpha_{01}\cdot\beta_{01}$, which in $\mathcal{T_1}$ coordinates is the product $$\boxed{0, 0}\times \boxed{1, 0}=\boxed{0,0}$$
        * $P^\prime_C = (\alpha_{00}+\alpha_{01})\cdot(\beta_{00}+\beta_{01})$, which in $\mathcal{T_1}$ coordinates is the product $$\boxed{0, 1}\times \boxed{0, 0}=\boxed{0,0}$$ (once done the necessary addition in each factor)
        * And finally the product of the uncanny $P^\prime_B X_{0}$ term:  
$$\boxed{0,0}\times\boxed{  
\begin{matrix}  
0 & 1 \newline  
1 & 1  
\end{matrix}  
}=\boxed{0,0}$$

It is now time to construct the product $\alpha_0 \beta_0$ as an element in $\mathcal{T_2}$; and now is where the special choice of basis comes into play (again): **The way elements of $\mathcal{T_1}$ sit into $\mathcal{T_2}$ is fundamental and computationally crucial: to view them in the extension above we simply pad with zeros at the end of their $\mathcal{T_1}$ coordinates to get a 4 bit string.**

According to the algorithm presented, the coordinate expression for

$$\alpha_0 \beta_0 = (P^\prime_A + P^\prime_B) + (M + P^\prime_B X_0) X_1$$

can be reconstructed step by step. **First add** in $\mathcal{T_1}$, **then pad** :

$$[P^\prime_A + P^\prime_B ]^1 = \boxed{0,1} + \boxed{0,0} = \boxed{0,1} \implies [P\prime_A+P\prime_B]^2 = \boxed{0,1,0,0}$$

Then, the slippery part: viewed as elements in $\mathcal{T_1}$,

$$[P^\prime_B X_0 ]^1 = \boxed{0,0} \implies [M + P^\prime_B X_0 ]^1 = \boxed{0,1} + \boxed{0,0} =\boxed{0,1}$$

**Before multiplying it with $X_1$, we embed this element in $\mathcal{T_2}$ by padding with zeros at the end.** Multiplication by $X_1$ is done by matrix multiplication

$$[(M + P^\prime_B X_0 )\cdot X_1 ]^2 = \boxed{0,1,0,0}\times \boxed{  
\begin{matrix}  
0 & 0 & 1 &0\newline  
0 & 0 & 0 & 1\newline  
1 & 0 & 0 & 1\newline  
0 & 1 & 1 & 1  
\end{matrix}  
} =\boxed{0,0,0,1}$$

Finally, performing the sum we obtain

$$\boxed{0,1,0,0} + \boxed{0,0,0,1} = \boxed{0,1,,0,1}$$

which means that $P_A = \alpha_0 \beta_0 = X_0 + X_0 X_1 \in \mathcal{T_2}$

        * Once that we explained in detail the first case, we proceed to calculate $P_B:$

$$\begin{pmatrix}\alpha_1\newline \hline \beta_1\end{pmatrix}^2=\begin{pmatrix}  
0 & 0 & 1 & 0\newline  
\hline % This command draws a solid horizontal line  
0 & 1 & 0 & 0  
\end{pmatrix}=  
\left(  
\begin{array}{cc:cc} % 'c' for centered column, ':' for a dotted vertical line  
0 & 0 & 1 & 0 \newline  
\hline % Solid horizontal line  
0 & 1 & 0 & 0  
\end{array}  
\right)  
= \left(  
\begin{array}{c:c} % 'c' for centered column, ':' for a dotted vertical line  
\alpha_{10} & \alpha_{11} \newline  
\hline % Solid horizontal line  
\beta_{10} & \beta_{11}  
\end{array}  
\right)$$

We'll compute $\alpha_1 \beta_1$ going one level down in the recursion, viewing its coordinates in $\mathcal{T_2}$ in its coordinates in $\mathcal{T_0}$, just as before:

        1. $P^\prime_A = \alpha_{10}\cdot\beta_{10}$, which in $\mathcal{T_1}$ coordinates is the product $$\boxed{0, 0}\times \boxed{1, 0} = \boxed{0,0}$$
        2. $P^\prime_B = \alpha_{11}\cdot\beta_{11}$, which in $\mathcal{T_1}$ coordinates is the product $$\boxed{1, 0}\times \boxed{0, 0} = \boxed{0,0}$$
        3. $P^\prime_C = (\alpha_{10} + \alpha_{11})\cdot(\beta_{10} + \beta_{11})$, which in $\mathcal{T_1}$ coordinates is the product $$\boxed{1, 0}\times \boxed{0, 1} = \boxed{0,1}$$ (once done the necessary addition in each factor)
        4. And finally we have the $P^\prime_B X_{0}$ term (we omit writing down the matrix product since this is fairly trivial and intuitive from reading the coordinates):  
$$\boxed{0,0}\times\boxed{0,1} = \boxed{0,0}$$

With all these, we're ready to reconstruct $\alpha_1 \beta_1$ as an element in $\mathcal{T_2}$. The coordinate expression for

$$\alpha_1 \beta_1 = (P^\prime_A + P^\prime_B ) + (M + P^\prime_B X_0) X_1$$

can be reconstructed from the 2-bit strings as follows: **first, add then pad.** We get

$$[P^\prime_A + P^\prime_B ]^1 = \boxed{0,0} + \boxed{0,0} = \boxed{0,0}\implies [P^\prime_A + P^\prime_B ]^2 = \boxed{0,0,0,0}$$

remembering the padding to view them in $\mathcal{T_2}$ coordinates. Then, the slippery part: viewed as elements in $\mathcal{T_1}$,

$$[P^\prime_B X_0 ]^1=\boxed{0,0}\implies [M + P^\prime_B X_0]^1 = \boxed{0,1} + \boxed{0,0} = \boxed{0,1}$$

**Before multiplying it with $X_1$, we embed this element in $\mathcal{T_2}$ by padding with zeros at the end.** Then, matrix multiplication:

$$[(M + P^\prime_B X_0 ) X_1]^2 = \boxed{0,1,0,0}\times \boxed{  
\begin{matrix}  
0 & 0 & 1 &0\newline  
0 & 0 & 0 & 1\newline  
1 & 0 & 0 & 1\newline  
0 & 1 & 1 & 1  
\end{matrix}  
}=\boxed{0,0,0,1}$$

We then perform the sum to obtain

$$\boxed{0,0,0,0} + \boxed{0,0,0,1} = \boxed{0,0,,0,1}$$

which means that $P_B = \alpha_1 \beta_1 = X_0 X_1 \in \mathcal{T_2}$

Now we want to compute $P_C = (\alpha_) + \alpha_1)(\beta_0 + \beta_1)$. By taking a look at the expression in coordinates of $u$ and $v$, the sum of its first and second halves is done quickly and now we have

$$\begin{pmatrix}\alpha_0 + \alpha_1\newline \hline \beta_0 + \beta_1\end{pmatrix}^2=\begin{pmatrix}  
0 & 1 & 1 & 0\newline  
\hline % This command draws a solid horizontal line  
1 & 1 & 1 & 0  
\end{pmatrix}=  
\left(  
\begin{array}{cc:cc} % 'c' for centered column, ':' for a dotted vertical line  
0 & 1 & 1 & 0 \newline  
\hline % Solid horizontal line  
1 & 1 & 1 & 0  
\end{array}  
\right)  
= \left(  
\begin{array}{c:c} % 'c' for centered column, ':' for a dotted vertical line  
a & b \newline  
\hline % Solid horizontal line  
c & d  
\end{array}  
\right)$$

We'll compute $P_C$ going one level down in the recursion, viewing its coordinates in $\mathcal{T_2}$ in its coordinates in $\mathcal{T_0}$, just as before:

        1. $P^\prime_A = a\cdot c$, which in $\mathcal{T_1}$ coordinates is the product $$\boxed{0, 1}\times \boxed{1, 1} = \boxed{1,0}$$
        2. $P^\prime_B = b\cdot d$, which in $\mathcal{T_1}$ coordinates is the product $$\boxed{1, 0}\times \boxed{1, 0} = \boxed{1,0}$$
        3. $P^\prime_C = (a + b)\cdot(c + d)$, which in $\mathcal{T_1}$ coordinates is the product $$\boxed{1, 1}\times \boxed{0, 1}=\boxed{1,0}$$ (once done the necessary addition in each factor)
        4. And finally we have the $P^\prime_B X_{0}$ term:  
$$\boxed{1,0}\times\boxed{0,1} = \boxed{0,1}$$

With all these, we're ready to reconstruct $P_C$ as an element in $\mathcal{T_2}$. The coordinate expression for

$$P_C = (P^\prime_A + P^\prime_B) + (M + P^\prime_B X_0 )X_1$$

can be reconstructed from the 2-bit strings as follows: **first add, then pad**. Since we already did this a couple of times, we allow some speeding:

$$[P^\prime_A + P^\prime_B ]^2 = \boxed{1,0,0,0} + \boxed{1,0,0,0} = \boxed{0,0,0,0}$$

Then, the slippery part: viewed as elements in $\mathcal{T_1}$,

$$P^\prime_B X_0 = \boxed{0,1}\implies M + P^\prime_B X_0 = \boxed{1,0} + \boxed{0,1} = \boxed{1,1}$$

**Before multiplying it with $X_1$, we embed this element in $\mathcal{T_2}$ by padding with zeros at the end.** We now perform the product in the upper extension by simply shifting its coefficients in two positions to the left while padding with zeros the first two slots:

$$[M + P^\prime_B X_0 ]^2=\boxed{1,1,0,0},\quad\text{then }\quad [(M + P^\prime_B X_0 )X_1 ]^2 = \boxed{0,0,1,1}$$

We obtain $[P_C ]^2=\boxed{0,0,1,1}$, this is, $P_C = X_1 + X_0 X_1 \in\mathcal{T_2}$

The last branch of this first layer amounts to computing $P_BX_1$; this product happens in the $\mathcal{T_2}$ subfield. In coordinates we have

$$[P_B X_1 ]^2 = \boxed{0,1,1,1}$$

        * **Second step:** Reconstruct by performing additions

We're now ready to build $u\cdot v$ with Karatsuba's recipe:

$$u\cdot v = (P_A + P_B ) +(M + P_B X_1 ) X_2$$

Let's proceed in coordinates. Before anything else, lest begin by displaying all the elements we need to combine so we don't mess up.

        1. $P_A = X_0 + X_0 X_1 \in\mathcal{T_2} \iff [P_A ]^2 = \boxed{0,1,0,1}$
        2. $P_B = X_0 X_1 \in\mathcal{T_2} \iff [P_B ]^2 = \boxed{0,0,0,1}$
        3. $P_C = X_1 + X_0 X_1 \in\mathcal{T_2} \iff [P_C ]^2 = \boxed{0,0,1,1}$
        4. $M = P_A + P_B + P_C = X_0 + X_1 + X_0 X_1 \in\mathcal{T_2} \iff [M]^2 = \boxed{0,1,1,1}$
        5. $P_B X_1 = X_0 + X_1 + X_0 X_1 \in\mathcal{T_2} \iff [P_B X_1 ]^2 = \boxed{0,1,1,1}$

To do this, we add these elements in $\mathcal{T_2}$ and then embed them in $\mathcal{T_3}$ by simply padding with zeros their last 4 positions to obtain 8 bit strings. This gives

$$[P_A + P_B]^3 = \boxed{0,1,0,0,0,0,0,0}$$

is the first thing we need. Now compute $M + P_B X_1$ in $\mathcal{T}^3$;

$$[M + P_B X_1 ]^2 = \boxed{0,0,0,0}\implies [M + P_B X_1 ]^3 = \boxed{0,0,0,0,0,0,0,0}$$

so trivially

$$[(M + P_B X_1 )X_2 ]^3 = \boxed{0,0,0,0,0,0,0,0}$$

The desired product is then

$$[u\cdot v]^3 = \boxed{0,1,0,0,0,0,0,0} + \boxed{0,0,0,0,0,0,0,0} = \boxed{0,1,0,0,0,,0,0}$$

this is $u\cdot v = X_0$ which can be verified directly by hand.

Obviously, this last example performed in full can quickly turn dull, but it only hightens the convenient recursive nature of multiplication in binary towers and that circuitry-level operations appear as a key element for fast and efficient implementations.

## Summary

In this post, we covered the basics of the tower construction powering Binius and some of its interesting properties. In an upcoming article, we raise the bar and aim for a more involved problem: polynomial evaluation in binary towers.
