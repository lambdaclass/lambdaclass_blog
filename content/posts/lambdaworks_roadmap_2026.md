+++
title = "Updated roadmap and priorities for lambdaworks for 2026"
date = 2026-02-03
description = "Nearly three years after launching our cryptographic library for zero-knowledge proofs, we outline our 2026 priorities, including new proof systems, GPU support, and performance improvements to support Ethereum's Lean Consensus roadmap."

[taxonomies]
tags = ["cryptography", "zero knowledge proofs", "lambdaworks"]

[extra]
authors = ["LambdaClass"]
feature_image = "/images/2026/Siege_of_La_Rochelle_1881_Henri_Motte.png"
math = true
+++

## Introduction

It's been nearly 3 years since we started [lambdaworks](https://github.com/lambdaclass/lambdaworks), our cryptographic library for zero-knowledge proofs. The first PR was merged on January 18th 2023 and since then we had over 575 PRs merged from almost 80 collaborators and counting. At that time, there was still a big debate in the Ethereum and ZK community regarding the best proof systems, which arithmetization to use, using circuits or virtual machines, going for elliptic curves or hash-based proof systems, among other things. We knew and understood the different technologies, and we thought that working with zero-knowledge virtual machines (zkvm) and hash-based proof systems/STARKs was the way to go, because it was simpler to understand, had less security assumptions, was post-quantum secure and it greatly simplified writing provable applications. We saw the potential of the [Cairo-vm](https://eprint.iacr.org/2021/1063) (the first provable virtual machine using STARKs) and  Risc0 virtual machine, using the RISC-V instruction set architecture (ISA), to simplify the work developers had to do when building verifiable applications. 2024 brought more powerful designs for  zkvms and it became increasingly easy to write provable applications; 2025 saw massive acceleration when real-time proving of Ethereum blocks was achieved and we have seen great performance gains over the year, showing the technology was maturing. We also saw that designs were converging to similar choices, using post-quantum secure STARKs and the RISC-V ISA. The Ethereum Foundation launched the roadmap for [Lean Ethereum](https://leanroadmap.org/), leveraging zero-knowledge proofs for post-quantum secure aggregatable signatures used in the consensus (Fort Mode) and to prove L1 and L2 blocks to reach massive throughput, around 1 Ggas ($10^9$ gas, over 10,000 transactions per second) in L1 and Tgas ($10^{12}$ gas) in L2 (Beast Mode). While we are working on our own zero-knowledge virtual machine, and we already have our execution client ([ethrex](https://github.com/lambdaclass/ethrex)) and are developing our lean consensus client ([ethlambda](https://github.com/lambdaclass/ethlambda/)), we also think it is good to continue building a general purpose library for zero-knowledge proofs and cryptography that other projects can use, and also do research and benchmarking.
                                                        
##  Why we built lambdaworks
                                                           
