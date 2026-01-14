+++
title = "Decentralized private computation: ZEXE and VERI-ZEXE"
date = 2023-01-13
slug = "decentralized-private-computations-zexe-and-veri-zexe"

[extra]
feature_image = "/images/2025/12/Charles_Le_Brun_-_Entry_of_Alexander_into_Babylon.jpeg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["zero knowledge proofs"]
+++

## Introduction

The [ZEXE](https://eprint.iacr.org/2018/962.pdf) (Zero-knowledge EXEcution) protocol appeared in 2018, introducing the cryptographic primitive of decentralized private computation (DPC). It aims to solve two main drawbacks that decentralized ledgers suffer: privacy and scalability.

Let's take the examples of Bitcoin and Ethereum. We see that the history of all transactions is public (which could leak sensitive information on your company's suppliers, acquaintances, or the services you hire). Ethereum offers programmability but requires each node to execute every operation, where the least powerful device acts as a bottleneck. ZCash tackles the privacy problem but does not offer programmability, just private transactions. ZEXE tries to get the best of both worlds:

        * Privately running arbitrary programs.
        * Being able to run computations offline.
        * Providing proof of the integrity of the computations, which nodes can verify quickly.

For an overview of the protocol, we recommend our previous post on [ZEXE](/fully-private-applications-a-zexe-protocol/). As a quick reminder, the protocol offers the following features:

        1. Programmability: we can run arbitrary programs.
        2. Fast verification: we can prove the validity of our computations by using zk-SNARKs (zero-knowledge Succinct Non-interactive ARguments of Knowledge), which offer short (succinct) proofs that verifiers can check on-chain in a few milliseconds.
        3. Data and function privacy: the protocol hides relevant input information and functions when we execute transitions in the ledger.

