+++
title = "Multiscalar Multiplication: Strategies and Challenges"
date = 2023-01-09
slug = "multiscalar-multiplication-strategies-and-challenges"

[extra]
math = true
feature_image = "/images/2025/12/Belisarius_by_Francois-Andre_Vincent.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["zero knowledge proofs"]
+++

## Introduction

Generating a zk-SNARK (zero-knowledge succinct non-interactive argument of knowledge), as the one Aleo uses, involves a lot of cryptographic calculations, almost all of which happen inside an elliptic curve over a finite field.

## Elliptic Curves

The following is a short version of [this](https://cryptographyinrustforhackers.com/chapter_2.html#elliptic-curves).

An elliptic curve point is a pair of numbers $(x,y)$ in a finite field (you can think of a finite field as $Z_p$, the integers modulo some huge prime number, though sometimes they're more than that), which satisfy an equation of the form:

$$  
y^2 = x^3 + ax + b  
$$

for some $a$ and $b$ in the finite field.

You can sum elliptic curve points, but not in the traditional way. Instead of doing

$$  
(x_1, y_1) + (x_2, y_2) = (x_1 + x_2, y_1 + y_2)  
$$

We do this:

$$  
(x_1, y_1) + (x_2, y_2) = (x_3, -y_3)  
$$

where

$$  
x_3 = s^2 - x_1 - x_2 \  
y_3 = s(x_1 - x_3) - y_1 \  
s = \frac{y_2 - y_1}{x_2 - x_1} x_3  
$$

There are two exceptions to this:

        1. When $(x_1, y_1) = (x_2, y_2)$
        2. When $x_1 = x_2$ but $y_1 \neq y_2$. In this case, as no other solution exists, $y_1 = - y_2$.

In both 1. and 2. the calculation above is not defined (we would be dividing by zero), so what we do instead is:

        1. The sum of a point with itself is, as before, a point $(x_3, y_3)$, only in this case  
$$  
x_3 = s^2 - 2 x_1 \  
y_3 = (x_1 - x_3) - y_1 \  
s = \dfrac{3 x_1^2 + a}{2 y_1}  
$$  
(Here, $a$ is the coefficient defining the curve equation above).
        2. In this case, the result of the sum is a unique point we arbitrarily add to the curve, called the _point at infinity_ and noted $\mathcal{O}$. This point works as the zero for our sum, i.e.,  
$$  
\mathcal{O} + (x, y) = (x, y)  
$$  
for every $(x,y)$.

## Primitive operations

Elliptic curve cryptography ultimately relies on two primitive operations, point addition (adding two different points) and point doubling (adding a point to itself), which we call `ECADD` and `ECDBL`.

We can apply the double-and-add algorithm if we try to add a point many times to itself. As already explained [in one of our posts](/what-every-developer-needs-to-know-about-elliptic-curves/), the idea is simple: if we want to calculate, say, $9P$ for some curve point $P$, instead of performing nine additions we can do

$$  
P + P = 2P \  
2P + 2P = 4P \  
4P + 4P = 8P \  
4P + P = 9P  
$$

which is only four addition operations.

When we have to add many different points $k_1P_1+k_2P_2+...+k_nP_n$, most techniques assume these primitives are given and focus on how to perform the scalar multiplications $k_i P_i$ and the additions, minimizing the amount of `ECADD`s and `ECDBL`s.

## MSM

The _Multi-Scalar Multiplication_ problem consists of, given an elliptic curve, calculating

$$  
\sum_{i=1}^{n} k_i P_i  
$$

for some scalars (a.k.a. integers modulo a certain prime) $k_i$, some elliptic curve points $P_i = (x_i, y_i)$ and some $n$ (in Aleo's challenge it is $2^{26}$).

The sum operation here is the one discussed in the previous section. Similarly, $k_i P_i$ means "$P_i$ summed to itself $k_i$ times," the sum once again being the one defined above.

Around 80% of the time to produce a zk-SNARK proof is spent doing MSM, so optimizing it is crucial for performance.

### Bucketing method

We can break the MSM into smaller sums and reduce the number of operations by repeatedly using the windowing technique. If we want to compute each $k_iP_i$, we can break it into windows of size $c$  
$$  
k_iP_i=k_{i0}P_i+k_{i1}2^{c} P_i+k_{i2}2^{2c} P_i+...+k_{i,m-1}2^{c(m-1)} P_i  
$$  
Using this, we can rewrite the MSM problem as  
$$  
P=\sum_{i} k_iP_i=\sum_{i}\sum_{j} k_{ij}2^{cj}P_i  
$$  
We can now change the order of the summations,  
$$  
P=\sum_{i} k_iP_i=\sum_{j}2^{cj}\left(\sum_{i} k_{ij}P_i\right)=\sum_j 2^{cj} B_j  
$$  
In other words, we first divide the scalars into windows and then combine all the points in each window. Now we can focus on how to calculate each $B_j$ efficiently:  
$$  
B_j=\sum_{i} k_{ij}P_i=\sum_{\lambda=0}{2c-1} \lambda \sum_{u(\lambda)} P_u  
$$  
where the summation over $u(\lambda)$ is done only over points whose coefficient is $\lambda$. For example, if $c=3$ and we have $15$ points,  
$$  
B_1=4P_1+3P_2+5P_3+1P_4+4P_5+6P_7+6P_8+3P_{14}+5P_{15}  
$$  
We can split the summation by the coefficients $\lambda$, taking values from $1$ to $7$. For $\lambda=1$, $\sum_u P_u=P_4$ (because $P_4$ is the only one with coefficient $1$), for $\lambda=4$, $\sum_u P_u=P_1+P_5$, etc. We place all points with a common coefficient $\lambda$ into the $\ lambda$ bucket. Thus,  
$$  
B_j=\sum_\lambda \lambda S_{j\lambda}=S_{j1}+2S_{j2}+3S_{j3}+4S_{4j}+5S_{5j}+6S_{j6}+7S_{j7}  
$$  
We can calculate this with a minimum number of point additions using partial sums.  
$T_{j1}=S_{j7}$  
$T_{j2}=T_{j1}+S_{j6}$  
$T_{j3}=T_{j2}+S_{j5}$  
$T_{j4}=T_{j3}+S_{j4}$  
$T_{j5}=T_{j4}+S_{j3}$  
$T_{j6}=T_{j5}+S_{j2}$  
$T_{j7}=T_{j6}+S_{j1}$  
Each of these operations involves doing just one elliptic point addition. We can obtain the final result by summing these partial sums:  
$$  
B_j=\sum T_{jk}  
$$

We can improve the calculations by changing the expansion of the coefficients $k_i$. In binary representation, the Hamming weight is the number of non-zero bits. Ideally, we would like this weight to be as small as possible to reduce the number of additions (For example, 65537, which is $2^{16}+1$, is used as the public key for the RSA cryptosystem in many implementations. The square and multiply algorithm requires only two multiplications). The average Hamming weight in a binary representation is $1/2$; if we introduce a signed binary representation ($-1,0,1$), the average weight is reduced to $1/3$, with the consequent decrease in the number of operations (on average).

## BLS 12-377

The curve which Aleo uses is called BLS 12-377. The base field (finite field) has order $q$ (a 377-bit prime) and has an embedding degree of 12. Both the order of the elliptic curve group $G_1$, $r$, and finite field are highly 2-adic (that is, both $q$ and $r$ can be written as $2^\alpha r+1$, where $r$ is an odd number and $\alpha$ is greater than $40$). The orders $q$ and $r$ are related by the embedding degree: $r \mid q^{12}-1$. The equation for the elliptic curve is  
$$  
y2=x3+1  
$$

Additionally, we can build a second group $G_2$ over a quadratic field extension of $\mathbb{F}_q$; the equation of the curve is  
$$  
y2=x3+B  
$$  
where $B$ is a parameter. For more information on the curve's parameters, see [here](https://docs.rs/ark-bls12-377/latest/ark_bls12_377/).

BLS 12-377 is birrationally equivalent to [Montgomery and twisted Edwards's curves](https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-hash-to-curve-05#appendix-B). This allows us to perform point addition and scalar multiplication faster by avoiding costly field inversions. In the case of Montgomery curves, it is possible to perform scalar multiplication in constant time, making the operation resistant to timing attacks.

Implementations of the BLS 12-377 curve and the (birrationally equivalent) twisted Edwards curve are given in this [repository](https://github.com/arkworks-rs/curves).

BLS 12-377 is one of the pairing-friendly elliptic curves; these have applications such as short digital signatures that are efficiently aggregatable, polynomial commitment schemes, and single-round multi-key exchanges.  
The reason why we have two equations for the BLS curve and two groups is related to pairings. A pairing is a bilinear map: it takes two points, each from a group of prime order $r$. For technical reasons, these groups need to be different. As the original curve has only one group of order $r$, we need to extend the field to find other groups of order $r$. The embedding degree gives how much we have to extend the field to find those other groups. As a bonus, the extended field contains all the $r$-th roots of unity.

### A note on Field Extensions

The embedding degree is also the degree of the field extension we need to use. Familiar examples of field extensions are the real numbers, $\mathbb{R}$, (extending the field of rational numbers $\mathbb{Q}$, which is a transcendental extension) and the complex numbers, \\( \mathbb{C} \\) (extending \\( \mathbb{R} \\)). The latter cannot be further extended since there are no irreducible polynomials in \\( \mathbb{C} \\) (we say that the complex numbers are algebraically closed).

If we want to build a quadratic extension of \\( \mathbb{F_{q}} \\), \\( \mathbb{F_{q^2}}\\) we can think of it as a polynomial \\( a_0+a_1x \\), where \\( a_0\\) and \\( a_1 \\) are elements in \\( \mathbb{F_q} \\). The addition is straightforward since we add the independent and linear terms separately. For multiplication, given elements $a$ and $b$  
\\[ a\times b = a_0b_0 +(a_0b_1+a_1b_0)x+a_1b_1 x^2\\]

To avoid the problem of going outside linear polynomials, we can reduce the degree by using an irreducible polynomial, such as \\( x^2+1 \\) and setting \\( x^2+1=0 \\). If we replace the above equation,  
\\[ a\times b = a_0b_0 - a_1b_1 +(a_0b_1+a_1b_0)x\\]  
which resembles multiplication in complex numbers.

The conditions for choosing the polynomial are:

        1. It must have the same degree as the extension field (quadratic in our case).
        2. It must be irreducible in the field we are extending, meaning that we cannot factor it into smaller degree polynomials.

Arithmetic in \\( \mathbb{F_{q^{12}}} \\) is complicated and expensive. Luckily, we can perform a sextic twist so that the group \\( G_2 \\) is defined over \\( \mathbb{F_{q^{2}}} \\).

In practice, when we want to build a field extension such as \\( \mathbb{F_{q^{12}}} \\), we can proceed by extending smaller fields in a sequential form: a tower of extensions (such as \\( \mathbb{Q}\rightarrow \mathbb{R}\rightarrow \mathbb{C} \\)).

## Faster with FFT

The potential use for FFTs comes when implementing the primitives `ECADD` and `ECDBL`. We can do these operations in different coordinate systems. As stated [here](/need-for-speed-elliptic-curves-chapter/), projective coordinates are typically much faster because they avoid doing a finite field inversion, which is much more expensive than multiplications and additions.

When using projective coordinates, the calculations are faster because we trade divisions for multiplications. This means there are a lot of multiplications to be done, which is why we need efficient methods to multiply integers, where Karatsuba's, Toom's, or FFT algorithms might become appealing since we are dealing with [multiplication of large integers](/weird-ways-to-multiply-really-fast-with-karatsuba-toom-cook-and-fourier/). The optimal algorithm will depend on the size of the integers.
