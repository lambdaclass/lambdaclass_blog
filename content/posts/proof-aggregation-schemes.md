+++
title = "Proof aggregation schemes:  SnarkPack and aPlonk"
date = 2023-01-27
slug = "proof-aggregation-schemes"

[extra]
feature_image = "/content/images/2025/12/A-Roman-Feast.jpg"
authors = ["LambdaClass"]
+++

## Introduction

[zk-SNARKs](/the-hunting-of-the-zk-snark/) are powerful cryptographic primitives, allowing one party, known as the prover, to show to a second party, the verifier, that he knows a given secret, without revealing anything about it. This has applications, for example, in decentralized private computations, where we can delegate an expensive computation to an untrusted server and receive cryptographic proof attesting to the correctness of the computation, without leaking sensitive information. We can also leverage zk-SNARKs to solve the problems of privacy and scalability affecting most decentralized ledgers. There, each node must perform the computation independently to check its validity. This means that the less powerful devices can act as bottlenecks, especially when the computations are expensive, affecting scalability. However, instead of having each node re-execute each computation, we could have them verify a short proof that shows that the computation is correct. In that case, we can lessen the burden on the entire system.

One of the main problems with zk-SNARKs is the proof's generation time. Typically, proof generation involves transforming computations into some NP-complete problem, where we can prove the correctness of the calculation. Among them are [arithmetic circuit satisfiability](/how-to-transform-code-into-arithmetic-circuits/) or systems of quadratic constraints (rank one constraint system, R1CS). We then have to perform some expensive computations, such as multiscalar multiplications ([MSM](/multiscalar-multiplication-strategies-and-challenges/)) and elliptic curve pairings to check the solution. Several strategies have been adopted to lessen the computational cost, such as proof composition, batching, recursion, dealing with an increased number of smaller proofs, and exploiting the advantages of polynomial commitment schemes.

