+++
title = "How Binius is helping move the ZK industry forward"
date = 2023-12-12
slug = "binius-moving-zk-forward"

[extra]
feature_image = "/content/images/2025/12/Hubert_Robert_-_The_Old_Bridge_-_1957.34.1_-_Yale_University_Art_Gallery.jpg"
authors = ["LambdaClass"]
+++

## Introduction

Zero-knowledge and validity proofs, often abbreviated as ZK, represent a fascinating field within the realms of cryptography, mathematics, and computer science. They allow one party, the prover, to convince other parties, termed verifiers, that a specific statement (such as the execution of a computer program) is true in a time- and space-efficient way. This means that the proof can be verified much faster than if the verifiers were to perform the computation directly and need less information, with the possibility that the proof does not leak sensitive data.

The consequences of practical zero-knowledge proofs for engineering are many and far-reaching, as we discussed in our previous [blog post](/transforming-the-future-with-zero-knowledge-proofs-fully-homomorphic-encryption-and-new-distributed-systems-algorithms/). One of those areas is crypto (see [our crypto doctrine](/lambda-crypto-doctrine/)). Still, it extends to content creation platforms, identity and authentication, national security, distributed computing, etc.

## Current developments in ZK

To prove the execution of arbitrary computer programs, we need to transform them into a form amenable to ZK; this process is called arithmetization and consists of expressing the program as a bunch of equations defined over integers/finite fields. There are differences in how we express and think in computer programs, using bytes and binary operations. For example, if our program has a boolean variable, we must ensure that the variable takes only the values 0 or 1. Since we work with integers, this condition adds an equation of the form $b(1 - b) = 0$. The problem is that this variable is represented with a large integer (at least 64 bits long), which adds significant overhead in memory use and computational time since we now work with operations over finite fields (not bits). Operations such as bitwise operations or showing the binary decomposition of an integer are costly.

Since performance in ZK involves different tradeoffs than ordinary programming, developers need to have a deeper understanding of cryptography and learn to code differently. The tooling for developers is still being created and depends, in some cases, on writing arithmetic circuits directly, which is time-consuming and prone to bugs. Besides, proving adds significant overhead, both in memory and time use. Therefore, ZK introduces difficulties both in developer and user experiences. It means more time and money spent on training developers and lower availability of skilled programmers.

During the last years, the zk space has advanced really fast, and we have seen efforts going in various directions to increase the performance of the proof systems:

        1. STARKs using small field sizes, such as mini-Goldilocks and the 31-bit Mersenne prime.
        2. Folding schemes, such as Nova, Protostar, and Protogalaxy.
        3. Lookup arguments, with Jolt aiming to reduce everything to just looking up any operation over a pre-computed table of valid input/output pairs.

Each system has advantages and disadvantages regarding proof size, prover time, verifier time, and the type of computations that can be easily supported. There have been efforts on the hardware side to accelerate these proof systems, but they all pay the price for representing bits in terms of field elements.

## Binius and the use of binary fields

Using smaller fields in STARKs reduced the overhead in representing variables and led to lower proving times. The question arises naturally: can we do better than this? Near the end of the year, Ulvetanna released a [paper](https://eprint.iacr.org/2023/1784.pdf) showing that we can work over smaller fields and open-sourced an implementation, Binius. A first analysis of Binius can be found [here](/snarks-on-binary-fields-binius/). We will release the second part of the post soon, diving deeper into the construction and its uses.

Binius's contributions can be summarized in three main points:

        1. Working with binary fields -this is essentially working with bitstrings of various sizes. It is possible to adjust the size to represent variables with no overhead.
        2. A commitment scheme for small fields. It is based on hash functions, which are faster than those based on elliptic curves and do not need a trusted setup. It draws heavily on [Brakedown](https://eprint.iacr.org/2021/1043.pdf).
        3. A SNARK built on top of 1 and 2, based on the ideas of HyperPlonk, but which could be extended to other arithmetization schemes.

The main advantage of the whole construction is that it handles bit operations more naturally (for example, the exclusive OR between two bitstrings is just the addition over the field) and eliminates the overhead associated with the representation of data types. For instance, boolean variables can be represented by just one field element of size 1 bit! This reduced the memory footprint of the whole proof system (though we will need to work with larger fields to achieve cryptographic security).

Another advantage is that operations are really fast and hardware-friendly. In the case of adding field elements, it is just the XOR operation, avoiding carry and overflow. There are also very efficient algorithms to work with binary fields, such as an additive Fast Fourier Transform (FFT), which is used to produce the Reed-Solomon encoding.

The main drawbacks are related to proof size (it is significantly larger than most SNARKs and STARKs, in the order of a few MB) and verifier time. However, the verifier's time is on par with most proof systems, and the prover is significantly faster. Besides, smaller proof sizes in SNARKs come at the cost of a trusted setup, which makes the whole system rely on the integrity of a parameter initialization ceremony, generally using several GB of memory.

## Applications

The original paper shows how to arithmetize the Keccak and Grøstl hash functions, which involve many bitwise operations, making them hard to work using other proof systems. The performance analysis offers an idea of the capabilities of the new construction and what we can gain by adopting it. The ability to handle bitwise operations more naturally also allows us to use these hash functions for commitments and prove them easily.

We could build a virtual machine and prove the correctness of its execution using Binius. This could make proving general computer programs very efficient, at least in terms of the time needed to generate the proof. We could solve the problem of proof size by wrapping the proofs with a SNARK/STARK, which will only need to verify Binius's proofs, leading to more lightweight and efficient constructions.

Reducing the prover's memory and time use can enable provable fully homomorphic encryption (FHE), which lets users delegate expensive computations to untrusted servers without compromising the data. FHE allows users to compute over encrypted data without decrypting it first.

## Conclusions

We think that Binius can be a game changer when it comes to scaling provable computations, which can spark significant changes in different areas of software engineering and finance. The reduction in memory use and hardware friendliness of the operations and the development of a virtual machine could make provable computations in consumer-end hardware a reality while enhancing the developer experience, and reducing the resources and training needed. We are one step closer to the mass adoption of zk technology. Lambdaclass is interested in this new proof system and its capabilities and we would like to start implementing and developing it in 2024.
