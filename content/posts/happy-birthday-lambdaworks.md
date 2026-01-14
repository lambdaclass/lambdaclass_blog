+++
title = "Happy birthday, lambdaworks!"
date = 2024-01-30
slug = "happy-birthday-lambdaworks"

[extra]
feature_image = "/images/2025/12/Retour_de_Napoleon_d-_Isle_d-Elbe-_by_Charles_de_Steuben.jpg"
authors = ["LambdaClass"]
+++

## Introduction

It's been almost a year since we started building [lambdaworks](https://github.com/lambdaclass/lambdaworks)! lambdaworks is our library that implements efficient cryptographic primitives to build proof systems. Along with it, many backends for proof systems are shipped, and compatibility with different frontends is supported. We wanted to give an overview of what we have done over the last year and the roadmap for the future. Why did we choose to embark on this journey? We are truly bullish on zero-knowledge/validity proofs and their potential to solve many problems and create new applications, as we stated in our [previous post](/transforming-the-future-with-zero-knowledge-proofs-fully-homomorphic-encryption-and-new-distributed-systems-algorithms/) and [crypto doctrine](/lambda-crypto-doctrine/). We decided to work in this challenging environment, where math, distributed systems, and cryptography meet. The first challenge we faced was the lack of performant and developer-friendly libraries, though there are some exceptions. Some have nice APIs and are easy to use but not written in Rust; others are written in Rust but have poor programming practices. So, we decided with a team of engineers and mathematicians to build a new library, written in Rust, focusing on performance and developer-friendliness. We also wanted to make all this knowledge available to other developers and help onboard new people to this space by writing clear documentation and explaining how each of the parts and proof systems work. Open source and decentralization are necessary practical conditions to build crypto, and we cannot think of decentralization as the knowledge and tools to build things are centralized in a few players. Let's jump into our plans for the future and some numbers.

## Some numbers:

Here we give some figures to understand all the work we have been doing in the library and the contributions from the community:

        * 464 PRs merged.
        * 60 contributors.
        * 8 releases.
        * 49k lines of code in Rust
        * Several posts on finite fields, cryptography, and proof systems.
        * Use of lambdaworks in 2 CTF events and Lambda ZK Week.
        * 800+ members in lambdaworks channel.
        * One cryptography bootcamp with 21 interns from 12 countries

## Objectives:

        * Reference library for cryptography and proof systems.
        * Written in Rust.
        * To be used in production, not just for academic research. However, we also want to enable researchers to write their papers in our library easily.
        * Support for GPU acceleration (Metal, CUDA).
        * Simple to use, developer-focused.
        * Clear documentation, plenty of examples.

## What do we still have to work on

We have added several tools and proof systems to the library, but we still have a long way to go:

        * Integration into other provers, VMs, and cryptography projects.
        * Documentation. We still need to improve the project documentation, add more examples, and enhance user experience.
        * Create a grant and bounty program
        * Support the use of Icicle.
        * Towers of binary fields.
        * New polynomial commitment schemes: basefold, brakedown, inner product argument (IPA), Binius.
        * New layouts for Cairo STARK Platinum.
        * Lookup arguments (for example, Plookup, and Lasso)
        * New proof systems: Hyperplonk, Spartan, Marlin, GKR.
        * Folding schemes.
        * Supporting new elliptic curves.
        * New hash functions.
        * Improve performance of FFT, elliptic curves, polynomials, and general finite field arithmetic.
        * Add new coordinate systems for elliptic curves.
        * Second edition of the cryptography bootcamp.

## What we accomplished?

Over the year, we have implemented different core math, crypto building blocks, and proof systems. We have received contributions from the community, not only in the form of PRs but also as issues and bug reports.

### Main crates:

The main crates we have implemented are:

        * Finite Fields: all the mathematical building blocks for cryptography and proof systems. This is used by the Cairo VM in production in Starknet.
        * Crypto: hash functions, Merkle trees, polynomial commitment schemes.
        * Provers (& verifiers): STARK Platinum, Groth 16, Plonk. Adapters for Cairo, Winterfell, Miden (STARKs), Circom, and Arkworks (Groth 16).

### Fields:

        * Optimized Montgomery backend.
        * Specialized backends for Mersenne-31 and Mini-Goldilocks ($2^{64} - 2^{32} +1$).
        * Field extensions.
        * Radix-2 and radix-4 fast Fourier Transform.
        * Elliptic curves.
        * Multiscalar multiplication.
        * Pairings.
        * Univariate polynomials.
        * Multivariate polynomials.

### Crypto:

        * Fiat Shamir transformation.
        * Hash functions: Poseidon, Pedersen
        * Merkle trees
        * KZG commitment scheme

### Provers:

        * General STARK prover
        * Groth 16
        * Plonk with KZG commitment
        * Adapters
