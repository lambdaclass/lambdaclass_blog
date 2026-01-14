+++
title = "How to get a true headache: brute forcing NTRU"
date = 2023-04-24
slug = "how-to-get-a-true-headache-brute-forcing-ntru"

[extra]
feature_image = "/images/2025/12/Alma-Tadema_The_Education_of_the_Children_of_Clovis.jpg"
authors = ["LambdaClass"]
+++

## Introduction

Lattice cryptography is a type of cryptographic scheme that relies on the hardness of certain computational problems related to lattices, which are geometric structures formed by repeating a pattern of points in space. Lattice-based cryptography is considered a promising candidate for post-quantum cryptography, as it is believed to be resistant to attacks by quantum computers.

The NTRU (N-th degree Truncated polynomial Ring Units) cryptosystem is a lattice-based public-key cryptosystem that was introduced in 1996. It is based on the properties of a specific type of lattice called an ideal lattice, a particular type constructed from the ideals of a polynomial ring. The NTRU cryptosystem uses polynomials with small coefficients to generate public and private keys, which are then used for encryption and decryption. For more details, see our [previous post](/i-want-to-break-free-from-lattice-based-cryptography-but-not-even-a-quantum-computer-can-help-me/). In this post, we will explain how finding the private key is equivalent to finding short vectors on a lattice and give bounds on brute-force attacks.

## The public and private keys in NTRU

In our [previous post](/i-want-to-break-free-from-lattice-based-cryptography-but-not-even-a-quantum-computer-can-help-me/), we discussed the NTRU encryption scheme. We now head to show how its keys are related to a specific lattice; the encryption and decryption processes are irrelevant for this purpose; hence they can be left aside.

Recall from our previous post the ring $R = \mathbb Z[X]$ and the ring $R_q = \mathbb Z_q[X]$. The private key in NTRU consists of two polynomials $f,g \in R$ whose coefficients are somehow _small_ : they are allowed to be only equal to 0, 1, or -1. These are called _ternary_ polynomials.

The polynomial $f$ must have an inverse $F \in R_q$. For example, let $N = 5, q = 37$ and  
$$  
f = 1 + x - x^2 + x^4.  
$$ Letting $F \in R$ be the polynomial given by  
$$  
F = 29x^4 + 35x^3 + 22x^2 + 12x + 32,  
$$ let's show that $F$ is the inverse of $f$ in $R_q$.

Recall that the product in $R_q$ is explained in our previous post: we multiply as usual, replacing the appearance of $x^N$. Then in our example, we have that  
$$  
\begin{align*}  
fF & = 29x^8 + 35x^7 + 30x^6 + 6x^5 + 8x^3 + 2x^2 + 7x + 32 \newline  
& = (29+8)x^3 + (35+2)x^2 + (30+7) x + (6+32) \newline  
& = 1.  
\end{align*}  
$$ This example shows that the inverse of $f$ can have arbitrarily large coefficients, even though $f$ is small.

The public key is the polynomial $h \in R_q$ given by $h = Fg$. In our example, if we let  
$$  
g = x - x^3 - x^4  
$$ We have that  
$$  
h = 28x^4 + 35x^3 + 22x^2 + 12x + 32.  
$$ We see that though $h$ is constructed from ternary polynomials, it is far from being ternary.

## The convolution ring revisited

By replacing every appereance of $x^N$ with 1, we can write every polynomial $h \in R$ as $h = h_0+\cdots+h_{N-1}x^{N-1}$. Moreover, we will identify the polynomial $h$ with the vector $\mathbf h = (h_0,\dots,h_{N-1})$.

In these terms, the multiplication in $R$ can be stated in matrix form. More precisely, let $M_\mathbf{h} \in \mathbb Z^{N\times N}$ be the matrix given by.  
$$  
M_h = \left(\begin{array}{cccc}h_0 & h_1 & \cdots & h_{N-1} \newline h_{N-1} & h_0 & \cdots & h_{N-2} \newline \vdots & \vdots & \ddots & \vdots \newline h_1 & h_2 & \cdots & h_0\end{array}\right).  
$$  
Then, given a polynomial $f \in R$ and letting $g = fh$, it is not hard to see that we have the equality of vectors  
$$\mathbf{g} = \mathbf{f} \cdot M_{\mathbf h}.$$ Regarding the example above, the reader can verify that modulo 37, we have that

$$  
(0, 1, 0, -1, -1) =  
(1, 1, -1, 0, 1)\cdot \left(\begin{array}{rrrrr}  
32 & 12 & 22 & 35 & 28 \newline  
28 & 32 & 12 & 22 & 35 \newline  
35 & 28 & 32 & 12 & 22 \newline  
22 & 35 & 28 & 32 & 12 \newline  
12 & 22 & 35 & 28 & 32  
\end{array}\right).$$