We saw that many of the [libraries available then were not written in Rust or were difficult to work with](https://blog.lambdaclass.com/lambdaworks-or-how-we-decided-to-created-our-zksnarks-library-and-a-stark-prover/), having unnecessary complexity and were built more for research purposes than for production. Based on the [lambda engineering philosophy](https://blog.lambdaclass.com/lambdas-engineering-philosophy/), we decided that our library had to be:
- Written in Rust with solid engineering practices
- Designed for production, not just academic research
- Simple to use with clear documentation
- Capable of GPU acceleration (CUDA, Metal)
- Modular enough for researchers to prototype new ideas
  
## Current state

Over two years of development, we were able add many different features and backends; the library is being used in the [Cairo-vm](https://github.com/lambdaclass/cairo-vm) and in [ethrex](https://github.com/lambdaclass/ethrex). Here is a summary of the functionality currently present in lambdaworks:
  
### Proof systems

- STARK Platinum: Our main STARK prover
- Groth16: Complete implementation with Circom support
- GKR: Sumcheck-based protocol for layered circuits 
- Plonk: Partial implementation, supporting basic circuits 

### Math
  
- Finite fields: Stark252, Mersenne31, BabyBear, MiniGoldilocks, binary fields, and more
- Elliptic curves: BLS12-381, BLS12-377, BN254, Pallas, Vesta, secp256k1, secq256r1
- Polynomials: Dense and sparse representations, FFT, NTT, evaluation and interpolation
- Pairings: Optimized Ate pairing for BN254 and BLS curves

### Cryptographic primitives

- Polynomial commitments: KZG10, FRI
- Hash functions: Poseidon, Rescue, Pedersen
  
### Educational resources

- Examples: Shamir secret sharing, Merkle trees, BabySNARK, Pinocchio, Reed-Solomon, FROST signatures, Schnorr, RSA.
- Bootcamp: Internal training program that produced several of these examples.
- CTF challenges: Lambda-Ingo ZK CTF with challenges built on lambdaworks

## Recent work

In the past weeks we have focused on performance and code quality:
- Field and curve optimizations for faster arithmetic
- Fixed slow square root computation
- BabyBear refactored to use only u32 operations
- Removed naive pairing implementation in favor of optimized version
- Extracted common serialization helpers
- Improved documentation with getting started guides

## Updated roadmap

During this year, we want to add some pending features, increase the performance of the library, add more support for GPU and add new proof systems and primitives for experimentation and learning. A comprehensive list is below:

### Proof systems
  - Complete STARK protocol supporting logUp using FRI
  - Complete Plonk protocol to support lookup tables
  - Add Circle STARKs
  - Add GKR logUp
  - Improve DSL for constraints in AIR and Plonk
### Polynomial commitment schemes
  - Add WHIR as polynomial commitment scheme
  - Add PCS trait and unify polynomial commitment interface
### Primitives and fields
  - Add missing fields such as KoalaBear
  - Improve multilinear polynomials and sumcheck protocol
  - Add constant-time operations to enable signatures
### Signatures
  - Add Lean Ethereum's XMSS signatures
  - Implement other post-quantum secure signatures
### Performance
  - Add GPU support for lambdaworks (CUDA, Metal, WebGPU)
  - Continue performance improvements across field and curve operations
### Code quality
  - Simplify codebase
  - Add more tests, fuzzing, and differential fuzzing
  - Work on formal verification of critical components

## Looking forward

The Ethereum ecosystem is converging around a clear technical vision. The https://leanroadmap.org/ outlines two complementary goals: Fort Mode for post-quantum security and resilience against nation-state adversaries, and Beast Mode for scaling L1 to 1 gigagas/second (~10,000 TPS) and L2s to 1 teragas/second (~10 million TPS). Both modes rely heavily on the cryptographic primitives that lambdaworks provides. lambdaworks can add value by offering performance, a simple codebase and redundancy (if all the zkvms rely on the same library and that library has a bug, then it does not matter whether we have multiple zkvm implementations).

  The broader ecosystem is also converging on similar choices: STARKs over SNARKs for their transparency and post-quantum security, RISC-V as the standard ISA for zkVMs, and hash-based cryptography as the foundation. New polynomial commitment schemes like WHIR and proof systems based on the sumcheck protocol are pushing the boundaries of what is possible. We want lambdaworks to support this experimentation while remaining simple and production-ready.
  We see lambdaworks serving three roles going forward:
  1. Infrastructure for our own projects: ethrex, ethlambda, and our zkvm all depend on lambdaworks primitives
  2. A toolkit for the broader ecosystem: teams building provers, verifiers, and cryptographic applications can use lambdaworks as a foundation
  3. A learning resource: understanding these primitives deeply is essential for anyone working in ZK, and our examples and documentation aim to make that easier
  
The next few years will be decisive for zero-knowledge technology. As Ethereum moves toward Lean Consensus with and post-quantum signatures, as L1 and L2 throughput increases by orders of magnitude, and as ZK becomes embedded in everything from identity to financial infrastructure, having robust, well-tested cryptographic libraries becomes critical. We're building lambdaworks to be one of those libraries.
  
If you want to contribute or have questions, join us on https://t.me/lambdaworks or open an issue on https://github.com/lambdaclass/lambdaworks.