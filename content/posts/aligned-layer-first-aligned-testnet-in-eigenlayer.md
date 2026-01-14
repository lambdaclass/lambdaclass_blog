+++
title = "Aligned Layer: First Aligned Testnet in EigenLayer"
date = 2024-05-03
slug = "aligned-layer-first-aligned-testnet-in-eigenlayer"

[extra]
feature_image = "/images/2025/12/Baron_Franc--ois_Pascal_Simon_Ge--rard_-_Marius_Returning_to_Rome_-_Google_Art_Project.jpg"
authors = ["LambdaClass"]
+++

## Introduction

Zero-knowledge and validity proofs have gained attention due to their capabilities in decentralized private computation, scaling blockchains, identity protocols, and verifiable machine learning, among others. They allow one party, the prover, to show to other parties, the verifiers, that a given statement is true in a time- and memory-efficient way. Zero-knowledge proofs allow us to prove the statement without revealing anything else other than its validity. They are becoming one of the main building blocks in web3. However, even though the technology has been around since the mid 1980's, it was not at the heart of Bitcoin and Ethereum due to the lack of efficient constructions for such applications. This leads to restrictions in the types of proof systems we can verify, introduces overhead in verification time and costs in Ethereum, and also increases development and go-to-market times, since we have to optimize the verification contracts to reduce gas usage (and, therefore, costs). [Aligned Layer](https://whitepaper.alignedlayer.com/), powered by EigenLayer, provides a decentralized network of verifiers that can check proofs from any proof system in a fast and cost-effective way.

With the introduction of zk-rollups and identity protocols, the demand for on-chain verification of zero-knowledge proofs has increased dramatically. These verifications compete for blockspace with other applications in Ethereum, such as DeFi and NFTs, leading to increasing costs. Luckily, there are ways of reducing on-chain verification, at the expense of time overhead, and a low marginal off-chain cost. Aligned Layer offers a solution without introducing time overhead, and lets developers choose whether they want to wait for the proof to be verified on Ethereum before proceeding further.

This post will explain what are succinct, non-interactive arguments of knowledge, how proofs are verified in Ethereum, strategies to reduce costs, what can Aligned Layer offer to Ethereum and how it differs from aggregation layers, with the capacity to verify several orders of magnitude more proofs than Ethereum.

## Succinct, Non-Interactive Arguments of Knowledge (SNARKs)

Succinct, non-interactive arguments of knowledge (SNARKs) allow us to prove the validity of a statement in a way that is much faster than it would take to check it naïvely. For example, say we wanted to show that we computed the 1,073,741,824th Fibonacci number correctly. The simplest way anyone could check the calculation is by recomputing the whole sequence, $a_0 = 1$, $a_1 = 1$, $a_2 = 2$, $a_3 = 3$, $a_{n + 2} = a_{n + 1} + a_n$, which is reexecuting the computation we did. This is how blockchains solved the issue of agreement between different parties: reexecution and consensus. However, this proves computationally intensive and it is problematic if we want to check computations we cannot check by ourselves due to limited computing power. SNARKs achieve sublinear verification (typically, logarithmic time verification), which means that we need to perform less work. It also means that we do not need to know all the steps in the computation (more precisely, we do not need the whole witness). Using STARKs, proof sizes and verification times are in the order of $\log^2 n$, where $n$ is the length of the program. In the case of our Fibonacci, $n = 2^{30}$, so proof sizes and times would be some constants times $30^2 = 900$, which is way smaller than $2^{30}$. So, instead of reexecution, we verify proofs, saving huge amounts of time and memory.

There are different SNARK constructions, based on either linear probabilistically checkable proofs (PCP) -such as Groth 16- and interactive oracles proofs (IOP) -such as Plonk or STARKs-, using different cryptographic assumptions and commitment schemes (collision resistant hash functions, hardness of the discrete log problem, knowledge of exponent), presence or absence of trusted ceremonies, arithmetization schemes, using multivariate or univariate polynomials, etc. This results in a wide variety of SNARKs, with different trade-offs in proof size, verification time, prover time, and the types of applications they are suited for. At the beginning the construction of SNARKs involved expressing the computations as circuits, which was a developer intensive operation, requiring expert knowledge and error/bug prone. With the advent of general purpose zkvms this task has been greatly simplified, allowing developers to write their programs in a higher level language, such as Rust, and prove them without having to write the circuits themselves.

