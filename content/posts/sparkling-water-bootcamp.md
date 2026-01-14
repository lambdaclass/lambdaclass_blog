+++
title = "Sparkling Water Bootcamp on Cryptography in a nutshell"
date = 2024-01-11
slug = "sparkling-water-bootcamp"

[extra]
feature_image = "/content/images/2025/12/The-Trojan-Women-Setting-Fire-to-Their-Fleet-Claude-Lorrain--Claude-Gelle--e-.jpg"
authors = ["LambdaClass"]
+++

## Introduction

16 weeks ago, we started the [Sparkling Water Bootcamp](https://github.com/lambdaclass/lambdaworks/blob/main/bootcamp/README.md) to teach cryptography and zero-knowledge proofs to a group of engineers and students from around the world, focusing on applications and coding. We started with a team of 21 people, with backgrounds in Computer Science, Physics, Mathematics, Engineering, and Architecture, among others. Our bootcampers came from several countries: India, Turkey, USA, Nigeria, Brazil, Venezuela, Ecuador, Paraguay, Cuba, France, Serbia, and Costa Rica. Given the different backgrounds and time zones, it has been a challenging experience (since it involves coordination, logistics, and adopting the best strategies to teach concepts to people with different learning styles and objectives) but we greatly enjoyed it and it taught us many things while making new friends and acquaintances. If you want to know more or keep with the latest developments, join our [telegram channel](https://t.me/lambdaworks) or see the [Lambdaworks repo](https://github.com/lambdaclass/lambdaworks).

The contents of the bootcamp included finite field arithmetics, elliptic curves, polynomials, SNARKs, STARKs, symmetric encryption, public key cryptography, signatures, as well as an intro to Fully Homomorphic Encryption (FHE). We also discussed new papers, including [Succinct Arguments over Towers of Binary Fields](https://eprint.iacr.org/2023/1784). We hosted several lectures, discussion sessions, workshops, and guest lectures.

## Guest Lectures and workshops

We had the opportunity to invite several speakers from different projects to talk about their work and discuss topics in cryptography. We were lucky to have Immanuel Segol from Ingonyama, Robert Remen from MatterLabs/ZKSync, and Alan Szepieniec from Neptune.

We also had workshops taught by engineers at LambdaClass, on Rust (Pablo Deymonnaz), and Cairo Native (Iñaki Garay). You can have a look at all the talks and workshops on the [YouTube channel](https://www.youtube.com/playlist?list=PLFX2cij7c2Pwm2XHBijKZ6Eh97BOqtGBh).

## Exercises

During the first weeks, we had some practice exercises and challenges, such as naïve implementations of RSA, elliptic curve cryptography, and Shamir secret sharing. Some of the exercises and answers are contained in the [Sparkling Water Bootcamp readme](https://github.com/lambdaclass/lambdaworks/tree/main/bootcamp). We also reviewed some challenges from the [Lambda/Ingo ZK CTF](/first-lambda-ingo-zk-ctf-zk-challenges-using-lambdaworks/).

## Coding - new features in Lambdaworks

We were able to put everything we learned into practice by adding new features and proof systems to Lambdaworks. We want to thank our bootcampers for all the hard work they have done during these weeks. Among the additions, we have:

        1. Groth 16 backend, [PR-612](https://github.com/lambdaclass/lambdaworks/pull/612).
        2. Arkworks adapter for Groth 16, [PR-701](https://github.com/lambdaclass/lambdaworks/pull/701)
        3. Added Starknet curve, and Pedersen hash, [PR-597](https://github.com/lambdaclass/lambdaworks/pull/597)
        4. Changing Serialization by AsBytes, [PR-747](https://github.com/lambdaclass/lambdaworks/pull/747).
        5. Affine serialization for elliptic curve points, [PR-687](https://github.com/lambdaclass/lambdaworks/pull/687)
        6. Pasta curves, [PR-690](https://github.com/lambdaclass/lambdaworks/pull/690), [PR-698](https://github.com/lambdaclass/lambdaworks/pull/698), and [PR-714](https://github.com/lambdaclass/lambdaworks/pull/714).
        7. Specific backend for the 31-bit Mersenne prime, [PR-669](https://github.com/lambdaclass/lambdaworks/pull/669)
        8. Fuzzer for the BLS12-381 elliptic curve, [PR-664](https://github.com/lambdaclass/lambdaworks/pull/664)
        9. Subgroup checks for BLS12-381 elliptic curve using Frobenius endomorphism, [PR-649](https://github.com/lambdaclass/lambdaworks/pull/649)
        10. New CLI command to be able to prove traces using STARK Platinum, [PR-634](https://github.com/lambdaclass/lambdaworks/pull/634)
        11. Adding support for BabyBear field, [PR-549](https://github.com/lambdaclass/lambdaworks/pull/549), [PR-576](https://github.com/lambdaclass/lambdaworks/pull/576), [PR-629](https://github.com/lambdaclass/lambdaworks/pull/629)
        12. Specialized backend for Mini-Goldilocks field ($2^{64} - 2^{32} + 1$), [PR-622](https://github.com/lambdaclass/lambdaworks/pull/622)
        13. Refactor the field benchmarks, [PR-606](h%5Bttps://%5D\(https://github.com/lambdaclass/lambdaworks/pull/606\))
        14. Bug fixes, [PR-575](https://github.com/lambdaclass/lambdaworks/pull/575)
        15. Adding Ed448 elliptic curve, [PR-546](https://github.com/lambdaclass/lambdaworks/pull/546), [PR-557](https://github.com/lambdaclass/lambdaworks/pull/557)
        16. Proptest for unsigned integers, [PR-526](https://github.com/lambdaclass/lambdaworks/pull/526)

There is still ongoing work on multivariate polynomials ([PR-726](https://github.com/lambdaclass/lambdaworks/pull/726), the Sumcheck Protocol ([PR-739](https://github.com/lambdaclass/lambdaworks/pull/739)), inner product arguments ([PR-743](https://github.com/lambdaclass/lambdaworks/pull/743)), adding BN254 elliptic curve ([PR-646](https://github.com/lambdaclass/lambdaworks/pull/646)) and an adapter for Circom ([PR-752](https://github.com/lambdaclass/lambdaworks/pull/752)).

## Hacking in Buenos Aires and visiting friends abroad

During the first weeks of December, we hosted an event and hacking house in Buenos Aires, where we received many engineers, researchers, and friends. It was a great opportunity to meet in person, discuss on cryptography, distributed systems, and engineering, and have a good time. We also had the opportunity to visit several landmarks in the city and outskirts, enjoy asados and dinners, as well as a short trip to the city of Bariloche.

We also met with many bootcampers in several events we participated, such as DevConnect at Istanbul or ZK Summit.

## Next steps

We have greatly enjoyed the whole experience and are grateful to our bootcampers for their commitment and hard work. We have learned a lot from them and the experience, and this will help us improve our hacking learning path to cryptography and zero-knowledge proofs. We will take more time to analyze the whole experience and we will be releasing new blog posts on different proof systems and how to use the different tools and features in Lambdaworks.
