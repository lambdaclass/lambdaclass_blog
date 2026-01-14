+++
title = "Multilinear polynomials: survival kit"
date = 2025-08-26
slug = "multilinear-polynomials-survival-kit"

[extra]
feature_image = "/content/images/2025/12/Le_Serment_des_Horaces_-_Jacques-Louis_David_-_Muse--e_du_Louvre_Peintures_INV_3692_-_MR_1432.jpg"
authors = ["LambdaClass"]
+++

## Introduction

In this article we briefly introduce a list of basic properties of multilinear polynomials that are convenient to have in mind when tackling a very interesting piece of work by Bagad, Dao, Domb and Thaler: "Speeding up SUM-CHECK proving". The authors focus on a specific setting for the SUMCHECK protocol, useful in various contexts: they narrow their attention to the case where the polynomial $g$ object of the SUMCHECK claim can be written as a product of $d$ multilinear polynomials

$$g(X) = \prod\limits_{ k = 1 }^d p_k (X)$$

and proceed to craft a series of algorithms tayloring their time and memory usage. Before diving into their findings, it is maybe timely that we refresh some facts about these type of polynomials for future use.

## Multilinear polynomials: definition and basic properties

For the rest of the article, fix a field $k$. By multilinear polynomial we mean a $\ell\geq 0$ variate polynomial $f\in k\left[X_1,\ldots X_\ell\right]$ such that each of its monomials has the following feature: each variable is raised to a power which is either 0 or 1. These polynomials are of great use and appear throughout field theory literature in different guises and recently re emerged as useful objects in Ben Diamond and Jim Posen's effort BINIUS.

We will use $\mathcal{M_k} \left[X_1,\ldots X_\ell\right]$ to denote the collection of all multilinear polynomials of $\ell$ variables with coefficients in $k$. Examples of multilinear polynomials abound:

$$p(X_1 , X_2) = 2 + X_1 + X_1 X_2,\quad q(X_1,X_2,X_3) = 2x_3 + X_1 X_2 X_3 + X_1 X_2, , \text{etc}$$

It should be noticed that multilinear polynomials of $\ell$ indeterminates have degree bounded by $\ell$; naturally, $\mathcal{M_k} \left[X_1,\ldots X_\ell\right]$ is a vector subspace of $k\left[X_1, \ldots X_\ell \right]$: it is closed respect to addition and scalar multiplication.

### Interpolation

One of the great features of multilinear polynomials is that they allow a neat way of replacing arbitrary functions over a very special domain. Cutting to the chase, _any_ function $\varphi$ defined over the hypercube $\\{ 0,1 \\}^\ell$ can be interpolated with multilinear polynomials. This happens because the hypercube being discrete, it allows the identification of the function $\varphi$ with the list of its images ${\varphi(x): x \in \\{0,1 \\}^\ell}$ and crucially, for each $x$ in the hypercube we have a multilinear polynomial that takes the value 1 over $x$ and evaluates to zero elsewhere.

For example, take $b = (1,0,1,1) \in \\{0,1 \\}^4$. Then

$$\chi_b (X_1 , X_2 , X_3 , X_4 ) = X_1 (1 - X_2 ) X_3 X_4$$

is a multilinear polynomial evaluating to 1 over $b$ and to 0 elsewhere. Generally, for $b \in \\{0,1 \\}^\ell$, the multilinear polynomial having this property can be expressed as

$$\chi_b (X) = \prod_{ j = 1 }^{\ell} ( b_j X_j + (1 - b_j) (1 - X_j))$$

The reader may recall Lagrange interpolation in one variable and polynomials satisfying this sort of condition). In cyprographic lingo, these are sometimes called "equality polynomials" and commonly nomenclated as $eq(x,y)$. So how does this interpolation property work? Let's cook up an example.

Suppose we are given the function

$$\varphi (X_1 ,X_2 ) = (1 + X_1) (X_1 + X_2)$$

As it is, this polynomial has degree 2 in $X_1$ so it is not a multilinear polynomial. However it can be interpolated over the cube $\\{0,1 \\}^2$, by the use of the equality or Lagrange polynomials: $\chi_b$ with $b$ in the boolean square $\\{0,1 \\}^2$.

