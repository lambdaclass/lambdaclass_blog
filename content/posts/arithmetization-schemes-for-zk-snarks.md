+++
title = "Arithmetization schemes for ZK-SNARKs"
date = 2023-01-14
slug = "arithmetization-schemes-for-zk-snarks"

[extra]
feature_image = "/content/images/2025/12/Siege-alesia-vercingetorix-jules-cesar.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["zero knowledge proofs"]
+++

## Introduction

Zero-knowledge proofs (ZKP) are gaining ground thanks to their many applications in delegating computations to untrusted servers and solving the scalability issues that decentralized ledgers suffer from. ZKP allow us to prove a given computation's validity without revealing sensitive data. One of the key advantages is that the proof is short (succinct), and its verification time is much faster than the naïve re-execution of the computation. We can exploit this in decentralized ledgers, where each node must check the correctness of the transactions. Here, the weakest devices act as bottlenecks. If we can now verify the validity of a transaction by checking a small proof (taking a few milliseconds), then the scalability problems begin to fade away. We can also make proofs showing that we executed thousands of transactions or operations by using recursive proof composition, [proof aggregation](https://www.entropy1729.com/proof-aggregation-schemes-snarkpack-and-aplonk/), or [folding schemes](https://www.entropy1729.com/incrementally-verifiable-computation-nova/).

To prove the validity of the computation and avoid revealing sensitive information, ZKP rely on polynomials and their properties. Polynomials are expressions of the form \\( a_0+a_1x+a_2x2+a_3x3+...a_n x^n \\), where the coefficients \\( a_k \\) are elements of some [ring or field](/math-survival-kit-for-developers/) (for example, integers, real numbers or members of a finite field, like \\( \mathbb{Z}/7\mathbb{Z}\\), the integers modulo 7). Now, to be able to use polynomials, we have to be able to express our computations in terms of them by a process known as arithmetization.

Arithmetization reduces computed statements to algebraic statements involving polynomials of a bounded degree. Arithmetization can be divided into two categories:

        * Circuit computations. Most SNARKs use this.
        * Machines computations. STARKs use this approach.

Circuit computations are better for unstructured computations and support composability with relative ease. On the other hand, machine computations are better for uniform computations and support unbounded computations.

Some operations can be easily transformed into arithmetic operations, either because they are algebraic operations over a finite field or because we can translate them with some slight changes into those. This leads to a shift in thought about what is an expensive or straightforward computation. For example, stream ciphers are efficient encryption schemes, performing XOR operations between the plaintext (the message we want to encrypt) and a keystream (a pseudorandom string of bits), which the processor can calculate very fast. However, in terms of their arithmetization and the number of equations we need to describe them (that is, the number of constraints), they are expensive operations for SNARKs. Examples of costly operations for SNARKs are bitwise operations (AND, XOR, OR), bound checks, and comparisons (because these require breaking the variable into bits).

The arithmetization adds significant overhead to the computation time. There can be nearly two orders of magnitude increase in computation time using SNARK-friendly operations and more for non-friendly operations.

