+++
title = "How we are shaping the future of modular blockchains with  Zero Knowledge Proof, Starknet and Ethereum"
date = 2023-03-07
slug = "how-we-are-shaping-the-future-of-modular-blockchains-with-zero-knowledge-proof-verifications-in-ethereum"

[extra]
feature_image = "/images/2025/12/Peter_Paul_Rubens_-_Battle_of_the_Amazons.jpg"
authors = ["LambdaClass"]
+++

We believe in a permissionless future where individuals can cooperate and coordinate in scalable blockchain environments. With ten years of experience in distributed systems and a new obsession with cryptography, we can help builders achieve their goals.

To realize this future, we believe that developers don't have all the tooling necessary to create products that compete with the UI/UX of Web2. For the past year, we have been collaborating with StarkWare because the technology they have brought to the world will allow us to fulfill this objective. Specifically, STARKs and Cairo have not only been a major breakthrough in Computer Science but have also been battle-tested in StarkEx and, more recently it's starting to be tested in Starknet.

Unlike most other solutions, StarkEx has been in production for years, already serving millions of users and facilitating over 850B USD in trades since its inception. It's not a permisionless system. That what Starknet brings to the table. It's ecosystem already has more than 900 experienced and talented developers bringing new products to the world. We are confident that while Starknet may encounter problems but we know that we will be able to overcome them. We trust that the quality of engineers at StarkWare, in our own team and the Starknet community is between the bests of the world.

We do recognize that there is still much work to be done. Specifically, it's really important to be able to launch sequencers and provers. We also want to have light clients and support interoperable protocols such as IBC. A great example of this is [zkMint](https://polymerlabs.medium.com/zkmint-the-first-zk-friendly-tendermint-consensus-engine-116000b9d4f9). These are some examples of the things that are missing to build the future of modular blockchains:

        * Sovereign rollups where the data availability is stored in another chain like Bitcoin, Celestia or other systems
        * Hybrid rollups using both optimistic and zero-knowledge techniques to get the best of both worlds
        * ZK Storage proofs to be able to move assets between chains in a safer manner
        * Safer wrapped assets
        * Multichain orderbooks that uses the liquidity of multiple chains

We're working to create internally and with other companies to build these tools and products.

### Our work in the Starknet ecosystem:

We developed [cairo-rs](https://github.com/lambdaclass/cairo-rs), which is now 150 times faster than the initial implementation. Over the last three months we worked over in our implementation of [starknet_in_rust](https://github.com/lambdaclass/starknet_in_rust). With starknet in rust and the cairo-rs vm we can now receive and execute transactions.

We have been also making great progress on a Cairo STARK prover in [LambdaWorks](https://github.com/lambdaclass/lambdaworks). LambdaWorks is a library designed for building provers and verifiers for SNARKs in general but the first thing we built is the Cairo STARK prover. We still have to implement the proving of builtins. Hopefully with the help of Starkware we will have this done in the upcoming weeks.

We're also working on a Proof of Concept for a [Starknet sequencer built with Tendermint Core](https://github.com/lambdaclass/starknet_tendermint_sequencer) that can be used as learning path to decentralize L2 such as Starknet. Yesterday we were happy to learn that the community took this effort and added support for Sovereign Rollups on [Celestia](https://celestia.space/) using [Rollkit](https://github.com/rollkit/). We're also working in a Sovereign Rollup to Bitcoin with Cairo and Starknet.

> broke: starknet as rollup with enshrined settlement layer  
> woke: starknet as sovereign rollup on celestia   
>   
> starknet <> rollkit <> celestia [pic.twitter.com/h77HajcL2j](https://t.co/h77HajcL2j)
> 
> — kari (@ammarif_) [March 6, 2023](https://twitter.com/ammarif_/status/1632680324290453506?ref_src=twsrc%5Etfw)

The Starknet sequencer will be [decentralized](https://medium.com/starkware/starknet-on-to-the-next-challenge-96a39de7717). With multiple sequencers it would be unnecessary to generate a execution trace since the sequencers can compare their results and let the prover generate the trace and the proof that is then checked in Ethereum L1.  
This allows us to compile Cairo 1.0 into [MLIR](https://mlir.llvm.org/) so that they can be executed in a much faster manner from the sequencer. Therefore we are currently working on a [Cairo to MLIR compiler](https://github.com/lambdaclass/cairo_sierra_2_MLIR)

It's very unlikely that Starknet will implement an hybrid approach with Optimistic and at the same time ZK rollup but it would be possible to do it. In addition to this as we have mentioned before data availabilty could be done in a different chain.

We're also working on other projects in Starknet that will be made public in the upcoming weeks.

### How we think that ZK can empower builders to create a future with modular blockchains and more powerful applications

We are also trying to help projects that will help create a modular ecosystem but that have Ethereum and ZK as the main building blocks.

Some of these projects are:  
**[Herodotus](https://www.herodotus.dev/)**  
The Herodotus team is trying to bring interoperability and synchronism back to the Ethereum ecosystem. To do so, they leverage a cryptographic protocol called Storage Proofs that allows developers to read, access, and process on-chain data. Developers will utilize Storage Proofs to process data from Chain A to execute certain logic on Chain B. This is incredibly useful for build multichain (L2 to L2 for now only) applications like secure bridges and multichain lending.

**[Giza](https://www.gizatech.xyz/)**  
On the other hand, Giza is utilizing Cairo to make on-chain Machine Learning a reality. This will be incredibly useful for on-chain gaming, advanced DeFi protocols, and zkML. That said we think that once the proving part is done in a faster way it will be possible to prove the training and inference of ML models. This will be crucial to run complex ML models off chain and verify them on chain.

We understand that this will not be a simple road, but we are excited to embark on this journey with our partners and test our abilities. In the last few years, here at LambdaClass, we have become a software powerhouse that specializes in developing critical infrastructure and our own products. We have had incredible growth, but we also believe we must empower other developer teams and communities, so stay tuned for further updates on our progress.

If you want to hack with us, send us an email at [federico@lambdaclass.com](mailto:federico@lambdaclass.com)
