+++
title = "libssz: a blazing fast, zkVM-friendly SSZ Rust library"
date = 2026-03-25
slug = "libssz-a-blazing fast-zkVM-friendly-SSZ-Rust-library"
description = "SSZ (Simple Serialize) is the serialization and Merkleization format of Ethereum's consensus layer. We present a new implementation in Rust that fills a niche: fast and zkVM friendly."

[extra]
feature_image = "/images/2026/Johannes_Vermeer_-_The_lacemaker_-c.1669-1671-.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["Rust", "Zero Knowledge", "Ethereum"]
+++

# libssz: a blazing fast, zkVM-friendly SSZ Rust library

[SSZ](https://ethereum.github.io/consensus-specs/ssz/simple-serialize) (Simple Serialize) is the serialization and Merkleization format of Ethereum's consensus layer. Consensus clients encode beacon states and blocks in SSZ, and compute Merkle proofs over that data using SSZ hash tree roots. Until recently, SSZ was a consensus-only concern, since execution clients didn't need it.

## The SSZ landscape today

Some of the Rust SSZ libraries that exist today are:

|               | [Lighthouse](https://github.com/sigp/ethereum_ssz) (`ethereum_ssz`) | [ssz_rs](https://github.com/ralexstokes/ssz-rs) |
| ------------- | ------------------------------------------------------------------- | ----------------------------------------------- |
| Performance   | Fast, battle-tested in production                                   | 100–300x slower on composite types              |
| `no_std`      | No. Depends on `std`, pulls `ring` (C lib) via `ethereum_hashing`   | Yes. `no_std + alloc`                           |
| Bounded types | `typenum`                                                           | `typenum`                                       |

Lighthouse is the reference implementation for Rust SSZ and what most projects use. ssz_rs supports `no_std`, but is 100–300x slower on composite types, which means that you can't use it in production. Until recently, no one needed both fast *and* `no_std` SSZ, so no one built it.

## Two proposals bring SSZ to the execution layer

Two proposals bring SSZ into the execution layer.

A [proposal to add binary SSZ to the Engine API](https://github.com/ethereum/execution-apis/pull/764) replaces JSON with raw SSZ bytes over HTTP. The CL already has execution payloads in SSZ from beacon blocks; binary transport lets it forward raw bytes to the EL without conversion. As blob counts grow, JSON becomes the bottleneck (hex encoding doubles each 128 KB blob), and switching to SSZ lets clients scale `MAX_BLOB_COMMITMENTS_PER_BLOCK`.

[EIP-8025](https://eips.ethereum.org/EIPS/eip-8025) (Optional Execution Proofs) extends the Engine API with endpoints for generating, submitting, and verifying zkVM execution proofs, allowing validators to attest to execution validity backed by cryptographic proofs. The public input for these proofs is `tree_hash_root(NewPayloadRequest)`, an SSZ Merkle root. Execution clients need to compute hash tree roots over structured consensus types like `ExecutionPayload`, `NewPayloadRequest`, and their sub-containers.

The [RISC-V target standard](https://github.com/eth-act/zkvm-standards/blob/main/standards/riscv-target/target.md) requires conforming zkVMs to compile guest code without the standard library. Many zkVMs today work around this with forked compilers, but [ZKsync's Airbender](https://github.com/matter-labs/zksync-airbender) enforces `no_std`. More will follow as teams adopt the standard.

If you're building binary SSZ transport, you need a fast SSZ library. If you're proving EIP-8025 execution inside a zkVM, you need one that is both fast and `no_std`.

## Why not adapt what exists?

[jsign](https://github.com/jsign) tried making Lighthouse's SSZ work in `no_std` while implementing EIP-8025 guest programs for [ere-guests](https://github.com/eth-act/ere-guests) ([ere-guests#8](https://github.com/eth-act/ere-guests/issues/8)):

> *I went into that rabbit hole a bit, and got pretty far but required at least these patches:*
>
> ```
> ethereum_ssz = { git = "https://github.com/han0110/ethereum_ssz", branch = "feature/no-std" }
> ethereum_ssz_derive = { git = "https://github.com/han0110/ethereum_ssz", branch = "feature/no-std" }
> ethereum_serde_utils = { git = "https://github.com/han0110/ethereum_serde_utils", branch = "feature/no-std" }
> tree_hash = { git = "https://github.com/jsign/tree_hash", rev = "2263d50" }
> tree_hash_derive = { git = "https://github.com/jsign/tree_hash", rev = "2263d50" }
> ssz_types = { git = "https://github.com/jsign/ssz_types", rev = "679b7ba" }
> ```

Six forked crates across three maintainers, and he still wasn't done. In [the PR](https://github.com/eth-act/ere-guests/pull/7), where he implemented the EIP-8025 guest program design, jsign wrote:

> *I spent a while patching crates, but I already needed to patch 6 crates before I felt too uncomfortable having so many patches.*

The Lighthouse team never built their SSZ ecosystem for `no_std`. `ethereum_hashing` pulls `ring` (a C library) without a feature gate, `ssz_types` depends on `typenum` with `std` features, and the dependency graph is deep enough that you'd need to coordinate patches across multiple repositories to make it `no_std`-clean.

## How we built libssz

SSZ encoding has two paths: fixed-size types (integers, byte arrays, structs with only fixed fields) and variable-size types (lists, containers with at least one variable field). The fixed path is a straight memcpy. The variable path pays for offset bookkeeping and intermediate buffers.

Lighthouse allocates a separate buffer for variable data, then copies it into the final output. Every variable field goes through two writes. For a BeaconState with 21 fields, that adds up.

We wrote a `ContainerEncoder` that writes variable data directly to the output buffer. Fixed fields get patched in-place into a pre-allocated region. One write per field, zero intermediate allocation. For all-fixed containers (BeaconBlockHeader, Fork, Checkpoint), the derive macro skips the encoder entirely and generates direct field-by-field append. No heap, no offset tracking.

The other bottleneck was per-element iteration. Lighthouse encodes a `Vec<u64>` by calling `ssz_append` on each element. On little-endian platforms, a `Vec<u64>` is already laid out in memory as SSZ expects. We use a single `memcpy` for the entire slice. Same for `[u8; N]` arrays and decode.

Merkleization had a similar problem: Lighthouse uses `lazy_static` for the zero hash table (64 SHA-256 hashes computed on first access). We compute them at build time via `build.rs`. No runtime initialization, no synchronization.

These decisions shaped the crate structure:

```
libssz-derive ···→ libssz-merkle ──→ libssz ←── libssz-types
  (proc macros)      (Merkleization)    (core)     (bounded collections)
```

- **`libssz`**: `SszEncode` / `SszDecode` traits, `ContainerEncoder` / `ContainerDecoder`, primitive impls
- **`libssz-types`**: Bounded collections (`SszVector`, `SszList`, `SszBitvector`, `SszBitlist`) using const generics instead of `typenum`
- **`libssz-merkle`**: `HashTreeRoot`, `merkleize`, build-time zero hashes
- **`libssz-derive`**: `#[derive(SszEncode, SszDecode, HashTreeRoot)]` with all-fixed detection

The structure follows from the decisions: Merkleization is separate because you might not need it (e.g., transport-only use cases). The derive macro detects all-fixed containers at compile time and generates a different code path. Bounded types use const generics (`SszVector<T, 1024>`) instead of typenum (`Vector<T, U1024>`) because the SSZ spec bounds are always literal constants.

Everything builds for `no_std + alloc`. CI verifies compilation on both `thumbv7m-none-eabi` and `riscv64imac-unknown-none-elf` on every commit.

## Correctness

We validate libssz against the official [Ethereum consensus spec test vectors](https://github.com/ethereum/consensus-specs/releases/tag/v1.6.1) (v1.6.1): **62,489 test cases** across all 9 forks (Phase0, Altair, Bellatrix, Capella, Deneb, Electra, Fulu, Gloas, EIP-7805).

This covers:
- **ssz_generic**: all SSZ primitive types, vectors, lists, bitfields, containers, and unions, both valid and invalid cases
- **ssz_static mainnet**: all Ethereum consensus types (`BeaconState`, `BeaconBlock`, `Attestation`, etc.) at mainnet parameters
- **ssz_static minimal**: same types at minimal preset parameters

Each test case verifies decode, re-encode roundtrip, and hash tree root correctness.

We run **19 differential fuzz targets** against both Lighthouse and ssz_rs, covering roundtrips, adversarial offsets, deep nesting, and wide unions. These run nightly in CI.

## Performance

We benchmarked against Lighthouse (`ethereum_ssz` + `tree_hash`) and ssz_rs v0.9, compiled with `--release` and thin LTO, on an AMD Ryzen 9 9950X3D (x86_64).

### Encode

| Type | libssz | Lighthouse | ssz_rs | vs Lighthouse | vs ssz_rs |
|------|--------|------------|--------|---------------|-----------|
| `BeaconBlockHeader` | 10.1 ns | 84.2 ns | 1.71 µs | **8.4x** | **170x** |
| `Vec<u64>` (100K) | 9.20 µs | 35.8 µs | 2.36 ms | **3.9x** | **257x** |
| `BeaconState` (100K val) | 450 µs | 773 µs | 201 ms | **1.7x** | **446x** |
| `BeaconState` (1M val) | 10.1 ms | 20.3 ms | 1.58 s | **2.0x** | **156x** |

### Decode

| Type | libssz | Lighthouse | ssz_rs | vs Lighthouse | vs ssz_rs |
|------|--------|------------|--------|---------------|-----------|
| `BeaconBlockHeader` | 8.96 ns | 7.08 ns | 196 ns | 0.8x | **22x** |
| `Vec<u64>` (100K) | 9.24 µs | 59.7 µs | 31.8 µs | **6.5x** | **3.4x** |
| `BeaconState` (100K val) | 313 µs | 908 µs | 20.5 ms | **2.9x** | **66x** |
| `BeaconState` (1M val) | 9.27 ms | 13.9 ms | 172 ms | **1.5x** | **19x** |

libssz is faster than Lighthouse on `BeaconState` encode and decode at all tested validator counts. On primitives, libssz reaches 3.2x on `u64` encode and 3.2x on `[u8; 32]` encode.

Full results including ARM (Apple M3 Max) benchmarks and hash tree root comparisons are in the [README](https://github.com/lambdaclass/libssz#performance). All benchmarks are reproducible via `cargo bench --bench differential`.

## Adoption

### ethlambda

[ethlambda](https://github.com/lambdaclass/ethlambda) is a minimalist Lean Consensus client written in Rust by LambdaClass. [PR #242](https://github.com/lambdaclass/ethlambda/pull/242) migrates from `ethereum_ssz` to libssz: +550/−460 across 34 files. The API surface is close enough to Lighthouse's SSZ that the team swapped it in without issues.

### ethrex

[ethrex](https://github.com/lambdaclass/ethrex) is implementing EIP-8025 in [PR #6361](https://github.com/lambdaclass/ethrex/pull/6361). The team uses libssz for the SSZ containers (`ExecutionPayload`, `NewPayloadRequest`, `NewPayloadRequestHeader`) and to compute the `hash_tree_root` that serves as the public input for execution proofs.

The implementation supports multiple zkVM backends: SP1, RISC Zero, OpenVM, and ZisK. The guest program takes `(NewPayloadRequest [SSZ], ExecutionWitness [rkyv])` as input and outputs 33 bytes (a 32-byte SSZ root plus a 1-byte validity boolean). libssz works in `no_std`, so ethrex doesn't need to maintain a stack of forked dependencies.

### ere-guests

[ere-guests](https://github.com/eth-act/ere-guests) switched from `ethereum_ssz` to libssz in [PR #26](https://github.com/eth-act/ere-guests/pull/26). The migration made `stateless-validator-common` fully `no_std`, which unblocked Airbender as a proving backend. The 15 mainnet blocks used for CI integration tests still match their fixed expectations. jsign measured a 2x speedup on the `hash_tree_root` section inside [ziskemu](https://0xpolygonhermez.github.io/zisk/getting_started/writing_programs.html?highlight=ziskemu#execution-statistics), translating to a 1.05x overall block proving time speedup.

### Start using it

`libssz` v0.1.0 is on [crates.io](https://crates.io/crates/libssz).

```bash
cargo add libssz libssz-derive libssz-merkle libssz-types
```

For `no_std` targets (zkVMs, WASM, embedded):

```bash
cargo add libssz --no-default-features --features alloc
cargo add libssz-types --no-default-features --features alloc
cargo add libssz-merkle --no-default-features --features alloc
cargo add libssz-derive
```

Full documentation, architecture guide, and examples: [github.com/lambdaclass/libssz](https://github.com/lambdaclass/libssz). Dual [Apache-2.0](https://github.com/lambdaclass/libssz/blob/main/LICENSE-APACHE) / [MIT](https://github.com/lambdaclass/libssz/blob/main/LICENSE-MIT) license.
