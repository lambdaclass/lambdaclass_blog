+++
title = "Incrementally verifiable computation: NOVA"
date = 2023-01-20
slug = "incrementally-verifiable-computation-nova"

[extra]
feature_image = "/images/2025/12/Edmund_blair_leighton_accolade.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["zero knowledge proofs"]
+++

## Introduction

One of the current goals is to realize, in an efficient way, incrementally verifiable computation (IVC). This cryptographic primitive allows a given party to show the integrity of a given computer program's execution by providing proof that the result of each step is correct and that all previous ones have been appropriately executed at every step. More precisely, given step \\( N \\), we apply a function \\( F_N \\) which updates the state, taking as inputs the current state \\( x_N \\) and a proof that asserts the correct execution of all steps \\( 1,2,...N-1 \\), \\( \pi_{N-1} \\), and outputting the new state \\( x_{N+1} \\) and a proof of its correct execution \\( \pi_{N+1} \\). IVC has many applications, such as allowing decentralized private computation (DPC), where you can delegate the execution of your programs to untrusted third parties, succinct blockchains, and verifiable delay functions.

In a previous post, we discussed the problem of DPC and two protocols related to it, [ZEXE and VERI-ZEXE](/decentralized-private-computations-zexe-and-veri-zexe/). ZEXE discussed the possibility of using proof-carrying data (PCD) to be able to verify arbitrary computations, but this can be pretty expensive computationally since, at each step, we need to verify the proof of the previous step, for which we need to:

        1. Compute expensive bilinear pairing operations.
        2. Include the arithmetic circuit of the verifier into our program, which is not a lightweight construction.

VERI-ZEXE leveraged accumulation schemes (AS) to provide IVC. The key idea is to delay the final proof to the ledger's validators (where we will need to compute the expensive pairing operation). At each step of the computation, the proof \\( \pi_{N-1} \\) is "added" to an accumulator, which is then partially verified: the prover checks that the result of the accumulation is correct, but does not compute pairing operations. We mask the group elements in the accumulator using a randomizer to ensure zero knowledge.