The ZEXE protocol has seen several improvements since its introduction to enhance its performance. This post will analyze the differences between the original protocol and a recent proposal, [VERI-ZEXE](https://eprint.iacr.org/2022/802.pdf). The authors of VERI-ZEXE compared their protocol's performance with the original proposal of ZEXE and its early modifications. There are no comparisons between the current improved versions of the ZEXE protocol and VERI-ZEXE.

## Building blocks

We mentioned that the ZEXE protocol uses zk-SNARKs, which allow us to provide proofs of integrity for given computations, which anyone can verify much faster than the naïve approach of re-execution. The highest cost of the system is related to the generation of the proof, which relies on elliptic curve operations. You can look at the basics of some SNARK systems in [our previous post](/the-hunting-of-the-zk-snark/).

Modern proof systems have two main building blocks: a polynomial interactive oracle proof -PIOP- (which transforms a given computation into polynomial equations) and a polynomial commitment scheme -PCS-. We get different proving systems depending on our choices, each of which has advantages and disadvantages. Some examples of PIOPs are Marlin, PLONK (Permutations over Lagrange-bases for Oecumenical Noninteractive arguments of Knowledge) -and all its derivates- and Spartan. Among the PCS, we have KZG (Kate-Zarevucha-Goldberg), FRI (Fast Reed-Solomon Interactive Oracle Proofs of Proximity), Bulletproofs, and DARK (Diophantine ARgument of Knowledge), to name a few.

To be able to perform proofs in a fast and efficient way, we need "SNARK-friendly" cryptographic primitives and operations. A function is "SNARK-friendly" if its representation as an arithmetic circuit is small. For example, intuitive and straightforward bitwise operations such as AND and XOR have a complex circuit representation. Therefore, the cost of functions in the context of SNARKs must consider the complexity of the arithmetic circuit used to represent the operation and its variables.

A great deal of the cost in SNARK systems comes from:

        * Multiscalar multiplication ([MSM](/multiscalar-multiplication-strategies-and-challenges/)). These are operations of the form \\( Q= \sum_k a_k P_k \\), where \\( a_k \\) are numbers and \\( P_k \\) are points belonging to an elliptic curve.
        * Elliptic curve pairings. These are used in the verification of some systems. They involve field extensions and operations between different groups of elliptic curves.
        * Polynomial evaluations over non-native fields.
        * Fiat-Shamir transform: a hash function is needed to generate the challenges. Many well-established cryptographic primitives have complicated representations as arithmetic circuits, which makes their evaluation costly.

Research efforts are attempting to solve all of these problems. GPUs or FPGA can [speed up the calculation of MSM](https://www.zprize.io/prizes/accelerating-msm-operations-on-gpu-fpga). New hash functions and encryption schemes with nicer arithmetic circuits can further reduce the complexity of frequently used cryptographic primitives (for example, [Poseidon](https://eprint.iacr.org/2019/458.pdf) and [Vision and Rescue](https://tosc.iacr.org/index.php/ToSC/article/view/8695/8287)).

## VERI-ZEXE's choices

To tackle these problems, VERI-ZEXE changes the proving system and cryptographic primitives. Here are some of the main modifications:

        * PLONK as PIOP. Over the last years, PLONK has seen several significant improvements, such as high-degree custom gates, the use of lookup tables, and the use of multilinear polynomials (which avoids using fast Fourier transform) (such as turboPLONK, ultraPLONK, and [hyperPLONK](https://eprint.iacr.org/2022/1355.pdf)).
        * Lightweight verifier circuit via [accumulation scheme](https://eprint.iacr.org/2020/499.pdf). The protocol moves out the pairing check from the SNARK circuit and delays the verification to the ledger's validators.
        * Instance merging. When performing transactions, birth and death predicates of records have to be checked. Instead of verifying each predicate separately, the protocol leverages that the predicates can be taken in birth/death pairs, resulting in a larger predicate. However, since the verification of the combined predicate has a simpler circuit representation (this means that the number of operations does not scale linearly), the overall cost is reduced.
        * Proof batching. We can generate and verify proofs in batches by exploiting the properties of some PCS, such as KZG. These allow the opening of \\( N \\) different commitments simultaneously, with a cost that does not scale linearly in the number of commitments (that is, you can open \\( N \\) commitments for less than the cost of \\( N \\) separate openings).
        * Variable base MSM via a lookup table. The MSM is carried out by combining Pippenger's algorithm (which splits the scalars into blocks) with a [lookup table](https://eprint.iacr.org/2020/315.pdf), reducing the cost of elliptic curve additions.
        * Polynomial evaluation over non-native fields. The circuits of the prover and the verifier lie in different finite fields. One way to deal with this was using two pairs of elliptic curves. VERI-ZEXE uses modular addition and multiplication with range check with lookup, resulting in a slightly more complicated circuit.
        * SNARK-friendly symmetric primitives. Using collision-resistant hash functions, pseudorandom generators, and commitment schemes with a smaller circuit representation (which reduces the number of operations), resulting in less memory and time use. For example, the Fiat-Shamir transformation uses the sponge construction of the Rescue permutation.

The use of PLONK and its additions, together with simpler constructions for cryptographic primitives, results in a reduction of more than one order of magnitude in the total number of constraints, which in turn decreases the scale of the MSM multiplications and overall proving time.

## Accumulation schemes (AS) and Incrementally verifiable computation (IVC)

The verification of proofs requires the calculation of costly pairing operations. The original ZEXE protocol used incrementally verifiable computation to prove the satisfiability of user-defined predicates using SNARK recursion: given a computation at step \\( N \\), the prover would receive the state \\( z_{N} \\) and a proof \\( \pi_{N-1} \\) attesting to the correct execution of the previous step. The prover would then execute step \\( N \\) and generate a proof \\( \pi_N \\) which certifies that "the new state \\( z^\prime \\) is the result of the correct execution and that \\( \pi_{N-1} \\) is true (in other words, that the prover did the \\( N-1 \\) previous steps correctly)". In this last step, the computational burden comes in: to check the proof, the verifier's computation is embedded inside the prover's circuit, which slows down the proof's generation.

An accumulation scheme proceeds differently by delaying the verification of the final proof to the ledger's validators. At each step of the calculation, the prover receives the current state and an accumulator, which is partially verified (the prover checks that the accumulation results are correct but does not calculate the elliptic curve pairing operation). The group elements in the accumulator must be masked using a randomizer, which acts as an additional witness (secret input) for the accumulator's verifier. This masking ensures that the accumulator does not leak information on the computations being carried out,

## Lookup tables and efficient modular operations

Using lookup tables for elliptic curve addition in the Pippenger algorithm and efficient operations for modular arithmetic reduces the number of PLONK constraints by a factor of 6.

The idea behind lookup tables for MSM is as follows:  
\\[ Q= \sum_i a_i P_i \\]  
The Pippenger algorithm splits the scalars \\( a_i \\) into \\( m \\) windows of length \\( c \\) (For example, a scalar is a 256-bit number, and we choose a window of 8-bits). We can write each scalar as  
\\[ a_i= \sum_j a_{ij}2^{mj}\\]  
where each \\( a_{ij} \\) is in the range \\( {0,1,...,2^c-1} \\). We can compute, for each point \\( P_i \\) all possible combinations of scalars values \\( 2P_i,3P_i,4P_i,...,(2^c-1)P_i\\).

We can now calculate the result \\( Q_{ij}=a_{ij}P_i\\) by looking at the table (which has a more straightforward description than pure elliptic curve operations) and get the results of the j-th bucket,  
\\[ B_j = \sum_i Q_{ij} \\]  
We can get the final result by finally adding over the \\( m \\) buckets,  
\\[ Q=\sum_j B_j 2^{cj}\\]

## Further improvements from HyperPlonk?

![](/images/external/xymqID7.jpg)

VERI-ZEXE uses PLONK with lookup tables, resulting in fewer constraints and shorter proving times. Two weeks ago, HyperPLONK came out, providing linear time prover and high-degree custom gates. One of the key changes is the shift from univariate polynomials (polynomials in one variable, \\(x \\), such as \\(a_0+a_1x+a_2x2+...a_dxd \\)) to multivariate linear polynomials (polynomials in several variables, where the degree of each \\( x_k \\) is at most one, such as \\( a_0 +a_1x_1+a_2x_2+a_{12}x_1x_2+a_{145}x_1x_4x_5 \\)). This change avoids using the fast Fourier transform (FFT) for very large systems (with over \\(2^{20} \\) constraints), which has a superlinear cost (roughly speaking, the FFT for \\( n \\) points needs \\( n\log(n) \\) operations). Preliminary studies have shown that this new PLONK version performs better for circuits with more than 16000 constraints compared to optimized versions of the original proposal. We will cover this topic in an upcoming post.

## Summary

ZK proofs are the key to many new applications, such as decentralized finances, governance, etc. The ZEXE protocol introduced the concept of decentralized private computation, allowing users to run private applications over public ledgers. The original proposal was based on non-universal proving systems, which have efficient performance but require a new trusted setup for each program we want to run. Since then, several significant improvements in proving systems (such as Marlin and PLONK) and new "SNARK-friendly" cryptographic primitives (such as symmetric ciphers and hash functions) have been introduced, resulting in increased performance and lower computational costs. These changes allow less powerful devices to act as provers and run more complex programs.