\begin{align*}  
\varphi(X_1, X_2) =& \sum\limits_{ b \in \\{0,1\\}^2 } g(b) \chi_b (x) =\newline  
=& \varphi(0,0)(1 - X_1)(1 - X_2) + \varphi(1,0) X_1 (1 - X_2)\newline  
+& \varphi(0,1) (1 - X_1) X_2 + \varphi(1,1) X_1 X_2  
\end{align*}

where this equality is functionally understood: it is the equality of two functions over the boolean hypercube, one of which is a multilinear polynomial. Before getting carried away, lets state a fact

**Fact number 1:** $\mathcal{M_\ell}$ is a vector space of dimension $2^\ell$ with basis the Lagrange polynomials

$$\mathcal{L_\ell} = \\{ \chi_b : b\in \\{0,1\\}^\ell \\}$$

As it is customarily done, there is an ordering of the dimension $\ell$ hypercube obtained by the binary expansion of the first $2^\ell$ non negative integers: if $0\leq m\leq 2^{\ell} - 1$ then

$$m = m_0 2^0 + m_1 2^1 + \cdots m_{ \ell - 1 } 2^{ \ell - 1}\quad m_i\in \\{0,1 \\}$$

we set the $m$-th basis polynomial to be the equality polynomial for the string $$(m_{ \ell - 1} ,\ldots m_1, m_0)$$ This will be the ordering we adopt for the Lagrange basis and the order we will use to obtain crucial information: the standard binary order. For those unfamiliar:

        1. The **first variable** , $X_1$, is associated with the **most significant bit (MSB)**.
        2. The **last variable** , $X_l$, is associated with the **least significant bit (LSB)**.

For example, for a 3-variable polynomial, $g(X_1, X_2, X_3)$, the hypercube coordinates are ordered as follows:

**Hypercube Point** (Binary Representation) | **Polynomial Coordinates** $(X_1, X_2, X_3)$  
---|---  
$000_2 = 0$ | $(0, 0, 0)$  
$001_2 = 1$ | $(0, 0, 1)$  
$010_2 = 2$ | $(0, 1, 0)$  
$\dots$ | $\dots$  
$111_2 = 7$ | $(1, 1, 1)$  
  
Don't fret, this is simply a choice to walk the cube and how we will consider the interpolation basis. For sake of clarity:

        1. One can easily verify that the basis

$$\mathcal{L_2} = \\{ (1 - X_1) (1 - X_2), (1 - X_1) X_2, X_1 (1 - X_2), X_1 X_2 \\}$$

interpolates the boolean hypercube in the sense that the $k$-th basis vector takes the value 1 over the binary representation of $k$ and takes the value 0 elsewhere.

        2. The basis for $\mathcal{M} \left[X_1 ,X_2 ,X_3 \right]$ is obtained by simply orderly taking from left to right each vector in $\mathcal{L_2}$ and multiplying it by ($1 - X_3$) first, and then secondly, by $X_3$. Then $\mathcal{L_3}$ consists of the collection
        * $(1 - X_1) ( 1 - X_2 )( 1 - X_3)$
        * $(1 - X_1) (1 - X_2) X_3$
        * $(1 - X_1) X_2 (1 - X_3)$
        * $(1 - X_1) X_2 X_3$
        * $X_1 (1 - X_2) (1 - X_3)$
        * $X_1 (1 - X_2) X_3$
        * $X_1 X_2 (1 - X_3)$
        * $X_1 X_2 X_3$

in this specific order.

### Coordinates and evaluations: the golden link

What we just discussed in the previous section already sets multlinear polynomials and their basis in a different ground respect to other sets. In linear algebra for instance, the expression of a vector as a linear combination of a basis set involves building (and solving!) a system of linear equations. As much as we love systems of linear equations, finding the coordinates of the vector REQUIRES SOLVING the system and this obviously costs time and memory. It is for this reason that some basis are preferred over others: finding coordinates of vectors should be as easy as possible.

Concretely, if we wanted to represent $v = (2,3)$ as a combination of $(1,2)$ and $(5, - 7)$ we would be required to first build a system of equations and secondly, solving it dealing with all the numerical complexities involved (this is a small example but think of vectors with $2^{128}$ elements...).

