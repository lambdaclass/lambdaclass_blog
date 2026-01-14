+++
title = "Our highly subjective view on the history of Zero-Knowledge Proofs"
date = 2024-02-17
slug = "our-highly-subjective-view-on-the-history-of-zero-knowledge-proofs"

[extra]
feature_image = "/images/2025/12/La_bataille_d-Austerlitz._2_decembre_1805_-Franc--ois_Ge--rard-.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["zero knowledge proofs"]
+++

Zero-knowledge, Succinct, Non-interactive ARguments of Knowledge (zk-SNARKs) are powerful cryptographic primitives that allow one party, the prover, to convince another party, the verifier, that a given statement is true without revealing anything else other than the validity of the statement. They have gained widespread attention due to their applications in verifiable private computation, providing proof of the correctness of the execution of computer programs and helping scale blockchains. We think SNARKs will have a significant impact in shaping our world, as we describe in our [post](/transforming-the-future-with-zero-knowledge-proofs-fully-homomorphic-encryption-and-new-distributed-systems-algorithms/). SNARKs acts as an umbrella for different types of proof systems, using different polynomial commitment schemes (PCS), arithmetization schemes, interactive oracle proofs (IOP) or probabilistically checkable proofs (PCP). However, the basic ideas and concepts date back to the mid-1980's. The development significantly accelerated after the introduction of Bitcoin and Ethereum, which proved to be an exciting and powerful use case since you can scale them by using Zero-Knowledge proofs (generally called Validity Proofs for this particular usecase). SNARKs are an essential tool for blockchain scalability. As Ben-Sasson describes, the last years have seen a [cambrian explosion of cryptographic proofs](https://medium.com/starkware/cambrian-explosion-of-cryptographic-proofs-5740a41cdbd2). Each proof system offers advantages and disadvantages and was designed with certain tradeoffs in mind. Advances in hardware, better algorithms, new arguments, and gadgets result in enhanced performance and the birth of new systems. Many of them are used in production, and we keep pushing the boundaries. Will we have a general proof system for all applications or several systems suited for different needs? We think that it is unlikely that one proof system will rule them all because:

        1. The diversity of applications.
        2. The types of constraints we have (regarding memory, verification times, proving times).
        3. The need for robustness (if one proof system gets broken, we still have others).

Even if proof systems change a lot, they all offer a significant property: proofs can be verified quickly. Having a layer that verifies proofs and can be easily adapted to handle new proof systems solves the difficulties associated with changing the base layer, such as Ethereum. To give an overview of the different characteristics of SNARKs:

        * Cryptographic assumptions: collision-resistant hash functions, discrete log problem over elliptic curves, knowledge of exponent.
        * Transparent vs trusted setup.
        * Prover time: linear vs superlinear.
        * Verifier time: constant time, logarithmic, sublinear, linear.
        * Proof size.
        * Ease of recursion.
        * Arithmetization scheme.
        * Univariate vs multivariate polynomials.

This post will look into the origins of SNARKs, some fundamental building blocks, and the rise (and fall) of different proof systems. The post does not intend to be an exhaustive analysis of proof systems. We focus instead on those that had an impact on us. Of course, these developments were only possible with the great work and ideas of the pioneers of this field.

## Fundamentals

As we mentioned, zero-knowledge proofs are not new. The definitions, foundations, important theorems, and even important protocols were established from mid-1980s. Some of the key ideas and protocols that we use to build modern SNARKs were proposed in 1990s (the sumcheck protocol) or even before the advent of Bitcoin (GKR in 2007). The main problems with its adoption were related to the lack of a powerful usecase (internet was not as developed in the 1990s), and the amount of computational power needed.

### Zero-knowledge proofs: the origins (1985/1989)

