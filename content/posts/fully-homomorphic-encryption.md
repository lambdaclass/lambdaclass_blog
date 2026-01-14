+++
title = "An introduction to Fully Homomorphic Encryption (FHE)"
date = 2022-12-23
slug = "fully-homomorphic-encryption"
description = "Fully homomorphic encryption (FHE) is a powerful cryptographic primitive which allows us parties to compute with encrypted data, without the need of decrypting it first. "

[extra]
feature_image = "/content/images/2025/12/Weeks_Edwin_Lord_A_Court_in_The_Alhambra_in_the_Time_of_the_Moors.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["Fully Homomorphic Encryption"]
+++

## Introduction

Recently, cloud computing and storage have changed the way businesses and individuals use, store and manage their data. To be secure, data is encrypted using a secure cryptographic scheme, such as AES, where a secret key is needed to decrypt and read the data. Before 2009, if we wanted to perform data analytics on an untrusted server, we needed to provide access to the data in the clear or hand the key encrypting the data to the server. Either option had its risks, as the server could learn valuable or sensitive information, without being able to fully control what it does with it later on. Or, even if the other party were honest, some attacker could breach its security and gain access to our private information in the clear (or the key). Fully homomorphic encryption (FHE) is a powerful cryptographic primitive which allows parties to compute with encrypted data, without the need of decrypting it first. It has applications in finance, health care systems, image and text classification, machine learning, electronic voting, and multiparty computation. An easy example would be wanting to calculate the sum of two numbers, \\( a \\) and \\( b \\). Instead of summing them directly, we could encrypt them, \\( E(a) \\) and \\( E(b) \\), perform some operation \\( E(a)\oplus E(b) \\) and get \\( E(c)=E(a)\oplus E(b) \\), where \\( c=a+b \\).

More formally, the idea is we have our data as plaintext and we want to compute some function over that plaintext space (for example, we could work with integers, \\( \mathbb{Z} \\), representing the salaries of individuals and want to compute the average function). To do so, we transform our plaintexts to ciphertexts and perform operations over the ciphertext space, such that the resulting ciphertext is the encryption of the function applied to the plaintexts: \\( E(f(x))=\hat{f}(E(x)) \\). In a [previous post](/arithmetization-schemes-for-zk-snarks/), we covered that computations could be expressed as arithmetic circuits, where we have two operations: addition and multiplication. If we could get those operations to work on ciphertexts, then, in principle, we could build more complex functions.

A homomorphism is a function between two [algebraic structures](/math-survival-kit-for-developers/) of the same kind (such as two groups, rings, fields, or vector spaces, to name a few), which preserves their structure. In particular, we are interested in ring homomorphisms, where we have a set with two operations. Given rings \\( (\mathcal{R_1},+,\times) \\) and \\( (\mathcal{R_2},\oplus,\cdot) \\), a function \\( f:\mathcal{R_1}\rightarrow \mathcal{R_2} \\) is a (ring) homomorphism if, given any \\( x,y \\) in \\( \mathcal{R_1} \\),

        * \\( f(x+y)=f(x)\oplus f(y) \\).
        * \\( f(x\times y)= f(x)\cdot f(y) \\).

Two common examples of homomorphisms are between integers with ordinary operations \\( (\mathbb{Z},+,\times) \\) and the integers modulo \\(p \\) with their operations \\( (\mathbb{Z}/p\mathbb{Z},+,\times) \\). Another example is between polynomials, \\( (\mathbb{Z}[X],+,\times) \\) and integers \\( (\mathbb{Z},+,\times) \\) when we use the evaluation of the polynomial at a point as morphism. We can see that it is the same if we first sum or multiply two polynomials and then evaluate them at point \\( x_0 \\), or we first evaluate the polynomials at \\( x_0 \\) and then add or multiply the results. Given \\( p(x), q(x) \\) polynomials and \\( \circ \\) an operation (addition or multiplication), \\( (p\circ q)(x_0)=p(x_0)\circ q(x_0) \\).

