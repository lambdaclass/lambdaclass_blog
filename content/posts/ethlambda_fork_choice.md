+++
title = "Fork Choice in leanConsensus: How ethlambda Implements LMD-GHOST"
date = 2026-03-17
slug = "fork-choice-in-lean-consensus"
description = "This is a follow-up to our posts on ethlambda's architecture. Here we explain the two core consensus mechanisms that ethlambda implements: LMD-GHOST for fork choice and 3SF-mini for finality."

[extra]
feature_image = "/images/2026/ethlamdba_fork_choice/Serment_du_Jeu_de_Paume_-_Jacques-Louis_David.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["Ethereum", "Lean Consensus", "Ethlambda"]
+++

# Fork Choice in leanConsensus: How ethlambda Implements LMD-GHOST

A deep dive into one of the two consensus mechanisms at the heart of leanConsensus: how the client picks the right chain and decides when a block is permanent.

---

*This is a follow-up to our posts on [introducing ethlambda](https://blog.lambdaclass.com/introducing-ethlambda-a-lean-consensus-client-for-ethereums-next-era/) and [ethlambda's architecture](https://blog.lambdaclass.com/building-a-minimalist-post-quantum-ethereum-client-ethlambdas-architecture/). Here we explain the two core consensus mechanisms that ethlambda implements: LMD-GHOST for fork choice and 3SF-mini for finality.*

> Much of the conceptual framing in this post is inspired by Ben Edgington's
> [Eth2 Book](https://eth2book.info/), particularly the [LMD GHOST chapter](https://eth2book.info/latest/part2/consensus/lmd_ghost/).
> Highly recommended reading for anyone interested in Ethereum consensus.

A consensus client has to answer two questions every few seconds: *which chain tip should I follow right now?* and *which blocks are permanent and can never be reverted?*

The first question exists because the blockchain can fork: two valid blocks may share the same parent, creating competing chains at the same height:

```text
                   ┌──────────┐
             ┌────▶│ Block C  │  ← Chain tip 1
             │     │ slot 4   │
┌──────────┐ │     └──────────┘
│ Block A  │─┤
│ slot 3   │ │     ┌──────────┐
└──────────┘ └────▶│ Block D  │  ← Chain tip 2
                   │ slot 5   │
                   └──────────┘

                    Which tip should validators follow?
```

Every node in the network must independently arrive at the same answer using only its local view of blocks and attestations. The fork choice rule is what makes this possible: a deterministic function from a node's observed state to a single chain tip. The second question is fundamentally different: it requires a conservative mechanism that only commits when there's overwhelming agreement.

In ethlambda, the first question is answered by **LMD-GHOST** and the second by **3SF-mini**. Together they form the consensus algorithm of the leanConsensus protocol.

## LMD-GHOST: following the heaviest subtree

The GHOST protocol was introduced by Sompolinsky and Zohar in a [2013 paper](https://eprint.iacr.org/2013/881.pdf). Its core idea: instead of choosing the longest or heaviest chain, choose the **heaviest subtree**. A vote for any block is implicitly a vote for all of its ancestors:

```text
Validator attests: head = F

A ── B ── C ── D ── E ── F
▲    ▲    ▲    ▲    ▲    ▲
│    │    │    │    │    │
└────┴────┴────┴────┴────┘
All ancestors implicitly supported
```

The "LMD" stands for Latest Message Driven: only each validator's most recent attestation counts. This prevents vote amplification: if all messages counted, a validator could cast many attestations and multiply their influence. With LMD, each validator gets exactly one active vote regardless of how many attestations they've broadcast.

```text
Validator 7's attestation history:

Slot 10: attests to head = B     ← discarded
Slot 11: attests to head = C     ← discarded
Slot 12: attests to head = E     ← THIS is the active vote

Only the slot 12 attestation counts for fork choice.
```

The fork choice store maintains a simple mapping: one row per validator, new attestation overwrites the old one.

```text
┌──────────────┬──────────────────────────────┐
│ Validator    │ Latest Attestation           │
├──────────────┼──────────────────────────────┤
│ 0            │ head=E, target=C, source=A   │
│ 1            │ head=D, target=C, source=A   │
│ 2            │ head=E, target=C, source=A   │
│ 3            │ head=F, target=D, source=A   │
│ ...          │ ...                          │
└──────────────┴──────────────────────────────┘
```

### Why subtrees beat chains

The simplest fork choice rule is "heaviest chain": follow the tip with the most votes. This works when fork rates are low, but it breaks under adversarial conditions:

```text
HEAVIEST CHAIN vs HEAVIEST SUBTREE
──────────────────────────────────

An attacker with 40% of stake forks at A.
The honest majority (60%) builds on B but forks into C and D:

                ┌───B──┬──C     V0, V1, V2 vote for C (30%)
          A ────┤      └──D     V3, V4, V5 vote for D (30%)
                │
                └───X──Y──Z     V6, V7, V8, V9 vote for Z (40%)

Heaviest chain:
  Z has 40% of votes, C and D each have 30%.
  Attacker wins! ✗

Heaviest subtree (LMD-GHOST):
  At A: B subtree has 60% (C + D), X subtree has 40%.
  Pick B. Then at B: C has 30%, D has 30% (tiebreaker).
  Honest majority wins. ✓
```

LMD-GHOST is strictly better when honest validators fork within a common subtree. Instead of requiring all honest validators to agree on a single chain tip (which is impossible under network delay), it aggregates their support at each level of the tree.

### The algorithm

The algorithm takes four inputs:

| Input | Purpose |
|-------|---------|
| Start root | The root of the subtree to search (justified checkpoint or genesis) |
| Block tree | The set of known blocks: root → (slot, parent) |
| Attestations | Latest message per validator: validator_index → attestation |
| Min score | Minimum weight for a branch to be considered (0 = any branch; ⌈2V/3⌉ = conservative) |

**Step 1: Accumulate weights.** Each attestation "paints" the path from its attested head back to the start root, adding +1 to every block along the way. In leanConsensus all validators currently have equal weight (a simplification for the proof of concept), unlike the Beacon Chain which weights votes by effective balance.

```text
Validator 0 attests to head = F

  R ─ A ─ B ─ C ─ D ─ E ─ F       (R = root of the subtree)
      +1  +1  +1  +1  +1  +1       R is at start_slot, not counted

Validator 1 attests to head = D

  R ─ A ─ B ─ C ─ D
      +1  +1  +1  +1

Accumulated weights:

  Block:    R    A    B    C    D    E    F
  Weight:   ─    2    2    2    2    1    1
            │
            └ start_root (not weighted, used as the descent origin)
```

**Step 2: Greedily descend.** Starting from the start root, pick the child with the most weight at each fork. Repeat until reaching a leaf. That leaf is the head.

```text
R ──┬── B (5)   ← pick B (higher weight)
    └── G (2)

B ──┬── C (3)   ← pick C (higher weight)
    └── H (2)

C ──── D (3)    ← only child, continue

D ── (no children) → HEAD = D!
```

Children below `min_score` are ignored during the descent.

**Tiebreaker:** When two children have exactly equal weight, the block with the lexicographically higher root hash wins. The specific choice doesn't matter; what matters is that all nodes apply the same rule.

```text
Equal weight scenario:

    Parent
    │
┌───┴───┐
B (3)   C (3)         ← Equal weight!
root:   root:
0x3a..  0x7f..        ← 0x7f > 0x3a, so pick C
```

In ethlambda, the core function is `compute_lmd_ghost_head()` in `crates/blockchain/fork_choice/src/lib.rs`.

### Worked example

Consider 5 validators (indices 0–4) and this block tree rooted at R at slot 10:

```text
Slot 10     ┌──────┐
            │  R   │ ← start_root
            └──┬───┘
               │
Slot 11     ┌──┴───┐
            │  A   │
            └──┬───┘
            ┌──┴────────┐
            │           │
Slot 12  ┌──┴───┐    ┌──┴───┐
         │  B   │    │  C   │
         └──┬───┘    └──┬───┘
            │           │
Slot 13  ┌──┴───┐    ┌──┴───┐
         │  D   │    │  E   │
         └──────┘    └──────┘
```

**Latest attestations:**

| Validator | Attested Head | Path back to R |
|-----------|---------------|----------------|
| 0         | D             | D → B → A      |
| 1         | D             | D → B → A      |
| 2         | E             | E → C → A      |
| 3         | E             | E → C → A      |
| 4         | E             | E → C → A      |

**Accumulated weights:**

| Block | Weight | Explanation |
|-------|--------|-------------|
| A     | 5      | On path of all 5 validators |
| B     | 2      | On path of V0, V1 |
| C     | 3      | On path of V2, V3, V4 |
| D     | 2      | Head of V0, V1 |
| E     | 3      | Head of V2, V3, V4 |

**Greedy descent:**

```text
Start at R
  └─▶ A (only child, weight 5)
       ├── B (weight 2)
       └── C (weight 3)  ← Pick C (3 > 2)
            └─▶ E (only child, weight 3)
                 └─▶ No children → HEAD = E ✓
```

The canonical head is **Block E**. Even though both branches have the same depth, the C→E branch has 3 votes vs B→D's 2 votes.

**What if a vote changes?** If two validators switch from E to D, the head reorgs:

```text
Before:  V0=D, V1=D, V2=E, V3=E, V4=E   → Head = E (3 vs 2)
After:   V0=D, V1=D, V2=D, V3=D, V4=E   → Head = D (4 vs 1)  ← REORG
```

Reorgs are normal during transient network conditions but should be rare in stable operation. They cannot cross a finalization boundary: once a block is finalized, it is permanently part of the canonical chain. Since you can't fix what you can't see, ethlambda tracks reorgs via Prometheus metrics (`lean_fork_choice_reorgs_total`) and detects them by checking whether the old and new heads share a common prefix.

### How finality bounds fork choice

On its own, LMD-GHOST would need to consider every block since genesis, and the block tree would grow without bound. 3SF-mini solves this by producing justified checkpoints: blocks that have received enough attestation support to be considered stable roots for fork choice.
LMD-GHOST uses the latest justified checkpoint as its start root. It never looks at blocks before it. Once a checkpoint is finalized (promoted from justified to finalized by 3SF-mini), all blocks at or before it can be discarded from the fork choice working set entirely.

```text
┌─────────┐         ┌─────────┐         ┌──── ...
│FINALIZED│────────▶│JUSTIFIED│────────▶│  fork choice
│ slot 50 │         │ slot 55 │         │  runs here
└─────────┘         └─────────┘         └──── ...
     │                   │
     │                   └── start_root for LMD-GHOST
     │
     └── everything before this is permanent;
         LiveChain is pruned up to here
```

This is what keeps ethlambda's LiveChain (the in-memory block tree) bounded: it is pruned every time finalization advances, retaining only the non-finalized portion of the chain.

### Safe target selection

Besides computing the head, the same LMD-GHOST algorithm is used to compute the **safe target**: a conservative head obtained by setting `min_score = ⌈2V/3⌉`, so only branches with supermajority support are followed. The safe target feeds into 3SF-mini for justification and finalization decisions. We'll cover this in detail in the next post.

## The attestation pipeline

In a naive implementation, every attestation would influence fork choice the instant it arrives. This creates problems: validators with faster network connections would see different heads than slower ones, and the proposer's view could shift mid-block-construction.

leanConsensus solves this with a **staged promotion pipeline**:

```text
                     ATTESTATION LIFECYCLE
                     ─────────────────────

┌──────────────┐       ┌──────────────────┐       ┌──────────────────┐
│   Network    │       │    Pending       │       │    Active        │
│  (gossip)    │──────▶│  ("new")         │──────▶│  ("known")       │
│              │       │  Attestations    │       │  Attestations    │
└──────────────┘       └──────────────────┘       └──────────────────┘
                               │                          │
                        NOT used for               Used for fork choice
                        fork choice                weight calculations
                               │                          │
                        Promoted at ─────────────▶ designated intervals
                        fixed points
```

This staged design serves two purposes: **consistency** (all validators promote attestations at the same moments, reducing divergence in head selection) and **proposer fairness** (the proposer computes the block against a known, fixed set of attestations).

Attestations enter the pipeline differently depending on their source:

| Source | Enters As | Reason |
|--------|-----------|--------|
| Network gossip | **Pending** | Must wait for promotion window |
| Block body (on-chain) | **Active** | Already consensus-validated |
| Proposer's own attestation | **Pending** | Prevents proposer weight advantage |

The proposer's own attestation entering as pending is deliberate: if it were immediately active, the proposer would gain an unfair weight advantage for their own block, a circular dependency where proposing a block gives you an extra vote toward making that block canonical.

### Tick-based scheduling

ethlambda (as per devnet-3) divides each 4-second slot into 5 intervals of 800ms each:

- **Interval 0: Block proposal.** The proposer promotes pending → known attestations, runs fork choice, builds and publishes a block.
- **Interval 1: Attestation casting.** Validators create and broadcast their attestation (entering the "new" pending set) with `head` = current fork choice head, `target` = derived from safe target (for 3SF-mini), `source` = latest justified checkpoint.
- **Interval 2: Aggregation.** Aggregators collect attestations, create aggregation proofs, and broadcast them to the network.
- **Interval 3: Safe target update.** Recalculate the safe target with the ⌈2V/3⌉ supermajority threshold.
- **Interval 4: End of slot.** Process accumulated attestations (promote pending → known), run fork choice, update the head.

### Data flow summary

![](/images/2026/ethlamdba_fork_choice/Screenshot-2026-03-17-at-2.51.06---PM.png)

## Design choices vs the Ethereum Beacon Chain

leanConsensus makes different design choices from the Beacon Chain. These aren't simplifications for their own sake; they follow from a deliberate commitment to keeping the protocol simple to reason about, analyze, and implement. Complexity is added only when it's proven necessary.

| Aspect | leanConsensus | Ethereum Beacon Chain | Rationale |
|--------|-----------|----------------------|-----------|
| **Vote weight** | Equal: 1 vote per validator (for now) | Proportional to effective balance (up to 32 ETH) | Proof-of-concept simplification; keeps analysis and implementation simple while the protocol matures |
| **Proposer boost** | None | Temporary bonus weight for newly proposed blocks | Solved differently: the staged attestation pipeline handles proposer fairness without adding fork choice complexity |
| **Attestation frequency** | Every slot | Once per epoch | More responsive fork choice at the cost of higher message volume |
| **Committee structure** | All validators attest each slot | Validators split into per-slot committees | Simpler; no committee selection logic needed |
| **Slot duration** | 4 seconds | 12 seconds | Faster finality |

### Performance and optimization

The naive approach to fork choice rebuilds the entire block tree from scratch on every call: walk every attestation, accumulate weights across the full tree, then descend. This works, but it's wasteful: most of the tree hasn't changed since the last run.

There's a spectrum of increasingly sophisticated implementations, pioneered by Beacon Chain clients:

| Approach | What it caches | Cost per fork choice run | Scales with |
|----------|---------------|--------------------------|-------------|
| **Naive** | Nothing; full rebuild each time | O(A × D) | Attestation count × chain depth |
| **Cached tree** | Pruned block tree, updated on new blocks and finalization | Avoids tree reconstruction; still recomputes weights | Block arrival rate |
| **Cached weights** | Weights stored in tree nodes, updated incrementally on each vote | O(1) amortized (proto-array) | Validator count (gracefully) |

ethlambda currently implements the second approach: the `LiveChain` keeps the pruned tree in memory and updates it as blocks arrive and finalization advances. We don't yet cache weights in the fork tree (the third approach), but it's on our radar. In networks with large validator sets, incremental weight updates become essential to keep fork choice fast.

## What's next

LMD-GHOST tells us which chain tip to follow, but fork choice alone provides no guarantee that a block is permanent. In our next post, we'll cover 3SF-mini, the finality gadget that makes blocks irreversible: how justification and finalization work at the slot level, the justifiability schedule that acts as a built-in backoff mechanism, and how it all differs from the Beacon Chain's Casper FFG.

We have recently added devnet-3 support and we continuously follow the latest leanSpec changes. We give daily updates on [Telegram](https://t.me/ethlambda_client).

ethlambda is open source at [github.com/lambdaclass/ethlambda](https://github.com/lambdaclass/ethlambda). Follow along or join the conversation on [Telegram](https://t.me/ethlambda_client) or [X](https://x.com/ethlambda_lean).