The field of zero-knowledge proofs made its appearance in academic literature with the paper by [Goldwasser, Micali and Rackoff](https://people.csail.mit.edu/silvio/Selected%20Scientific%20Papers/Proof%20Systems/The_Knowledge_Complexity_Of_Interactive_Proof_Systems.pdf). For a discussion on the origins, you can see the [following video](https://www.youtube.com/watch?v=uchjTIlPzFo). The paper introduced the notions of completeness, soundness, and zero-knowledge, providing constructions for quadratic residuosity and quadratic non-residuosity.

### Sumcheck protocol (1992)

The [sumcheck protocol](/have-you-checked-your-sums/) was proposed by [Lund, Fortnow, Karloff, and Nisan](https://dl.acm.org/doi/pdf/10.1145/146585.146605) in 1992. It is one of the most important building blocks for succinct interactive proofs. It helps us reduce a claim over the sum of a multivariate polynomial's evaluations to a single evaluation at a randomly chosen point.

### Goldwasser-Kalai-Rothblum (GKR) (2007)

The [GKR protocol](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/12/2008-DelegatingComputation.pdf) is an interactive protocol that has a prover that runs linearly in the number of gates of a circuit, while the verifier runs sublinearly in the size of the circuit. In the protocol, the prover and verifier agree on an arithmetic circuit of fan-in-two over a finite field of depth $d$, with layer $d$ corresponding to the input layer and layer $0$ being the output layer. The protocol starts with a claim regarding the output of the circuit, which is reduced to a claim over the values of the previous layer. Using recursion, we can turn this into a claim over the circuit's inputs, which can be checked easily. These reductions are achieved via the sumcheck protocol.

### KZG polynomial commitment scheme (2010)

[Kate, Zaverucha, and Goldberg](https://www.iacr.org/archive/asiacrypt2010/6477178/6477178.pdf) introduced in 2010 a commitment scheme for polynomials using a bilinear pairing group. The commitment consists of a single group element, and the committer can efficiently open the commitment to any correct evaluation of the polynomial. Moreover, due to batching techniques, the opening can be done to several evaluations. KZG commitments provided one of the basic building blocks for several efficient SNARKs, such as Pinocchio, Groth16, and Plonk. It is also at the heart of the [EIP-4844](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-4844.md). To get an intuition on batching techniques, you can see our post on the [Mina-Ethereum bridge](/mina-to-ethereum-bridge/).

## Practical SNARKs using elliptic curves

The first practical constructions for SNARKs appeared in 2013. These required a preprocessing step to generate the proving and verifying keys, and were program/circuit specific. These keys could be quite large, and depended on secret parameters which should remain unknown to the parties; otherwise, they could forge proofs. Transforming code into something that could be proven required compiling the code to a system of polynomial constraints. At first, this had to be done in a manual way, which is time-consuming and error-prone. The advances in this area tried to remove some of the main problems:

        1. Have more efficient provers.
        2. Reduce the amount of preprocessing.
        3. Having universal rather than circuit specific setups.
        4. Avoid having trusted setups.
        5. Developing ways to describe circuits using a high-level language, instead of writing the polynomial constraints manually.

### Pinocchio (2013)

[Pinocchio](https://eprint.iacr.org/2013/279) is the first practical, usable zk-SNARK. The SNARK is based on quadratic arithmetic programs (QAP). The proof size was originally 288 bytes. Pinocchio's toolchain provided a compiler from C code to arithmetic circuits, which was further transformed into a QAP. The protocol required that the verifier generate the keys, which are circuit-specific. It used elliptic curve pairings to check the equations. The asymptotics for proof generation and key setup were linear in the computation size, and the verification time was linear in the size of the public inputs and outputs.

### Groth 16 (2016)

[Groth](https://eprint.iacr.org/2016/260.pdf) introduced a [new argument of knowledge with increased performance](/groth16/) for problems described by an R1CS. It has the smallest proof size (only three group elements) and fast verification involving three pairings. It also involves a preprocessing step to obtain the structured reference string. The main drawback is that it requires a different trusted setup per program that we want to prove, which is inconvenient. Groth16 was used in ZCash.

### Bulletproofs & IPA (2016)

One of the weak points of the KZG PCS is that it requires a trusted setup. [Bootle et al.](https://eprint.iacr.org/2016/263) introduced an efficient zero-knowledge argument system of openings of Pedersen commitments that satisfy an inner product relation. The inner product argument has a linear prover, with logarithmic communication and interaction, but with linear time verification. They also developed a polynomial commitment scheme that does not require a trusted setup. PCS using these ideas are used by Halo 2 and Kimchi.

### Sonic, Marlin, and Plonk (2019)

[Sonic](https://eprint.iacr.org/2019/099), [Plonk](https://eprint.iacr.org/2019/953), and [Marlin](https://eprint.iacr.org/2019/1047) solve the problem of the trusted setup per program that we had in Groth16, by introducing universal and updatable structured reference strings. Marlin provides a proof system based on R1CS and is at the core of Aleo.

[Plonk](/all-you-wanted-to-know-about-plonk/) introduced a new arithmetization scheme (later called Plonkish) and the use of the grand-product check for the copy constraints. Plonkish also allowed the introduction of specialized gates for certain operations, the so-called custom gates. Several projects have customized versions of Plonk, including Aztec, zkSync, Polygon ZKEVM, Mina's Kimchi, Plonky2, Halo 2, and Scroll, among others.

### Lookups (2018/2020)

Gabizon and Williamson introduced [plookup](https://eprint.iacr.org/2020/315) in 2020, using the grand product check to prove that a value is included in a precomputed value table. Though lookup arguments were previously presented in [Arya](https://eprint.iacr.org/2018/380), the construction required the determination of the multiplicities for the lookups, which makes the construction less efficient. The [PlonkUp](https://eprint.iacr.org/2022/086) paper showed how to introduce the plookup argument into Plonk. The problem with these lookup arguments was that they forced the prover to pay the price for the whole table, independently of his number of lookups. This implies a considerable cost for large tables, and a lot of effort has been devoted to reducing the cost of the prover to just the number of lookups he uses.  
Haböck introduced [LogUp](https://eprint.iacr.org/2022/1530), which uses the logarithmic derivative to turn the grand-product check into a sum of reciprocals. LogUp is crucial for performance in the [Polygon ZKEVM](https://toposware.medium.com/beyond-limits-pushing-the-boundaries-of-zk-evm-9dd0c5ec9fca), where they need to split the whole table into several STARK modules. These modules have to be linked correctly, and cross-table lookups enforce this. The introduction of [LogUp-GKR](https://eprint.iacr.org/2023/1284) uses the GKR protocol to increase the performance of LogUp. [Caulk](https://eprint.iacr.org/2022/621) was the first scheme with prover time sublinear in the table size by using preprocessing time $\mathcal{O}(N \log N)$ and storage $\mathcal{O}(N)$, where $N$ is the table size. Several other schemes followed, such as [Baloo](https://eprint.iacr.org/2022/1565), [flookup](https://eprint.iacr.org/2022/1447), [cq](https://eprint.iacr.org/2022/1763) and [caulk+](https://eprint.iacr.org/2022/957). [Lasso](https://eprint.iacr.org/2023/1216) presents several improvements, avoiding committing to the table if it has a given structure. Besides, Lasso's prover only pays for table entries accessed by the lookup operations. [Jolt](https://eprint.iacr.org/2023/1217) leverages Lasso to prove the execution of a virtual machine via lookups

### Spartan (2019)

[Spartan](https://eprint.iacr.org/2019/550) provides an IOP for circuits described using R1CS, leveraging the properties of multivariate polynomials and the sumcheck protocol. Using a suitable polynomial commitment scheme, it results in a transparent SNARK with a linear time prover.

### HyperPlonk (2022)

[HyperPlonk](https://eprint.iacr.org/2022/1355.pdf) builds on the ideas of Plonk using multivariate polynomials. Instead of quotients to check the constraints' enforcement, it relies on the sumcheck protocol. It also supports constraints of a high degree without harming the running time of the prover. Since it relies on multivariate polynomials, there is no need to carry out FFTs, and the prover's running time is linear in the circuit size. HyperPlonk introduces a new permutation IOP suitable for smaller fields and a sum check-based batch opening protocol, which reduces the prover's work, proof size, and the verifier's time.

### Folding schemes (2008/2021)

[Nova](https://eprint.iacr.org/2021/370) introduces the idea of a folding scheme, which is a new approach to achieve incrementally verifiable computation (IVC). The concept of IVC dates back to [Valiant](https://https://iacr.org/archive/tcc2008/49480001/49480001.pdf) who showed how to merge two proofs of length $k$ into a single proof of length $k$. The idea is that we can prove any long-running computation by recursively proving that the execution from step $i$ to step $ I + 1$ is correct and verifying a proof that shows that the transition from step $i - 1$ to step $i$ was correct. Nova deals well with uniform computations; it was later extended to handle different types of circuits with the introduction of [Supernova](https://eprint.iacr.org/2022/1758). Nova uses a relaxed version of R1CS and works over amicable elliptic curves. Working with amicable cycles of curves (for example, the Pasta curves) to achieve IVC is also used in Pickles, Mina's main building block to achieve a succinct state. However, the idea of folding differs from recursive SNARK verification. The accumulator idea is more deeply connected to the concept of batching proofs. [Halo](https://eprint.iacr.org/2019/1021.pdf) introduced the notion of accumulation as an alternative to recursive proof composition. [Protostar](https://eprint.iacr.org/2023/620) provides a non-uniform IVC scheme for Plonk that supports high-degree gates and vector lookups.

## Using collision-resistant hash functions

Around the same time that Pinocchio was developed, there were some ideas to generate circuits/arithmetization schemes that could prove the correctness of the execution of a virtual machine. Even though developing the arithmetization of a virtual machine could be more complex or less efficient than writing dedicated circuits for some programs, it offered the advantage that any program, no matter how complicated, could be proven by showing that it was executed correctly in the virtual machine. The ideas in TinyRAM were later improved with the design of the Cairo vm, and subsequent virtual machines (such as zk-evms or general purpose zkvms). The use of collision-resistant hash functions removed the need for trusted setups or use of elliptic curve operations, at the expense of longer proofs.

### TinyRAM (2013)

In [SNARKs for C](https://eprint.iacr.org/2013/507), they developed a SNARK based on a PCP to prove the correctness of the execution of a C program, which is compiled to TinyRAM, a reduced instruction set computer. The computer used a Harvard architecture with byte-level addressable random-access memory. Leveraging nondeterminism, the circuit's size is quasilinear in the size of the computation, efficiently handling arbitrary and data-dependent loops, control flow, and memory accesses.

### STARKs (2018)

[STARKs](https://eprint.iacr.org/2018/046) were introduced by Ben Sasson et al. in 2018. They achieve $\mathcal{O}(\log^2 n )$ proof sizes, with fast prover and verifier, do not require a trusted setup, and are conjectured to be post-quantum secure. They were first used by Starkware/Starknet, together with the Cairo vm. Among its key introductions are the algebraic intermediate representation (AIR) and the [FRI protocol](/how-to-code-fri-from-scratch/) (Fast Reed-Solomon Interactive Oracle Proof of Proximity). It is also used by other projects (Polygon Miden, Risc0, Winterfell, Neptune) or has seen adaptations of some components (zkSync's Boojum, Plonky2, Starky).

### Ligero (2017)

[Ligero](https://eprint.iacr.org/2022/1608) introduces a proof system that achieves proofs whose size is $\mathcal{O}(\sqrt{n})$, where $n$ is the size of the circuit. It arranges the polynomial coefficients in matrix form and uses linear codes.  
[Brakedown](https://eprint.iacr.org/2021/1043) builds on Ligero and introduces the idea of field-agnostic polynomial commitment schemes.

## Some new developments

The use of different proof systems in production showed the merits of each of the approaches, and led to new developments. For example, plonkish arithmetization offers a simple way to include custom gates and lookup arguments; FRI has shown great performance as PCS, leading to Plonky. Similarly, the use of the grand product check in AIR (leading to randomized AIR with preprocessing) improved its performance and simplified memory access arguments. Commitments based on hash functions have gained popularity, based on the speed of hash functions in hardware or the introduction of new SNARK-friendly hash functions.

### New polynomial commitment schemes (2023)

With the advent of efficient SNARKs based on multivariate polynomials, such as Spartan or HyperPlonk, there has been an increased interest in new commitment schemes suited for this kind of polynomials. [Binius](/snarks-on-binary-fields-binius/), [Zeromorph](https://eprint.iacr.org/2023/917), and [Basefold](/how-does-basefold-polynomial-commitment-scheme-generalize-fri/) all propose new forms to commit to multilinear polynomials. Binius offers the advantage of having zero overhead to represent data types (whereas many proof systems use at least 32-bit field elements to represent single bits) and works over binary fields. The commitment adapts brakedown, which was designed to be field agnostic. Basefold generalizes FRI to codes other than Reed-Solomon, leading to a field-agnostic PCS.

### Customizable Constraint Systems (2023)

[CCS](https://eprint.iacr.org/2023/552) generalizes R1CS while capturing R1CS, Plonkish, and AIR arithmetization without overheads. Using CCS with Spartan IOP yields SuperSpartan, which supports high-degree constraints without having the prover to incur cryptographic costs that scale with the degree of the constraint. In particular, SuperSpartan yields a SNARK for AIR with a linear time prover.

## Conclusion

This post describes the advances of SNARKs since their introduction in the mid-1980s. Advances in computer science, mathematics, and hardware, together with the introduction of blockchain, have led to new and more efficient SNARKs, opening the door for many applications that could transform our society. Researchers and engineers have proposed improvements and adaptations to SNARKs according to their needs, focusing on proof size, memory use, transparent setup, post-quantum security, prover time, and verifier time. While there were originally two main lines (SNARKs vs STARKs), the boundary between both has begun to fade, trying to combine the advantages of the different proof systems. For example, combining different arithmetization schemes with new polynomial commitment schemes. We can expect that new proof systems will continue to rise, with increased performance, and it will be hard for some systems that require some time to adapt to keep up with these developments unless we can easily use these tools without having to change some core infrastructure.