It results in a different story altogether if now the vectors we want to use are $(1,0)$ and $(0,1)$: the canonical basis. Now the problem is almost trivially solved by eyeballing or directly, evaluating what the contents of $v$ are:

$$v = 2\cdot (1,0) + 3\cdot (0,1)$$

> This is the precise situation we have with the equality polynomials: now coordinates in this basis are simply the evaluations of the function we want to interpolate. And this is great news because computers love to evaluate.

This conversation yields

> **Fact number 2:** Coordinates of a function $f$ defined over the boolean hypercube $\\{0,1 \\}^\ell$ respect to the Lagrange basis $\mathcal{L_\ell}$ are simply its evaluations:

$$coords(f)= \left[f(b) \right]_{ b\in \\{0,1 \\}^\ell}$$

For instance, for the multilinear polynomial

$$g(X_1 , X_2) = 1 + X_1 + X_1 X_2$$

Then its coordinates in the interpolation basis are simply

$$g\longleftrightarrow coords(g) = \left[1,1,2,3 \right] = \left[g(0), g(1), g(2), g(3) \right]$$

where we exploited the ordering of teh cube and took the liberty of "evaluating $g$ at the integers $0\leq n\leq 2^2 - 1$".

### Tensorization in this context

One of the operations between polynomials that we learn in highschool is polynomial multiplication: for example, when given polynomials

$$X + 1\quad\text{and }\quad 2 + Y$$

we compute their product using the distributive law, juxtaposing indeterminates and using powers to abbreviate equal symbols juxtaposed:

$$(X + 1)( 2 + Y) = 2 X + XY + 2 + Y$$

and assuming the order of the symbols in monomial is irrelevant. When thinking of polynomials as vectors, we need a formalism to portray this exact operation. That formalism is called the tensor product and allows vector multiplication just as we know it; the field that studies tensor products is called multilinear algebra and is obviously an older brother of linear algebra. The symbol commonly found for the tensor product of vectors $v\in\mathbb{V}$ and $w\in\mathbb{W}$ is

$$v\otimes w\in \mathbb{V}\otimes\mathbb{W}$$

and we notice that $\mathbb{V}\otimes\mathbb{W}$ is a new vector space, constructed with $\mathbb{V}$ and $\mathbb{W}$ obviously called their tensor product. This product has all the properties we want to abstract, the distributive law being crucial for our needs:

$$v\otimes w + 2v.u \otimes w = (3v + u)\otimes w$$

All this in our setting is quite natural: if we set $\mathbb{V}$ the vector space of polynomials of degree at most 1 in the indeterminate $X_1$ and $\mathbb{W}$ the vector space of polynomials of degree at most 1 in the indeterminate $X_2$, then

$$\mathbb{V}\otimes \mathbb{W} = \mathcal{M} \left[X_1 \right]\otimes \mathcal{M} \left[X_2 \right] = \mathcal{M_2} \left[X_1,X_2 \right]$$

and more importantly, the tensor product of the basis yields a basis for the tensor product. The general theory guarantees that whenever $\mathcal{B}$ and $\mathcal{C}$ are basis for $\mathbb{V}$ and $\mathbb{W}$ respectively, then

$$\mathcal{B}\otimes\mathcal{C}={v_i\otimes w_j: 1\leq i\leq dim(\mathbb{V}), 1\leq j\leq dim(\mathbb{W})}$$

is a basis for the new vector space. However a choice of order for those vectors must be made. To our interest, it is convenient to order the tensor products of the basis vectors in a fashion compatible with the binary expansion; in the case of $dim(\mathbb{V})=dim(\mathbb{W})=2$ the basis we're going to be looking at is simply

$$\mathcal{B}\otimes\mathcal{C}={v_1\otimes w_1, v_1\otimes w_2, v_2\otimes w_1,v_2\otimes w_2}$$

which is commonly referred to as the lexicographic order. In this sense, this basis works just fine: say you pick $z \in V \otimes W$ for instance

$$z = 2(v_1 \otimes w_1) + 5(v_1 \otimes w_2) + 3(v_2 \otimes w_1) - 1(v_2 \otimes w_2)$$