[Nova](https://eprint.iacr.org/2021/370.pdf) is a new protocol proposing an alternative to realizing IVC with lightweight construction. Instead of using [zk-SNARKs](/the-hunting-of-the-zk-snark/), they take advantage of folding schemes, accumulating NP instances instead of SNARKs. The authors claim it results in a weaker, simpler, and more efficient scheme than those relying on succinct arguments of knowledge:

        * The verifier circuit is constant in size and dominated by two group scalar multiplications.
        * The prover's work is dominated by two multiexponentiations.

The key point is that the folding acts as a deferral of proof verification until the last point: to check the correct application of \\( N \\) times a given function, we only need to check the folded proof for the \\( N \\) steps.

## Folding schemes

A folding scheme is a protocol between an untrusted prover and a verifier. Each of them has an \\( N- \\)sized NP instance of equal size, and the prover has, in addition, witnesses for both instances (recall, in the context of zk-SNARKs that we call witness the secret inputs/information). The protocol enables them to output a single \\( N- \\) sized NP instance, known as the folded instance. The folding scheme guarantees that the folded instance is satisfiable only if the original instances are valid. We call the scheme non-trivial if the verifier's work and communication are less than those he would have if he did not participate in the folding scheme. The folding scheme reduces the satisfiability of two NP instances to just one NP instance. Some techniques exhibiting this two-to-one reduction (or some reduction) are sum check protocols, batch proving, and bulletproofs. To realize such a construction, we have to introduce relaxed (quadratic) rank-one constraint systems (relaxed R1CS).

## R1CS and relaxed R1CS

We saw that the correct execution of a given code could be expressed as a [circuit satisfiability problem](/how-to-transform-code-into-arithmetic-circuits/). Circuits are equivalent to R1CS, which are systems of equations of the form:  
\\[ Az \times Bz = Cz \\]  
where \\( A,B,C \\) are sparse matrices and \\( \times \\) denotes component-wise product. It is quadratic because each variable in each equation has at most degree two (we can have \\( z_1^2 \\) but not \\( z_1^4 \\)). Even though R1CS are a convenient way to express circuits, they are not fully compatible with folding schemes; in other words, it is not easy to build a folding scheme on top of R1CS.

Nova works by taking incremental computations, where each step is expressed as an R1CS; the constraint system is augmented with the verification circuit, which has to assert the correctness of the execution of the previous step. However, instead of verifying the proof \\( \pi_{N-1} \\), Nova treats it as an instance of R1CS and folds it into a running relaxed R1CS.

A relaxed R1CS introduces an error, \\( E \\), and a scalar, \\( u \\), such that  
\\[ Az \times Bz = uCz+E \\]  
Note that any R1CS is also a relaxed R1CS, where \\( E \\) is the zero vector and \\( u=1\\). Relaxed R1CS retains the property that it is NP-complete, which means that we can reduce any NP problem to it.

We want the folding scheme to merge two instances of R1CS with the same matrices \\( A, B, C \\) into a single one. Each R1CS has its corresponding instance-witness pairs (that is, public and private data), \\( z_i=(w_i,x_i) \\), and we want to create a new \\( z=(w,x) \\) satisfying the R1CS system of equations with \\( A, B, C \\), such that this also implies that each \\( z_i=(w_i,x_i) \\) does so. One way to do this is by having the verifier select a random \\( r \\) and perform the following transformation:  
\\[ z=z_1+rz_2 \\]  
This transformation would suffice for linear systems of equations, but since the R1CS is nonlinear, we cannot apply this simple strategy. If we replace this into the R1CS  
\\[ Az_1\times Bz_1+r(Az_1 \times Bz_2 +Az_2\times Bz_1)+r^2(A_2z_2\times B_2z_2) = Cz_1+rCz_2 \\]

In the relaxed R1CS, the error term \\( E \\) will absorb all the cross-terms generated by introducing the linear combination, and \\( u \\) will take the extra \\( r \\) term on the right-hand side. To do so,  
\\[ u=u_1+ru_2 \\]  
\\[ E=E_1+r(Az_1\times Bz_2+Az_2\times Bz_1-u_1Cz_2-u_2Cz_1)+r^2E_2\\]  
and both \\( u,E \\) are added to the instance-witness pair. The main problem is that the prover has to send the witnesses \\( w_1,w_2 \\) to the verifier so that he can compute \\( E \\). To do this, we treat both \\( E \\) and \\( w \\) as witnesses and hide them using polynomial commitment schemes.

## Polynomial commitment scheme

Nova uses an inner product argument ([IPA](https://dankradfeist.de/ethereum/2021/07/27/inner-product-arguments.html)), which relies on Pedersen commitments. These are based on the assumption that the discrete log is hard to solve and do not require a trusted setup. IPA differs from other popular commitment schemes, such as KZG, which relies on elliptic curve pairings and needs a trusted setup. Regarding proof sizes and verification times, KZG is better since IPA with Pedersen commitments requires linear work from the verifier, with proof size depending on the input (KZG's proof and verification time are constant). However, we can work these weaknesses around in systems such as Halo.

The lightweight construction of the verifier is tied to the polynomial commitment scheme. In this case, the highest cost is two [group scalar multiplications ](/need-for-speed-elliptic-curves-chapter/). Nova's verifier circuit is around 20,000 constraints.

The fundamental property that the polynomial commitment scheme must satisfy is that it is additively homomorphic: given two variables \\( a, b \\), we say that the commitment is additively-homomorphic if \\( \mathrm{cm}(a+b)=\mathrm{cm}(a)+\mathrm{cm}(b) \\), where \\( \mathrm{cm}(x) \\) is the commitment of \\( x \\). Both KZG and Pedersen's commitments fulfill this property. Using this, both the verifier's communication and work are constant.

The other necessary property is succinctness: the commitment size must be logarithmic in the opening size. For example, if we have a degree \\( n \\) polynomial, its commitment should take at most \\( \log(n) \\) elements.

## Folding scheme for committed relaxed R1CS

An instance (that is, the public variables) for a committed relaxed R1CS is given by \\( x \\), the public input and output variables, \\( u \\) and the commitments to \\( E \\), \\( \mathrm{cm}(E) \\) and \\( \mathrm{cm}(w) \\). We can group these in the tuple \\( (x,\mathrm{cm}(w),\mathrm{cm}(E),u)\\). The instance is satisfied by a witness (secret variables) \\( (E,r_E,w,r_w)\\) if \\( \mathrm{cm}(E)=\mathrm{Commit}(E,r_E)\\), \\( \mathrm{cm}(w)=\mathrm{Commit}(w,r_w)\\) and \\( Az\times Bz = uCz+E \\), where \\( z=(w,x,u) \\). In simple words, the witness satisfies the instance if the public variables \\( \mathrm{cm}(E) \\) and \\( \mathrm{cm}(w) \\) are indeed the commitments to the private variables \\( E,w \\) using randomness \\( r_E,r_w \\), respectively and they fulfill the relaxed R1CS equations.

The prover and verifier have access to two instances of relaxed R1CS, \\( (x_1,\mathrm{cm}(w_1),\mathrm{cm}(E_1),u_1)\\) and \\( (x_2,\mathrm{cm}(w_2),\mathrm{cm}(E_2),u_2)\\). In addition, the prover has \\( (E_1,r_{E1},w_1,r_{w1})\\) and \\( (E_2,r_{E2},w_2,r_{w2})\\). The protocol proceeds as follows:

1.The prover computes \\( T=Az_1\times Bz_2+Az_2\times Bz_1-u_1Cz_2-u_2Cz_1\\) and sends the commitment to it, \\( \mathrm{cm}(T)=\mathrm{Commit}(T,r_T) \\).  
2\. The verifier samples the random challenge, \\( r \\).  
3\. The prover and verifier output the folded instance,  
\\( \mathrm{cm}(E)=\mathrm{cm}(E_1)+r^2\mathrm{cm}(E_2)+r\mathrm{cm}(T) \\)  
\\( u=u_1+ru_2 \\)  
\\( \mathrm{cm}(w)=\mathrm{cm}(w_1)+r\mathrm{cm}(w_2) \\)  
\\( x=x_1+rx_2 \\)  
4\. The prover updates the witness  
\\( E=E_1+rT+r^2E_2 \\)  
\\( r_E=r_{E1}+rr_T+r^2r_{E2} \\)  
\\( w=w_1+r w_2 \\)  
\\( r_w=r_{w1}+rr_{w2} \\)

The protocol can be made non-interactive by using the Fiat-Shamir transformation.

Using this strategy, we can realize IVC by successively updating the parameters after folding. The prover can then use a zk-SNARK showing that he knows the valid witness \\( (E,r_E,w,r_w) \\) for the committed relaxed R1CS in zero knowledge, that is, without revealing its value.

The problem with using some common SNARKs is that the prover must show that he knows valid vectors whose commitments equal given values. This implies encoding a linear number of group scalar multiplications in the SNARK's model. Therefore, we need a new construction to deal with this problem.

## Polynomial interactive oracle proof (PIOP)

The PIOP is a modified version of Spartan. It is based on the sum-check protocol and multilinear polynomials. For a given function mapping bitstrings to field elements, \\( f:{0,1}^n \rightarrow \mathbb{F}\\), we say that \\( p:{0,1}^n \rightarrow \mathbb{F} \\) is a polynomial extension of \\( f \\) if it is a low degree polynomial satisfying \\( f(x)=p(x) \\) for all \\( x \\) in \\( {0,1}^n \\). We call the extension multilinear if \\( p \\) is a multilinear polynomial such that \\( f(x)=p(x) \\). Multilinear polynomials are polynomials in several variables, such that the degree of each variable is at most 1 in every term. For example, \\( p(x_1,x_2,x_3)=x_1+x_1x_2x_3+x_2x_3 \\) is multilinear (in each term, we have at most \\( x_i \\)), but \\( p(x_1,x_2)=x_1^2x_2 \\) is not.

The R1CS matrices, \\( A,B,C \\) can be thought as functions from \\( {0,1}^m \times {0,1}^m\\) to some finite field \\( \mathbb{F_p} \\) in a natural way. Therefore, we can also make multilinear extensions of them \\( A_{ML}, B_{ML}, C_{ML} \\), that is, \\( 2\log(m) \\) multilinear polynomials. Since the R1CS matrices are sparse, the corresponding multilinear polynomials are sparse (in simple words, they have few non-zero coefficients). The vectors \\( E \\) and \\( w \\) can also be interpreted as polynomials, \\( E_{ML} \\) and \\( w_{ML} \\). The vector \\( z=(w,x,u) \\) and \\( y=(x,u) \\) have also their multilinear extensions \\(z_{ML},y_{ML} \\). We have the following function,  
\\[ F(t)=(\sum_y A_{ML}(t,y)z_{ML}(y))\times (\sum_y B_{ML}(t,y)z_{ML}(y))-\ (u\sum_y C_{ML}(t,y)z(y)+E_{ML}(t)) \\]  
where we sum over all values of \\( y \\) in \\( {0,1}^s \\). We only need to check whether the following identity holds for a randomly sampled \\( \tau \\)  
\\[ \sum_x g(\tau,x)F(x)=0 \\]  
for \\( x \\) in \\( {0,1}^s \\), with \\( g(x,y)=1 \\) for \\( x=y \\) and zero otherwise. We can check that equality by applying the sum-check protocol to the polynomial \\( p(t)=g(\tau,t)F(t) \\)

## Advantages

        * The verifier circuit is lightweight, with little more than 20,000 constraints.
        * It does not need to perform FFT, so no special elliptic curves are required. The only condition is that it is sufficiently secure (that is, the discrete log problem must be hard).
        * The verification is not based on elliptic curve pairings, so expensive operations and pairing-friendly curves are unnecessary.

## Summary

Nova is a new protocol for realizing incrementally verifiable computation based on a new cryptographic primitive called a folding scheme. The key idea is to merge two instances of a given NP statement into a single one. To be able to do so, we have to make changes to the R1CS to include an error term \\( E \\) and a scalar \\( u \\) to obtain a relaxed R1CS, over which we can build an efficient folding scheme. We also need additively-homomorphic polynomial commitment schemes, such as Pedersen commitments. The resulting construction has a small verifier circuit (around 20,000 constraints in R1CS), obtaining fast proof generation and verification. This has many applications to public ledgers, verifiable delay functions, and proof aggregation.
