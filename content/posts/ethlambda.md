# Introducing ethlambda: A Lean Consensus Client for Ethereum's Next Era

At LambdaClass we have been working on an Ethereum Lean Consensus client called ethlambda. As Ethereum prepares for its most ambitious consensus layer redesign since the Merge, client diversity will be more important than ever. ethlambda is our contribution to that future—a minimalist, fast, and modular implementation of the Lean Ethereum consensus protocol, written in Rust.

This is not our first foray into Ethereum consensus. We have been building [lambda_ethereum_consensus](https://github.com/lambdaclass/lambda_ethereum_consensus), an Elixir-based Beacon Chain client, since 2023. That project taught us how consensus clients work from the inside out. Combined with our work on [ethrex](https://github.com/lambdaclass/ethrex) (our execution client), we now have deep insight into what makes Ethereum clients complex—and what can be simplified.

ethlambda is the synthesis of everything we've learned. Where lambda_ethereum_consensus targets the current Beacon Chain, ethlambda is purpose-built for Lean Consensus from day one—no legacy code, no backward compatibility concerns, just a clean implementation of the new protocol.

The ideas motivating ethlambda share the same core tenet as our other projects: simplicity. We recommend reading Vitalik's [recent post](https://vitalik.eth.limo/general/2025/05/03/simplel1.html) about simplifying the L1; it greatly resonates with us as a guiding principle and reflects much of what Lean Ethereum aims to achieve.

## Why Lean Consensus Matters

When Justin Drake unveiled the Lean Consensus proposal (originally called Beam Chain) at Devcon Bangkok in November 2024, it represented a rare opportunity to make a clean-slate redesign of Ethereum's consensus layer, informed by five years of lessons from the previous Beacon Chain.

Lean Consensus bundles several critical upgrades into a single cohesive redesign:

- **Faster finality**: From ~15 minutes to seconds using 3-slot finality (3SF)
- **Post-quantum security**: Hash-based signatures (leanSig) ready for both SNARKs and quantum computers
- **Lower staking requirements**: From 32 ETH to 1 ETH, dramatically improving decentralization
- **SNARKified consensus**: Real-time provable state transitions
- **Modern networking**: Gossipsub v2.0 and advanced set reconciliation for 4-second slots

Rather than incrementally patching the existing Beacon Chain, Lean Consensus asks: what would we build if we could start fresh with everything we know now?

## Why Build Another Client?

The Lean Consensus ecosystem already has several client teams: Ream (Rust), Zeam (Zig), Qlean (C++), Lantern (C), and a Lighthouse fork (also Rust). With two Rust implementations already in progress, why is LambdaClass building a third?

The answer lies in our approach to software.

The more we work in the crypto space, the more we encounter codebases carrying unnecessary complexity. Libraries with dozens of modules to modularize the slightest things, APIs with excessive traits and generics to abstract every contingency, macros used to save lines at the cost of readability. These are inconveniences we and others constantly deal with when integrating with crypto repositories.

ethlambda is our attempt at building the consensus client we wish existed. 

Bolstering diversity needs implementations that take different approaches to architecture, abstraction, and philosophy in addition to merely implementing in different languages. 

In line with the [LambdaClass work ethos](https://blog.lambdaclass.com/lambdas-engineering-philosophy/), our goal is to always keep things simple and minimal.

## Simplicity as Strategy

**Lines of code matter.** We track LoC for all our projects, ensuring we never exceed a limit. Our ethrex execution client sits at 96k lines—including the EVM, L2 stack, ZK provers, and SDK—while comparable clients exceed 200k before even counting external dependencies. ethlambda currently sits at under 5k lines with full devnet-1 consensus functionality complete. 

**Vertical integration over fragmentation.** Rather than splitting code into dozens of packages, we favor a flat structure with self-explanatory crates. If you can't explain what a module does in one sentence, it's probably doing too much.

**Traits are a last resort.** Rust's type system is powerful, but power easily becomes complexity. ethrex contains only 12 traits, which we already consider too many. We use traits only when absolutely necessary—for serialization, storage backends, and cryptographic operations. Having a rich type system doesn't mean you should reify every problem into it.

**Macros are frowned upon.** They save lines at the cost of debuggability. ethrex has exactly four macros, three for tests and one for metrics. Every macro is technical debt you pay interest on when things go wrong at 3 AM.

**Concurrency is contained.** Concurrency adds complexity. We avoid spreading it throughout the codebase and use it only where strictly necessary—not as a default architectural pattern.

**No historical baggage.** Lean Consensus is a clean slate by design. We don't need to implement deprecated features or maintain backward compatibility with pre-merge infrastructure. This improves ROI because it allows us to develop and maintain the client with a smaller team.

## The Post-Quantum Imperative

A key motivation for Lean Consensus is preparing Ethereum for a post-quantum world. Current BLS signatures will eventually fall to quantum computers. Lean Consensus uses hash-based signatures (leanSig) with XMSS aggregation (leanMultisig), which remain secure against both classical and quantum adversaries.

In addition to protecting from theoretical future attacks, there is also a performance aspect: hash-based signatures are SNARK-friendly and enable efficient proof aggregation. The same primitive serves two purposes—a beautiful example of the elegant design that Lean Ethereum embodies.

## Current Status

Lean Consensus development follows a phased approach, with devnets progressively adding complexity:

- **pq-devnet-0** (September 2025): Basic multi-client coordination with modified 3SF-mini consensus
- **pq-devnet-1** (November 2025): leanSig signing and verification integrated across clients

On the ethlambda side, we have completed all core client functionality:

- **Networking**: Connecting to peers via libp2p, responding to STATUS messages, listening for blocks and attestations via gossipsub
- **State management**: Generating initial state from genesis, implementing the state transition function, transitioning state on each new block
- **Fork choice**: Implementing and applying the fork-choice rule based on received attestations
- **Validator duties**: Producing and broadcasting attestations, computing the current proposer, building and broadcasting new blocks

The client integrates with [lean-quickstart](https://github.com/blockblaz/lean-quickstart), so spinning up a local devnet with ethlambda alongside Zeam and Ream is a single command.

We're building in close collaboration with the broader Lean Consensus community—participating in weekly PQ interop breakout meetings, contributing to the shared specifications at [leanSpec](https://github.com/leanEthereum/leanSpec), and learning from other client teams, particularly [Zeam](https://github.com/blockblaz/zeam).

## What's Next

Next up for Lean Consensus is **pq-devnet-2** (targeting January 2026), which will integrate full signature aggregation using leanMultisig.

With core consensus functionality complete, our immediate focus shifts to:

1. **Devnet 2 support**: Implementing leanMultisig signature aggregation
2. **Resilience**: Data persistence and historical syncing
3. **Observability**: Expanded metrics, structured logging, and Grafana dashboards
4. **Performance**: Optimizing for the 4-second slot times Lean Consensus demands

Production deployment is projected for 2029–2030 (although recent events may move that timeline up :P). The real work happens now — in the specification discussions, the devnets, and the hard engineering of turning research into running code.

## The LambdaClass Vision

At LambdaClass, we believe Ethereum should have a forward-looking, accelerationist attitude. This means moving fast, embracing change, and remaining lean by not being afraid of big redesigns when they're warranted. Lean Consensus is exactly this kind of necessary leap.

We can't emphasize enough that client diversity isn't just having multiple implementations but also ensuring that the various implementations embody different approaches and philosophies. ethlambda represents our philosophy: simplicity is not the opposite of capability, but its foundation.

ethlambda is open source from day one:

- **GitHub**: [github.com/lambdaclass/ethlambda](https://github.com/lambdaclass/ethlambda)
- **Telegram**: [t.me/ethlambda_client](https://t.me/ethlambda_client)

The next era of Ethereum is being built now. We're excited to be part of it.
