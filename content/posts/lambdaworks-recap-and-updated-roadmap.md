+++
title = "lambdaworks - recap and updated roadmap"
date = 2024-09-24
slug = "lambdaworks-recap-and-updated-roadmap"

[extra]
feature_image = "/images/2025/12/Steuben_-_Bataille_de_Poitiers.png"
authors = ["LambdaClass"]
+++

## Introduction

It has been over a year and a half since we launched [lambdaworks](https://github.com/lambdaclass/lambdaworks), our cryptography library for zero-knowledge (ZK) proofs. We built it focusing on performance, ease of use, support for hardware acceleration, and teaching others how to develop and understand ZK.

Several advances in ZK in the last year have offered incredible performance gains over previous schemes. For example, circle STARKs has allowed to prove over [620k Poseidon2 hashes per second on consumer-end hardware](https://x.com/StarkWareLtd/status/1807776563188162562). Binius allows us to leverage the power of binary fields. Their performance can be greatly increased by using specialized hardware. We have seen new lookup arguments that depend only on the number of lookups used. We also have more efficient hash functions. Last year, we also saw the development and release of general proving zk virtual machines (zkvm). These allow us to write ordinary code (for example, in Rust), execute it on top of the virtual machine, and generate a proof of the execution. This simplifies the development of verifiable applications, abstracting developers from the low-level details of ZK. With the introduction of [Aligned](https://docs.alignedlayer.com/), we expect proof verification costs to go consistently down, enabling new verifiable applications built on top of Ethereum. We can predict that ZK will become more and more important in the coming years, and it is necessary, therefore, to have many of the essential tools in our library.

Before jumping into the future, let us recap some of the features and numbers of lambdaworks:

        * 493 pull requests merged.
        * 73 contributors.
        * 14 releases.
        * Over 185k downloads.
        * 4 proof systems (STARKs, Cairo, Groth16, Plonk) and two additional example implementations (Pinocchio and BabySNARK).
        * 2 editions of the Sparkling Water Bootcamp in Cryptography, with 30 bootcampers from different countries.
        * [Backend for finite fields](https://github.com/lambdaclass/lambdaworks/tree/main/math/src/field) using Montgomery arithmetic, plus specialized backends for fields with simpler reduction formulae.
        * [Backend for elliptic curve operations](https://github.com/lambdaclass/lambdaworks/tree/main/math/src/elliptic_curve), with different coordinate systems.
        * [Backend for Univariate polynomials](https://github.com/lambdaclass/lambdaworks/tree/main/math/src/polynomial) and Fast Fourier Transform (FFT).
        * Several cryptographic tools, such as hash functions (Poseidon and Pedersen), Merkle trees, KZG commitments, and Fiat-Shamir transformation.
        * Examples and exercises.

Considering all the recent advances and trends, as well as the experience we got from users and friends, we will incorporate new features and improve existing ones according to the following roadmap.

## Roadmap

The following is a list of features and updates we want to incorporate into lambdaworks. We may change some or include new ones according to the latest developments in ZK technology:

        * Improve field backends using assembly.
        * Improve field extension backends.
        * Provide new backend implementation for Mersenne primes.
        * Incorporate binary fields.
        * Improve and add features on multilinear and multivariate polynomials.
        * Improve the performance of BLS12-381 and BLS12-377 pairings.
        * Add new hash functions: Rescue, [XHash8 and XHash12](https://eprint.iacr.org/2023/1045.pdf), Poseidon 2.
        * Add [logUp with GKR](https://eprint.iacr.org/2023/1284).
        * Add [Binius](https://eprint.iacr.org/2023/1784).
        * Add [Circle STARKs](https://eprint.iacr.org/2024/278).
        * Provide tools for efficient proof recursion.
        * Provide more documentation, examples, use cases, etc.
        * Add more theoretical background to the library.
        * Finish integration with [Icicle](https://github.com/ingonyama-zk/icicle).
        * Add bindings for Python and other programming languages.

## Summary

Over the last year and a half, we have seen many new developments in ZK, improving the performance of proof systems while greatly simplifying the development of verifiable applications. The introduction of ZK verification layers will lead to lower verification costs and new applications.

lambdaworks has incorporated many proof systems and different cryptographic primitives to help developers build applications and understand how things work under the hood. We present the new roadmap for the library, hoping to incorporate new proof systems, such as Circle STARKS and Binius while maintaining simplicity and providing clear and straightforward documentation. That way, we hope to bring ZK to developers worldwide, helping them adopt and make this transformative technology available to everybody.
