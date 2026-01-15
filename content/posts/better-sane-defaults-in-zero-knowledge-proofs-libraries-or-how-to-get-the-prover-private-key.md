+++
title = "Better sane defaults in Zero Knowledge Proofs libraries or how to get the prover's private key"
date = 2023-03-09
slug = "better-sane-defaults-in-zero-knowledge-proofs-libraries-or-how-to-get-the-prover-private-key"

[extra]
math = true
feature_image = "/images/2025/12/Old_Amsterdam_-_Barend_Cornelis_Koekkoek.png"
authors = ["LambdaClass"]
+++

## Introduction

Many ZK libraries allow the creation of pair of points $(x,y)$ which do not belong to the elliptic curve they are working with when building circuits. Some also do not check that the points belong to the appropriate subgroup, which can lead to vulnerabilities.

The argument being made is that invalid points should not reach a prover. What is more surprising is that we would expect the example code or applications to tackle this issue, but they do not. They are not even giving thought to whether these additional checks are needed or not. Of course, many are worried about benchmarks since adding the constraints would make things slower, but removing the safety net and ignoring some attacks published many years ago is not a good long-term strategy. Even if these checks aren't part of the prover, they must be somewhere and in many cases they aren't! If builders take points, like Public Keys, from untrusted users, their system may be compromised, and secret keys may get stolen.

Secret keys may reveal encrypted data or hold access to funds the server may need to operate.

Going back to the checks, as we said before, they may not be needed if the application validates inputs before they reach the prover or if there is a thoughtful analysis of the protocol.

But the first solution, while easy, may lead to censorship. Why should a prover reject a proof generation, saying the input is invalid, without proof that it is invalid?

If there's another bug in the code, there may be even more issues since a malicious user may have even more ways to scramble the program.

In a practical example, some weeks ago, we found a bug that allows us to [make the prover believe two points are equal when they are not](https://github.com/dusk-network/plonk/pull/721/files). Basically, they did not check that, given $A=(x_A,y_A)$ and $B=(x_B,y_B)$, $y_A=y_B$. If they check the points are in the elliptic curve, then necessarily, for the same $x=x_A=x_B$, there are only two possibilities, either $y_A=y_B$ or $y_A=-y_B$, since they have to satisfy the curve's equation. If there is no such check (because the developer did not deem it necessary), then there are as many values as the order of the prime field for the $y$ coordinate.

So, even if the protocol is not vulnerable, it is a good idea and engineering practice to keep some extra checks as a _"defense in depth"_ , to make the program more robust in case there are any other bugs that may be used in tandem with the lack of verifications to create exploits.

## A history of attacks and vulnerabilities.

The issue of not checking that a point belongs to a subgroup was first reported in 1997 by Chae Hoon Lira and Pil Joong Lee in [ "A Key Recovery Attack on Discrete Log-based Schemes Using a Prime Order Subgroup"](https://www.iacr.org/archive/crypto2000/18800131/18800131.pdf).

Meanwhile, the issue with not checking bad curves was first reported in the year 2000 by Bhiel in [ "Differential fault attacks on elliptic curve cryptosystems "](https://www.iacr.org/archive/crypto2000/18800131/18800131.pdf). [This article](https://eprint.iacr.org/2017/554.pdf) also shows some problems when the code does not verify belonging to the elliptic curve.

Let's see how this exploit works with an example. We can write elliptic curves in Weierstrass form,  
$$ y^2 = x^3 +a x + b $$  
One crucial fact is that addition and doubling formulas do not depend on the value $b$. This means that two curves $E$ and $E^\prime$ have the same operations if they only differ in $b$. The curve $E^\prime$ is called an invalid curve relative to $E$, and an attacker may choose an $E^\prime$ with much weaker security.

Suppose an attacker sends some point $Q$ of low order $k$ (the simplest case is $k=2$, which means that $2Q=\mathcal{O}$). If the attacker performs a key exchange with the user $A$ to derive a shared key $K=KDF(sk_A Q)$ and $A$ sends some message $m$ to the attacker, then he can learn $sk \equiv sk_k \pmod{k}$

If the attacker repeats this process several times (using points of different order, all coprime), possibly using different invalid curves, he gets a system of congruences.

$sk\equiv sk_1 \pmod{k_1}$  
$sk\equiv sk_2 \pmod{k_2}$  
$sk\equiv sk_3 \pmod{k_3}$  
$sk\equiv sk_4 \pmod{k_4}$

Then, he can use the Chinese Remainder Theorem to reconstruct $sk$ or at least a list of candidates and solve the remaining problem with brute force search. This leads to the attacker learning the secret key and impersonating the server or user, and even signing transactions on behalf of the user (leading to fund stealing, for example)

We can extend this attack for protocols with a key exchange that starts diverging from the straightforward original example. For another example, see [Practical Invalid Curve Attacks on TLS-ECDH  
](https://link.springer.com/chapter/10.1007/978-3-319-24174-6_21#Sec12)

## Summary

Many cryptographic libraries for zero-knowledge-proof applications remove or ignore some basic checks on elliptic curves, which can lead to vulnerabilities. We're talking with the contributors of the libraries to fix these issues and disclose them.

Even if they have been known for over 20 years, eagerness for performance has led to ignoring these issues, creating potential problems for developers building on top of these libraries. The question remains then, how far are our applications from these kinds of exploits, and how careful will the programmers be when handling data that can be poisoned.

Good defaults are important. From our point of view, all the checks should be done by default in libraries and if they aren't this should be made mor explicit. Good examples with sane defaults should be part of the libraries. Leaving the optimizing of code by removing checks for highly audited code where skipping those checks gives a real improvement to real users.

Thanks to Diego Kingston and Mauro Toscano from LambdaClass for helping write this.
