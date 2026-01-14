+++
title = "SNARKs on binary fields: Binius - Part 1"
date = 2023-12-01
slug = "snarks-on-binary-fields-binius"

[extra]
feature_image = "/content/images/2025/12/Hubert_Robert_-_The_Fire_of_Rome_-_Google_Art_Project.jpg"
authors = ["LambdaClass"]
+++

## Introduction

ZK-SNARKs (zero-knowledge, succinct, non-interactive arguments of knowledge) and STARKs (scalable, transparent arguments of knowledge) have gained widespread attention due to their applications in distributed private computing and blockchain scaling. Over the years, we have seen several performance improvements thanks to new proof systems, new lookup arguments, and smaller fields. One of the biggest challenges is related to the arithmetization of programs, that is, the transformation of a given program into a system of polynomial relations. This represents a considerable overhead, as we have to represent variables, such as bits, by elements in a finite field. In the case of SNARKs over elliptic curves, the field is given by the elliptic curve used, which means that to represent simple bit operations, we have to use (at least) 256-bit field elements. In the case of STARKs, we can use smaller fields (such as mini Goldilocks or Mersenne 31), which gives a smaller overhead, but then we have to work over extension fields to achieve cryptographic security. Typical hash functions involve lots of bitwise operations, which makes their arithmetization costly (and therefore proving things that involve computing hashes). This has led to the use of SNARK-friendly hashes such as Poseidon or Tip5.

