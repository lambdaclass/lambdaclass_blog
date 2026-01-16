title = "Commit Boost"
date = 2024-01-15
description = "Interview with Drew Van Der Werff on Commit-Boost, a new Ethereum validator sidecard focused on standardizing the communication between validators and third-party protocols,"

[taxonomies]
tags = ["commit-boost", "ethereum"]

[extra]
authors = ["LambdaClass"]
feature_image = "/images/2026/allegory-of-fortune-and-virtue-peter-paul-rubens.jpg"
math = false
+++

## Introduction

For those not part of the community of Ethereum infrastructure operators, developers, and researchers, how the machine works can seem somewhat Rube-Goldberg-esque, especially the parts of the protocol related to block building and selection. Ethereum is a fascinating case study in the interaction of technical constraints and economic incentives, and how it has evolved to address the complexities and tradeoffs brought by the transaction supply chain, which merits its own long-form post. The transaction journey is a strange land, full of dark forests and myths, of actors looking for profit or fairness. 

Today, we interviewed one of its inhabitants, Drew Van der Werff. Previously investing at Brevan Howard Digital and one of the early members of the Digital Assets team at Goldman Sachs, today he is working on Commit Boost (@Commit_Boost) and EthereumFabric (@Fabric_ethereum).

Commit-Boost is a new Ethereum validator sidecar focused on standardizing the communication between validators and third-party protocols, aimed at returning autonomy to Ethereum validators to put constraints around block construction and offer new services to improve Ethereum’s most important product: blockspace. It also aims to improve the quality of life and capabilities of validators and to address some of the key pain points that have emerged over the last few years. 

Importantly, Commit Boost as a project is community-driven, fully open-source, grant-funded, and is currently used by ~35% of validators.

## Why was Commit Boost created?

Commit-Boost was created to increase autonomy for its validator set and help reduce risks for Ethereum.

## How exactly does commit boost reduce risk for Ethereum?

When Commit-Boost was started, multiple teams were working on sidecars to enable new services such as preconfirmations for Ethereum. Having dozens of sidecars would not be great for Ethereum or node operators. Further, like client diversity, Ethereum had one main sidecar and no diversity. Commit-Boost now has 35% adoption and provides an implementation of the sidecar in Rust, improving the robustness of Ethereum.

## What projects or features are being built on top of it?

Currently, the team's main features built on top are preconfirmations, slot auctions, and an out-of-protocol implementation of FOCIL.

## What is the core problem Commit-Boost solves that MEV-Boost cannot or will not solve?

MEV-Boost by design takes power and autonomy away from Ethereum’s decentralized proposer set, Commit-Boost returns this. Further, Commit-Boost came with features to enable transparency and operational streamlining that MEV-Boost did not support. Last, MEV-Boost was not written with performance in mind. These features are part of Commit-boost. I also want to note that many of the features and functionalities were thought of and developed by Ethereum’s validators and the broader community!

## What is the philosophical stance of Commit-Boost on protocol ossification vs. experimentation?

This is not Commit-Boost’s view, but my personal view, you must keep innovating or you will become irrelevant. Obviously, you can’t keep changing everything, but as much as possible, we must keep that mindset front and center. 

## Is Commit-Boost designed to be a neutral standard, a reference implementation, or a competitive product?

Commit-Boost is a public good built by people across Ethereum. The team sustaining it is a non-profit funded by generous grants and time from dozens of teams. 

## What are the key architectural choices you made that differentiate Commit-Boost from MEV-Boost?

Speak with the end customer (validators / proposers) and reflect their desired features, return autonomy back to Ethereum’s decentralized validator set, and help make Ethereum as robust and performant as possible.

## What are your thoughts on ePBS / EIP-7732? 

Again these are my thoughts…Time will tell, but I think this is a hardfork that is shipping something few will use and shouldn’t have been a priority over other alternative items we could have tackled. I suspect it will have negative impacts on Ethereum block construction. Beyond that, I hope it achieves what the core devs feel it will enable.

## Which features do you think should never be inside the protocol layer?

It has always been my dream for Commit-Boost capabilities and what it enables to make its way into Ethereum.

## There seems to still be some ongoing discussions whether all of ePBS will make it into Glamsterdam, especially regarding the trustless aspects. Do you think there is a chance that what gets included will be revised?

No, the core devs made it clear here despite some pushback on the implications of this from market participants. 

## Can you explain the relationship between based rollups and Commit Boost today? 

Commit-Boost helps enable a key feature for based rollups, preconfirmations. I still think synchronous composability with the L1 is a massive unlock and something that should still be heavily pursued by the Ethereum community.

## What is the sustainable funding model for Commit-Boost as a public good?

Commit-Boost is funded through grants that should cover development costs and education for the next few years. At that time, I expect protocol changes will remove the need to run Commit-Boost.

## What is the one thing the community misunderstands about Commit-Boost?
A couple of things here:
- What it can enable for Ethereum, including adding key features such as preconfs, inclusion lists, blockspace futures, specific transactions ordering, and many other features
- Why it was created: reduce risk for Ethereum and return power back to the Ethereum +1m validators!
- How much traction it has!

