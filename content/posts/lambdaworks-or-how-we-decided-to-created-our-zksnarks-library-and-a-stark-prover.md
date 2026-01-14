+++
title = "LambdaWorks or how we decided to create our zkSNARKs library and a STARK prover"
date = 2023-03-01
slug = "lambdaworks-or-how-we-decided-to-created-our-zksnarks-library-and-a-stark-prover"

[extra]
feature_image = "/content/images/2025/12/Peter_Paul_Rubens_110.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["zkp", "zero knowledge proofs"]
+++

## Introduction

We think that most ZK libraries are not yet easy-to-use. Most of them assume that the user had a significant cryptography background, making it hard for a newcomer to learn from them, even if he had all the code in front of him. We also found that some commonly used libraries had poor documentation or hard-to-follow examples for beginners. In addition to this some libraries don't follow state of the art engineering practices that are crucial to build reliable systems that go to production. There are many efforts like Cairo, Noir that don't have these issues but they are full blown programming languages. We wanted a tool to build languages like those, new proving systems or anything that we need.

So, we decided to start building our [LambdaWorks](https://github.com/lambdaclass/lambdaworks) library with the following goals in mind:

        1. Implemented in Rust with WASM support and an FFI API in other mainstream languages
        2. Easy to use API
        3. Contains most famous proving systems (Groth16, Plonk, STARKs, Plonky2 and maybe Halo2) and recursion/IVC (Nova, Supernova)
        4. Allow for hardware acceleration, such as GPU and FPGA integration
        5. Clear documentation with different kinds of tutorials, from starters to advanced users

Given their importance and applications, we decided to begin our library by implementing the STARKs' prover. We had to implement finite field arithmetic and basic cryptographic stuff, such as Merkle trees and hash functions. We will continue with elliptic curves and SNARKs.

## STARKs

[STARKs](https://eprint.iacr.org/2018/046.pdf) (scalable, transparent arguments of knowledge) are cryptographic primitives, which are a convenient means to an end. The goal we are after is computational integrity, that is, showing that a computation was performed correctly (according to a set of instructions). For example, we want to prove that we computed the first 5000 values of a sequence correctly, or we ran a given machine learning algorithm, or we processed 4000 transactions in a blockchain. STARKs provide us with short proof of the integrity of the computation. The advantage STARKs gives us is that checking the proof is much faster than performing the naïve verification (re-executing the program by the verifier).

There are many interesting resources to learn the basics of STARKs, such as [Starkware's STARK 101](https://starkware.co/stark-101/), [Anatomy of a STARK](https://aszepieniec.github.io/stark-anatomy/overview), [Ministark](https://github.com/andrewmilson/ministark), as well as Starkware's blog on arithmetization ([parts I](https://medium.com/starkware/arithmetization-i-15c046390862) and [II](https://medium.com/starkware/arithmetization-ii-403c3b3f4355)).

The STARK protocol contains the following steps:

        * Arithmetization
        * Transformation to polynomial equations.
        * FRI, which has two steps: commitment and decommitment.

## Arithmetization

An execution trace is a table containing $w$ columns (the registers) and $T$ rows representing each state of the system. A trace looks like this:

Register 1 | Register 2 | $\dots$ | Register w  
---|---|---|---  
$x_{1,0}$ | $x_{2,0}$ | $\dots$ | $x_{w,0}$  
$x_{1,1}$ | $x_{2,1}$ | $\dots$ | $x_{w,1}$  
$\vdots$ | $\vdots$ | $\ddots$ | $\vdots$  
$x_{1,T}$ | $x_{2,T}$ | $\dots$ | $x_{w,T}$  
  
We will interpret each column (register) as the evaluation of a polynomial over a domain (we will call it the trace evaluation domain). For example, we can say that $f_1(x)$ is the polynomial representing column 1 and thus:  
$f_1(0)=x_{1,0}$  
$f_1(1)=x_{1,1}$  
$\vdots$  
$f_1(T)=x_{1,T}$

To make things easier and faster, we will use as trace evaluation domain a multiplicative subgroup, $\mathbb{Z_p}^\star$ of size $2^n$, such that $2^n \geq T$. That group has a generator, $\omega$, which spans all elements in the subgroup. The subgroup can be represented by the powers of $\omega$, $\\{ 1, \omega , \omega^2 , \omega^3 ,..., \omega^N \\}$. Our trace polynomial satisfies then  
$f_1(1)=x_{1,0}$  
$f_1(\omega)=x_{1,1}$  
$\vdots$  
$f_1(\omega^{T-1})=x_{1,T}$

The elements in the execution trace satisfy certain relations given by the computation and boundary conditions. We call these relations constraints. They can be broadly classified into two groups:

        * Boundary constraints.
        * Transition constraints.

Boundary constraints are rather straightforward: they specify the value of a register at a given time. For example, when we initialize the computations, each register has a given value. In the case of the Fibonacci sequence,  
$a_0=a_1=1$  
If our trace consists of a single column representing the sequence, the first two elements are equal to one:  
$x_{1,0}=1$  
$x_{1,1}=1$

We can translate the constraints into polynomial relations. We know that $x_{1,0}=f_1(1)$ and $x_{1,1}=f_1(\omega)$. If the constraint holds, say at $x=\omega$, then the monomial $x-\omega$ divides $f_1(x)-1$. This means that the result of the division of $f(x)-1$ by $x-\omega$ is a polynomial,  
$$ Q_{BC,1}(x)=\frac{f_1(x)-1}{x-\omega} $$  
Analogously,  
$$ Q_{BC,0}(x)=\frac{f_1(x)-1}{x-1} $$

One drawback in this approach is that if we have $n$ boundary constraints, we get $n$ polynomials. One optimization is to interpolate boundary constraints and obtain a new polynomial. In this case,  
$f_{BC}(1)=1$  
$f_{BC}(\omega)=1$  
Combining everything, we get  
$$ Q_{BC}(x)=\frac{f(x)-f_{BC}(x)}{Z_{BC}(x)}$$  
where $Z_{BC}(x)$ is the polynomial vanishing on the points where the boundary conditions are enforced:  
$Z_{BC}(x)=(x-1)(x-\omega)$

Transition constraints are relations between different rows that can be applied at various calculation points. In the case of the Fibonacci sequence, we have $a_{n+2}=a_{n+1}+a_n$ for every $n={0,1,...T-2 }$. In terms of the trace polynomial,  
$f_1(\omega^2 x)-f_1(\omega x)-f_1(x)=0$  
If the constraint is satisfied, the following function should be a polynomial,  
$$Q_T(x)=\frac{f_1(\omega^2 x)-f_1(\omega x)-f_1(x)}{Z_T(x)} $$  
where $Z_T(x)$ is the vanishing polynomial where the transition constraints are enforced,  
$Z_T(x)=\prod_{k=0}^{T-2} (x-\omega^k)$

Transition constraints are commonly expressed as multivariate polynomials linking two consecutive rows of the execution trace. For example, if we denote by $x$ a given row and $y$ is the next, a constraint could be something like  
$P(x,y)=y-x^2=0$  
If we compose the constraint polynomial with the trace polynomial, we have $x=t(x)$, $y=t(\omega x)$, so  
$t(\omega x) - t(x)^2=0$

If we did the calculations properly, then $Q_{BC}(x)$ and $Q_T(x)$ should be polynomials; if not, they are rational functions (quotients of two polynomials). We can reduce proving that each of them is a polynomial by taking a random linear combination  
$$ CP(x)=\alpha_{BC} Q_{BC}(x)+\alpha_{T} Q_T(x) $$  
If $Q_{BC}(x)$ and $Q_T(x)$ are both polynomials, so is $CP(x)$. But if at least one of them is a rational function, then $CP(x)$ is unlikely to be a polynomial.

Given that proving that $CP(x)$ is a polynomial is difficult, we will show that it is close to a low-degree polynomial. To do so, we will project $CP(x)$ to a new function with a smaller degree. We will continue taking projections until we reach a constant polynomial. The critical ingredient is that the projection operation respects the distance. If the original function is far from a low-degree polynomial, then the projections will also be far from it. Before jumping to the procedure (called FRI), we must commit to the trace polynomials.

## Committing to the trace

We need to evaluate the trace polynomials over a much larger domain; the domain size is $\beta 2^n$, where $\beta$ is the blowup factor. To avoid problems, we shift the domain by multiplying the elements by $h$, which belongs to the coset. The low-degree extension domain (simply domain) is given by  
$$D = \\{ h, h \eta , h \eta^2 , ... , h \eta^{ 2^n -1} \\} $$  
Here $\eta$ is the generator of the subgroup of order $\beta 2^n$ so that it does not get confused with $\omega$ (though we could relate them by taking $\omega=\eta^\beta$).  
We evaluate the trace polynomials over this large domain and obtain vectors representing each evaluation:  
$$[ f_1 (h) , f_1 (h \eta) ,... , f_1 (h \eta^{ 2^n -1} )]$$  
$$[f_2 (h) , f_2 (h \eta) , ... , f_2 (h \eta^{ 2^n -1} )]$$  
$$[f_w (h) , f_w (h \eta ) , ... , f_w ( h \eta^{ 2^n -1} )]$$

To commit to these evaluations, we build Merkle trees, and the prover sends the root of the Merkle trees to the verifier. To make things easier, the elements of each row of the low-degree extension of the trace are grouped into a single leaf.

## Committing to the composition polynomial

We use the same domain $$D = \\{ h, h \eta , h \eta^2 , ... , h \eta^{ 2^n -1} \\} $$ to evaluate the composition polynomial. We can then create a Merkle tree from these evaluations and send the root to the verifier.

## Relating the LDE of execution trace and the composition polynomial

At some point, the verifier will ask the prover for the value of the composition polynomial at one point, $z$, that is, $CP(z)$. The verifier needs to be sure that the composition polynomial results from applying the polynomial constraints onto the trace polynomials. Given the value $z \in D$ (in DEEP, the value of $z$ is sampled outside the domain), the prover needs to send the values of the trace polynomials at given points so that the verifier can check the calculation. For example, in the case of Fibonacci (we will ignore all other constraints just for simplicity),  
$P(u,v,w)=w-v-u=0$  
$P(t(x),t(\omega x),t(\omega^2 x))=t(\omega^2x)-t(\omega x)-t(x)=0$  
To create the composition polynomial, we must divide the previous polynomial by the corresponding vanishing polynomial. So, if we pick $x=z$, we have

$$Q(z)=\frac{t(\omega^2z)-t(\omega z)-t(z)}{Z_D(z)}$$

The prover needs to send those three values. Note that $z=h \eta^k$, so the prover needs to send the values of $t(\omega^2 h \eta^k)$, $t(\omega h \eta^k)$, $t( h \eta^k)$, which are separated by $\beta$ elements in the Merkle tree. The verifier takes the three values, evaluates the vanishing polynomials, and checks that  
$Q(z)=CP(z)$

This way, the verifier is convinced that the composition polynomial is related to the execution trace via the constraint polynomials.

## FRI protocol

The prover must show that $CP(x)$ is close to a low-degree polynomial. To do so, he will randomly fold the polynomial, reducing the degree, until he gets a constant polynomial (in optimizations, obtaining a constant polynomial is unnecessary, as the prover could send all the coefficients of a polynomial and have the verifier check it). The FRI protocol has two steps: commit and decommit.

### Commitment

The prover takes $CP(x)$ and splits it in the following way:  
$$g(x^2)=\frac{CP(x)+CP(-x)}{2}$$  
$$x h(x^2)=\frac{CP(x)-CP(-x)}{2}$$  
so that  
$$CP(x)=g(x^2)+x h(x^2)$$  
The verifier chooses a random value $\alpha_0$, and the prover forms the polynomial,  
$P_1(x)=g(x^2)+\alpha_0 h(x^2)$  
with the new domain $D_1 = \\{ h^2 , h^2 \eta^2 , ... , h^2 \eta^m \\}$ having half the size of $D$.

The prover can perform the low-degree extension by evaluating $P_1(x)$ over $D_1$ and then commit to it by creating a Merkle tree and sending the root. He can continue with the procedure by halving the degree at each step. For step $k$, we have  
$$P_k(y^2)=\frac{P_{k-1}(y)+P_{k-1}(-y)}{2}+\alpha_{k-1}\left(\frac{P_{k-1}(y)-P_{k-1}(-y)}{2}\right)$$  
and  
$$D_k = \\{ h^{ 2^{k-1} } , (h \eta)^{ 2^{k-1} } , ... ,( \eta^l h)^{ 2^{k-1} } \\}$$  
The prover evaluates $P_k(x)$ over $D_k$ and commits to it, sending the Merkle root.

### Decommitment

The verifier chooses at random a point $q$ belonging to $D$. The prover needs to convince him that the trace polynomials and composition polynomial are related (we covered that previously) and that the elements of consecutive FRI layers are also related. For each layer, the prover needs to send two elements to the verifier, $P_k(z)$ and $P_k(-z)$. He also needs to show that these elements belong to the corresponding Merkle tree, so the authentication paths for each element are also required.

The verifier can check the correctness of the FRI layers by performing a colinearity check. Given $P_k(z)$, $P_k(-z)$ and $P_{k+1}(z^2)$, the verifier can compute  
$$g_{k+1}(z^2)=\frac{P_k(z)+P_k(-z)}{2}$$  
$$h_{k+1}(z^2)=\frac{P_k(z)-P_k(-z)}{2z}$$  
and get the value for the next layer  
$$u_{k+1}=g_{k+1}(z^2)+\alpha_k h_{k+1}(z^2)$$  
If the prover performed the calculations correctly, then  
$$u_{k+1}=P_{k+1}(z^2)$$

## A toy example for FRI

We will use a simple example to understand how everything works on FRI. We choose $p=17$, whose multiplicative group has order $16=2^4$ and set $\eta=3$, which is a primitive root of unity (that is, $3^{16}=1$ and $3^k \neq 1$ for $0 <k<16$). Our composition polynomial is $P_0 (x) = x^3 + x^2 + 1$. The domain for the LDE is simply $ D_0 = \mathbb{Z_{17}}^\star = \\{1 , 2 , 3 , 4 , 5 , 6 , ... , 16 \\}$. The following table contains the LDE of $P_0(x)$:

Index | $x$ | $P_0(x)$ | Index | $x$ | $P_0(x)$  
---|---|---|---|---|---  
0 | 1 | 3 | 8 | 16 | 1  
1 | 3 | 3 | 9 | 14 | 0  
2 | 9 | 12 | 10 | 8 | 16  
3 | 10 | 13 | 11 | 7 | 2  
4 | 13 | 4 | 12 | 4 | 13  
5 | 5 | 15 | 13 | 12 | 3  
6 | 15 | 14 | 14 | 2 | 13  
7 | 11 | 8 | 15 | 6 | 15  
  
Suppose the verifier samples $\beta_0=3$. The prover performs the random folding over $P_0(x)$,  
$g_1( x^2 ) = 1 + x^2$  
$xh_1 ( x^2 ) = x^3 $  
so  
$P_1 ( x^2 ) = 1 + ( 1 + \beta_0) x^2$  
To make things simpler,  
$P_1(y)=1+4y$  
with $y = x^2$. The new domain is obtained by squaring the elements of $D_0$. The LDE of $P_1(y)$ is

Index | $y$ | $P_1(y)$ | Index | $y$ | $P_1(y)$  
---|---|---|---|---|---  
0 | 1 | 5 | 4 | 16 | 14  
1 | 9 | 3 | 5 | 8 | 16  
2 | 13 | 2 | 6 | 4 | 0  
3 | 15 | 10 | 7 | 2 | 9  
  
The verifier samples $\beta_1=2$ and the prover folds $P_1(y)$ to get $P_2(z)$,  
$P_2(z)=1+4\beta_1=9$  
which is a constant polynomial. The domain $D_2 = \\{ 1 , 13 , 16 , 4 \\}$. All the elements in the LDE evaluate to 9, so there is no need for a table.

The evaluations of the polynomials $P_0(x)$, $P_1(x)$, and $P_2(x)$ are each committed using a Merkle tree and sent to the verifier.

Suppose the verifier selects index 4 in the LDE to check the correctness of the FRI layers. The prover needs to send him the following:

        * $P_0(13)=4$ and $P_0(-13)=P_0(4)=13$ and their authentication paths.
        * $P_1(16)=14$ and $P_1(-16)=P_1(1)=5$ and their authentication paths.
        * $P_2(4)=9$.

We can see that, for the first layer, the prover passes the values at positions 4 and 12, then 4 and 1 (which is $index+|D_1|/2$, where $|D_1|$ is the number of elements in $D_1$, but since 8 exceeds the maximum value, we wrap around).

The verifier does the following calculation,  
$$u=\frac{P_0(13)+P_0(4)}{2}+\beta_0\left(\frac{P_0(13)-P_0(4)}{2\times 13}\right)$$

Recall that division by $t$ is simply multiplication by $t^{-1}$. In the case of $2$, we have $2^{-1}=9$, since $2\times 9=18\equiv 1 \pmod{17}$. Thus,  
$$u=2^{-1}\left(4+13\right)+3\times 9^{-1}\left(4-13\right)$$  
The first term is $0$, while the second is $48\equiv 14 \pmod{17}$, so  
$u=14$.  
Next, he checks  
$u=P_1(16)$  
Both are $14$, so the first layer is correct.

The verifier moves on to the next layer. He needs to calculate  
$$u=\frac{P_1(16)+P_1(1)}{2}+\beta_1\left(\frac{P_1(16)-P_1(1)}{2\times 16}\right)$$

If we work the calculations,  
$$u=\frac{2}{2}+2\left(\frac{9}{2 \times 16}\right)$$  
But this is just  
$$u=1+(-9)=1+8=9$$  
Now,  
$$P_2(4)=9=u$$  
so all the layers have been checked. You should try selecting an index and showing that all the calculations match.

## Summary

STARKs are powerful cryptographic primitives allowing a party to prove the integrity of a computation. To generate the proof, we obtain the execution trace of the program and interpret each column of the trace as the evaluations of a polynomial over a "nice" domain. The rows of the execution trace are related by low-degree polynomials, which determine the constraints. When we compose the constraint polynomials with the trace polynomials, we enforce the constraints over the execution trace. We can then divide them by the vanishing polynomial over their validity domain (the places where each constraint is enforced); if the constraints hold, the division is exact and yields a polynomial. Instead of proving that the result is a polynomial, STARKs show that the result is close to a low-degree polynomial. FRI randomly folds the function, halving the degree at each step; the critical point is that this folding preserves distance from low-degree polynomials. The protocol contains two phases: commit, in which the prover binds himself to evaluations of the polynomials over their corresponding domain, and decommit, where he generates the proof that allows the verifier to check the calculations. In an upcoming post, we will cover some optimizations and examples.
