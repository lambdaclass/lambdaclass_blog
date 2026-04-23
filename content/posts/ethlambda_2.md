+++
title = "Ethlambda: Building a post-quantum Ethereum client with the help of shared tooling"
date = 2026-02-05
description = "This is a follow-up to our introduction of ethlambda, in which we cover what a Lean Consensus client consists of and what tooling facilitates its development."

[taxonomies]
tags = ["ethereum", "lean", "post-quantum"]

[extra]
authors = ["LambdaClass"]
feature_image = "/images/2026/Frans_Hals_-_Banquet_of_the_Officers_of_the_St_Hadrian_Civic_Guard_Company_-_WGA11092.jpg"
math = false
+++

*This is a follow-up to our [introduction of ethlambda](https://blog.lambdaclass.com/introducing-ethlambda-a-lean-consensus-client-for-ethereums-next-era/), where we covered why we're building a Lean Consensus client and our approach to simplicity. Here we talk about what a Lean Consensus client consists of and what tooling facilitates its development.*

ethlambda is participating in `pq-devnet-2`, the latest post-quantum interoperability devnet for Ethereum's Lean Consensus. This devnet focuses on integrating leanMultisig, the signature aggregation scheme that makes post-quantum signatures practical at scale.

In this post, we'll cover the devnet progression, baseline client requirements, and ecosystem tooling. A follow-up post will detail our architecture.

## Devnet 2

The Lean Consensus devnets progressively add complexity:

- **pq-devnet-0**: Multi-client coordination with 3SF-mini consensus
- **pq-devnet-1**: leanSig signing and verification
- **pq-devnet-2**: leanMultisig aggregation ← *we are here*

XMSS signatures are 3112 bytes each, compared to 96 bytes for BLS. Signature aggregation has always been important for consensus (even BLS signatures don't support enough validators without it), but with XMSS the need is even greater.

The goal of devnet 2 is to benchmark PQ signature aggregation in a live consensus environment. For that, it targets 400 validators, based on the current leanMultisig benchmark of ~400 XMSS aggregations per second.

You can learn more at [leanroadmap.org](https://leanroadmap.org/) and [leanEthereum/pm repository](https://github.com/leanEthereum/pm/tree/main/breakout-rooms/leanConsensus/pq-interop).

![Ethlambda devnet 2 grafana dashboard](/images/2026/ethlambda_devnet_2.jpg)

## Additional client requirements

In addition to the devnet-specific features, a Lean Consensus client needs:

- **Consensus**: 3SF-mini + LMD GHOST consensus and lean state transition function
- **Networking**: Gossipsub and request-response for block and attestation propagation, using libp2p with QUIC (and optionally TCP) transport
- **Sync**: Out-of-sync clients can sync to chain head through request-response
- **RPC API**: HTTP endpoints with observability metrics

## Ecosystem tooling

Building all of this from scratch would be a significant undertaking, but the Lean Consensus ecosystem provides shared tooling that accelerates client development. These components incorporate learnings from the Beacon chain.

### [leanSpec](https://github.com/leanEthereum/leanSpec)

The reference Python specification, with generated test vectors for validating client implementations. A working minimal lean client is also in the works, to kickstart client interoperability for each devnet.

ethlambda runs these test vectors in CI for every PR, ensuring spec compliance before code is merged.

### [leanSig](https://github.com/leanEthereum/leanSig) + [leanMultisig](https://github.com/leanEthereum/leanMultisig)

Cryptographic primitives for a post-quantum chain. leanSig handles individual XMSS signature production and verification, while leanMultisig handles signature aggregation and recursive aggregation.

### [leanMetrics](https://github.com/leanEthereum/leanMetrics)

A standardized metrics specification for cross-client observability. It provides a solid baseline for metrics, including consensus information, P2P connectivity, and performance timing. The spec also includes Grafana dashboards that consume these standardized metrics out of the box.

ethlambda already supports most of these metrics. See our [metrics documentation](https://github.com/lambdaclass/ethlambda/blob/main/docs/metrics.md) for the full list.

### [lean-quickstart](https://github.com/blockblaz/lean-quickstart)

An easy way to start a local devnet or a multi-machine devnet with Ansible. Integrating new clients is straightforward: add your client configuration and you're ready to test interop.

lean-quickstart makes spinning up a multi-client devnet a single command, which meant we could test interop continuously rather than waiting for scheduled devnet deployments.

[This aligns with something we care deeply about at LambdaClass](https://blog.lambdaclass.com/lambdas-engineering-philosophy/): repositories should build easily and cleanly, and a newcomer should be able to have a project running in minutes. Short feedback loops are essential for fast iteration: you can't fix what you can't observe, and you can't observe without a running system.

### [leanpoint](https://github.com/blockblaz/leanpoint)

A work-in-progress tool from the Zeam team. Similar to the beacon chain's checkpointz tool but for the lean chain, it monitors finality across nodes and requires 50%+ consensus before serving checkpoint data.

ethlambda already supports the RPC API endpoints used by leanpoint, and we'll be adding checkpoint-sync support soon.

## What's next: devnet 3

Joining devnet 2 is a milestone, not the finish line. We'll continue actively participating in the Lean Consensus devnet progression, and we give weekly updates at the PQ Interop Breakout Meetings.

pq-devnet-3 decouples aggregation from block production by introducing a separate aggregator role. Validators are assigned to attestation subnets, and aggregators collect individual attestations from their subnet, aggregate them via leanMultisig, and propagate the results. Proposers then collect these aggregated signatures and include them in blocks.

This lays the foundation for tiered aggregation: in pq-devnet-4 we'll introduce recursive aggregation at the proposer, allowing us to reduce the size of block signatures.

ethlambda is open source at [github.com/lambdaclass/ethlambda](https://github.com/lambdaclass/ethlambda). Follow along or join the conversation on [Telegram](https://t.me/ethlambda_client) or [X](https://x.com/ethlambda_lean).