## The NTRU lattice

The natural attack involves looking for ternary polynomials $f,g \in R$ such that $fh = g \in R_q$. Equivalently, such that there exists $k \in R$ such that  
$$ fh = g + qk \quad \in R.$$

To use the matrix formulation from above, we introduce the block matrix $M_{\mathbf h,q}$ given by  
$$  
M_{\mathbf h,q} = \left(\begin{array}{cc}I_N & M_{\mathbf h} \newline 0 & qI_N \end{array}\right).  
$$ Note that it has a nonzero determinant. This means that its rows form a basis of $\mathbb R ^{2N}$. In particular, they span a (public) lattice, which we will denote by $L_{h,q}$.

Considering block multiplication, we see that the equality above is rewritten as  
$$ (\mathbf f,-\mathbf k) \cdot M_{\mathbf h,q} = (\mathbf f,\mathbf g).$$ From here on, we can leave polynomials aside.

Note that the vector on the left-hand side is obtained by linearly combining the rows from $M_{\mathbf h,q}$ with the coefficients of $(\mathbf f,- \mathbf k)$, which are integers. In other words, this is a vector in the lattice $L_{h,q}$.

The vector on the right-hand side, being $f$ and $g$ ternary, is a small (or _short_) vector. Thus, breaking NTRU is equivalent to finding short vectors in the lattice $L_{h,q}$ given by the public key.

## Finding short vectors, the rough way

### Lattices: recalling the basics

Recall that given a basis $v_1 , \dots , v_n$ of $\mathbb R^n$, the lattice $L$ defined by this basis is  
$$ L = \\{ \sum_{ i = 1 }^n k_i v_i : k_i \in \mathbb Z \\}.$$

It is easy to see that if we apply to the given basis a base change given by a matrix with integral coefficients and determinant 1 or -1 (a _unimodular_ matrix), we obtain a different basis for $L$. Moreover, every other basis for $L$ is obtained in this way.

For example, the lattice in the plane defined by the canonical basis $e_1 = (1,0), e_2 = (0,1)$ can also be defined by the basis  
$$ v = (-7226, 23423),\quad w = (379835, -1231231). $$ In fact,$$-1231231 v - 379835 w = e_1, \quad -23432 v - 7226 w = e_2,$$ which shows that $e_1$ and $e_2$ (and hence every integral combination of them) can be written as an integral combination of $v$ and $w$.

As we see, the same lattice can have more and less complicated bases.

### The volume

The most important invariant of a lattice $L$ is its _volume_ , which is the size of the parallelepiped $\mathcal F$ generated by a basis $\mathcal B$ of $L$.

![](https://i.imgur.com/srRCpaD.png)

It can be computed as $$vol (L) = |\det(C)|$$ where $C$ is the matrix having the vectors in $\mathcal B$ as columns (the reader interested in understanding why this computes the volume should consider the case $n = 2$). This number is independent of the chosen basis (i.e., an _invariant_ of $L$) since changing $\mathcal B$ resorts to multiply $C$ by a unimodular matrix.

The volume is essential for our cryptographic interests since it gives a bound for the size of the shortest vector.

### Short vectors: brute force

Every lattice $L$ contains the zero vector, which is naturally discarded when discussing short vectors. More precisely, a _shortest vector in $L$ is a nonzero vector $v \in L$ such that $\Vert v\Vert$ is minimum. Such a vector exists, though it is not unique: for example, because $\Vert v\Vert = \Vert- v\Vert$.

From a XIX century result due to Hermite, we know that

> The lattice $L$ contains a shortest vector $v$ such that $|v_i| \leq vol(L)^{1/n}$ for every $1 \leq i \leq n$.

This gives us a box $B$ where we can, by brute force, perform a search for shortest vectors.

How expensive would this be? Roughly, $ L \cap B$ should be the number of times $\mathcal F$ fits in $B$. Hence from the result of Hermite, we get that  
$$ L \cap B \sim vol(B) / vol(L) = ( 2 vol(L)^{ 1/n } )^n / vol(L) = 2^n,$$ which shows that brute force is impractical for large $n$, independently of $L$. This continues to hold for the slight improvements available for Hermite's result.

## Summary

In this post, we described how to transform the problem of finding the key in NTRU involving polynomials into a matrix problem. We explained the lattice behind the NTRU public key and how finding the private key can be reduced to finding short vectors in that lattice. We also provided some bounds on how hard it is to find short vectors, in general, using brute force attacks, showing that it is impractical for sufficiently large values of $n$, that is, polynomials of very large degrees. In upcoming posts, we will cover the fundamentals of other lattice schemes, such as CRYSTALS Kyber, and those related to fully homomorphic encryption, as well as more efficient lattice reduction techniques.
