+++
title = "Celebrating a year of ethrex"
date = 2025-05-16
slug = "celebrating-a-year-of-ethrex"
description = "We celebrate a year of development on ethrex and talk about what sets it apart."

[extra]
feature_image = "/content/images/2025/12/Jean-Le--on_Ge--ro--me_-_Louis_XIV_and_Moliere.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["ethereum", "ethrex"]
+++

We have been working at LambdaClass on an Ethereum L1 Execution and L2 client called ethrex since June 2024. Now that it's maturing and[ _recently added to Hive_](https://github.com/ethereum/hive/pull/1286), we think it's time to talk about it a bit and highlight what sets it apart from others. 

Ethrex began as an exploratory project with just three team members and has since grown into a 40-person initiative—now one of LambdaClass’ top priorities. It is the first stack to natively incorporate based rollups since day one. We’re preparing to enter the security audit phase and will move directly into production with [_Rogue_](https://x.com/fede_intern/status/1846035499799978475), alongside several institutions and clients eager to deploy their own L2 stacks.

Most of the ideas that motivate ethrex share a core tenet: simplicity. We recommend reading Vitalik’s [_recent post_](https://vitalik.eth.limo/general/2025/05/03/simplel1.html) about simplifying the L1; it shares many of the same ideas we will talk about in this post and greatly resonates with us as a guiding principle.

## **Why build yet another Ethereum execution client?**

At this point, the Ethereum ecosystem has good client diversity: Geth, Besu, Erigon, Nethermind and Reth are all production-grade choices, though with varying degrees of popularity. So why write a new client, and why do it in Rust when Reth exists?

The more we got involved in the crypto space and used its tools and codebases, the more we realized that most of them had more complexity than we were comfortable with; sometimes even actively seeking it as part of their development process. Libraries with dozens of modules to modularize even the slightest things, APIs with tons of traits and generics looking to abstract every contingency, macros used to (debatably) save lines of code at the cost of readability, these are all inconveniences we and others have to constantly deal with when integrating with crypto repositories.

Ethrex is our attempt at solving this. It aims to be the infrastructure, libraries and tooling we wish we had when we started. In line with the[ _LambdaClass work ethos_](/lambdas-engineering-philosophy/), our goal is to always keep things simple and minimal. This is reflected in a few different ways.

We track lines of code for the project, ensuring we never go over a limit. The entire repo currently sits at 62k lines. This includes code for our EVM implementation, our L2 stack (along with ZK provers and TEE code), and our ethereum sdk. Most other clients average around 200k on their main repos, not even counting their dependencies, that are usually split into other repos (EVM, sdk, provers). Including those can easily tip it over 300k or more. Our approach heavily leans into vertical integration and minimalism, ensuring we have control over the whole stack while keeping it as simple as possible.

We have daily automated slack messages to be vigilant about lines of code on our project, and regularly look for dead or unnecessary code and refactor opportunities to trim them down.

![](https://lh7-rt.googleusercontent.com/docsz/AD_4nXdcALtGQVAcNJIEOOLkG6-jxrPB_TceM-wGY_XHqMNqk7mA0-e5ybIXqr0avzaihCNCcjfkKC-Kyved58JHcVGJ0fBgBMs1JBAOpfhUwm-v9V3DTQ0JwQZHRpbayXHK3aF-YodyWQ?key=QZhQagxqvNX4hb2HYsJWkA)Lines of code report

As the image above shows, the ethrex repo consists only of six self-explanatory main crates:

        * blockchain
        * common
        * l2
        * networking (divided into p2p and rpc)
        * storage
        * vm

This is very much on purpose; other clients tend to modularize code too much into different packages, hurting readability and simplicity.

Use of traits is kept to a minimum, only when it absolutely makes sense to introduce them. Our codebase contains as few as 12 traits, which we already consider to be too many and are actively looking to reduce them. They are used for the following:

        * RLP encoding and decoding.
        * Signing of data.
        * Trie Storage, Regular Storage, and L2 Storage.
        * RLPx encoding and RPC handlers.
        * EVM hooks.

Use of macros is frowned upon throughout the codebase. There are only four of them in ethrex, three used only for tests and one for Prometheus metrics collection.

Dependencies are also kept in check as much as possible. Rust codebases are notorious for piling up crates, and while we still consider we depend on too many of them, we make periodic efforts to reduce them.

Minimalism is also reflected in our decision not to implement historical features; ethrex only supports post merge forks. We believe Ethereum should have a forward-looking accelerationist attitude to win over its competitors in the blockchain landscape, which means moving fast, embracing change, and remaining lean by not being afraid of quickly dropping support for old features. This also improves ROI on the project because it allows us to both develop and maintain it with a smaller team.

We are very opinionated about how to write Rust code. While we love the language for its mix of high performance, memory safety guarantees and high level language constructs, we believe it is easy to get carried away with its features and overcomplicate codebases; having a rich and expressive type system does not mean one should take every opportunity to reify every problem into it through a trait. This obfuscates code for newcomers and makes it more complex at very little benefit.

For developers, all this has an impact not only on readability and ease of use, but also on compilation times. Complex code architectures with many traits and macros add to compile times, which hurts developer experience. It is not uncommon to see Rust projects take multiple minutes to compile on modern machines, and code complexity plays a big part in that.

However, simplicity and minimalism is not just about making developer experience easier. The fewer the lines of code, the easier it is to maintain the code, to find bugs or vulnerabilities, and to spot possible performance bottlenecks and improvements. It also reduces the attack surface for security vulnerabilities to be there in the first place.

## **Ethrex L2**

From the beginning, ethrex was conceived not just as an Ethereum L1 client, but also as an L2 (ZK Rollup) client. This means anyone can use ethrex to deploy an EVM equivalent, multi-prover (supporting SP1, RISC Zero and TEEs) based rollup with just one command. Financial institutions can also use it to deploy their own L2, with the choice of deploying it as a Validium, a based Rollup or a regular ZK Rollup. In fact, our upcoming permissionless based L2[ _Rogue_](https://x.com/fede_intern/status/1846035499799978475) uses ethrex and anyone will be able to join it by just cloning the repo and running a command.

Key to the development of ethrex L2 is the availability of general purpose ZK virtual machines using hash-based proving systems, such as SP1 and RISC Zero, that allow proving arbitrary code written in Rust.

Being in the crypto space for some years now, we have experienced firsthand the pains of writing arithmetic circuits using libraries like Circom, Bellman, Arkworks or Gnark. Doing so requires in-depth knowledge about the internals of zk-SNARKS, which most engineers do not and should not care about. Additionally, requiring a different API or DSL to write circuits means you end up with two implementations of the same thing: one out of circuit and one in-circuit. This is a huge source of problems, because on every code change there's the possibility of a divergence between the code being executed and the code being proven, and solving those types of bugs can be challenging and time consuming.

With a RISC-V zkVM, those problems go away; engineers can easily write the code to be proven without having to understand any of the internals, and the chances of a divergence are minimal, because almost all code can be shared between the "out of circuit" and the "in circuit" versions.

ZK-rollups like Scroll and ZKsync tightly coupled their proving system with their VM. While this worked, it meant having a non-EVM architecture and going through a lot of hoops to support EVM equivalence. It also meant having an in-house team of expert cryptographers to design and develop all the complex circuits required to prove their execution. At LambdaClass, we believe that the low level cryptography should be left to projects like Starkware’s Stwo, Lita’s Valida, Polygon’s PetraVM, Succinct’s SP1, or a16z’s Jolt. Our job is to then plug their work into ours, decoupling the cryptography from the rest of the codebase, greatly simplifying the development. This is what allowed us to be the only client designed from the beginning to be an L1, an L2 and a based rollup.

All these benefits can be seen very clearly: the entire l2/prover directory where all the related code lives has only 1.3k lines of code, and even that can be reduced further since we haven't moved some behavior to common functions yet. In other projects we have used and worked with, the ZK-related code was massive, sometimes matching or surpassing the regular non-ZK one.

## **What's left**

We have made a lot of progress in the past year, from an empty repository to a full-fledged L1 and L2 client, but there is still work to be done to make ethrex production-ready. The main focus right now is on performance. We are currently sitting at around 0.3 gigagas/s, and we aim to hit at least 1 gigagas/s in the coming weeks, most of it coming from improvements to trie/database accesses. Afterwards come security audits and based rollup support. We also have extra features planned on top, including alternative DA support for validiums and custom native token mode, both for ethrex L2.

This year’s Devconnect will take place in our hometown, Buenos Aires. By then, we aim to have a feature-complete version of ethrex running in production, ready to showcase some of its most exciting use cases. As mentioned, a growing number of companies and institutions have expressed interest in ethrex and its potential. Our mission is to help advance Ethereum’s development by building infrastructure and applications that address real-world challenges.

We invite you to follow along our progress as we build in the open and try it out yourself:

Telegram: [_https://t.me/ethrex_client_](https://t.me/ethrex_client)  
Github: [_https://github.com/lambdaclass/ethrex_](https://github.com/lambdaclass/ethrex)
