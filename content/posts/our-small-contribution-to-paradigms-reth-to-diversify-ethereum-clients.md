+++
title = "Our small contribution to Paradigm’s Reth to diversify Ethereum clients"
date = 2023-03-06
slug = "our-small-contribution-to-paradigms-reth-to-diversify-ethereum-clients"

[extra]
feature_image = "/content/images/2025/12/Peter_Paul_Rubens_-_Hercules_as_Heroic_Virtue_Overcoming_Discord_-cropped-.jpg"
authors = ["LambdaClass"]
+++

In December, last year, we heard about [Reth](https://github.com/paradigmxyz/reth), and it immediately piqued our interest. A greenfield new implementation of an Ethereum full node? Where do we sign up!?

The project, started and driven by [@gakonst](https://www.twitter.com/gakonst) from Paradigm (if you haven’t heard about it yet, we encourage you to read gakonst’s [introductory post](https://www.paradigm.xyz/2022/12/reth) ), aims to not just experiment improvements to performance, safety, software reuse through modularity, and node architecture, but also to contribute to Ethereum’s stability by improving implementation diversity.

These goals strongly resonated with our values and interests, the intersection of deep technical problems, good engineering, and building in the open and jointly. “Diversity” is not just a buzzword: time and time again we’ve seen how monocultures stagnate, how team composition and output benefits from integrating differing viewpoints and experiences, how the state of the art advances by integrating engineering and research, and how software projects grow stronger, instead of weaker, by having several implementations of the same thing. It’s not _just_ “more eyeballs”, or “competition breeds excellence”. It’s an emergent property.

All this made us commit to contributing, but when we started we had to first go out on a learning path: the evolution and design tradeoffs of blockchain node architectures and protocols, the nitty gritty of implementing data structures and patterns used in crypto projects, and so on. For ourselves, we expected to just learn and hone our skills in this process of giving back, but were very satisfied to see other benefits: other projects we were working on required something we learned working on reth, or viceversa. Our seniors had interesting problems to work on, and our juniors had excellent guidance in their maturation process.

Among the many fascinating things one learns when working on cryptocurrency infrastructure project internals is just how to structure such a beast. Blockchain nodes are a kind of distributed database, so they need to handle incoming requests, both to read from the node storage and to write to the transaction mempool, handle connections to peers and the protocol used to communicate with them, and manage the actual storage of the data and cryptographic data structures used to provide the features and guarantees blockchains are known for.

As mentioned elsewhere, Reth takes some cues from Akula and Erigon, which propose a different [architecture](https://github.com/ledgerwatch/erigon-book/blob/main/architecture.md) than Geth, again, more modular and built up out of commmunicating components which can be separated out into other processes or projects as needed. A key component is the [staged](https://github.com/ledgerwatch/erigon/blob/devel/eth/stagedsync/README.md) [sync](https://erigon.substack.com/p/erigon-stage-sync-and-control-flows), a version of Go-Ethereum’s Full Sync designed with performance in mind.

This staged sync is in essence a state machine consisting of series of stages, each one of which is a segmented part of the syncing process of the node. Each stage takes care of one well-defined task, such as downloading headers or executing transactions, persist their results to a database, and roll forwards and backwards according to required changes. Each stage is thus executed once, unless an interruption or a network reorg/unwind requires restarting or rolling back.

In Reth, the staged sync pipeline executes queued stages serially. An external component determines the tip of the chain and the pipeline then executes each stage in order from the current local chain tip and the external chain tip. When a stage is executed, it will run until it reaches the chain tip.

The [reth docs](https://github.com/paradigmxyz/reth/blob/main/crates/stages/src/pipeline/mod.rs#L28) for the pipeline have an excellent diagram detailing how the stages work.

![](https://i.imgur.com/yMGxizE.png)

Of course, nothing is written in stone, and may change as possible improvements are detected and implemented, and as the project takes on it’s own direction.

What is relevant here is how things one takes for granted need in other contexts to be re-thought and implemented, such as maintaining data consistency, being able to provide efficient rollbacks and cryptographic hash state computations, etc.

But at the end of the day, code rules. Here are some of the more interesting PRs we were able to contribute:

        * [Adding a stage to the sync pipeline for calculating the chain’s state root in an incremental fashion](https://github.com/paradigmxyz/reth/pull/994)
        * [Adaptable request timeouts](https://github.com/paradigmxyz/reth/pull/789)
        * [Prioritizing requesting peers with low latency](https://github.com/paradigmxyz/reth/pull/835)
        * [Adding support for prometheus metrics](https://github.com/paradigmxyz/reth/pull/474) to the [headers sync stage](https://github.com/paradigmxyz/reth/pull/498) and [txpool](https://github.com/paradigmxyz/reth/pull/584).

As well as general tests and documentation.

We are thankful to Paradigm for spearheading and allowing us to collaborate with them and the community. Managing a project takes time and effort.

EOF.