In a [previous post](/incrementally-verifiable-computation-nova/), we covered incrementally verifiable computation (IVC) and folding schemes, which give us ways to realize IVC in practice. We covered the basics of [Nova](https://github.com/microsoft/Nova) and how the folding scheme works. We will now turn our attention to proof aggregation schemes: [SNARKPack](https://eprint.iacr.org/2021/529.pdf) and [aPlonK](https://eprint.iacr.org/2022/1352.pdf). These allow us to reduce the total size of the proofs and their associated verification time: for \\( n \\) proofs, the size and verification time of the aggregated proof will be \\( \mathcal{O}(n) \\), which is a significant reduction, especially for a large number of proofs. SNARKPack is built on top of the Groth16 SNARK, while aPlonk works with the [Plonk](/the-hunting-of-the-zk-snark/) proving system. Both are among the most widely used SNARKs and use trusted setups, resulting from setup ceremonies involving multi-party computations.

## SNARKPack

In the Groth16 scheme, a proof \\( \pi \\) consists of three [elliptic curve](/need-for-speed-elliptic-curves-chapter/) group elements, \\( A,B,C \\). Both \\( A,B \\) belong to the group \\( \mathbb{G_1} \\) and \\( C \\) belongs to the group \\( \mathbb{G_2} \\). The groups have the same [order](/need-for-speed-elliptic-curves-chapter/) (number of elements), \\( p \\) and are among the torsion groups of order \\( p \\) of the elliptic curve over an extension field. We can define a bilinear map (or pairing operation) by taking an element from each group and outputting an element on a third group \\( \mathbb{G_t} \\): \\( e:\mathbb{G_1} \times \mathbb{G_2} \rightarrow \mathbb{G_t}\\). The operation has to fulfill the property \\( e( g^a , h^b ) = e( g , h )^{a b}\\) to be bilinear. In the equation before, \\( a,b \\) are numbers, and \\( g,h \\) are the generators of the groups \\( \mathbb{G_1} \\) and \\( \mathbb{G_2} \\), respectively (we say an element of the group, \\( g \\), is a generator if any element in the group can be obtained by repeatedly adding it). We perform the proof verification in Groth16 via the pairing operation,  
\\[ e(A,C) = Ye(B,D)\\]  
where \\( D \\) is an element of \\( \mathbb{G_2} \\) and \\( Y \\) is an element of \\( \mathbb{G_t} \\). The main idea behind the aggregation of \\( n \\) Groth16 proofs is that we can verify all of them simultaneously by using a random linear combination (up to some tiny error). This way, we only need to perform one pairing operation instead of \\( n \\),  
\\[ \prod e(A_k,C_k)^{ r^k } = \prod Y_k^{ r^k } \prod e(B_k^{ r^k },D)\\]  
where \\( r \\) is a randomly sampled number, and \\( \prod \\) means that we take the product of all possible pairings.

The following terms are defined to ease notation:  
\\( Z_{AC} = \prod e(A_k,C_k)^{ r^k } \\)  
\\( Y_{prod} = \prod Y_k \\)  
\\( Z_B = \prod e(B_k^{ r^{k} },D) \\)  
\\( Z_{AC} = Y_{prod} Z_B \\)  
After checking that this last equation holds, we are left with the task of verifying that, for some initial committed vectors \\( A=(A_1,A_2,...A_n) \\), \\( B=(B_1,B_2,...,B_n) \\) and \\( C=(C_1,C_2,...,C_n) \\), \\(Z_{AC},Z_B \\) are consistent with those specifications. We check this using two inner pairing arguments:

        1. The target inner pairing product (TIPP) shows that \\( Z_{AC} = \prod e( A_k , C_k )^{ r^k } \\).
        2. The multi-exponentiation inner pairing product (MIPP) shows that \\( Z_B = \prod e( B_k^{ r^{k} }, D) \\).

We need efficient commitment schemes with homomorphic and collapsing properties to build these inner pairing products. We say that a commitment is additively homomorphic if, given two elements, \\( a,b \\), the commitment scheme satisfies that \\( \mathrm{cm}(a+b)=\mathrm{cm}(a)+\mathrm{cm}(b) \\). Pedersen and Kate-Zaverucha-Goldberg commitments have this property, for example. To achieve logarithmic proof size, the authors of SNARKPack use the same strategy as bulletproofs, which is based on an inner product argument. These commitments are also homomorphic in the key space: given two keys \\( k_1,k_2 \\) and for any message \\( m \\), we have that \\( \mathrm{cm}(m,k_1+k_2)=\mathrm{cm}(m,k_1)+\mathrm{cm}(m,k_2)\\).

The protocol uses the trusted setups of two large setup ceremonies: Filecoin and Zcash. In Groth16, the structured reference string (SRS), which is the outcome of the ceremony, consists of the powers of a random element \\( \tau \\), hidden inside the groups \\( \mathbb{G_1}, \mathbb{G_2} \\). Given the generators \\( g,h \\), the SRS is given by \\( {g, g^\tau , g^{ \tau^2 },...g^{ \tau^d }}={g,g_1,g_2,...} \\) and \\( {h, h^\tau , h^{ \tau^2 },...,h^{ \tau^d }}={h,h_1,h_2,...} \\). These will allow us to commit to polynomials and verify claims over them.

We can now create pair group commitments by using the two SRS. To ease notation, we will call

        1. \\( w_1 = (g,g_{11}, h_{12},...) \\) and \\( v_1 = (h,h_{11},h_{12},...) \\) are the SRS for ceremony 1.
        2. \\( w_2 = (g,g_{21}, h_{22},...) \\) and \\( v_2 = (h,h_{21},h_{22},...) \\) are the SRS for ceremony 2.

There are two versions of these commitments: single group and double group. The former takes as commitment key \\( k_s=(v_1,v_2) \\), while the latter uses \\( k_d=(v_1,w_1,v_2,w_2) \\).

The single group commitment takes a vector \\( A \\) and the key \\( k_s \\) and outputs two group elements:  
\\[ \mathrm{cm_S}(A,k_s)=(t_A,u_A)\\]  
where  
\\( t_A=e(A_1,h)\times e(A_2,h_{11})\times e(A_3,h_{12})\times.... = A\cdot v_1 \\)  
\\( t_A=e(A_1,h)\times e(A_2,h_{21})\times e(A_3,h_{22})\times.... = A\cdot v_2 \\)

The double commitment takes vectors \\( A \\) and \\( C \\) formed of elements in \\( \mathbb{G_1} \\) and \\( \mathbb{G_2} \\), respectively and \\( k_d \\) and outputs two elements:  
\\[ \mathrm{cm_d}(A,C)=(t_{AC},u_{AC}) \\]  
with  
\\( t_{AC} = (A\cdot v_1)(C\cdot w_1) = (\prod e(A_k,h_{1,{k-1}})(\prod e(g_{1,k-1},C_k)) \\)  
\\( u_{AC}=(A\cdot v_2)(C\cdot w_2) = (\prod e(A_k,h_{2,{k-1}})(\prod e(g_{2,{k-1}},C_k)) \\)

We will use the double commitment in conjunction with TIPP to show that \\( Z_{AC} = \prod e(A , C)^{ r^k } \\), while the MIPP will be used with the single commitment to see that \\( Z_B = \prod e(B_k^{ r^k },D) \\). There are two relations to be checked:  
\\[ \mathcal{R_{MIPP}}={ (t_B,u_B,r,Z_B,B,r_v ): Z_B=B_k^{ r^k } \wedge (u_B,t_B) = \mathrm{cm_s}(B) \wedge (r_v)_{i} = r^{i-1} }\\]

\\[ \mathcal{R_{TIPP}} = (t_{AC},u_{AC},r,Z_{AC},A,C,r_v ): Z_{AC} = \prod e(A_k,C_k)^{ r^k } \wedge \\]

\\[ (u_{AC},t_{AC}) = \mathrm{cm_d}(A,C) \wedge (r_v)_{i} = r^{i-1} \\]

In simple words, in each relation, we check that the value is correct and that the commitments are valid.

For the exact details of the proving and verification algorithms, we refer the reader to the [source](https://eprint.iacr.org/2021/529.pdf).

In the case studies shown, the aggregation scheme outperforms batch verification in size and time at slightly more than 100 proofs.

## aPlonk

[aPlonk](https://eprint.iacr.org/2022/1352.pdf) builds on the ideas of SNARKPack, using a different proving system (Plonk) and introducing multi-polynomial commitments to achieve sublinear size in the number of polynomials. The key idea is to verify several proofs by performing a random linear combination of commitments and checking it. The notation is slightly different since the authors of aPlonk use additive notation when working with groups, whereas the authors of SNARKPack use multiplicative notation. If \\( \mathrm{cm}(p_k) \\) is a commitment to a polynomial \\( p_k \\) (which, if we use KZG commitments, is an elliptic curve element), then we can verify all of them by doing  
\\[ \sum r^k \mathrm{cm}(p_k)=\beta \\]  
and checking that \\( \beta \\), at point \\( z \\), opens (evaluates) to  
\\( v=\sum r^k v_k \\)  
where \\( v_k \\) is the value of \\( p_k(z) \\). Had we used multiplicative notation, the previous equation would have read  
\\[ \prod (\mathrm{cm}(p_k))^{ r^k }=\beta \\]  
To achieve the sublinear size, the prover will commit to the commitments of the polynomials, that is \\( \beta=\mathrm{cm}(\mathrm{cm}(p_1),\mathrm{cm}(p_2)...)\\).  
Since we are calculating a linear combination using the powers of \\( r \\), it is natural to use a polynomial commitment scheme, such as KZG or inner product arguments (IPA).

Plonk's constraint system has the following expression  
\\[ q_{L_i}x_{a_i}+q_{R_i}x_{b_i}+q_{O_i}x_{C_i}+q_{M_i}x_{a_i}x_{b_i}+q_{C_i}=0\\]  
and can be extended to include higher-order terms or custom gates. For each \\( q_k \\) we can define an univariate polynomial, \\( q_L(x),q_R(x),q_O(x),q_M(x),q_C(x) \\) by having each polynomial evaluate to their corresponding \\( q_{k_i} \\) at the n primitive roots of unity \\( \omega_i \\) (We say that \\( \omega_i) \\) is a primitive n-th root of unity if \\( \omega_i^n=1 \\) and \\( \omega_i^k \neq 1 \\) if \\( k < n \\). In addition, the prover has to show that the relations between the indices \\( a_i,b_i,c_i \\) are related by permutations. These permutations are also expressed in terms of polynomials. Therefore, we have to commit to a total of 8 polynomials.

One key building block is the multi-polynomial commitment scheme. This comprises of 5 efficient algorithms, \\( \mathrm{setup},\mathrm{commit- polynomial},\mathrm{commit-evaluation},\mathrm{open},\mathrm{check}\\); the main difference is the addition of the \\( \mathrm{commit-evaluation} \\) algorithm. The multi-polynomial commitment is built upon two polynomial commitment schemes: KZG and IPA.

One important optimization is that all polynomials are evaluated at the same random challenge \\( r \\), given by the Fiat-Shamir heuristic. Therefore, provers must obtain \\( r \\) from the partial transcript of all proofs, requiring that the proofs of each statement run coordinately. Even if this prevents the construction of incrementally-verifiable computation (IVC), since in that case, the proofs are generated one after the other, the construction works well for validity rollups.

## Summary

Proof aggregation schemes are an alternative to reduce the size and verifying time of many zk-SNARKs. In particular, we can obtain proof sizes and verification times of order \\( \mathcal{O}(\log(n)) \\) for \\( n \\) proofs. Proof aggregation outperforms batching techniques for slightly more than 100 proofs and has a clear advantage when we add together more than 1000 proofs. The main building blocks to achieve these properties are homomorphic polynomial commitments (such as KZG), two trusted setups, and the fact that we can verify many proofs by taking a random linear combination, using as coefficients the powers of some number \\( r \\).