Its coordinate vector turns out to be $[2, 5, 3, -1]$. Moreover, since tensors are compatible with the distributive law, we are allowed to regroup the terms:

$$z = (2w_1 + 5w_2) \otimes v_1 + (3w_1 - 1w_2) \otimes v_2$$

The coefficients of this combination are the following elements of $V$:

        * **Coefficient of $v_1$** : $c_1 = 2w_1 + 5w_2$
        * **Coefficient of $v_2$** : $c_2 = 3w_1 - 1w_2$

These coefficients, expressed in coordinates of the basis chosen for $\mathbb{W}$ are simply $[2, 5]$ and $[3, -1]$. The way the order for the tensor basis is chosen to recreate the fact:

$$\text{concat}(\text{coords}(c_1), \text{coords}(c_2)) = \text{concat}([2, 5], [3, -1]) = [2, 5, 3, -1]$$

In the context of multilinear polynomials, this discussion makes clear that these polynomials can be obtained by recursively tensoring vector spaces of polynomials of degree at most 1 in distinct variables: we have an algebraic characterization of the vector space of multilinear polynomials

$$\mathcal{M_\ell} \left[X_1,\ldots X_\ell \right] = \mathcal{M_\ell} \left[X_1,\ldots X_{ \ell - 1} \right]\bigotimes \mathcal{M}\left[X_\ell \right]$$

and moreover, exploiting the associativity of the tensor product we arrive at a very natural fact:

> **Fact number 3:** Let $\\{1,2,\ldots, \ell \\} = J \bigcup I$ with $J,I$ disjoint. Then multilinear polynomials with indeterminates $X_1,\ldots X_\ell$ can be regarded as multlinear polynomials with indeterminates $X_j\in J$ and coefficients being multilinear polynomials in the indeterminates $X_i\in I$.

To fix the idea, take a look at the polynomial

$$h = X_1+X_1 X_3 + 2X_2 X_3 X_4 + 2X_4$$

This naturally is a multilinear polynomial in $X_3$ and $X_4$, since they are raised to power at most 1. Using the Lagrange basis for multilinear polynomials in the variables $X_3$ and $X_4$

$$\\{(1 - X_3) (1 - X_4), (1 - X_3 ) X_4, X_3 (1 - X_4), X_3 X_4 \\}$$

we find the corresponding coefficients by making use of we what we already discussed: the coefficients will be polynomials in the remaining variables, $X_1$ and $X_2$ obtained by evaluating the original polynomial $h$ at the four points of the hypercube for $X_3$ and $X_4$.

        * **Coefficient of $(1 - X_3) (1 - X_4)$:** We evaluate $h$ at $(X_3 = 0, X_4 = 0)$.  
$$h(X_1, X_2, 0, 0) = X_1 + X_1(0) + 2 X_2 (0)(0) + 2(0) = X_1$$  
This is the coefficient for the first basis polynomial.
        * **Coefficient of $(1 - X_3) X_4$:** We evaluate $h$ at $(X_3 = 0, X_4 = 1)$.  
$$h(X_1, X_2, 0, 1) = X_1 + X_1(0) + 2X_2 (0)(1) + 2(1) = X_1 + 2$$  
This is the coefficient for the second basis polynomial.
        * **Coefficient of $X_3 (1 - X_4)$:** We evaluate $h$ at $(X_3 = 1, X_4 = 0)$.  
$$h(X_1, X_2, 1, 0) = X_1 + X_1(1) + 2X_2 (1)(0) + 2(0) = X_1 + X_1 = 2X_1$$  
This is the coefficient for the third basis polynomial.
        * **Coefficient of $X_3 X_4$:** We evaluate $h$ at $(X_3 = 1, X_4 = 1)$.  
$$h(X_1, X_2, 1, 1) = X_1 + X_1(1) + 2X_2(1)(1) + 2(1) = X_1 + X_1 + 2X_2 + 2 = 2X_1 + 2X_2 + 2$$  
This is the coefficient for the fourth basis polynomial.

Putting it all together, the coordinates for $h$ viewed as a multilinear polynomial in the variables $X_3$ and $X_r$ is simply

$$\left[X_1, 2+X_1, 2X_1, 2 + 2X_1 + 2X_2 \right]$$

