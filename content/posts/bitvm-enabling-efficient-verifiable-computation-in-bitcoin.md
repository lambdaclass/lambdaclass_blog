+++
title = "BitVM: enabling efficient verifiable computation in Bitcoin"
date = 2025-06-26
slug = "bitvm-enabling-efficient-verifiable-computation-in-bitcoin"

[extra]
feature_image = "/images/2025/12/John_Martin_-_Ruins_of_an_Ancient_City_-_Cleveland_Art_Museum.jpg"
authors = ["LambdaClass"]
+++

## Introduction

Bitcoin was the first blockchain in history, enabling a peer-to-peer electronic cash system for the first time. Introduced in [2008 by Satoshi Nakamoto](https://bitcoin.org/bitcoin.pdf), it provided an elegant yet simple construction to enable people from across the world to store and exchange value over a permissionless and censorship-resistant network.

An important drawback from all blockchains is that they suffer from scalability issues, which stems from the blockchain trilemma between security, decentralization and scalability. The fact that all nodes have to do the same amount of work to secure the network limits the throughput, since the less powerful ones act as bottlenecks. Zero-knowledge proofs allow a party, the prover, to convince another, the verifier, that a given statement is true, without revealing anything else other than the validity of the statement. These proofs are much faster to verify than naïve re-execution.

The smart contract capabilities in Bitcoin are limited to basic types, such as signature, timelocks and hashlocks. Besides, Bitcoin's block size and stack (limited to 1000 elements) are important constraints when it comes to running programs. Bitcoin was not designed to carry out stateful computation, that is, computation that can persist through multiple transactions and user interactions. There a couple of ways of achieving stateful computation with varying security assumptions:

        1. Multisigs: a predetermined set of $n$ parties oversee the computation. It assumes there are at least $t$-of-$n$ honest parties for both safety and liveness. While this is the most straightforward construction, it has undesirable security assumptions for a censorship resistant and permissionless network.
        2. Covenants: they allow the locking script to constrain the spending transaction. This allows for data and logical persistence in Bitcoin without additional assumptions. However, covenants are not available in Bitcoin and would require an upgrade.
        3. ColliderScript: uses a prohibitive amount of computation to emulate covenants. On the upside, it does not require trusted parties and has essentially the same security guarantees as covenants.

The BitVMs are a paradigm that allows for the execution of arbitrary programs in Bitcoin, achieving greater expressivity while keeping the security of Bitcoin's consensus. There are other proposals, such as [ColliderVM](https://eprint.iacr.org/2025/591.pdf). In this post, we will discuss some designs for the BitVM and their tradeoffs. Having more general compute capabilities would allow us to build bridges, L2 and general smart contracts on top of Bitcoin.

There have been several advances and criticism on these approaches. For example, see

        * [advances and breakthroughs on BitVM](https://x.com/david_seroy/status/1930342753961161172),
        * [BitVM on X](https://x.com/ercwl/status/1936774866432110678),
        * [Transfer of Ownership by Fairgate Labs](https://eprint.iacr.org/2025/964.pdf),
        * [On proving pairings by Alpen Labs](https://eprint.iacr.org/2024/640.pdf),
        * [Why BitVM bridges are unsafe](https://medium.com/@twhittle/bitvm-bridges-considered-unsafe-9e1ce75c8176),
        * [How adding a simple opcode could make zk a reality in Bitcoin](https://x.com/ercwl/status/1918938164929962268),
        * [Engineering challenges regarding circuit sizes](https://x.com/dntse/status/1937843989031555124).

## Challenges

Bitcoin script has limited expressivity, making the execution of arbitrary programs extremely expensive. For example, executing the verification of a Groth16 proof, which in a consumer-end laptop can be carried out in few milliseconds, requires up to 3GB in storage space-almost three orders of magnitude more than the 4MB blockspace available right now! Doing operations on-chain is expensive, both in terms of space and wasted resources, so being able to move as much as possible of the computation off-chain can result in greater efficiency. In Ethereum, using ZK proofs is more straightforward, since verification contracts are deployed once and we can call them whenever needed. Even if verification is quite expensive, we can always use recursive proof verification (such as Aligned's proof aggregation mode) to combine several proofs into one and amortize the cost among the constituent proofs.

In Bitcoin, we will have to leverage optimistic computation, assuming the party submitting the proof is behaving honestly, and different parties will be able to challenge him, forcing the disclosure of intermediate steps and allowing them to provide fraud proofs showing where the submitter cheated. That way, the prover does not have to present most of the steps unless he is challenged. This is actually an example of a [naysayer's proof](https://eprint.iacr.org/2023/1472.pdf), which can help reduce the on-chain burden significantly.

A positive point of the construction is that we do not need to implement changes at the consensus level in Bitcoin.

## BitVM-1

This was the [first design](https://bitvm.org/bitvm.pdf) to enable verifiable computation on top of Bitcoin. The basic point is that the prover can claim that a given function over certain inputs, evaluates to a result. If the claim is false, the verifier can trigger a dispute, provide a short fraud proof and punish the prover.

In this case, the design involved only two parties, a prover and a verifier. The off-chain computational burden and communication needed for the protocol is significant, limiting the kind of programs that can be executed. Future designs improved on these aspects, allowing for more parties to interact and further reducing the size of disputes and off-chain communicational and computational burden.

Prover and verifier compile the program into a binary circuit. Any arbitrary computer program can be represented as a circuit of 1s and 0s flowing through logic gates like AND, OR, and NAND. BitVM chooses NAND (NOT-AND) gates as they are universal – any computation can be built using enough NAND gates. The prover then commits to the binary circuit in a Taproot address having one leaf script for each binary gate in the circuit. A taproot tree or taptree makes an UTXO spendable by satisfying certain conditions; the spending conditions are tap-leaves of a Merkle tree. They then presign a sequence of transactions, to enable the challenge-response dynamics. After this, they can make on-chain deposits to the address, which activates the contract and they can start exchaning off-chain data to produce changes in the circuit. Should the prover make false claims, the verifier can take his deposit.

How does the prover commit to a circuit? Basically, for each `bit` he wants to commit to, he has two hashes, `hash0` and `hash1`. If he wants to set the `bit` to 0, he reveals the preimage of `hash0` and if he wants to set `bit` to 1, he reveals the preimage of `hash1`. If at some point the prover ends up revealing both preimages, then the verifier can use them to punish the prover. The value of the bit is set in the stack by hashing the preimage and checking that is matches with one of the hashes. Any gate can be committed to by supplying two commitments to the input and one commitment to the output. Needless to say, this results in a huge blowup in memory footprint, since every bit will require two hashes, and the program has to be represented by a Boolean circuit, which may not be the most efficient form to represent it. Using other operations, such as those involving `u32` can result in a more compact representation.

Once everything is set, the prover and verifier can engage in a game of challenges and responses. If at some point any of them stops cooperating (there is a time limit), the other can claim the deposit. The leaves in the prover's tree (representing the gates) can only be spent if he knows the preimage held by the verifier. If the prover tries to change at least one of the values used in the gate, he would be revealing the preimage of the undisclosed hash (either `hash0` or `hash1`) and the verifier would be in possession of both preimages and can punish the prover for misbehavior. Using binary search, the verifier can find the error efficiently in a few rounds of interaction. In order to reduce the on-chain footprint, prover and verifier can exchange the preimages off-chain. In case the prover doesn't want to cooperate, the verifier can force him to disclose on-chain. A huge drawback is that disproving a computation involves nearly 70 transactions.

## BitVM-2

[BitVM-2](https://bitvm.org/bitvm_bridge.pdf) achieves several advantages in security and efficiency. For example, we can solve the problem of bridging from a t-of-n honest majority to existential honesty during setup, 1-of-n. The new design enabled multiple verifiers (allowing permissionless challenging) and the development of a bridge on top of it, which is a core component for L2 layers.

To be able to execute arbitrary programs, we will leverage SNARKs to generate a proof for the correct execution of the program and verify the proof on Bitcoin. Since verifying the proof is still expensive, we can have the prover commit to the results and, should watchers assume that he is cheating, can challenge him. The dispute can be solved in just 3 on-chain transactions, which is significantly less than in BitVM-1. To be able to run the verification, we proceed as follows:

        1. The verification program (at least 1.2 GB for Groth16 after optimizations) is broken up into subprograms, each at most 4 MB. Each chunk can be run in a single Bitcoin block. The programs run sequentially, and each depends on the output of the previous program.
        2. The prover/operator commits to executing the program, presigning especially crafted messages and taproot trees to ensure that he can withdraw funds and still be challenged for misbehavior.
        3. When he wants to withdraw funds, he must provide the output of the SNARK verifier on-chain and stake capital.
        4. Anyone can check the result with their (local) execution of the SNARK verifier and the public input (which should be available). In other words, other parties can run the full verification on chain and compare their results with the one published by the prover.
        5. If there is a difference, anyone can challenge the prover, who is forced to reveal the whole computation on-chain.
        6. Anyone can then find the wrong chunks, execute them on-chain, proving that the results for the subprogram don't match and slash the prover.

To avoid malicious verifiers from challenging correct executions just to increase the cost for the prover, the verifiers have to pay a fee, which should be at least equal to the cost of posting an intermediate step.

The BitVM-2 could be implemented in a simpler fashion if covenants where available in Bitcoin. These are a proposed class of spending constraints allowing a locking script to restrict how the coins in UTXOs can be spent in the future. To circunvent this, during the setup phase of every instance of the BitVM, a committee of $n$ signers creates a new key pair, presigns messages with the key that should be used to spend the UTXO, establishing that an $n$-of-$n$ quorum must be reached. The members then delete their keys, ensuring that things can only be spent in the intended way. As long as a single one of them complies with this, we ensure that the constraints are enforced.

There are a couple of objections to this design, particularly, the bridge. For example, [here](https://medium.com/@twhittle/bitvm-bridges-considered-unsafe-9e1ce75c8176) it is shown that the bridge is secure so long as the operator is collaterallized at least 1:1. Different options are considered in the [following discussion](https://stacker.news/items/495391). The fact that security requires very large liquidity poses a great threat and has practical implications. Another drawback of this design is the still high cost of asserting and disproving a transaction, with a high on-chain footprint.

## BitVM-3

[BitVM-3](https://bitvm.org/bitvm3.pdf) uses garbled circuits to reduce the on-chain footprint of its predecessor. The circuit is designed to conditionally reveal a secret only if the garbler provides an invalid SNARK proof, acting as a fraud proof. Garbled circuits are a technique from secure two-party computation (Yao’s protocol) where one party (garbler) creates an encrypted version of a boolean circuit and provides “keys” for the input values such that the other party (evaluator) can evaluate the circuit without learning intermediate values – except for the final output, which in certain cases can be a secret reveal. In the context of BitVM3, the idea is that the Prover garbles the SNARK verifier circuit in such a way that if the SNARK proof provided is invalid, the garbled circuit’s output reveals a secret (which serves as a fraud proof).

The largest cost involves sharing the circuit, which takes 5 TB of memory. While this can take several days, it is a one-time setup cost. Asserting a transaction takes around 56 kB, while disproving a transaction involves roughly 200 bytes (compared to between 2 and 4 MB in BitVM-2). This cost reduction puts proof verification in Bitcoin in the realm of feasibility, though we still need to overcome the large communication costs of the circuit, which luckily will go down with further optimizations.

The garbling of the circuit relies on RSA. Each wire in the circuit has two possible keys corresponding to 0 or 1. The garbler (Prover) generates these such that only the correct combination yields a meaningful output key. According to the BitVM3 text, the garbler selects an RSA modulus $N = (2p + 1)(2q + 1)$ (product of two safe primes) and some public exponents $e, e_1 , e_2 , e_3 , e_4$. There are also secret exponents, $d, d_1 , d_2 , d_3 , d_4$ and $h = e_1 e_4 d_2 - e_3$. The $e_i$ and $d_i$ are inverses modulo $\phi (N)/4 = pq$, that is $e_i d_i \equiv 1 \pmod{pq}$. Using the secret factors of $N$ (the trapdoor), the garbler computes wire label values such that the relationships between them hold if and only if the gate’s logical truth table is satisfied. For the output labels $c_0, c_1$ from the circuit, he computes the secret input wires $a_0, a_1, b_0, b_1$ from the following equations:  
\begin{align*}  
b_0 &= (c_1 c_0^{-1} )^{ h^{-1} } \pmod{N} \newline  
b_1 &= b_0^{ e_1 d_2} \pmod{N} \newline  
a_0 &= c_0^d b_0^{ - e_1 d} \pmod{N} \newline  
a_1 &= c_0^d b_0^{ - e_3 d} \pmod{N}  
\end{align*}

These exponentiations can be computed efficiently, since the exponents $e_i$ are chosen as small numbers. Besides, $b_0^d$ and $c_0^d$ can be computed just once and reused in the calculations.

The garbler starts from the output of the circuit and works backwards, producing the labels $a_0 , a_1 , b_0 , b_1$ for each gate. For a preceding gate with output feeding into the first input of the next gate, use $c_0 = a_0$ and $c_1 = a_1$ and if it is for the other input, use $b_0$ and $b_1$.

To be able to handle more general gates (with fan-out > 1, that is, more than one output), the garbler precomputes and publishes a static factor $T_{ik}$. For an output wire $W_{y}$ using labels $l_{y0} , l_{y1}$, feeds and input wire $W_x$, the static factor is given by  
$$l_{xi,k} = l_{yi,k} T_{ik}$$  
so that $T_{ik} = l_{xi,k} l_{yi,k}^{ - 1 }$. The adaptors become part of the public parameters of the circuit.

We can also reblind the labels several times (which amounts to reusing the circuit several times). This is useful to define smaller subcircuits which are used several times, such as field arithmetic or elliptic curve operations. For each round of reblinding, the garbler needs to publish a new $u_k$ which is pairwise coprime with the exponents of previous rounds (the only common divisor of $u_k$ and $u_i$ must be 1).

In case we are using different subcircuits for field operations, we need to add connectors linking the output of one subcircuit to the input of another one. To avoid telescoping attacks, there are two copies of every subcircuit (for example, MulA and MulB) and forbid the use of the same type twice in a row.

The verifier can check the correctness of the garbled circuit's structure by checking each gate in plaintext. Thus, the garbler only needs to prove in zero-knowledge that the circuit's inputs were correctly reblinded, and this involves only few exponentiations. If the prover misbehaves by providing a wrong calculation, the circuit will reveal the hash of the output label for 0 (a short string), which is used as fraud proof.

## Summary

BitVM and its variants are a significant milestone in Bitcoin's evolution, showing that it is possible to have general computation on top of Bitcoin (like Ethereum), without changes to how Bitcoin's consensus works. The core idea is based on naysayer's proofs, which reduces the on-chain footprint, representing the highest cost in the protocol. Since verifying the proof on-chain is expensive, we can have the prover post a claim on-chain and watchers/verifiers can do the check off-chain and dispute the prover's claim using a short proof on-chain. BitVM had a large challenge and response game, involving several transactions and with a large finality. BitVM-2 reduced the response and challenge game to only 3 transactions, but the costs remained high. BitVM-3 uses garbled circuits to further reduce the costs of proving and challenging to 56 kB and 200 bytes, at the expense of a very large setup. It is clear that research and engineering have been improving over the last year and that it won't be long before we have trust-minimized bridges, L2s and general smart contracts on Bitcoin. In upcoming posts, we will cover more in depth different aspects of Bitcoin, its L2 solutions and other virtual machines.