Recently, many different optimizations have been presented to reduce the overhead, such as:

        * Lookup tables.
        * SNARK-friendly cryptographic primitives (such as [Rescue](https://eprint.iacr.org/2020/1143.pdf), [SAVER](https://eprint.iacr.org/2019/1270.pdf) or [Poseidon](https://eprint.iacr.org/2019/458)).
        * Concurrent proof generation.
        * Hardware acceleration (such as using GPU or FPGA).

In general, arithmetization cannot be done manually except for elementary programs. Besides, the use of naïve arithmetization can lead to significant overhead. To deal with this, dedicated compilers accepting high-level programming languages have been developed, as well as zero-knowledge virtual machines, such as CAIRO. We will examine the most popular schemes, R1CS, AIR, and plonkish arithmetization.

## R1CS

Arithmetic circuits can be expressed as (quadratic) rank one constraint systems (R1CS). These are systems of equations, each at most quadratic in each variable, of the form  
\\[ (\sum_k A_{ik} z_k)(\sum_k B_{ik}z_k)-(\sum_k C_{ik}z_k)=0 \\]  
where \\( A_{ik}, B_{ik}, C_{ik} \\) are elements in some finite field \\( \mathbb{F} \\), with many of them zero. We can write down any complex computation in this way. For example, if we want to calculate \\( w=x^4 \\) we can express this as  
\\( x\times x= w_1 \\)  
\\( w_1 \times w_1=w \\)  
where we have introduced an additional variable, \\( w_1 \\), which we have to decide whether it will be a public or private variable. It is important to see that R1CS for describing a given computation are not unique. For example, we could have expressed the previous computation as  
\\( x\times x= w_1 \\)  
\\( x\times w_1= w_2 \\)  
\\( x\times w_2= w \\)  
This system is equivalent to the previous one but has one more constraint.

To implement R1CS, programs have gadgets, allowing one to construct arithmetic circuits modularly. For example, if we want to work with a boolean variable, we can have a gadget implementing the constraints, such that the variable only takes the values 0 or 1. If we call the variable \\( b \\), then  
\\( b(1-b)= 0 \\)  
If we want to perform an OR operation between \\( a \\) and \\( b \\), then the boolean gadget implements also  
\\( a(1-a)=0 \\)  
while the OR gadget adds  
\\( a+b-ab=c \\)

The [Arkworks](https://github.com/arkworks-rs/snark/tree/master/relations/src) library contains gadgets for basic data types and operations. Common expressions for operators and range checks can be found in the [Zcash protocol specification](https://zips.z.cash/protocol/protocol.pdf).

## Algebraic intermediate representation (AIR)

Algebraic Intermediate Representation (AIR) is the arithmetization procedure used by StarkWare in their virtual machine, CAIRO (CPU AIR). The AIR consists of the three following elements:

        1. The execution trace of the computation. This is expressed as a trace execution matrix, \\( T \\), whose rows represent the computation state at a given time point and whose columns correspond to an algebraic register tracked over all the computation steps.
        2. Transition constraints enforce the relations between two or more rows of the trace matrix \\( T \\).
        3. Boundary constraints enforce equalities between some cells of the execution and constant values.

The arithmetization takes place in two stages:

        * Generating the execution trace and the low-degree polynomial constraints.
        * Transforming the previous two into a single univariate polynomial.

The set of polynomial constraints is constructed so that they are all verified if and only if the execution trace is valid (that is if the trace represents a valid computation). The constraints are low-degree polynomials but are not necessarily restricted to degree \\( 2 \\), as in the case of R1CS.

To see how AIR works, let us look at a few examples. Suppose that we want to add all the elements in a given vector of size \\( n \\), \\( a=(a_1,a_2,a_3,...,a_n) \\). We could introduce a variable \\( t \\) starting at \\( 0 \\) and which at each step adds the value of one of the components of \\( a \\). The trace matrix contains two columns; the first one is given by the elements of \\( a \\) and the partial sums in \\( t \\)

Row | \\( a \\) | \\( t \\)  
---|---|---  
1 | \\( a_1 \\) | \\( 0 \\)  
2 | \\( a_2 \\) | \\( a_1 \\)  
3 | \\( a_3 \\) | \\( a_1+a_2 \\)  
4 | \\( a_4 \\) | \\( a_1+a_2+a_3 \\)  
\\( \vdots \\) | \\( \vdots \\) | \\( \vdots \\)  
n | \\( a_n \\) | \\( \sum_k^{n-1} a_k \\)  
n+1 | \\( \sum_k a_k \\) | \\( \sum_k a_k \\)  
  
The following polynomial constraints can summarize the correctness of the computation:  
\\( t_1=0 \\)  
\\( t_{j+1}-t_j-a_j=0 \\) for \\( j=1,2,...n \\)  
\\( a_{n+1}-t_{n+1}=0 \\)

The advantage, in this case, is that the polynomial equations are not constrained to degree two or less. Multiplicative inverses, \\( x^{-1} \\), such that \\( x \times x^{-1}=1 \\) can be written down in two equivalent forms:  
\\( x^{p-2}=y \\)  
\\( x\times y -1 =0 \\)  
The first expression uses Fermat's little theorem and involves a gate of degree \\( p-2 \\), while the second has degree 2.

The procedure for AIR as used in STARKs follows these steps:

        1. Get the execution trace.
        2. Perform low-degree extension.
        3. Evaluate constraints.
        4. Compose constraints into the compositional polynomial.

The low-degree extension works as follows:

        1. Take each register (each column of the execution trace matrix) as evaluations of some polynomial, \\( f \\).
        2. Interpolate the \\( f \\) over the trace domain to find its coefficients.
        3. Evaluate \\( f \\) over a larger domain.

The easiest way to work our way around is by using the number theoretic transform (this is the finite field version of the fast Fourier transform). We need to select a finite field such that it contains the n-th roots of unity, \\( w_k \\), such that \\( w_k^n=1 \\) and \\( n \\) is a power of 2 (\\( n=2^m \\)) larger than the number of rows. To obtain all the n-th roots, we can take powers of a generator, \\( \omega \\), \\( \omega^0=1, \omega=w_1, \omega^2=w_2,...\\), etc. To perform a low-degree extension, we can increase the domain by adding the 2n-th roots of unity and take advantage of our previous evaluations (or 4n-th roots of unity, leading to a 4x blowup).

To evaluate the constraints,

        1. Define the algebraic relations between rows.
        2. Reinterpret these relations as polynomials with roots at the points where the conditions hold.
        3. Divide out roots from constraint polynomials to convert them into rational constraints.

For example, if we have some relation between the rows, such as  
\\( r_{k+2} = r_{k+1}^2+2r_{k} \\)  
we can interpret this as some polynomial \\( f \\) and associate each step with \\( x_k=\omega^k \\), so  
\\( f(x \omega^2)=(f(x \omega)^2+2 f(x)) \\)  
The polynomial  
\\( p(x)=f(x \omega^2)-(f(x \omega)^2+2 f(x)) \\)  
has roots at the points \\( x \\) where the relation \\( f \\) holds.  
We can then take out the roots by dividing them by  
\\( d(x)=\prod_k (x-\omega_k) \\)  
where the product is carried out only over the values of \\( k \\) where the constraint holds. We get the required polynomial,  
\\[ g(x)=\frac{p(x)}{d(x)} \\]  
The following identity gives a practical result,  
\\[ \prod_{k=0}^{n-1} (x-\omega^k) = x^n-1 \\]  
So, if we know that the constraint holds on most \\( \omega^k \\), \\( d(x) \\) can be computed efficiently using that identity. For example, if \\(n=256 \\) and it holds for all rows, except \\( k=128, 194 \\), then  
\\[ d(x) = \frac{x^n-1 }{(x-\omega^{128}) (x-\omega^{194}) }\\]

For our previous relationship  
\\( r_{k+2} = r_{k+1}^2+2r_{k} \\)  
say that \\( r_1=1, r_2=5 \\) and we want to calculate until \\( r=1000 \\). We will use \\( n=1024 \\) because this is the smallest power of \\( 2 \\) larger than \\( 1000 \\). In addition to the constraints being valid for all points from \\( 3 \\) to \\( 1000 \\), we also have constraints for the two initial values:  
\\( f(\omega^0)=1=f(1) \\)  
\\( f(\omega)=5 \\)  
Therefore, we get some additional polynomials (if the conditions do hold):  
\\[ p_1(x)=\frac{f(x)-1}{x-1} \\]  
\\[ p_2(x)=\frac{f(x)-5}{x-\omega} \\]  
\\[ p_3(x)=\frac{f(x \omega^2)-(f(x \omega)^2+2 f(x))}{d_3(x)} \\]  
where  
\\[ d_3(x) = \frac{x^{1024}-1 }{(x-1 )(x-\omega) \prod_{k = 1001}{1023}(x-\omegak) } \\]  
We can finally obtain the compositional polynomial by taking a random linear combination of \\( p_1,p_2,p_3 \\):  
\\[ P(x)=\alpha_1 p_1+\alpha_2 p_2+\alpha_3 p_3\\]

## Plonkish arithmetization

The arithmetization used by Plonk is known as randomized algebraic intermediate representation with preprocessing (RAP, for short). TurboPlonk and UltraPlonk are restricted cases of RAP. As before, our starting point is the execution trace matrix, \\( T \\), consisting of \\( n \\) rows and \\( w \\) columns.

Plonk's constraint system is written (considering two fan-in gates) as  
\\[ q_L x_a+q_R x_b+q_O x_C+q_M x_a x_b +q_C=0 \\]

This can represent the operations found in R1CS and allows for the implementation of custom gates. Plonk's original arithmetization scheme consisted in encoding the computation trace into polynomials, for which we had to check the correctness of the wiring, that the polynomial encodes the inputs correctly, that every gate is evaluated correctly, and the output of the last gate.

A preprocessed AIR (PAIR) extends the execution trace by adding new columns, \\( c_1,c_2,...c_m \\) so that the new columns will participate in the constraints. These variables allow us to change the relationship between different rows in the trace matrix. For example, we could alternate the relationship between even and odd rows, performing different operations. For example, we might want to have the following:  
\\( x_{2n} = x_{2n-1}^2 \\)  
\\( x_{2n+1} = 2\times x_{2n} \\)  
We can encode this relationship by doing  
\\( c_1(x_n-x_{n-1}^2)+(1-c_1)(x_n-2x_{n-1}) \\)  
where \\( c_1=1 \\) in even rows and \\( c_1=0 \\) in odd rows. Because we can use them to choose the operation we want to perform, they are called selectors. We can use more selectors to describe complex operations, such as elliptic curve addition.

We can use the grand product check to check that two vectors \\( a,b \\) are permutations of each other. Given a random \\( \gamma \\) in the finite field \\( \mathbb{F} \\), the following equality should hold:  
\\[ \prod (a_i+\gamma) = \prod (b_i+\gamma)\\]  
Due to the Schartz-Zippel lemma, we know that the probability that two polynomials are equal at a randomly sampled value is less than \\( 1-d/\vert \mathbb{F} \vert \\), where \\( d \\) is the degree of the polynomial and \\( \vert \mathbb{F} \vert \\) is the number of elements of the finite field.

To check that this operation has been carried out correctly, we can introduce one additional variable, \\( v \\), such that  
\\( v_1=1 \\)  
\\( v_k=v_{k-1}\times (a_{k-1}+\gamma)/(b_{k-1}+\gamma) \\) for \\( k={2,n+1} \\)  
If the last value, \\( v_{n+1} \\), is equal to one, then we know, with very high probability, that the columns \\( a,b \\) are permutations of each other.

Plonk allows one to include lookup arguments. These help us check that a given operation between two variables \\( a,b \\) yielding output \\( c \\) is correct by looking inside a table with precomputed valid \\( (a,b,c) \\). To do so, we need to incorporate a table \\( t \\) where the rows give all possible input/output combinations. For example, we can take \\( a,b \\) be 8-bit strings and provide the results of the XOR operation, \\( c=a\oplus b \\). This gives a total of \\( 2^{16} \\) combinations. To check that the result is correct, we can use a random variable, \\( \beta \\), and compute \\( f_k=a_k+\beta b_k+\beta^2 c_k \\) and \\( g_k=t_{k1}+\beta t_{k2}+\beta^2 t_{k3} \\), where \\( t_{ki} \\) are the elements of the table. We will cover these kinds of arguments in an upcoming post.

## Summary

One of the critical steps in the generation of zk-SNARKs for verifiable computation is transforming a given computer program into polynomials. This process is known as arithmetization, and we have some schemes to do it efficiently, such as R1CS, AIR, and Plonkish arithmetization. In the first one, we need gadgets to implement the data types (such as boolean, u8, and i64 variables) and their associated operations. In the case of AIR and Plonkish, we need to get the execution trace of the program, establish the relationship between the rows and interpolate polynomials. Both approaches need to be carefully implemented, as naïve ways to do so can lead to a greater number of constraints and significant overhead. Fortunately, the development of new SNARK-friendly primitives, lookup arguments, custom gates, and hardware acceleration (such as the use of GPU and FPGA) can reduce either the arithmetic complexity or increase the speed at which calculations are performed and enable shorter proving and verifying times, open the doors for many new and exciting applications in the real world.