As the reader may already be thinking "but we can also compute the coordinates of the coordinates" and yes, there is where we are headed: a recursive algorithm to produce coordinates of multilinear polynomial or in a different light: a protocol to use strings of evaluations.

> **Fact number 4:** In the same vein, evaluating a multilinear polynomial in a subset of its variables yields a multilinear polynomial in the remaining ones.

## The adventure of multilinear interpolation

What we just discussed can be seen as a case of _multilinear interpolation_. By the nature of the interpolation basis for multilinear polynomials in $\ell$ variables, this process can be iterated and coordinates computed efficiently, if tackled in an organized manner.

### Algorithm: MultilinearCoordinates/ InterpolationBasis(g, l)

This algorithm takes a multilinear polynomial $g$ in $l$ variables and returns a vector of $2^l$ coordinates that represent $g$ in the multilinear interpolation basis.

        1. **Base Case:**
           * **If** $l = 0$:  
i. The polynomial $g$ is a constant.  
ii. **Return** the vector with the single coordinate $[g]$.

           * **If** $l = 1$:  
i. The polynomial $g$ is multilinear in one variable $X_1$.  
ii. The coordinates are the evaluations of $g(0)$ and $g(1)$.  
iii. **Return** the vector $[g(0), g(1)]$.

        2. **Recursive Step:**
           * **If** $l > 1$:  
i. Express $g$ as a polynomial in the variable $X_l$ with coefficients that are multilinear polynomials in the first $l - 1$ variables:  
$$g(\mathbf{X}) = C_0 (X_1, \dots, X_{l - 1})(1 - X_l) + C_1 (X_1, \dots, X_{l - 1}) X_l$$  
ii. Compute the coefficients $C_0$ and $C_1$ by evaluating $g$ at the extreme points of $X_l$:  
$$C_0(\mathbf{X_{<l}}) = g(\mathbf{X_{<l}}, 0)$$  
$$C_1(\mathbf{X_{<l}}) = g(\mathbf{X_{<l}}, 1)$$  
iii. **Recursively call** the algorithm to find the coordinates of these two new polynomials in $l - 1$ variables:  
a. $coords_0 \gets$ `MultilinearCoordinatesInterpolationBasis(C_0, l - 1)`  
b. $coords_1 \gets$ `MultilinearCoordinatesInterpolationBasis(C_1, l - 1)`  
iv. The coordinates of the original polynomial $g$ are the concatenation of the vectors $coords_0$ and $coords_1$.  
v. **Return** $$concat(coords_0, coords_1)$$

This algorithm exploits the fact that over the corresponding interpolation basis, the coordinates are none but the evaluation of the polynomial in the designated point in the hypercube, just as in the previous section.

To illustrate let's pick up our previous example. For our toy polynomial

$$h = X_1 + X_1 X_3 + 2X_2 X_3 X_4 + 2X_4$$

we computed its coordinates in the interpolation basis in the variables $X_3, X_4$, obtaining:

$$\left[ X_1, 2+X_1, 2X_1, 2 + 2X_1 + 2X_2 \right]$$

Now we go on by obtaining the coordinates of each of these polynomials in the multilinear interpolation basis for the variables $X_1$ and $X_2$:

        * **Coordinates for $X_1$:** We evaluate $X_1$ at each of the points of the boolean square, obtaining  
$$X_1\longleftrightarrow \left[0, 1, 0, 1 \right]$$

        * **Coordinates for $2 + X_1$:** We evaluate $2 + X_1$ at each of the points of the boolean square, obtaining  
$$2 + X_1\longleftrightarrow \left[2, 3, 2, 3 \right]$$

        * **Coordinates for $2X_1$:** repeating the idea we get  
$$2X_1\longleftrightarrow \left[0, 2, 0, 2 \right]$$

        * **Coordinates for $2 + 2X_1 + 2X_2$:** finally, evaluating at the point of the boolean square in binary order  
$$2 + 2X_1 + 2X_2 \longleftrightarrow \left[2, 4, 4, 6 \right]$$

The concatenation of these final coordinates gives us the 16 evaluations of the polynomial $h$ on the hypercube ${0,1}^4$:

