+++
title = "Diving DEEP FRI in the STARK world: learning your daily moon math with a concrete example"
date = 2023-03-06
slug = "diving-deep-fri"

[extra]
feature_image = "/content/images/2025/12/Peter_Paul_Rubens_-_The_Fall_of_Phaeton_-National_Gallery_of_Art-.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["zero knowledge proofs", "lambdaworks"]
+++

## Introduction

At LambdaClass, we are building [Lambdaworks](https://github.com/lambdaclass/lambdaworks), a library for developing zero-knowledge stuff. One important proof system is [STARKs](https://eprint.iacr.org/2018/046.pdf) (Scalable, transparent arguments of knowledge). STARKs are a powerful tool that allows us to prove the integrity of a given computation. For an overview of STARKs, you can look at our [previous post](/lambdaworks-or-how-we-decided-to-created-our-zksnarks-library-and-a-stark-prover/t) or the excellent tutorials by Starkware, such as [STARK-101](https://starkware.co/stark-101/) (for the rust version, you can follow [this link](https://github.com/lambdaclass/STARK101-rs/)) and the posts on [arithmetization I](https://medium.com/starkware/arithmetization-i-15c046390862) and [II](https://medium.com/starkware/arithmetization-ii-403c3b3f4355), and [Anatomy of a STARK](https://aszepieniec.github.io/stark-anatomy/overview).

In this post, we will do a pen-and-paper example of STARKs, so we can follow all the steps needed to generate and validate a proof (we will skip the hashing part, though). One important aspect to point out is that, in this case, we are not interested in the security properties of what we do (but it should really matter in real life). Let's jump into the problem...

## Problem statement

Suppose we want to compute a sequence given by the following relations:  
$a_0=3$  
$a_{n+1}={a_n}^2$  
The sequence gives the square of the previous number, starting with the value 3. We will use as modulus the prime 17 (a Fermat prime, $2^4+1$), and we will understand all operations done modulo 17. The advantage of 17 is that it contains a multiplicative group of 16 elements, which is helpful for STARKs (in general, we want $p-1$ to be $2^m\times q$, where $m$ should be sufficiently large and $q$ is an odd prime). The first four elements of the sequence are:  
$a_0 = 3$  
$a_1 = {a_0}^2 = 9$  
$a_2 = {a_1}^2 = 9^2 = 81 \equiv 13 \pmod{17}$  
$a_3 = {a_2}^2 = 13^2 = 169 \equiv 16 \pmod{17}$  
The first step is to interpret these values as evaluations of a polynomial over a suitable domain. We are working with $p=17$, whose multiplicative group has 16 elements: $\\{ 1 , 2 , 3 , 4 , \dots , 15 , 16 \\}$. We will choose the following subgroup $D_t = {1 , 13 , 16, 4 }$, which is none other than the group formed by all powers of $13$ modulo $17$:  
$13^0 = 1$  
$13^1 = 13$  
$13^2 = 169 \equiv 16 \pmod{17}$  
$13^3 \equiv 4 \pmod{17}$  
$13^4 \equiv 1 \pmod{17}$  
From now on, we will drop the $\pmod{17}$ as understood from the context. We see that the powers of $13$ repeat every 4, which is the order of the element in the multiplicative group. Using this and calling the polynomial interpolating the trace as $t(x)$, we have:  
$t(1) = 3$  
$t(13) = 9$  
$t(16) = 13$  
$t(4) = 16$

## Interpolation

We can use Lagrange interpolation to find the polynomial (for larger problems, it is best to use the Fast-Fourier Transform):  
$t(x) = L_1(x)t(1) + L_2(x)t(13) + L_3(x)t(16) + L_4(x)t(4)$  
The Lagrange polynomial $L_1(x)$ is given by  
$$L_1(x) = \frac{(x-13)(x-16)(x-4)}{(1-13)(1-16)(1-4)}$$  
Doing the operations, we get  
$L_1 (x)t(1) = 5(x^3 + x^2 + x + 1)$  
Th other polynomials are  
$L_2 (x)t(13) = 8x^3 + 2x^2 + 9x + 15$  
$L_3 (x)t(16) = x^3 + 16x^2 + x + 16$  
$L_4 (x)t(4) = 16x^3 + 13x^2 + x + 4$  
The trace interpolating polynomial is thus  
$t(x) = 13x^3 + 2x^2 + 16x + 6$  
If we evaluate the polynomial at $D_t$, you can check that we get the same values as in the trace execution table.

## Committing to the trace polynomial

We have to commit to the trace interpolating polynomial. To do so, we perform a low-degree extension by choosing a larger domain, different from the original domain. If we choose $h = 9$ and its powers, we get a cyclic subgroup with $8$ elements, $\\{ h^0 , h^1 , h^2 , \dots , h^7 \\}$. This group contains elements from $D_t$, so we shift it to another domain by introducing an element from the coset, $w$, and forming the following domain,  
$$ D_0 = \\{ wh^0 , wh^1 , wh^2, \dots , wh^7 \\}$$  
We can choose $w = 3$, and so the domain becomes  
$$ D_0 = \\{ 3, 10, 5, 11, 14 , 7 , 12 , 6 \\}$$  
To commit, we evaluate $t(x)$ over all values in $D_0$ and form a Merkle tree whose leaves are those values.

$x$ | $t(x)$  
---|---  
3 | 15  
10 | 4  
5 | 10  
11 | 13  
14 | 16  
7 | 0  
12 | 0  
6 | 7  
  
## Enter the constraints

We now need to focus on the constraints over the trace elements the calculation gives. In this problem, we have two constraints:

        1. Boundary condition. This applies to the first row, where $t(1)=3$.
        2. Transition constraint. These are given by the multivariate polynomial $P(x,y) = y - x^2$, where if $x = a_n$, then $y = a_{n+1}$.  
What we need to do at this point is compose the trace polynomial with these constraints to enforce them over the whole trace.

### Boundary constraint

The first constraint is  
$p_1 (x) = t(x)-3$  
To ensure that it is enforced on the first step, the polynomial $p_1 (x)$ must be divisible by $x-1$ (a property of polynomials says that $p(a)=b$ if and only if $r(x) = p(x)-b$ is divisible by $x-a$).  
We have  
$p_1 (x) = 13x^3 + 2x^2 + 16x + 3$  
If we factorize this polynomial, we get  
$p_1 (x) = 13(x-1)(x^2 + 9x + 5)$  
which has the factor $(x-1)$. If we divide, we get  
$C_1 (x) = 13 (x^2 + 9x + 5)$  
You can check that if we want $t (x) - a$ to be divisible by $x-1$, the necessarily $a=3$.

### Transition verification constraint

To evaluate the second constraint, we need to be able to choose an element of the trace and the next. We can do it by noting that the elements of $D_t$ are generated by $g = 13$, so if we select $x=x_0$, then $y=g x_0$ is the next. So, $y=t(gx)=t(13x)$ and  
$t(gx) = x^3 + 15x^2 + 4x + 6$  
We now replace these polynomials into the transition verification polynomial, $P(x,y)$, to get $p_2(x)$  
$p_2 (x) = P(t(x) , t(gx)) = x^6 + 16 x^5 + 5x^4 + 2x^3 + 7x^2 + 16x + 4$  
You can check that if we choose $x \in {1, 13, 16 }$ the polynomial evaluates to $0$. This is expected, since the elements $a_n$ and $a_{n+1}$ are linked by the formula $a_{n+1}= {a_n}^2$. This is no longer the case for $4$ since there is no next element. As before, if the constraints are valid, then $p_2 (x)$ should be divisible by $Z_2 (x)$, which is the vanishing polynomial over the domain where the constraints are enforced. In our case,  
$Z_2 (x) = (x-1)(x-13)(x-16)$  
We can also write it as  
$$Z_2 = \frac{x^4 - 1}{x-4}$$  
where we just remove the elements in which the constraints are not enforced. We verified that $p_2 (x)=0$ for $x \in {1, 13, 16 }$, so $p_2 (x)$ has factors $(x-1)(x-13)(x-16)$. Its complete factorization is  
$p_2 (x) = (x-1)(x-13)(x-16)(x^3 + 12 x^2 + 9x + 16)$  
Thus,  
$$C_2 (x) = \frac{p_2 (x)}{Z_2 (x)} = x^3 + 12 x^2 + 9x + 16$$

## The (constraint) composition polynomial

We are now in a condition to build the composition polynomial  
$$H(x) = C_1 (x) (\alpha_1 x^{ D - D_1 } + \beta_1 ) + C_2 (x) (\alpha_2 x^{ D - D_2 } + \beta_2 )$$  
where the $\alpha_k$ and $\beta_k$ are values provided by the verifier. The terms $D - D_k$ are added so that all the polynomials in the linear combination have the same degree. We want the total degree to be a power of $2$, so $D=4$.

Suppose the verifier samples as random coefficients the following: $\alpha_1 = 1$, $\beta_1 = 3$, $\alpha_2 = 2$, $\beta_2 = 4$. Then,  
$C_1 (x) (1 x^{ 4 - 2 } + 3 ) = 13x^4 + 15 x^3 + 2 x^2 + 11x + 8$  
$C_2 (x) (2 x^{ 4 - 3 } + 4 ) = 2x^4 + 11 x^3 + 15 x^2 + 13$  
Then,  
$H (x) = 15 x^4 + 9 x^3 + 11 x + 4$  
Splitting the polynomial into odd and even terms,  
$H_1 (x^2) = 15 x^4 + 4$  
$H_2 (x^2) = 9x^2 + 11$  
so that  
$H(x) = H_1 ( x^2 ) + x H_2 (x^2)$  
We can commit to the polynomial $H(x)$ or its parts, $H_1(x)$ and $H_2(x)$ by evaluating over $D_0$ and forming a Merkle tree.

$x$ | $H_1(x)$ | $H_2(x)$  
---|---|---  
3 | 12 | 7  
10 | 13 | 10  
5 | 12 | 15  
11 | 13 | 12  
  
## Sampling outside the original domain

The verifier now chooses a random point, $z$, outside the trace interpolation and evaluation domains. In our example, the points outside those are $\\{ 2, 8, 9 , 15 \\}$. Suppose the verifier selected $z = 8$. Then,  
$H ( 8 ) = 10$  
with each part being  
$H_1 (8^2) = 6$  
$H_2 (8^2) = 9$  
We need to check that the composition polynomial and trace elements are related. To be able to evaluate the constraints numerically, we need both $t(z)$ and $t(gz)$ (remember, $g$ is the generator of the trace interpolating domain) since we have to calculate $P(x,y)$. The necessary values are:  
$t(8) = 16$  
$t(13 \times 8) = t(2) = 14$

## Why does the verifier need this?

The verifier can now check that the trace and composition polynomial are related:

        1. $p_1 (8) = t(8) - 3 = 13$
        2. $Z_1 (8) = 8 - 1 = 7$
        3. $C_1 (8) = p_1 (8) / Z_1 (8) = 13 \times 7^{-1} = 14$
        4. $C_1 (8) (1\times 8^2 +3) = 3$
        5. $p_2 (8) = t(2) - t(8)^2 = 13$
        6. $Z_2 (8) = 8$
        7. $C_2 (8) = p_2 (8)/ Z_2 (8) = 13 \times 8^{-1} = 8$
        8. $C_2 (8) (2\times 8 +4) = 7$
        9. $H (8) = C_1 (8) + C_2 (8) = 3 + 7 = 10$

We see that the evaluation of $H_1 (z^2)$ and $H_2 (z^2)$ matches the calculation of $H(z)$ from the trace elements.

## Ensuring the prover does not cheat

How does the verifier check that the values we passed are indeed the trace and composition polynomial evaluations at $z$ and $gz$? We can use the same trick: if the polynomial $y(x)$ evaluates to $b$ in $x=a$, then $y(x) - b$ is divisible by $x - a$. We form the DEEP composition polynomial,  
$$ P_0 (x) = \gamma_1\frac{t(x)-t(z)}{x-z} + \gamma_2 \frac{t(x)- t(gz)}{x-gz}+\gamma_3 \frac{H_1 (x^2) - H_1 (z^2) }{x-z^2 } + \gamma_4 \frac{H_2 (x^2) - H_2 (z^2) }{x - z^2}$$  
Let's calculate each term  
$$\frac{t(x)-t(8)}{x-8} = 13(x+13)(x+3) = 13 (x^2 + 16 x + 5)$$  
$$\frac{t(x)-t(2)}{x-2} = 13(x+8)(x+2) = 13 (x^2 + 10 x + 16)$$  
$$\frac{H_1 (x^2) - H_1 (8^2) }{x-8^2 } = 15(x+15)(x+8)(x+2) $$  
$$\frac{H_2 (x^2) - H_1 (8^2) }{x-8^2 } = 9(x+8) $$

Each term is a polynomial, so the linear combination is also a polynomial. By applying the FRI protocol, we must prove to the verifier that this is close to a low-degree polynomial. The polynomial is (using $\gamma_i = 1$),  
$P_0 ( x ) = 15 x^3 + 15 x + 1$  
We can commit to this polynomial using $D_0$ and forming a Merkle tree,

$x$ | $P_0(x)$  
---|---  
3 | 9  
10 | 4  
5 | 13  
11 | 3  
14 | 10  
7 | 15  
12 | 6  
6 | 16  
  
Splitting into odd and even terms,  
$xP_{0,odd} (x) = 15 x^3 + 15 x$  
$P_{0,even} (x) = 1$  
The verifier samples $\beta_0 = 4$. Then,  
$P_1 (y=x^2) = 9y +10$  
The domain is given by points of the form $y=x^2$, so $D_1 = \\{ 9, 15, 8, 2\\}$. The leaves of the Merkle tree are

$y$ | $P_1(y)$  
---|---  
9 | 6  
15 | 9  
8 | 11  
2 | 14  
  
We repeat the process,  
$yP_{0,odd} (y) = 9y$  
$P_{0,even} (y) = 10$  
The verifier samples $\beta_1 = 3$  
$P_2 (z=y^2) = 3$.  
And we ended with a constant polynomial. This second domain is $D_2 = \\{13, 4\\}$

## Checking FRI layers

To generate the proof, the verifier chooses an element from $D_0$. We have to send him all the elements needed to reconstruct the evaluations of the composition polynomial and the FRI steps. Say he chooses $x=10$, which corresponds to the index equal to $1$. To evaluate everything, we must pass the evaluation at $x$ and $-x$ for each layer and the trace polynomial evaluated at $x$ and $gx$.

From $P_0(x)$ we pass the values $P_0(x=10)=4$ and $P_0(x=7)=15$, together with their authentication paths.  
From $P_1(x)$ we pass the values $P_1(x=15)=9$ and $P_1(x=2)=11$ and their authentication paths.  
From $P_2(x)$, we only need the constant value of $3$.

Checking the correctness of FRI requires verifying that each value corresponds to its Merkle tree and the colinearity test,  
$$P_{i+1}(x^2)=\frac{P_i(x) + P_i(-x)}{2}+\beta_i \frac{P_i (x) - P_i (-x)}{2x}$$  
Let's check the jump from each layer:  
$$P_1(15) = 16 = \frac{P_0(10) + P_0(7)}{2} + 4 \frac{P_0 (10) - P_0 (7)}{2\times 10}$$  
We can see that  
$$\frac{P_0(10) + P_0(7)}{2} = 1$$  
and  
$$ 4 \frac{P_0 (10) - P_0 (7)}{2\times 10} = 8$$

Let's jump onto the next layer,  
$$P_{2}(y^2)=\frac{P_1(y) + P_1(-y)}{2}+\beta_1 \frac{P_1 (y) - P_1 (-y)}{2y}$$  
Replacing the values,  
$$P_{2}(y^2) = 3$$  
and  
$$ \frac{P_1(15) + P_1(2)}{2} = 10$$  
$$ 3\frac{P_1 (15) - P_1 (2)}{2\times 15} = 10$$  
But  
$$ 10 + 10 = 3 = P_2(4)$$  
which completes the check. You can try selecting other indices and verifying the proof.

The only remaining check shows that the trace and composition polynomial are related. We leave it as a challenge (the answer will appear shortly)

## Summary

This post covered a pen-and-paper example of computational integrity using STARKs. We chose a sequence where each element is the square of the previous one, starting from 3. We stated the problem, interpreted the computation as evaluating a polynomial over a suitable domain, and performed Lagrange interpolation. After that, we enforced the constraints over the execution trace and obtained the composition polynomial. To improve soundness, we forced the prover to evaluate at a point $z$ outside the domain and showed that the trace and composition polynomial are related. Then, we created a rational function that ensured the prover did not cheat and sent the correct values. If the prover is honest, then the resulting function is a polynomial, and we proved by showing that it is close to a low-degree polynomial using FRI. If you want to try more complicated examples, follow the updates at Lambdaworks.