A recent [line of work by Ulvetanna](https://eprint.iacr.org/2023/1784.pdf) proposes using binary fields with the brakedown polynomial commitment scheme to obtain a new SNARK, which can represent bitwise operations more naturally. It also has the advantage that it is hardware-friendly and has a lower memory footprint. This post will explain some key concepts, such as binary fields and the brakedown commitment scheme. We will use these concepts later to understand the working principle of [Binius](https://gitlab.com/UlvetannaOSS/binius/-/tree/main/src?ref_type=heads).

## Binary fields

Binary fields are fields of characteristic two. They are of the form $\mathbb{F_{ 2^n }}$ for some $n$. The simplest binary field is $\mathbb{F_2}$ whose elements are just $\\{ 0, 1 \\}$ with the operations done modulo $2$. Addition corresponds to bitwise exclusive OR, and multiplication corresponds to bitwise AND. Given that $2^n$ is not prime, we need to do some work to turn it into a field. First, we are going to consider the polynomials over $\mathbb{F_2}$, that is, polynomials whose coefficients are either $0$ or $1$, such as $p(x) = x^7 + x^5 + x^2 + 1$. Then, we select an irreducible polynomial $m(x)$ over $\mathbb{F_2}$ and consider the equivalence classes by taking the remainder of any polynomial by $m(x)$. For example, the polynomial $m(x) = x^2 + x + 1$ is irreducible; the remainder is always a polynomial of at most degree one $r(x) = a x + b$, where $a$ and $b$ is either zero or one. The resulting field is $\mathbb{F_{ 2^2 }}$, which contains $4$ elements, $0 + 0x$, $1 + 0x$, $0 + x$, $1 + 1x$, which we can represent as $00$, $10$, $01$ and $11$. We can always represent unambiguously an element in $\mathbb{F_{ 2^n }}$ by a bitstring of length $n$. A list of irreducible polynomials over $\mathbb{F_2}$ can be found [here](https://www.hpl.hp.com/techreports/98/HPL-98-135.pdf).

The polynomial $m(x) = x^3 + x + 1$ is also irreducible, so we can use it to build a different extension, $\mathbb{F_{ 2^3 }}$, containing $8$ other elements. A different approach to constructing $\mathbb{F_{ 2^3 }}$ is using extension towers. Binius uses the construction proposed by [Wiedemann](https://www.fq.math.ca/Scanned/26-4/wiedemann.pdf).

We can use the multilinear Lagrange polynomials as a base for the tower of extensions. This has the advantage that embedding one extension into the others is achieved trivially by padding zero coefficients. The construction proceeds inductively:

        1. Start from $\tau_0 = \mathbb{F_2}$.
        2. Set $\tau_1 = \mathbb{F_2} [ x_0 ] / (x_0^2 + x_0 + 1)$
        3. Continue $\tau_k = \mathbb{F_2} [ x_{ k - 1} ] / ( x_{ k - 1 }^2 + x_{ k - 1} x_{ k - 2} +1)$

We have $\tau_0 \subset \tau_1 \subset \tau_2 \subset \dots \subset \tau_m$.

Let's take a look at the elements to see how this works:

        1. For $\tau_0$ this is straightforward, since we have either $0$ or $1$.
        2. For $\tau_1$, the elements are $0 + 0x_0$, $1 + 0x_0$, $0 + 1x_0$, $1 + 1x_0$. We can identify the elements of $\tau_0$ with the first two, $00$ and $10$.
        3. For $\tau_2$, we have $0 + 0 x_0 + 0 x_1 + 0 x_0 x_1$, $1 + 0 x_0 + 0 x_1 + 0 x_0 x_1$, $0 + 1 x_0 + 0 x_1 + 0 x_0 x_1$, $1 + 1 x_0 + 0 x_1 + 0 x_0 x_1$, $1 + 0 x_0 + 1 x_1 + 0 x_0 x_1$, $0 + 1 x_0 + 1 x_1 + 0 x_0 x_1$, $1 + 1 x_0 + 1 x_1 + 0 x_0 x_1$, etc, which we identify with all bitstring of size 4. The elements of $\tau_1$ can be seen as the elements in $\tau_2$ of the form $b_0 b_1 00$. This way of sorting the elements corresponds to lexicographic ordering.

It's also worth noting that given an element $b_0 b_1 b_2 ... b_{ 2^k - 1}$ from $\tau_k$, we can break it into halves, which satisfy $b_{lo} + X_{k - 1} b_{hi}$, where $b_{hi}$ and $b_{lo}$ are from $\tau_{ k - 1}$. The addition is just XOR, which has several advantages from the hardware point of view, including the fact that we don't need to worry about carry. Multiplication can be carried out in a recursive fashion using the decomposition we saw. If we have $a_{hi} x_k + a_{lo}$ and $b_{hi} x_k + b_{lo}$ we get  
$a_{hi} b_{hi} x_k^2 + (a_{hi} b_{lo} + a_{lo} b_{hi}) x_k + a_{lo} b_{lo}$  
But we know that $x_k^2 = x_{k-1} x_k + 1$. We then have to compute products in $\tau_{ k - 1}$, where we can apply the same strategy until we can solve them either because it's a trivial operation (operation over $\mathbb{F_2}$) or because we have a lookup table to get the values. There are also efficient multiplication techniques to multiply elements from a field by an element in a subfield. For example, an element from $\tau_{ k + j}$ can be multiplied by an element of $\tau_k$ in just $2^j$ multiplications.

## Coding Theory

A code of block $n$ over an alphabet $A$ is a subset of $A^n$, that is, vectors with $n$ elements belonging to $A$. The Hamming distance between two codes is the number of components in which they differ.

A $[k, n , d]$ code over a field $\mathbb{F}$ is a $k$-dimensional linear subspace of $\mathbb{F}^n$ such that the distance between two different elements is at least $d$. Reed-Solomon codes are examples of these types of codes. Given a vector of size $k$, $(a_0, a_1, ... , a_{ k - 1})$, its Reed-Solomon encoding consists in interpreting each $a_k$ as the evaluation of a $k - 1$ degree polynomial and then evaluating this polynomial over $n$ points (we used this encoding when working with STARKs). The code is called systematic if the first $k$ elements correspond to the original vector. The ratio $\rho = k / n$ is the rate of the code (we worked with its inverse, the blow-up factor). In this case, the distance is $n - k + 1$ since degree $k - 1$ polynomials can coincide at most in $k - 1$ points.

The $m$-fold interleaved code of block length can be seen as the linear code of size $n$ defined over the alphabet $A^m$. We can view the code as rows with elements in $A^m$.

Given a $[n,k,d]$ linear code $C$ over $\mathbb{F}$ with generating matrix $M$ and a vector space $V$ over $\mathbb{F}$, the extension code $C^\prime$ of $C$ is the image of the mapping $M x$, where $x$ is in $V^k$.

## Polynomial Commitment Scheme

The polynomial's coefficients and code field size $\mathbb{F}$ can be as small as needed, but they should be the same. The security can be added by sampling elements from an extension field $\mathbb{E}$.

The prover starts with a vector $(t_0, t_1, ... t_n)$, which he interprets as the coefficients in the Lagrange basis over ${0 , 1}^{\log n}$. Then, he organizes the coefficients in an $m_0 \times m_1$ matrix $T$, with rows $\mathrm{row_i}$ and encodes $\mathrm{row_i}$ to obtain $u_i$ (there are $m_0$ rows of length $\rho^{ - 1 } m_1$). We call the matrix containing the $u_i$ as rows, $U$. Build a Merkle tree using each column as a leaf and output the root as the commitment.

The verifier selects an evaluation point $r = (r_0, r_1 , \dots, r_{ \log (n) - 1})$, and the prover will provide $s$ as the evaluation of the polynomial over $r$. To generate the evaluation proof,

        1. The prover sends the vector - matrix product $R.T$, where $R$ is the tensor product of the last $\log (m_0 )$ components of $r$.
        2. The verifier samples $i$ queries (which depend on the security level), selecting one column of $U$ each time.
        3. The prover sends the requested columns and their corresponding authentication paths.

The proof consists of the evaluation, $s$, the Merkle root, $\mathrm{root}$, the vector-matrix product $R.T$, the $i$ columns, and their corresponding authentication paths.

To check the proof:

        1. The verifier checks that the Merkle tree contains the columns.
        2. The verifier computes the encoding of $R.T$ and checks that the product of the selected columns of $U$ by $R$ correspond to the columns of encoding of $R.T$.
        3. The verifier checks that $s$ is the proper evaluation using $R.T$ and the tensor product of first $\log (m_1)$ components of $r$.

A key concept to building the commitment scheme is that of packing. Given m elements $\tau_{ k }$, we can group then into $m/2^j$ elements of $\tau_{ k + j}$. Similarly, the rows can be packed into elements of $\tau_r$. The polynomial commitment is modified to have the verifier test blocks of columns instead of single columns.

## Conclusion

In this post, we covered the basic concepts behind Binius. The construction takes advantage of binary fields built using extension towers, which leads to hardware-friendly operations. The construction also lets us concatenate several elements and interpret them as elements of an extension field. The commitment scheme is based on brakedown, which uses Merkle trees and Reed-Solomon encoding. The scheme results in larger proofs and longer verification times than FRI, but the prover's time is significantly reduced. However, the benefits in terms of prover time generally outweigh those of longer verification times. Besides, using recursive proofs can further reduce the proof size, or we could use one final SNARK, such as Groth16 or Plonk, to achieve smaller proofs to post to L1. In the following posts, we will look deeper at the commitment scheme and the different protocols for the SNARK.