$$\text{coords}(h) = \text{concat}([0,1,0,1], [2,3,2,3], [0,2,0,2], [2,4,4,6] )$$

this is,

$$\text{coords}(h) = [0,1,0,1,2,3,2,3,0,2,0,2,2,4,4,6]$$

As we can easily verify the evaluations of $h$ directly. We've shown this procedure forwards, but this makes available for us a quick way of looking at coordinates in a quick way by simply eyeballing sub-vectors in the original string of coordinates. More on this later.

## Products of multilinear polynomials

As we've seen already, the set of multilinear polynomials in $\ell$ variables is indeed a vector space over the base field. However, product of multilinear polynomials fails to be a multilinear polynomial, in general.  
Suppose now that

$$g = \prod\limits_{ k = 1 }^d p_k$$

where the factors $p_k$ are all multilinear polynomials in $X_1,\ldots X_\ell$. By picking a variable $X_i$ we can view the product as a general polynomial in $X_i$ and coefficients in the ring of polynomials in the remaining variables.

> **Fact number 4:** The degree of $g$ as a polynomial in $X_i$ is the sum of the degrees, as polynomials in $X_i$ for each of the factors $p_k$; this can be determined by deciding whether the polynomial $p_k$ has $X_i$ as a variable.

So if we want to decide what is the degree of $g$ in the $X_i$ variable, we need to check whether each multilinear factor includes this variable or not. We can decide this fact with a rudimentary algorithm that uses a simple evaluation-based test: a multilinear polynomial $p(X_1, \dots, X_\ell)$ does **not** include the variable $X_k$ if and only if its value remains constant when you change the value of $X_k$ from 0 to 1, while keeping all other variables fixed. This is, if

> **Fact number 5:**  
>  $$p(x_1, \dots, x_{k - 1}, 0, x_{k + 1}, \dots, x_\ell) = p(x_1, \dots, x_{k - 1}, 1, x_{k + 1}, \dots, x_\ell)$$  
>  for all $x_j \in \\{0,1 \\}$ where $j \neq k$ $\iff$ $p$ does not depend on $X_k$.

To illustrate this fact, suppose we have

$$p(X_1, X_2, X_3) = X_1 (X_2 + X_3)$$

and we want to test if this polynomial includes the variable **$X_3$**. The test requires us to check if $$p(X_1, X_2, 0) = p(X_1, X_2, 1)$$ for all possible combinations of $(X_1, X_2) \in \\{0,1 \\}^2$.

        1. **First we check for $(x_1, x_2) = (0, 0)$:**
        * $p(0, 0, 0) = 0(0 + 0) = 0$
        * $p(0, 0, 1) = 0(0 + 1) = 0$
        * The equality holds and observe that if the algorithm stopped here, it would wrongly conclude that the polynomial does not depend on $X_3$. Checking equality at all points of the hypercube is necessary.
        2. **Now check for $(x_1, x_2) = (1, 0)$:**
        * $p(1, 0, 0) = 1(0 + 0) = 0$
        * $p(1, 0, 1) = 1(0 + 1) = 1$
        * The equality **fails**.

Because the equality fails for at least one case, an algorithm comparing evaluations correctly concludes that the variable $X_3$ **is** included in the polynomial.

Since we've spent some time discussing the connection between evaluations on the hypercube and coordinates over the multilinear interpolation basis - how can we make use of what we already know?

> Concretely, can we come up with an algorithm to decide whether a certain multilinear polynomial includes a specific variable or not, in a way that the algorithm exploits the recursive nature of the coordinates in the multilinear interpolation basis and the ordering of the hypercube?

Since evaluations are no other than coordinates in the multilinear interpolation basis, performing the test we mentioned before amounts to inspecting different entries in the coordinate vector.

And how is this possible? Well, the first step is realizing that there is a relation between the position on the coordinate vector and the value of a variable $X_i$. For instance, take the polynomial $$g(X_1, X_2, X_3) = X_1 + X_3$$ which clearly does not depend on $X_2$. Its coordinate vector is:

$$\text{coords}(g) = [0, 1, 0, 1, 1, 2, 1, 2]$$

