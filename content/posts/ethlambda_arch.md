# Building a Minimalist Post-Quantum Ethereum Client: ethlambda's Architecture

*This is a follow-up to our post on [building a post-quantum Ethereum client with the help of shared tooling](https://blog.lambdaclass.com/ethlambda-building-a-post-quantum-ethereum-client-with-the-help-of-shared-tooling/), where we covered the devnet progression, baseline client requirements, and ecosystem tooling. Here we detail the ethlambda architecture.*

ethlambda is participating in pq-devnet-2, the latest post-quantum interoperability devnet for Ethereum's Lean Consensus. This devnet focuses on integrating leanMultisig, the signature aggregation scheme that makes post-quantum signatures practical at scale.

In this post, we'll cover the ethlambda architecture: how we handle concurrency, cryptography, networking, and metrics.

## Repo structure

ethlambda is structured as 10 Rust crates:

```
bin/ethlambda/              # Entry point, CLI, orchestration
crates/
  blockchain/               # Fork processing actor
    ├─ fork_choice/         # LMD GHOST implementation
    └─ state_transition/    # Process slots, blocks, attestations
  common/
    ├─ types/               # Core types
    ├─ crypto/              # XMSS aggregation (leansig wrapper)
    └─ metrics/             # Prometheus metrics
  net/
    ├─ p2p/                 # libp2p: gossipsub + req-resp
    └─ rpc/                 # HTTP REST API
  storage/                  # Storage API (RocksDB and InMemory backends)
```

This is the entire project. No thirty crate-workspace or trait hierarchies to navigate before understanding what happens at startup. 
The entry point wires together the components and starts listening.

## Concurrency

The BlockChain component is the core of ethlambda, and runs as an actor using [spawned](https://github.com/lambdaclass/spawned). 
It handles fork choice, state transitions, and validator duties through message-passing: no shared mutable state or explicit locks.

The P2P and RPC layers currently use plain async, though we plan to migrate them to spawned as well. 
The important thing is that the architecture already enforces clean boundaries: P2P receives a block from gossip and sends it to BlockChain for processing. 
BlockChain transitions state and, if it's our turn to attest, sends an attestation back to P2P for broadcasting. 
Networking is separated from consensus, and neither knows the other's internals.

We chose an actor model for BlockChain because concurrency should be contained, not spread. 
The Lean Consensus slot time is 4 seconds, and within that window we need to verify signatures, transition state, and produce attestations. 
The actor boundary keeps the state transition sequential and predictable while the I/O-heavy parts (networking, signature verification) run concurrently around it.

![Ethlambda Architecture](ethlambda_arch.png)

## Cryptography

The crypto crate wraps the ecosystem's [leanSig](https://github.com/leanEthereum/leanSig) and [leanMultisig](https://github.com/leanEthereum/leanMultisig) libraries. 

In Lean Consensus every validator votes in every slot, thus each XMSS key index is used exactly once per slot, 
preventing key reuse, which is a fundamental restriction of hash-based signature schemes.

XMSS signatures are 3112 bytes each. 
Without aggregation, a block with 400 validator signatures would carry over 1.2 MB of signature data alone. 
leanMultisig solves this by aggregating individual signatures into a compact proof.

Aggregation in the current Lean Consensus design follows a two-phase approach:

1. **Fresh signatures**: XMSS signatures arrive via gossip, are verified, and aggregated using leanMultisig. This is the happy path: all validators are online and their signatures arrive within the slot.
2. **Fallback for missing validators**: When we don't have a validator's plain signature for a given attestation, we can still include that validator by reusing an aggregated attestation from a previous block that covers the same attestation and includes them.

## Networking

The p2p layer is built on libp2p, with QUIC over UDP as the transport layer. 
QUIC gives us lower latency than TCP, native encryption, and multiplexing, all of which matters when you have 4-second slots.

Gossipsub parameters are inherited from the Beacon Chain: mesh size of 8, heartbeat interval of 700ms. 
Block and attestation messages flow through topics like `/leanconsensus/{network}/block/ssz_snappy`.

Beyond gossip, we implement request-response protocols for `Status` and `BlocksByRoot` with exponential backoff retry (10ms → 2560ms over 5 attempts). 
These are used during sync: when a node comes online and needs to catch up to the chain head, it requests blocks by root from its peers.

## Metrics

We expose Prometheus metrics via a `/metrics` endpoint, following the [leanMetrics](https://github.com/leanEthereum/leanMetrics) specification for cross-client observability. 
This means any Lean Consensus Grafana dashboard works out of the box with ethlambda.

The metrics we track include slot processing time, attestation counts, peer connectivity, fork choice head, and signature verification duration. 
When something breaks in a devnet, metrics are how we know.

## Takeaways and next steps
We learned a few things during these recent sprints:

**Local devnets shorten the feedback loop.** We can spin up a multi-client devnet in a single command, so we run local devnets continuously. 
They give us a short feedback loop for fast iteration, catching issues in minutes instead of waiting for scheduled deployments.

**Real networks reveal real problems.** Even when local devnets catch some problems, others only surface in long-lived, distributed devnets. 
Non-finalization from state transition mismatches, timing-dependent networking bugs, edge cases in signature aggregation: these need real multi-client environments running over time to appear.

**Shared tooling accelerates everyone.** We covered the ecosystem tooling in detail in our [previous post](https://blog.lambdaclass.com/ethlambda-building-a-post-quantum-ethereum-client-with-the-help-of-shared-tooling/). 
The Lean Consensus ecosystem provides shared specifications, cryptographic libraries, metrics standards, and devnet infrastructure that make it significantly easier to start a new client. 
The Beacon Chain never had this at such an early stage.

In that post we also covered what's ahead for the devnet progression, but to recap, we're currently working on devnet-3 support, along with checkpoint-sync and continued resilience work as the devnets grow in complexity.

We'll continue actively participating in the Lean Consensus devnet progression. We give weekly updates at the PQ Interop Breakout Meetings and daily updates on [Telegram](https://t.me/ethlambda_client).

ethlambda is open source at [github.com/lambdaclass/ethlambda](https://github.com/lambdaclass/ethlambda). Follow along or join the conversation on [Telegram](https://t.me/ethlambda_client) or [X](https://x.com/ethlambda_lean).