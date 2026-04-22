+++
title = "Finality in leanConsensus: How ethlambda Implements 3SF-mini"
date = 2026-04-14
slug = "finality-in-leanconsensus-how-ethlambda-implements-3sf-mini"
description = "In our previous post, we covered how ethlambda uses LMD-GHOST and ended with an open question: how does the protocol decide when a block is permanent and the chain tip can no longer be reorged? This post covers the other half of consensus: 3-Slot Finality, minimal version."

[extra]
feature_image = "/images/2026/lean_consensus_finality/_The_School_of_Athens__by_Raffaello_Sanzio_da_Urbino.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["Lean Ethereum", "Ethlambda"]
+++

# Finality in leanConsensus: How ethlambda Implements 3SF-mini

In our [previous post](https://blog.lambdaclass.com/fork-choice-in-leanconsensus-how-ethlambda-implements-lmd-ghost/), we covered how ethlambda uses LMD-GHOST to answer the question *"which chain tip should I follow?"* We ended with an open question: how does the protocol decide when a tip reorg is no longer possible? Fork choice tells you where the chain is going, but it doesn't tell you when a block is **permanent**. 

This post covers the other half of consensus: **3SF-mini** (3-Slot Finality, minimal version), the finality gadget used by leanConsensus. If LMD-GHOST is about navigating forks, 3SF-mini is about ending them.

## The problem: when is a block permanent?

On Ethereum today, finality takes about 13 minutes (two epochs of Casper FFG). During that window, a chain reorganization can, in theory, undo any transaction. For most use cases this is fine and for some it's not. At the protocol level, it means the system carries 13 minutes of uncertainty at all times.

leanConsensus targets faster finality, looking to reach finality in 3 slots, bringing finality time down to an average of 10 seconds with 4-second slots. 3SF-mini may not be the final algorithm, but it let's us catch a glimpse of what faster finality looks like. 

## Recap: what attestations carry

Before we get into finality, let's revisit what a validator vote looks like. Each attestation carries three checkpoints:

```
+------------------------------------------------------------------+
|                         ATTESTATION                              |
|                                                                  |
|  head     The block obtained from running fork-choice            |
|           <- LMD-GHOST (covered in the previous post)            |
|                                                                  |
|  target   Block the validator wants justified next               |
|           <- Derived from the safe target, walked back           |
|              to the nearest justifiable slot                     |
|                                                                  |
|  source   Latest justified checkpoint                            |
|           <- Read from the store state                           |
+------------------------------------------------------------------+
```

The **head** feeds into fork choice. The **source** and **target** feed into finality. A vote says: *"I believe checkpoint S is justified, and I want checkpoint T to be justified next."* When enough validators agree on the same (source, target) link, the target becomes justified. Justified checkpoints, under certain conditions, become finalized (irreversible).

The justification threshold is a two-thirds supermajority:

```
3 * vote_count >= 2 * validator_count
```

With 9 validators and 7 voting for the same target: `3*7=21 >= 2*9=18` the target is justified.


**In ethlambda:** Justification and finalization happen inside [`process_attestations()`](https://github.com/lambdaclass/ethlambda/blob/main/crates/blockchain/state_transition/src/lib.rs#L228) in `crates/blockchain/state_transition/src/lib.rs`, called during [`process_block()`](https://github.com/lambdaclass/ethlambda/blob/38229f5d6c3976b7721089c57f91cda3b809b9a0/crates/blockchain/state_transition/src/lib.rs#L103).

## Three slots to finality: the happy path

With 4 validators and everything running smoothly, finality follows the chain tip by just two slots:



At each slot, validators vote for the newest block as their target, citing the latest justified checkpoint as source:

- **Slot N+1:** Votes `source=N, target=N+1`. Three of four vote (`3*3=9 >= 2*4=8`), so N+1 is **justified**.
- **Slot N+2:** Votes `source=N+1, target=N+2`. Three of four vote, so N+2 is **justified**. N+1 and N+2 are consecutive justifiable slots and both are justified, so N+1 is **finalized**.

Each block carries attestations that justify the parent slot and finalize the one before it. With 4-second slots, that's **8 seconds from proposal to finality**.

This is the steady state; but networks aren't always steady.

## When things go wrong: the justifiability schedule

When the network is partitioned or validators disagree about the head, votes scatter across competing targets. No single slot reaches the two-thirds threshold. Justification stalls, and with it, finalization.

This is where 3SF-mini introduces its most interesting idea: **not every slot can be justified**. Only slots at specific distances from the last finalized slot are eligible. The protocol calls these slots *justifiable*.

A slot is justifiable if `delta = slot - finalized_slot` is either less than or equal to 5, a perfect square, or a [pronic number](https://en.wikipedia.org/wiki/Pronic_number):

```
+-------------------------------------------------------+
|             JUSTIFIABILITY RULES                      |
|                                                       |
|  Rule 1:  delta <= 5          (always justifiable)    |
|                                                       |
|  Rule 2:  delta = n^2         (perfect squares)       |
|           1, 4, 9, 16, 25, 36, 49, 64, 81, 100, ...   |
|                                                       |
|  Rule 3:  delta = n(n+1)      (pronic numbers)        |
|           2, 6, 12, 20, 30, 42, 56, 72, 90, 110, ...  |
|                                                       |
+-------------------------------------------------------+
```

Visualized over the first 36 slots:

```
delta: 0  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15 16 17 18 19 20
       Y  Y  Y  Y  Y  Y  Y  .  .  Y  .  .  Y  .  .  .  Y  .  .  .  Y
       |- delta <= 5 -|  2*3      3^2      3*4         4^2         4*5

delta: 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36
       .  .  .  .  Y  .  .  .  .  Y  .  .  .  .  .  Y
                   5^2            5*6               6^2
```

Close to finalization, every slot is justifiable and the chain moves fast. As the gap grows, justifiable slots become sparser. The gaps between them grow from 1, to 3, to 4, to 5, and keep widening.

Why restrict which slots can be justified? Because it creates **natural vote concentration**. If only one slot in a 30-slot window is justifiable, all validator votes in that window funnel toward the same target. When the network is struggling to reach consensus, the protocol structurally forces votes to converge instead of scattering across many candidates.

> **In ethlambda:** The function `slot_is_justifiable_after(slot, finalized_slot)` in `crates/blockchain/state_transition/src/lib.rs` implements this check. It uses `isqrt()` for perfect-square detection and the identity `4n(n+1) + 1 = (2n+1)^2` for pronic-number detection.

## Finalization: the gap rule

Justification alone doesn't make a block permanent. A justified checkpoint becomes **finalized** when the next justifiable slot is also justified, and there are **no justifiable slots in between**. Source and target must be consecutive entries in the justifiability schedule.



The reasoning is elegant: if no justifiable slot exists between source and target, then validators couldn't have directed their votes anywhere else. There's no alternative justification path. That structural impossibility is what makes the checkpoint irreversible.

This is fundamentally different from Casper FFG, which checks that any intermediate checkpoints *are* justified. 3SF-mini checks that intermediate checkpoints *don't exist at all*. A stronger guarantee with simpler logic.

> **In ethlambda:** The `try_finalize()` function in `crates/blockchain/state_transition/src/lib.rs` iterates over slots between source and target and calls `slot_is_justifiable_after` on each. If any slot is justifiable, finalization fails. The check uses `original_finalized_slot` (the finalized slot at the start of block processing, not the current one), since finalization can advance mid-processing.

## Adaptive backoff: self-healing under stress

In addition to being a filter, the justifiability schedule is also a **backoff mechanism**. When finalization stalls, the gap between the finalized slot and the chain head grows. As delta increases, justifiable slots become sparser. As they become sparser, votes concentrate. As votes concentrate, consensus becomes easier. The system pushes itself toward recovery.

Consider a network that's been partitioned for a long time. The finalized slot is stuck at 0, and the chain head is near slot 1000:


Once the network converges:

**Phase 1: Long stall.** Votes finally concentrate. Slots 992 and 1024 are justified. No justifiable slots between them. Slot 992 is finalized. New F=992.

**Phase 2: Partial reset.** The justifiability schedule shifts to anchor on F=992. Near the head (~1024), the delta is only ~32. Gaps shrink from 31-32 to about 6-7.

**Phase 3: Another finalization.** Gaps shrink further.

**Phase 4: Recovery complete.** Delta is small enough that every slot is justifiable again. Fast finalization resumes.

| After finalizing  |  F   | Delta | Nearby gaps  |
|-------------------|------|-------|--------------|
| (stalled)         |    0 | ~1000 | 31-32        |
| Slot 992          |  992 |   ~32 | 6-7          |
| Slot 1022         | 1022 |    ~6 | 1            |

Each finalization step tightens the schedule. The system heals itself progressively, without manual intervention or parameter tuning.

Casper FFG has no equivalent since its epoch spacing is fixed whether the network is healthy or partitioned.

## Forks and delayed convergence: a worked example

Let's walk through a realistic scenario where a fork delays finalization, and see how the system recovers. This connects 3SF-mini back to the fork choice mechanisms from the [previous post](https://blog.lambdaclass.com/fork-choice-in-leanconsensus-how-ethlambda-implements-lmd-ghost/).

**Setup:** 9 validators, finalized=100, justified=101. Safe target threshold: 6 votes (2/3 of 9).

**Slots 102-103: Fork splits votes.**


Neither branch clears two-thirds. Safe target is stuck at block 101. Attestations can't advance justification because the walk-back from head always lands on the source, so there's nothing new to justify.

**Slot 104: Fork resolves.** Validators V7 and V8 receive block 102a (delayed by the partition) and switch sides.


B102a now has 7 votes >= 6. Safe target advances to B102a. Slot 102 is justifiable (delta=2 <= 5). Attestations with `source=101, target=102` reach supermajority: `3*7=21 >= 2*9=18`. Slot 102 is **justified**. No justifiable slots between 101 and 102, so slot 101 is **finalized**.

**Slots 105-106: Full convergence.**

All 9 validators are on the a-branch. Slot 105 with target=B104a is justified. But finalization of 102 fails because slot 103 (between source=102 and target=104) is justifiable but was never justified (lost in the fork). 

In slot 106 target=B105a is justified. No justifiable slots between 104 and 105, so slot 104 is **finalized**. Finalization jumped from 101 to 104, skipping 102 and 103.


The fork caused a brief stall, but the protocol recovered within two slots of convergence. No special recovery mode, no operator intervention. The same rules that handle the happy path handle the unhappy one.

## 3SF-mini vs Casper FFG

Both are finality gadgets built on supermajority links between checkpoints. Both share the same theoretical foundation. They differ in their unit of time and what that implies for the rest of the system.

**Casper FFG** groups 32 slots (~6.4 minutes) into an **epoch** and splits the validator set across them. Each validator attests once per epoch. The full tally is only available at epoch boundaries. Fastest finalization: 2 epochs, about 13 minutes.

This exists because of a scalability constraint, not a protocol-theory preference. With ~1,000,000 active validators on Ethereum, having everyone vote every 12-second slot would be unmanageable. Epochs are the solution.

**3SF-mini** operates on individual **slots** (4 seconds). Every validator votes every slot. This only works right now because leanConsensus has a smaller validator set. The reward: finality in 2 slots instead of 2 epochs.

| Aspect | **3SF-mini** | **Casper FFG** |
|---|---|---|
| Who votes when | All validators, every slot | Each validator once per epoch |
| Messages per slot | N (all validators) | N / 32 (one committee) |
| Supermajority known after | 1 slot | 1 epoch |
| Fastest finalization | 2 slots ~ **8 seconds** | 2 epochs ~ **13 minutes** |
| Adaptive backoff | Yes (justifiability schedule) | No (fixed epoch spacing) |
| Practical validator limit | Hundreds-thousands | Millions |

The finalization logic differs too. Casper uses **k-finality**: a justified checkpoint is finalized when `k` consecutive epoch checkpoints after it are also justified (Ethereum uses k=2 as a recovery mechanism for missed epochs). 3SF-mini uses the **gap rule**: a justified checkpoint is finalized when the next justified checkpoint is its immediate successor in the justifiability schedule, with no possible intermediate targets. Instead of tolerating missed windows, 3SF-mini makes the windows wider when the network is struggling.

## Implementation in ethlambda

The finality pipeline in ethlambda is integrated into block processing. When a block is imported, `process_block()` applies attestations, checks for justification, and attempts finalization, all in a single pass.

| Step | Where | What happens |
|------|-------|-------------|
| Attestation collection | `crates/blockchain/src/store.rs` | Attestations promoted from pending to active at intervals 0 and 4 |
| Justification check | `crates/blockchain/state_transition/src/lib.rs` | `process_attestations()` tallies votes, applies supermajority rule |
| Justifiability filter | `crates/blockchain/state_transition/src/lib.rs` | `slot_is_justifiable_after()` gates which slots can be justified |
| Finalization attempt | `crates/blockchain/state_transition/src/lib.rs` | `try_finalize()` checks the gap rule between source and target |
| Window shift | `crates/blockchain/state_transition/src/justified_slots_ops.rs` | `shift_window()` prunes the justified-slots bitlist when finalization advances |
| Metrics | `crates/blockchain/src/metrics.rs` | `lean_head_slot`, `lean_finalized_slot` updated each tick |

The `justified_slots` bitlist uses relative indexing (index 0 maps to `finalized_slot + 1`). When finalization advances, `shift_window()` drops the now-finalized prefix and reanchors the bitlist. This keeps the data structure bounded regardless of how long the chain runs.

If you want to see 3SF-mini in action, ethlambda is open source and running multi-client devnets today:

- [ethlambda on GitHub](https://github.com/lambdaclass/ethlambda)
- [leanConsensus specification](https://github.com/leanEthereum/leanSpec)
- [Join us on Telegram](https://t.me/ethlambda_client)
- [Follow us on X](https://x.com/ethlambda_lean)

![](/images/2026/lean_consensus_finality/finalization-cascade.png)


At each slot, validators vote for the newest block as their target, citing the latest justified checkpoint as source:

- **Slot N+1:** Votes `source=N, target=N+1`. Three of four vote (`3*3=9 >= 2*4=8`), so N+1 is **justified**.
- **Slot N+2:** Votes `source=N+1, target=N+2`. Three of four vote, so N+2 is **justified**. N+1 and N+2 are consecutive justifiable slots and both are justified, so N+1 is **finalized**.

Each block carries attestations that justify the parent slot and finalize the one before it. With 4-second slots, that's **8 seconds from proposal to finality**.

This is the steady state; but networks aren't always steady.

## When things go wrong: the justifiability schedule

When the network is partitioned or validators disagree about the head, votes scatter across competing targets. No single slot reaches the two-thirds threshold. Justification stalls, and with it, finalization.

This is where 3SF-mini introduces its most interesting idea: **not every slot can be justified**. Only slots at specific distances from the last finalized slot are eligible. The protocol calls these slots *justifiable*.

A slot is justifiable if `delta = slot - finalized_slot` is either less than or equal to 5, a perfect square, or a [pronic number](https://en.wikipedia.org/wiki/Pronic_number):

```
+-------------------------------------------------------+
|             JUSTIFIABILITY RULES                      |
|                                                       |
|  Rule 1:  delta <= 5          (always justifiable)    |
|                                                       |
|  Rule 2:  delta = n^2         (perfect squares)       |
|           1, 4, 9, 16, 25, 36, 49, 64, 81, 100, ...   |
|                                                       |
|  Rule 3:  delta = n(n+1)      (pronic numbers)        |
|           2, 6, 12, 20, 30, 42, 56, 72, 90, 110, ...  |
|                                                       |
+-------------------------------------------------------+
```

Visualized over the first 36 slots:

```
delta: 0  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15 16 17 18 19 20
       Y  Y  Y  Y  Y  Y  Y  .  .  Y  .  .  Y  .  .  .  Y  .  .  .  Y
       |- delta <= 5 -|  2*3      3^2      3*4         4^2         4*5

delta: 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36
       .  .  .  .  Y  .  .  .  .  Y  .  .  .  .  .  Y
                   5^2            5*6               6^2
```

Close to finalization, every slot is justifiable and the chain moves fast. As the gap grows, justifiable slots become sparser. The gaps between them grow from 1, to 3, to 4, to 5, and keep widening.

Why restrict which slots can be justified? Because it creates **natural vote concentration**. If only one slot in a 30-slot window is justifiable, all validator votes in that window funnel toward the same target. When the network is struggling to reach consensus, the protocol structurally forces votes to converge instead of scattering across many candidates.

> **In ethlambda:** The function `slot_is_justifiable_after(slot, finalized_slot)` in `crates/blockchain/state_transition/src/lib.rs` implements this check. It uses `isqrt()` for perfect-square detection and the identity `4n(n+1) + 1 = (2n+1)^2` for pronic-number detection.

## Finalization: the gap rule

Justification alone doesn't make a block permanent. A justified checkpoint becomes **finalized** when the next justifiable slot is also justified, and there are **no justifiable slots in between**. Source and target must be consecutive entries in the justifiability schedule.

![](/images/2026/lean_consensus_finality/finalization-fails.png)

![](/images/2026/lean_consensus_finality/finalization-succeeds.png)


The reasoning is elegant: if no justifiable slot exists between source and target, then validators couldn't have directed their votes anywhere else. There's no alternative justification path. That structural impossibility is what makes the checkpoint irreversible.

This is fundamentally different from Casper FFG, which checks that any intermediate checkpoints *are* justified. 3SF-mini checks that intermediate checkpoints *don't exist at all*. A stronger guarantee with simpler logic.

> **In ethlambda:** The `try_finalize()` function in `crates/blockchain/state_transition/src/lib.rs` iterates over slots between source and target and calls `slot_is_justifiable_after` on each. If any slot is justifiable, finalization fails. The check uses `original_finalized_slot` (the finalized slot at the start of block processing, not the current one), since finalization can advance mid-processing.

## Adaptive backoff: self-healing under stress

In addition to being a filter, the justifiability schedule is also a **backoff mechanism**. When finalization stalls, the gap between the finalized slot and the chain head grows. As delta increases, justifiable slots become sparser. As they become sparser, votes concentrate. As votes concentrate, consensus becomes easier. The system pushes itself toward recovery.

Consider a network that's been partitioned for a long time. The finalized slot is stuck at 0, and the chain head is near slot 1000:

![](/images/2026/lean_consensus_finality/justifiable-gaps.png)

Once the network converges:

**Phase 1: Long stall.** Votes finally concentrate. Slots 992 and 1024 are justified. No justifiable slots between them. Slot 992 is finalized. New F=992.

**Phase 2: Partial reset.** The justifiability schedule shifts to anchor on F=992. Near the head (~1024), the delta is only ~32. Gaps shrink from 31-32 to about 6-7.

**Phase 3: Another finalization.** Gaps shrink further.

**Phase 4: Recovery complete.** Delta is small enough that every slot is justifiable again. Fast finalization resumes.

| After finalizing  |  F   | Delta | Nearby gaps  |
|-------------------|------|-------|--------------|
| (stalled)         |    0 | ~1000 | 31-32        |
| Slot 992          |  992 |   ~32 | 6-7          |
| Slot 1022         | 1022 |    ~6 | 1            |

Each finalization step tightens the schedule. The system heals itself progressively, without manual intervention or parameter tuning.

Casper FFG has no equivalent since its epoch spacing is fixed whether the network is healthy or partitioned.

## Forks and delayed convergence: a worked example

Let's walk through a realistic scenario where a fork delays finalization, and see how the system recovers. This connects 3SF-mini back to the fork choice mechanisms from the [previous post](https://blog.lambdaclass.com/fork-choice-in-leanconsensus-how-ethlambda-implements-lmd-ghost/).

**Setup:** 9 validators, finalized=100, justified=101. Safe target threshold: 6 votes (2/3 of 9).

**Slots 102-103: Fork splits votes.**

![](/images/2026/lean_consensus_finality/fork-choice.png)

Neither branch clears two-thirds. Safe target is stuck at block 101. Attestations can't advance justification because the walk-back from head always lands on the source, so there's nothing new to justify.

**Slot 104: Fork resolves.** Validators V7 and V8 receive block 102a (delayed by the partition) and switch sides.

![](/images/2026/lean_consensus_finality/fork-choice-2.png)

B102a now has 7 votes >= 6. Safe target advances to B102a. Slot 102 is justifiable (delta=2 <= 5). Attestations with `source=101, target=102` reach supermajority: `3*7=21 >= 2*9=18`. Slot 102 is **justified**. No justifiable slots between 101 and 102, so slot 101 is **finalized**.

**Slots 105-106: Full convergence.**

All 9 validators are on the a-branch. Slot 105 with target=B104a is justified. But finalization of 102 fails because slot 103 (between source=102 and target=104) is justifiable but was never justified (lost in the fork). 

In slot 106 target=B105a is justified. No justifiable slots between 104 and 105, so slot 104 is **finalized**. Finalization jumped from 101 to 104, skipping 102 and 103.

![](/images/2026/lean_consensus_finality/slot-timeline.png)

The fork caused a brief stall, but the protocol recovered within two slots of convergence. No special recovery mode, no operator intervention. The same rules that handle the happy path handle the unhappy one.

## 3SF-mini vs Casper FFG

Both are finality gadgets built on supermajority links between checkpoints. Both share the same theoretical foundation. They differ in their unit of time and what that implies for the rest of the system.

**Casper FFG** groups 32 slots (~6.4 minutes) into an **epoch** and splits the validator set across them. Each validator attests once per epoch. The full tally is only available at epoch boundaries. Fastest finalization: 2 epochs, about 13 minutes.

This exists because of a scalability constraint, not a protocol-theory preference. With ~1,000,000 active validators on Ethereum, having everyone vote every 12-second slot would be unmanageable. Epochs are the solution.

**3SF-mini** operates on individual **slots** (4 seconds). Every validator votes every slot. This only works right now because leanConsensus has a smaller validator set. The reward: finality in 2 slots instead of 2 epochs.

| Aspect | **3SF-mini** | **Casper FFG** |
|---|---|---|
| Who votes when | All validators, every slot | Each validator once per epoch |
| Messages per slot | N (all validators) | N / 32 (one committee) |
| Supermajority known after | 1 slot | 1 epoch |
| Fastest finalization | 2 slots ~ **8 seconds** | 2 epochs ~ **13 minutes** |
| Adaptive backoff | Yes (justifiability schedule) | No (fixed epoch spacing) |
| Practical validator limit | Hundreds-thousands | Millions |

The finalization logic differs too. Casper uses **k-finality**: a justified checkpoint is finalized when `k` consecutive epoch checkpoints after it are also justified (Ethereum uses k=2 as a recovery mechanism for missed epochs). 3SF-mini uses the **gap rule**: a justified checkpoint is finalized when the next justified checkpoint is its immediate successor in the justifiability schedule, with no possible intermediate targets. Instead of tolerating missed windows, 3SF-mini makes the windows wider when the network is struggling.

## Implementation in ethlambda

The finality pipeline in ethlambda is integrated into block processing. When a block is imported, `process_block()` applies attestations, checks for justification, and attempts finalization, all in a single pass.

| Step | Where | What happens |
|------|-------|-------------|
| Attestation collection | `crates/blockchain/src/store.rs` | Attestations promoted from pending to active at intervals 0 and 4 |
| Justification check | `crates/blockchain/state_transition/src/lib.rs` | `process_attestations()` tallies votes, applies supermajority rule |
| Justifiability filter | `crates/blockchain/state_transition/src/lib.rs` | `slot_is_justifiable_after()` gates which slots can be justified |
| Finalization attempt | `crates/blockchain/state_transition/src/lib.rs` | `try_finalize()` checks the gap rule between source and target |
| Window shift | `crates/blockchain/state_transition/src/justified_slots_ops.rs` | `shift_window()` prunes the justified-slots bitlist when finalization advances |
| Metrics | `crates/blockchain/src/metrics.rs` | `lean_head_slot`, `lean_finalized_slot` updated each tick |

The `justified_slots` bitlist uses relative indexing (index 0 maps to `finalized_slot + 1`). When finalization advances, `shift_window()` drops the now-finalized prefix and reanchors the bitlist. This keeps the data structure bounded regardless of how long the chain runs.

If you want to see 3SF-mini in action, ethlambda is open source and running multi-client devnets today:

- [ethlambda on GitHub](https://github.com/lambdaclass/ethlambda)
- [leanConsensus specification](https://github.com/leanEthereum/leanSpec)
- [Join us on Telegram](https://t.me/ethlambda_client)
- [Follow us on X](https://x.com/ethlambda_lean)