The first half of the vector corresponds to evaluations over points in the hypercube with $X_1=0$ and the second half corresponds to evaluations over points with $X_1=1$. In this way we split the coordinates in two chunks of half the size and proceed to compare those strings:

$$\text{coords} g_{ X_1 = 0} = [0, 1, 0, 1],\quad \text{coords} g_{ X_1 = 1 } = [1, 2, 1, 2]$$

> _As a brief comment: it is worth mentioning that these new strings of evaluations correspond to the coordinates of the multilinear polynomials that act as coefficients of $g$ as discussed in the earlier sections: they are the coordinates of $C_0^1 (X_2 , X_3)$ and $C_1^1 (X_2 , X_3)$ in the equality_ $$g(X_1, X_2 , X_3 ) = C_0^1 (X_2 , X_3) ( 1 - X_1 ) + C_1^1 (X_2 , X_3) X_1$$

But let's stick to the coordinates. We now scan these pieces: since they differ in the fist position we correctly conclude that $g$ depends on $X_1$.

Next we have the task to decide whether $X_2$ is present in $g$: w can now identify these two sub-vectors as coefficients in the multilinear interpolation basis for the variables $X_2$ and $X_3$ and call this test again on both pieces. We split both in two halves, corresponging to the evaluations $X_2 = 0$ and $X_2 = 1$:

        * the coordinates of $C^1_0 (X_2,X_3)$ are $\text{coords}(c^1_0 ) = [0, 1, 0, 1]$ and split into $[0, 1]$ and $[0, 1]$
        * the coordinates of $C^1_1 (X_2 , X_3)$ are $\text{coords}(c^1_1 ) = [1, 2, 1, 2]$ and split into $[1, 2]$ and $[1, 2]$  
in both cases, the sub-vectors coincide and this means that in effect, $X_2$ is not present in $g$.

Finally to decide for $X_3$ we perform the same test on each of the 4 pieces obtained in the last step. It is easy to see that splitting $[0, 1]$ yields the scalar vectors

$$[0]\quad\text{and}\quad [1] $$

which are obviously different and so $g$ effectively contains the variable $X_3$.

In this example, we organized the routine in a "divide and conquer" fashion which is already appealing by inspecting equality starting in the most significant bit (MSB), working by halving string size towards the less significant bit (LSB) $X_3$. However, this is not the only way the inspection can be done, and as a matter of fact, for memory access reasons it is more convenient to assess variables _in reverse order of significance_. On the one hand this kills the divide and conquer approach but yields better performance results: modern computers access memory in contiguous blocks (cache) and the "divide and conquer" approach we discussed compares positions that are far apart in the original vector: $g(0)$ is compared to $g(5)$, $g(1)$ is compared to $g(6)$, and so on, and this is costly in terms of performance. How do cook up a way of using contiguity?

A good way of making use of contiguity is by the use of _strides_. The coordinate vector is ordered lexicographically, which means the indices of the elements correspond to the binary representation of integers, from 0 to $2^l - 1$. In this convention, each polynomial variable, $X_k$, is associated with a specific bit in the binary representation of the coordinates.

The _stride_ for variable $X_k$ is simply the **positional weight** of its bit in the binary representation: in other words, how much does the $k-th$ bit contribute to the position in the hypercube. For a polynomial  
$$g(X_1, X_2, X_3)$$  
with an 8-element coordinate vector, the _stride_ aligns with the inspection of each variable:

        * **For $X_3$ (LSB):** To change the value of $X_3$ from 0 to 1, we only need to change the least significant bit. The weight of this bit is $2^0 = 1$. Therefore, the _stride_ for $X_3$ is **1**. The test compares pairs of adjacent coordinates, such as $v_0$ with $v_1$ (corresponding to $000$ and $001$).
        * **For $X_2$:** To change the value of $X_2$ from 0 to 1, we need to change the middle bit. The weight of this bit is $2^1 = 2$. Therefore, the _stride_ for $X_2$ is **2**. The test compares pairs of coordinates that are 2 positions apart, such as $v_0$ with $v_2$ (corresponding to $000$ and $010$).
        * **For $X_1$ (MSB):** To change the value of $X_1$ from 0 to 1, we need to change the most significant bit. The weight of this bit is $2^2 = 4$. Therefore, the _stride_ for $X_1$ is **4**. The test compares pairs of coordinates that are 4 positions apart, such as $v_0$ with $v_4$ (corresponding to $000$ and $100$).