The first FHE scheme was presented in 2009 by [Craig Gentry](https://crypto.stanford.edu/craig/craig-thesis.pdf). To get an idea of how the scheme works, we can imagine the ciphertext to contain an error or noise attached to it. As long as the error is not large, we can decrypt the ciphertext and recover the plaintext. If we add or multiply ciphertexts, the error increases; if it is above a certain threshold, then decryption will not work. The key point introduced in Gentry's work is bootstrapping, by which we can take a ciphertext and a public evaluation key and re-encrypt the message, reducing the error. This enables the computation of circuits of higher depth (performing more operations).

Even though Gentry's construction proved that FHE is possible, it was extremely slow to be practical, taking as much as half an hour to perform the bootstrapping of 1 bit. Since then, there have been numerous advances and we reached a point where bootstrapping can be done on the scale of microseconds per bit (nearly 10 orders of magnitude). There are 4 generations of FHE as of today. Some constructions are Brakerski/Fan-Vercauteren (BFV) and Brakerski-Gentry-Vaikuntanathan (BGV) for integer arithmetic, Cheon-Kim-Kim-Song (CKKS) for real number arithmetic and Ducas-Micciancio (DM) and [Chillotti-Gama-Georgieva-Izabachene](https://eprint.iacr.org/2018/421.pdf) (CGGI/TFHE) for boolean circuits and arbitrary functions. In this post, we will focus on fully homomorphic encryption over the torus (TFHE).

Currently, schemes can be divided in:

        1. Bootstrapping approach. This has no depth limitations and bootstrapping is done whenever needed to reduce the noise. It works better when the circuit is very deep or its depth is unknown. TFHE is an example of this approach.
        2. Levelled approach. This needs the circuit to be known in advance and works better when the depth of the circuit is small and known in advance. CKKS is an example of this strategy.

The security of many FHE schemes is based on the hardness of the ring learning with errors (RLWE) problem. This is closely related to a famous hard lattice problem, which is thought to be secure against quantum computers. Quantum computers are efficient at breaking homomorphic encryption schemes based on Abelian groups.

## Encryption using TFHE

TFHE supports various schemes to encrypt different variables or to perform certain operations.

### LWE scheme

Suppose that we want to encrypt a message \\( m \\), which can be a bit or a modular integer. To encrypt, we need two numbers, \\( p \\), and \\( q \\), a secret key, \\( s \\), of \\( n \\) bits (depending on the security level), and an error distribution, from which we will obtain the error, \\( e \\). To encrypt, we need to sample a random vector \\( a \\) with \\( n \\) elements in \\( \mathbb{Z}/q\mathbb{Z} \\). \\( q=2^{n_b} \\), where \\( n_b \\) is the number of bits in the ciphertext and \\( p=2^{m_b} \\), with \\( m_b \\) the number of bits of the plaintext. Typically, \\( q \\) is in the order of \\( 2^{32} \\) to \\( 2^{64} \\). The error, \\( e \\) should be less than \\( p/2q \\), otherwise, it could affect the message's bits when adding or multiplying.

The ciphertext, \\( c \\), resulting from the encryption of \\( m \\) is given by  
\\[ E(m,s)=c=(a,b) \\]  
where \\( b=\sum_{k=1}^n a_ks_k+e+\Delta m \\). Here, \\( \Delta \\) is the ratio of \\( p \\) and \\( q \\), so that the message is encoded in the most significant bits of the ciphertext.

To decrypt, we have to use the key to eliminate \\( \sum_{k=1}^n a_ks_k \\) and round the result (take the most significant bits),  
\\[ D(c,s)=\mathrm{round}(b-\sum_{k=1}^n a_ks_k) \\]

This scheme supports ciphertext addition and multiplication by a constant factor. The addition, \\( \oplus \\), of two ciphertexts is  
\\[ E(m_1,s)\oplus E(m_2,s)=(a_1+a_2,b_1+b_2) \\]  
The multiplication by a constant factor \\( \alpha \\) is  
\\[ \alpha E(m,s)=(\alpha a,\alpha b)\\]

### Ring Learning with Errors (RLWE)

In this case, the message is a polynomial \\( M \\) modulo \\( x^N-1 \\), which contains \\( N \\) coefficients. The key \\( S(x) \\) is a polynomial with coefficients in \\( {0,1} \\). The encryption function is  
\\[ E(M(x),S(x))=(A(x),B(x))\\]  
with \\( B(x)=A(x)\cdot S(x)+E(x)+\Delta M(x) \\). The error is now a polynomial of degree \\( N-1 \\), too.

The scheme supports the addition of ciphertexts and multiplication by a constant polynomial.

### Ring GSW (RGSW)

This scheme supports the addition and multiplication of ciphertexts. The message, key, and error are the same as in RLWE, but the ciphertext is different. We can think of it as a three-dimensional matrix, containing \\( \ell \\) layers of

$A_j(x)$ | $B_j(x)$  
---|---  
$A_j^\star(x)$ | $B_j^\star(x)$  
  
The resulting polynomials are given by the following relations:  
\\[ B_j(x)=A_j(x)S(x)+E_j(x)-M(x)S(x)\frac{q}{\beta^j} \\]

\\[ B_j\star(x)=A_j\star(x)S(x)+E_j\star(x)+M(x)S(x)\frac{q}{\betaj} \\]

Addition and multiplication by a constant polynomial follow the same rules as the cases before. To multiply two messages, we need to decompose each layer of the first term into \\( \ell \\) smaller polynomials and perform a multiplication between this decomposition and the corresponding layer of the other ciphertext.

### Summary of ciphertexts

The following table summarizes the different types of ciphertexts and the supported operations.

Case | Addition | Constant Mult | Multiplication  
---|---|---|---  
LWE | Yes | Yes | No  
RLWE | Yes | Yes | No  
RGSW | Yes | Yes | Yes  
  
## Turning private key into public key schemes

Rothblum's theorem states that a semantically secure private key homomorphic encryption scheme, which can perform addition modulo 2, can be turned into a public key semantically secure homomorphic scheme.

## External product and controlled multiplexer (CMux) gates

The external product, \\( \times \\), is an operation involving an RLWE ciphertext and an RGSW ciphertext, outputting, and RLWE ciphertext. To perform the outer product, we have to decompose the \\( A(x) \\) and \\( B(x) \\) polynomials in the RLWE ciphertext and perform a matrix-vector product between the decomposition and the layers of the RSGW ciphertext.

One interesting application of the external product is related to the controlled mux gate, where we assign values according to an if condition. Given two values, \\( y_1, y_2 \\) and a boolean variable \\( b \\), we can construct the following operation  
\\[ (y_2-y_1)b+y_1=y \\]

If \\( b \\) is \\( 0 \\), we get \\( y_1 \\) and if \\( b=1 \\) we get \\( y_2 \\).

This is an important building block for the bootstrapping operation.

## Key switching

The key-switching operation can be used to change encryption keys in different parameter sets. To implement it, we need key switching keys. The procedure has some parallelism with bootstrapping, with the subtle difference that it increases the noise in the ciphertext. The key switching can be applied to change the keys in LWE and RLWE ciphertexts, but it can also be used to transform LWE ciphertexts (one or many) into one RLWE.

## Summary

FHE is an important cryptographic primitive which allows us to compute with encrypted data, without the need of decrypting it first, opening the doors for many interesting and new applications. Since 2009, four generations of FHE schemes have been proposed, adding new functionalities and improving performance by several orders of magnitude. There are two types of approaches: bootstrapped and leveled. The first one works for circuits that are deep or their depth is unknown, while the second works for circuits of small depth. The security of many FHE schemes relies on post-quantum hard problems, such as ring learning with errors (RLWE). One powerful scheme is TFHE, a bootstrapped construction that operates on different types of ciphertext to attain rich functionality. In upcoming posts, we will be covering other schemes and we will go deeper into the fundamentals of FHE.
