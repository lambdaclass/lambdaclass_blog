+++
title = "Fully private applications: A ZEXE protocol"
date = 2023-01-05
slug = "fully-private-applications-a-zexe-protocol"

[extra]
feature_image = "/content/images/2025/12/Blake_Dante_Hell_V.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["zero knowledge proofs"]
+++

## Introduction

One of the key issues in the current world is how to achieve consensus between trustless parties. Distributed ledgers have become popular since the advent of cryptocurrencies, built over a technology known as blockchain. One of the main problems is that these ledgers offer limited privacy and are quite constrained on the kind of programs they can run. Aleo provides a full-stack approach for writing private applications. One of its core components is the ZEXE protocol, which is the first ledger system in which applications can be run privately, trustlessly, and can be easily scaled.

As we mentioned before, ledger-based systems can support rich applications, but often suffer from two main drawbacks:

        1. Validating a transaction requires re-executing the state transition it refers to.
        2. Transactions are not private; they reveal information about users and the state of the system.

The latter creates a large number of issues where privacy is critical, since it may leak relevant information regarding one's medical history, payment records, acquaintances and trading partners, etc, which can be used to the advantage of malicious parties.

The first drawback, on the other side, creates scalability issues, since every transition has to be recomputed by every device forming the network (which can have very different computational power), with the weakest one acting as a bottleneck. This has led to the introduction of mechanisms such as gas to make users pay more for expensive computations and discourage denial-of-service attacks.

Some protocols, such as Zerocash, provide privacy-preserving payments and Hawk allows for state transitions where private data remains hidden from third parties. We can say that they achieve data-privacy, but not function privacy, because the transition function being executed is not hidden (even though the input and output parameters may be secret). Function privacy means that an observer is unable to distinguish between different computations performed offline from one another.

ZEXE's aim is to provide a scalable solution to these problems, where both data and function privacy are achieved. This can act as a solid foundation for new forms of data sharing, financial systems, and governance. The main ideas are based on the following:

        1. We can run programs offline (or delegate their execution to a powerful but trustless server) and obtain a proof attesting to the validity of the computation.
        2. We can quickly verify the validity of a computation or transition by checking the proof; this operation will be less computationally expensive than performing the whole computation.
        3. Transitions can be accepted into the layer by checking the proofs.

The proofs will have to satisfy two properties for this system to work:

        * Privacy: The proofs should not reveal anything, other than the validity of the statement.
        * Succinctness: the proof can be validated in a time that is independent of the cost of the computation to whose correctness it attests.

ZEXE will offer users rich functionality, with offline computations used to realize state transitions of multiple applications, running atop the same ledger. The shared execution environment provides the following properties:

        * Extensibility: users can run arbitrary functions, without seeking anyone's permission.
        * Isolation: functions of malicious users cannot interfere with the computations and data of honest users.
        * Interprocess communication: functions may exchange data with one another.

In the next section, we will cover the main ingredients and how the protocol works: terms such as zk-SNARKs, elliptic curve cryptography, pairings, etc, will be demystified.

## Ingredients

### Decentralized private computation

The core of ZEXE relies on a new cryptographic primitive to perform computations on a ledger, known as decentralized private computation (DPC), by extending the ideas on how Zerocash works. We can perform the computations offline and present a proof asserting that it is a valid transition on the ledger; the proof can be quickly verified by the nodes of the ledger (much faster than it would take each of them to repeat our original calculation) and be accepted. One disadvantage is that, even though proofs are fast to verify, their generation can be quite expensive (remember that we want to allow the user to run arbitrary programs; thus, the proof system should be able to cope with many different kinds of statements and instructions). We can leverage the construction and create a delegable DPC: we can make trustless servers or devices carry out computations and provide us with proofs that the computations were performed as they should and without leaking relevant information.

The building blocks of the DPC schemes are:

        * Collision-resistant hash function.
        * Pseudorandom function family.
        * Commitments.
        * NIZK: non-interactive arguments of knowledge (the proofs).

To enable delegatable DPC we need a further ingredient: randomized signatures.

### Records