> The _stride_ works as an algorithmic shortcut to find the pairs of coordinates that only differ in the variable you are testing, by leveraging the structure of the binary encoding.

By the use of the stride for each variable, now we have a way of scanning the coordinate vector in an efficient way. The pseudocode of such an algorithm is not complicated:

**Inputs:**

        * _coords_ : A vector of $2^l$ coordinates (evaluations) of the polynomial $g$ on the hypercube ${0,1}^l$.
        * _l_ : The total number of variables in the polynomial ($X_1$ to $X_l$).

**Intermediate Parameters:**

        * _stride_ : The step or distance between the coordinates being compared. Its value is $2^{l-k}$ for variable $X_k$.
        * _block length_ : The size of each iteration block. Its value is $2^{k - 1}$.

> The algorithm _DecideDependence_LSBFirst(coords, l)_ is executed as follows:

        1. For each variable $X_k$ (iterating from $k = l$ down to $1$):
        2. Calculate _stride_ $= 2^{l - k}$.
        3. Set a flag _depends_ to _FALSE_.
        4. Iterate from $j = 0$ to $j = 2^{l} - 1$, with a step of $2 \cdot \text{stride}$.
        5. In each iteration, compare the coordinates _coords[j]_ and _coords[j + stride]_.
        6. If it is found that _coords[j]_ $\neq$ _coords[j + stride]_ , set _depends_ to _TRUE_ and exit the inner loop.
        7. Report the result of _depends_ for variable $X_k$.

As an example with absolutely no surprises, here's the application to the polynomial $$g(X - 1, X_2, X_3) = X_1 + X_3$$

We will use the same 8-element coordinate vector for $g$:  
$$\text{coords}(g) = [0, 1, 0, 1, 1, 2, 1, 2]$$

### 1\. Decision for $X_3$ ($k = 3$)

        1. _stride_ = $2^{ 3 - 3} = 1$.
        2. The algorithm compares the pairs _(coords[j], coords[j+1])_ for $j = 0, \dots, 6$ with a step of 2.
        3. For $j = 0$: _coords[0] (0)_ vs. _coords[1] (1)_. Since $0 \neq 1$, the test fails.
        4. **Conclusion:** $g$ **depends** on $X_3$.

### 2\. Decision for $X_2$ ($k = 2$)

        1. _stride_ = $2^{ 3 - 2} = 2$.
        2. The algorithm compares the pairs _(coords[j], coords[j+2])_ for $j = 0, \dots, 6$ with a step of 4.
        3. For $j = 0$: _coords[0]} (0)_ vs. _coords[2] (0)_. They are equal.
        4. For $j = 1$: _coords[1]} (1)_ vs. _coords[3] (1)_. They are equal.
        5. For $j = 4$: _coords[4]} (1)_ vs. _coords[6] (1)_. They are equal.
        6. For $j = 5$: _coords[5]} (2)_ vs. _coords[7] (2)_. They are equal.
        7. **Conclusion:** $g$ **does not depend** on $X_2$.

### 3\. Decision for $X_1$ ($k = 1$)

        1. _stride_ = $2^{ 3 - 1} = 4$.
        2. The algorithm compares the pairs _(coords[j], coords[j+4])_ for $j = 0, \dots, 3$.
        3. For $j = 0$: _coords[0] (0)_ vs. _coords[4] (1)_.
        4. Since $0 \neq 1$, the test fails.
        5. **Conclusion:** $g$ **depends** on $X_1$.

This is obviously the same result as above, but the way in which the comparisons are executed makes this algorithm preferrable.

## What comes next

Next will employ these ideas to understand the algorithmic proposed by Bagad, Dao, Domb and Thaler in their recent article "Speeding-up SUMCHECK proving" where they explore different implementations of the SUMCHECK protocol for polynomials of the shape just described: products of multilinear polynomials. They investigate and exploiting the different multiplication and addition costs involved in the interaction between base field elements and random field elements at each step of the protocol and this obviously involves clever manipulation and understading of multilinear polynomials and their properties.