## Verification in Ethereum

We have several options to prove computations, depending on our needs. However, not all proof systems are easy or cheap to verify in Ethereum, due to two factors: storage and gas costs associated with running the verification algorithm. [For example](https://a16zcrypto.com/posts/article/measuring-snark-performance-frontends-backends-and-the-future/), the cost of verifying a STARK is around 5,000,000 gas, while Plonk based proofs are below 1,000,000 gas. Due to precompiles, SNARKs based on pairings (such as Groth 16 and proof systems using the KZG commitment scheme) tend to be less expensive, since the pairing operation costs around 200,000 gas and elliptic curve operations of the BN254 elliptic curve, such as addition and scalar multiplication are rather cheap.

There are several limitations to the proof systems we can verify directly in Ethereum. For example, inner product argument based proof systems such as Mina's Kimchi (which has efficient recursion via Pickles) or Brakedown-based such as Binius (with square root sized proofs) become very expensive to verify, either because of the number of operations they involve or because of proof size.

In order to verify these proofs, we need to wrap them using a more cost effective solution for Ethereum, such as KZG Kimchi for Mina. However, this comes at the expense of simulating costly operations such as foreign field arithmetic and lots of elliptic curve operations, taking a lot of effort in terms of development and go-to-market time. Besides, if you invent a new proof system which is very efficient but not EVM-friendly, you need to spend a lot of time developing the wrapper to make it cheap to verify in the EVM.

## Amortizing costs

The best ways to reduce costs in Ethereum are related to shrinking proof and public input size (thus reducing storage) and proving large computations instead of shorter ones (for example, verifying a proof for all the transactions in one block is way less expensive than verifying each transaction separately). The first strategy involves using constant proof size SNARKs, such as Groth 16 or Plonk, and providing a commitment to the public input, instead of the whole public input. The second one involves bundling several computations in one, such as all the transactions in one block. This idea was used in Starknet, proving the execution of the bootlader program in the Cairo-vm. However, many proof systems have greater memory use when proving larger computations, limiting the size of the computations we can prove using this approach. To deal with these issues, we can use recursive proof composition to aggregate several proofs into one; thus, the cost of verification in Ethereum will be split between the different computations we checked.

## Batch verification

Some schemes allow for batch verification: by doing some extra operations, we can check several proofs together, splitting most of the cost between the proofs. For example, if we have several evaluation proofs from a KZG commitment scheme, we can check them together by sampling random scalars, instead of verifying each separately. Even though one KZG verification can be expensive (it involves one pairing operation), by batching several proofs together, the cost per proof becomes negligible. BLS signatures exploit this property, too. Even though the BLS signatures are more expensive to check than ECDSA signatures, with batch verification we can make overall verification costs much smaller.

## Aggregation

Proof aggregation is usually carried out by recursive verification, using an n-ary tree structure (one common case is a binary tree, taking 2 proofs and producing a proof of the correctness of the verification of the two proofs). However, this is not the only technique available. For an overview of some techniques, see our [previous blog post](/proof-aggregation-techniques/). Proof recursion is a good technique for aggregation, but it usually involves expensive operations. For example, it may involve non-native arithmetic (the proof we want to verify is over some finite field, but the verification's proof is over a different field), performing expensive elliptic curve operations such as pairings or calculating many hashes (in hash-based systems, such as STARKs).

Some projects focus on reducing costs by providing proof aggregation, either as a service or as part of their protocol (for example, rollups). However, proof aggregation is limited to a few proof systems, and they incur in some overhead. Since they want to achieve cheap verification in Ethereum, they have to end up wrapping their proofs into an EVM-friendly proof.

## Looking for speed?

The main drawbacks with proof aggregation are the overhead associated with the aggregation and the need for several proofs to bundle together. This means that we have an increase in latency (which could make some applications infeasible) and that some applications may have trouble in scaling (for example, you are just starting a new protocol which is not widely used yet, or you offer a very valuable service but does not have many users).

Aligned Layer offers fast and cheap verification, which is different from proof aggregation. Aligned Layer can be faster than Ethereum because of the following reasons:

        1. Aligned Layer does not run the verification on top of the EVM. It just runs the code natively in CPUs or even in GPUs.
        2. Aligned Layer can leverage parallelization, which is something Ethereum cannot.
        3. The EVM cannot process operations exceeding 30,000,000 gas per block, even if there is unused computing capacity.
        4. Ethereum verifiers are optimized for gas usage, whereas verification in Aligned Layer can be optimized for speed. Use of faster finite field arithmetic, more efficient elliptic curve operations or faster hashing will result in higher throughput in Ethereum.
        5. Aligned Layer can use other DA layers to further reduce storage costs.
        6. Aligned Layer can verify proof systems that are not feasible in Ethereum, either because their proof size is large or the operations involved are expensive in Ethereum (such as Kimchi or Binius).
        7. Since verification costs in Aligned Layer are smaller than Ethereum, the demand for ZK verification is very likely to increase due to lower entry costs.

To see the potential advantages of Aligned Layer for verification over Ethereum, we will do some rough estimates of performance. The numbers are summarized in the following table:

Proof System | Groth 16 | STARKs  
---|---|---  
Gas cost Ethereum | 220,000 | 5,000,000  
Proofs per block in Ethereum | 136 | 6  
Verification time, consumer-end hardware (ms) | 1-3 | <25  
Proofs per block time | 4000 | 480  
Improvement over Ethereum | 29x | 80x  
  
A Groth16 proof costs between 220,000 gas and 300,000 gas; using the full capacity of Ethereum, this amounts to at most 136 verifications every 12 seconds. Verification of the same proofs in consumer grade hardware, without parallelization, takes between 1 and 3 ms, leading to at least 4,000 Groth16 proofs over the same period of time, nearly 30 times more proofs. For STARK proofs, which cost around 5,000,000 gas, it is just 6 proofs per block. STARK verification over CPUs depend on program size, but could be below 25 ms, leading to at least 480 proofs, an 80x improvement. The numbers of Ethereum represent its maximum nominal capacity and will not improve unless the gas limit is increased or proof gas use is further reduced (however, there are other applications running on Ethereum, which compete for this limited verification capacity). Aligned Layer can use more powerful devices, optimize code for speed and leverage a high degree of parallelization. Moreover, since Aligned Layer only verifies proofs, its computing power is not shared with other applications.

## Advantages of having a fast and a slow mode

Aligned Layer offers the best of both worlds with its fast and slow modes. Aligned Layer's goal is to verify any proof system quickly and new proof systems can be incorporated easily. After getting Aligned Layer's verification, which is backed by a subset of Ethereum's validators, developers can use the result to move forward. It is also cheaper since it is not constrained by the EVM. Besides, if you develop a new proof system, you just need to provide the verifier code in Rust and have no need to code a wrapper, reducing development time.

Having cheap verification makes easier for protocols and applications to adopt zero-knowledge proofs, reducing the barrier of entry. Besides, it helps scale zero-knowledge proofs since the amount of proofs per unit time increases, making it easier to achieve a reasonable number of proofs to aggregate and check in Ethereum, leading to a reduction in the cost of verification per proof. The slow mode adds additional security since the final verification is done in Ethereum. Moreover, if the validators misbehaved in the fast mode, the slow mode will override any results they provided and lead to slashing.

## Conclusions

There has been a growing demand for zero-knowledge proofs due to their applications in decentralized private computing, blockchain scalability, verifiable machine learning and identity protocols. The demand for on-chain verification in Ethereum has grown, but single proof verification costs remain high and compete with other applications. Proof aggregation reduces costs by bundling several proofs into one, at the expense of higher latency, and a small marginal off-chain cost, which is expected to go down as prover technology improves. However, the overhead introduced and the need for a sufficiently large number of proofs limit the types of applications that can effectively leverage zero-knowledge proofs, due to latency requirements or scale. Aligned Layer provides a decentralized network of verifiers, backed by the trust of Ethereum via EigenLayer, providing fast and cheap verification of proofs, providing low latency verification and low costs. It is different from aggregation layers, since its main goal is to verify proofs and allow developers to choose the best proof system for their needs. Aggregation works by bundling proofs and dividing the fixed cost of verification between the proofs but developers must wait until settlement in Ethereum. In Aligned Layer, it is up to developers to choose whether they prefer the fast or the slow mode. We think Aligned Layer will accelerate the adoption of zero-knowledge proofs in applications and, together will EigenLayer, will help bring further innovation to Ethereum.