In Zerocash, when coins are created, their [commitments](https://en.wikipedia.org/wiki/Commitment_scheme) (1) are published on the ledger; when they are consumed, their serial number is published. Every transaction tells that some "old" coins were consumed to create "new" coins: it has the serial number of the spent coins, the commitments of the "new" coins, and a proof that the values of the "old" and "new" coins add up (the proof shows that it was a valid transaction and that no extra money was created or destroyed during the exchange). The transaction is private because we don't know the values or addresses of the coins exchanged. Since the serial number is published, no coin can be spent more than once.

The units of data, called records (the coins in ZEXE), are bound to arbitrary programs and specify the conditions under which a record can be created and consumed. We can think of them as having tokens or coins that we can spend to run programs and get proofs that what we have done is valid (like in arcade games). To extend the idea to arbitrary functions, we can think of a record as storing some arbitrary data payload. The commitment of a record is published whenever a record is created and its serial number is revealed when it is consumed. A transaction on the ledger contains information on the records spent and created during the operation and a proof that invoking a function on the data payload of the old record produces the data payload of the new records.

A record structure contains:

        * The address public key.
        * The data payload.
        * Birth and death predicates.
        * A serial number nonce.
        * The record's commitment.

The record's commitment is a commitment to all the aforementioned attributes (public key, payload, birth and death predicates, and the serial nonce).

### The Record Nano Kernel (RNK)

This is an execution environment operating over the records. We can think of it as a kind of operating system for the ledger. It provides process isolation, data ownership, handling of interprocess communications, etc. The RNK ensures that birth and death predicates are met so that during the record's lifetime certain constraints are enforced. In other words, depending on the input data, predicates can decide whether certain interactions with that record are allowed or not.

### Transitions and transactions

On the ledger, transactions contain the following information:

        1. The serial number of all consumed records during the transaction.
        2. The commitments of all the records created in the transaction.
        3. A memorandum. This is a string associated with the transaction.
        4. Other construction-specific information.

Recently, transactions have been updated and are made up of transitions. In other words, a transaction is composed of several transitions.

### zk-SNARKs

zero-knowledge succinct non-interactive arguments of knowledge (zk-SNARKs for friends) are cryptographic primitives which allow one party (the prover) to convince another one (the verifier) of the validity of a certain statement/calculation. It has the following properties:

        * Completeness: Given a statement and a witness (for example, I know $x$ such that $g^x=b$), the prover can convince an honest verifier.
        * Soundness: A malicious prover cannot convince the verifier of a false statement.
        * Zero-knowledge: the proof reveals nothing else other than the validity of the statement; it does not reveal the witness.
        * Succinctness: the proof is small and "easy" to verify.

Given that we want to let users perform arbitrary computations, we need the proof system to be able to handle lots of different statements in a rather general way; this will represent the largest cost in the ZEXE protocol. These statements fall in the [class NP](https://en.wikipedia.org/wiki/NP_\(complexity\)) (non-deterministic polynomial time), which are problems that can be efficiently verified in polynomial time. The NP statements that we need to prove contain predicates defined by the user, which would force us to build everything on zk-SNARKs for universal computations, which depend on very expensive tools. An advantage of zk-SNARKs, verification is done in constant-time; in other words, the amount of time needed to verify is independent of the size of the computation. This is a desirable property from the point of view of privacy because different verification times could give hints on what kind of operations are being performed.

To tackle this problem, the protocol relies on recursive proof composition: instead of checking the arbitrary NP statement, we can check succinct proofs attesting to the validity of the statement. This way, we can avoid zk-SNARKs for universal computations and can instead focus on succinct proofs, which can be hardcoded in the statement. We can achieve the goal by making use of [proof carrying data](https://eprint.iacr.org/2012/095.pdf): we append to a message a succinct proof that asserts that the result is consistent. For example, instead of checking directly the birth and death predicates (which can be quite general), we can verify succinct proofs $\pi_b$ and $\pi_d$ attesting to the satisfaction of these predicates. Since the inner proofs are succinct, it is (relatively) inexpensive to verify them. Moreover, since the outer proofs are zero knowledge (therefore, not revealing anything that is used to generate the proof), the inner proofs need not be zero-knowledge, further simplifying the calculations.

We can reduce any NP statement to an equivalent NP-complete problem, such as graph-coloring or boolean circuit satisfiability. ZEXE proves the correctness of computations by transforming our arbitrary program into an arithmetic circuit satisfiability problem, defined over a [finite field](/math-survival-kit-for-developers/) $\mathbb{F}_r$. The problem that arises is that proof verifications involve operations over field $\mathbb{F}_q$, where $r \neq q$. It is, in principle, possible to simulate operations in $\mathbb{F}_q$ over $\mathbb{F}_r$, but this is quite expensive and would make the whole system burdensome. An alternative to this is working with a pair of [elliptic curves](/what-every-developer-needs-to-know-about-elliptic-curves/), with some desired properties; we call them pairing-friendly elliptic curves.

### Pairing-friendly Elliptic Curves.

Given an elliptic curve $E$ defined over some finite field $\mathbb{F}_q$, we can define an operation over the points of the curve such that they form a [group](https://www.entropy1729.com/math-survival-kit-for-developers/) under that operation. The order of the subgroup $\mathbb{G}$ (that is, the number of elements) is $r$, with $r \neq q$. Two prime order curves $E_1$ and $E_2$ over fields $\mathbb{F}_q$ and $\mathbb{F}_r$ are said to be pairing friendly if the size of one's base field $\mathbb{F}$ equals the other's subgroup order and vice versa.

An elliptic curve pairing is a function $e:\mathbb{G}_1\times \mathbb{G}_2 \rightarrow \mathbb{G}_T$ that is bilinear. Here, $\mathbb{G}_1$ and $\mathbb{G}_2$ are the groups over elliptic curves. Bilinear means that, given two points $\mathcal{P_1}$ and $\mathcal{Q}_1$ in $\mathbb{G}_1$ and $\mathcal{P_2}$ and $\mathcal{Q}_2$ in $\mathbb{G}_2$ the following properties hold (we will write all the group operations as additions):

        1. $e(\mathcal{P_1}+\mathcal{Q}_1,\mathcal{P}_2)=e(\mathcal{P_1},\mathcal{P}_2)+e(\mathcal{Q}_1,\mathcal{P}_2)$
        2. $e(\mathcal{P_1},\mathcal{P}_2+\mathcal{Q}_2)=e(\mathcal{P_1},\mathcal{P}_2)+e(\mathcal{P}_1,\mathcal{Q}_2)$

For efficiency reasons, we need both fields to have subgroups whose orders are large powers of $2$. ZEXE uses a curve from the Barreto-Scott-Lynn family, $E_{BLS}$ (with embedding degree(2) 12), which conservatively achieves 128 bits of security. The pairing friendly curve is generated via the [Cocks-Pinch method](https://eprint.iacr.org/2006/372.pdf), $E_{CP}$. This is a very time consuming step since it involves exploring many different curves until we find one with the desired properties.

Given that the base field of $E_{CP}$ is larger than that of $E_{BLS}$, operations over the former are more expensive. To avoid this shortcoming, the relation $R_e$ is split into two: $R_{BLS}$ and $R_{CP}$. The last one is responsible for verifying proofs of predicates' satisfaction, while all other checks depend on the $E_{BLS}$ curve.

Commitments and collision-resistant hash functions can be expressed as efficient arithmetic circuits for Pedersen-type constructions over Edwards curves. Therefore, two additional curves, $E_{Ed,BLS}$ and $E_{Ed,CP}$ over the fields $\mathbb{F}_r$ and $\mathbb{F}_q$ are selected, so as to implement important cryptographic primitives, such as hashing, commitments, and randomizable signatures. This allows us to reduce the difficulty of the multiple checks for NP relations.

## Summary

ZEXE is a protocol that was designed to allow users to execute arbitrary programs over public ledgers, without compromising privacy. It solves two of the main drawbacks of distributed ledgers so far: First, computations can be performed offline and a proof of the correct computation is submitted to the ledger. Since the proof is fast to verify, this avoids the problem of naïve re-execution and gives scalable solutions. Second, it achieves both data and function privacy: observers cannot get information over the data involved in the computations, not even on which specific functions are being called.

The protocol introduces new cryptographic primitives, such as DPC and delegatable DPC; the latter allows users with less powerful devices (such as smartphones) to hand their computations to untrusted parties and get proofs that show that the results obtained correspond to the correct execution of the program. These are supported by zk-SNARKs, relying on elliptic curve pairings and tools for converting arbitrary programs to an arithmetic circuit, where we can check the validity of the calculations.

It gives the basis for fully private applications, becoming an ideal platform for decentralized applications, such as finance, gaming, authentication, governance, and more.

## Notes

(1) A commitment allows a user to commit to one value, with the ability to later reveal it. For example, in a roulette bet, I could choose "25" (I really feel very confident) and with the commitment, I am bound to my choice of "25" (though nobody could know, a priori, that I chose 25 since it is hidden). A way to achieve this is by using a collision resistant hash function and publishing the resulting hash (to make it work, we need to add something else, otherwise we can hash all the possibilities and see which one has the corresponding hash). If I then try to change my bet, the hash will not match with that of my original bet.  
(2) The embedding degree of an elliptic curve over the field $\mathbb{F}_q$ is the smallest positive integer $k$ such that $q^k-1$ is divisible by $r$, the order of the group. The embedding degree should be high so that the discrete logarithm problem is hard to solve. However, if $k$ is too large, then the arithmetic over the curves becomes much slower.
