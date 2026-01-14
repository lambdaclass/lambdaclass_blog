+++
title = "Mina to Ethereum ZK bridge"
date = 2024-02-05
slug = "mina-to-ethereum-bridge"

[extra]
feature_image = "/images/2025/12/The-Death-of-Socrates-Jacques-Louis-David-.jpg"
authors = ["LambdaClass"]
+++

## Introduction

During the last few months, we have been developing a [bridge between Mina and Ethereum](https://github.com/lambdaclass/mina_bridge). [Mina](https://minaprotocol.com/) is a layer-1 blockchain that uses zero-knowledge proofs (zk-SNARKs) to maintain its [size at 22 kB](https://minaprotocol.com/blog/22kb-sized-blockchain-a-technical-reference). The bridge serves two purposes:

        1. Allowing cross-chain transactions seamlessly.
        2. Allowing applications to leverage Mina's zero-knowledge capabilities and expand their functionalities across multiple chains.

Due to $2$, users can simply prove things off-chain and verify them on-chain in Ethereum.

At its core, Mina uses a proof system called [Kimchi](https://o1-labs.github.io/proof-systems/specs/kimchi.html), which is a variant of Plonk with many optimizations and uses an inner product argument (IPA) polynomial commitment scheme. Its key optimizations are custom gates for foreign field addition and multiplication, Keccak, Poseidon, and lookup arguments. Above that, we have Pickles, which is Mina's inductive SNARK composition, enabling a flexible way to have [incrementally verifiable computation](/incrementally-verifiable-computation-nova/). This construction allows us to generate a proof that attests to the validity of the transition from state $S_n$ to state $S_{n + 1}$ while checking a proof that the previous step was correct. While this helps Mina achieve its succinctness, verifying these proofs in Ethereum is very expensive.

Currently, pairing-based SNARKs (such as those using KZG) have cheaper verification costs in Ethereum, which makes this option attractive. To "wrap" Mina state proofs, we can generate a SNARK to verify a Mina proof obtained with IPA, using a variant of Kimchi with the KZG commitment scheme. To do so, we must first express all the verification logic of the Kimchi-IPA proof as a circuit, then use this circuit, the proof, and other public input and generate a proof using Kimchi-KZG. This is more easily said than done. First, we must express all the verification operations as an arithmetic circuit. The good thing is that we can express even complex operations such as MSM using elliptic curve gates and lookup arguments. The bad thing is that the equations are expressed over Ethereum's BN-254 scalar field, which differs from the Pasta fields. This means we will have to do many foreign field operations, making the SNARK quite expensive.

This post will provide an overview of the bridge, Kimchi, and the KZG verifier. For an introduction to some of the topics, see [Plonk](/all-you-wanted-to-know-about-plonk/), [IPA](/ipa-and-a-polynomial-commitment-scheme/), and [lookups](/lookups/).

## The Bridge

The bridge has the following components:

        1. A backend service periodically wraps and posts Mina's state proofs to an EVM chain.
        2. A "wrapping" module for Mina's proofs to make them easy to verify on the EVM.
        3. The solidity logic for verifying the wrapped Mina state proofs in the EVM.
        4. Browser utility for smart contracts.
        5. A solidity contract utility that smart contract developers or users can execute on an EVM chain to feed in a Mina state lookup proof that will check the state lookup against the latest posted Mina state proof to verify that this Mina state is valid.

The flow is shown in the following picture. For more details related to the architecture, see the [bridge's readme](https://github.com/lambdaclass/mina_bridge/blob/main/README.md).  
![flow](https://hackmd.io/_uploads/HJ6DjwYcT.jpg)

## SNARKs

As mentioned, Mina's proof system is Kimchi, a modified version of Plonk, using IPA and working over a pair of elliptic curves, Pallas and Vesta (shortened to Pasta curves). IPA and Pasta curves enable easy recursion but at the expense of longer proofs than KZG-based SNARKs. Verifying and storing these proofs in Ethereum is expensive, so we need to obtain a new type of proof that can be checked less expensively in Ethereum. Let's dive into Kimchi, Pickes, and KZG commitments.

## [Kimchi](https://o1-labs.github.io/proof-systems/kimchi/overview.html)

This is a modified version of [Plonk](https://eprint.iacr.org/2019/953). There are three types of arguments:

        * Custom gates.
        * Permutation.
        * Lookups.

These arguments are translated into several polynomials, which must evaluate to zero over some set. Luckily, we can check that all the polynomials evaluate to zero over the set by doing a random linear combination. Say, for example, that $p_1 , p_2 ... p_n$ all evaluate to zero over the set $S = { 1, 2, ... , m}$. We can have the verifier sample $\alpha$ and obtain  
$p (x) = \alpha p_1 (x) + \alpha^2 p_2 (x) + \dots + \alpha^n p_n (x)$  
which should also evaluate to zero. To see that the polynomial has that property, we can show that $p(x)$ is divisible by the polynomial vanishing on S, $Z_S (x)$. Another way to state this is that there is some polynomial $q(x)$ such that $p(x) = Z_S (x) q(x)$. Moreover, if we decide to perform this check at just one random point $\zeta$ from a very large set, then, with high probability, we have that the previous equality holds for all the set.

The ingredients are the circuit specification (the gates and the connections/wirings) and the execution trace. The execution trace in Kimchi has input/output registers (7) plus advice registers (8). The circuit is known beforehand and represents a given program/computation. The execution trace depends on the particular execution of the program (for example, we can run the same program with different inputs).

The following tables describe the circuit:

        * Gates: Generic, Poseidon, Elliptic Curve Addition, Endo Scalar, Endo Scalar Multiplication, Scalar Multiplication, Range Check, Foreign Field Addition, Foreign Field Multiplication, Rotation, and XOR.
        * Coefficients. These are only used in Poseidon and generic gates.
        * Wirings (also Permutations or Sigmas)
        * Lookup tables
        * Lookup selectors
    
    pub struct CircuitGate<F: PrimeField> {
        /// type of the gate
        pub typ: GateType,
    
        /// gate wiring (for each cell, what cell it is wired to)
        pub wires: GateWires,
    
        /// public selector polynomials that can used as handy coefficients in gates
        #[serde_as(as = "Vec<o1_utils::serialization::SerdeAs>")]
        pub coeffs: Vec<F>,
    }
    

Kimchi contains three main algorithms:

        1. Setup: takes the circuit and produces the prover and verifier indexes.
        2. Proof creation: takes the circuit and the prover index and outputs a proof.
        3. Proof verification: takes the proof and the verifier index and checks the proof.

The steps performed by the prover to obtain the proof are listed [here](https://o1-labs.github.io/proof-systems/specs/kimchi.html#proof-creation). The verification follows the steps shown [here](https://o1-labs.github.io/proof-systems/specs/kimchi.html#proof-verification).

## Pickles

Pickles uses the Pasta curves to deliver incrementally verifiable computation efficiently. The Pasta curves are also known as:

        * Tick/Step (Vesta), handling blocks and transactions' proofs.
        * Tock/Wrap (Pallas), handling signatures and performing recursive verifications.

Tock is used to prove the verification of a Tick proof and outputs a Tick proof. Tick is used to prove the verification of a Tock proof and outputs a Tock proof.

        * $\mathrm{Prove_{tock} ( Verify(Tick) ) = Tick_{proof}}$
        * $\mathrm{Prove_{tick} (Verify(Tock) ) = Tock_{proof}}$

Both Tick and Tock can verify at most two proofs of the opposite kind. Pickles contains two components: fast (1 - 30 ms) and slow (100 ms - 1 s) verifiers. Given a proof $\pi_1$, we first execute the fast verifier, and the update algorithm takes the previous proof state, $S_0$, and $\pi_1$ and generates the next proof state, $S_1$. If we have an incoming $\pi_2$, we do not execute the slow verifier, beginning a new cumulative phase. We run the fast verifier on $\pi_2$ and update the proof state from $S_1$ to $S_2$. If there are no more incoming proofs, we use the slow verifier to check the last state proof $S_n$.

## KZG verifier solidity

The code for the verifier in solidity is [here](https://github.com/lambdaclass/mina_bridge/blob/main/eth_verifier/src/Verifier.sol). The verifier can be divided into two large parts:

        * Partial verification.
        * Final verification.

The first handles checks such as the correct length of evaluations and commitments regenerates the random challenges using Fiat-Shamir and uses the claimed evaluations to see whether the gate and permutation constraints are valid. The second part checks the commitments by calling the pairing check function. In a naïve KZG verification, we must compute one pairing for every evaluation we want to check. However, we can randomly combine the commitments and evaluations to perform just one pairing check.

The working principle behind the verification of the KZG evaluation proof is the following: we have a commitment to a polynomial, $p(x)$, an evaluation point, $\zeta$, a claimed evaluation, $v = p(\zeta)$, and the evaluation proof, $\pi = \mathrm{cm}(q)$, which is the commitment to a quotient polynomial, $q(x)$. If the evaluation is correct, then $p(x) - v$ should be divisible by $x - \zeta$, that is  
$p(x) - v = (x - z) q(x)$  
We cannot do this check directly since we have access only to the commitments and not the whole polynomials. We have $\mathrm{cm}(p) = p(s) g_1$ and $\mathrm{cm}(q) = q(s) g_1$, which are points on an elliptic curve. We could attempt to check everything at just one point, $s$, and, if the two sides match, then with overwhelming probability, the polynomial was evaluated correctly. The pairing is a function $e(x,y)$ with two properties:

        1. Bilinear: $e(x_1+x_2,y_1+y_2) = e(x_1 , y_1 )e(x_2 , y_2 )e(x_1 , y_2 )e(x_2 ,y_1 )$
        2. Non-degenerate: if $e(x,y) = 1$, then $x$ or $y$ are the point at infinity (neutral element for elliptic curve addition).

It follows from the bilinearity property that  
$e( p(s) g_1 - v g_1 , g_2 ) = e(g_1 , g_2 )^{p(s) - v}$  
Similarly,  
$e( q(s) g_1 , s g_2 - \zeta g_2 ) = e(g_1 , g_2 )^{q(s)(s - \zeta)}$  
Since neither $g_1$ nor $g_2$ are the point at infinity (because they are generators of the whole group), $e (g_1 , g_2) \neq 1$, and therefore, if both pairings are equal, then it follows that  
$p(s) - v = q(s) (s - \zeta)$  
The EVM has a function, pairing check, which computes the product of both pairings and verifies that it is equal to one. Because of this condition, we rewrite the second pairing, negating the commitment to the quotient,  
$e( - q(s) g_1 , s g_2 - \zeta g_2 ) = e(g_1 , g_2 )^{ - q(s)(s - \zeta)}$

### Batching evaluation at point $\zeta$ for several polynomials

If we have several polynomials $p_1, p_2, ... p_n$ and we want to check the evaluation at the same point $\zeta$, we just need to perform a random linear combination for each of these elements:

        * Commitments to $p_k$: $\mathrm{cm}(p) = \sum \alpha^k \mathrm{cm}(p_k )$
        * Commitments to quotients $q_k$: $\mathrm{cm}(q) = \sum \alpha^k \mathrm{cm}(q_k )$
        * Evaluations: $v = \sum \alpha^k v_k$

### Batching evaluations at several points $\zeta_k$ for one polynomial

If we need to check that a polynomial evaluates at $\zeta_1$ to $v_1$, at $\zeta_2$ to $v_2$, ... and at $\zeta_n$ to $v_n$, we can fuse all these checks into a single one. The steps are as follows:

        * Compute the polynomial of degree $n - 1$, $I(x)$, that interpolates the points $(\zeta_k , v_k )$. This means that $I( \zeta_k ) = v_k$ for $k = 1, 2, ... n$. If we have two points only, $I(x) = (v_2 - v_1 ) (\zeta_2 - \zeta_1 )^{- 1} (x - \zeta_1 ) + v_1$, which is the line passing through those two points.
        * The polynomial $p(x) - I(x)$ evaluates to $0$ at $\zeta_k$, which means that $p(x) - I(x)$ is divisible by the polynomial $D(x) = \prod (x - \zeta_k )$(in our two-dimensional case, this is $(x - \zeta_1 )(x - \zeta_2 )$). Compute the quotient $q(x)$ of $p(x) - I(x)$ by $D(x)$ and commit to it.

We can combine this idea with batch verification for several polynomials and just pay for one pairing check!

## Conclusions

This post presented the bridge between the succinct blockchain Mina and Ethereum, allowing seamless cross-chain transactions and dApps to leverage Mina's zk capabilities. One of the main challenges is related to the verification of Mina's proofs in Ethereum since they rely on IPA, which is more expensive than those based on KZG. To deal with this, we have to create a wrapper (a program that proves the verification of Mina proofs) to obtain new proofs that can be verified in Ethereum more cost-effectively. We covered the basics of Kimchi (Mina's proof system) and Pickles (which allows Mina to deliver incrementally verifiable computation, the key component for succinctness) and how KZG commitments work. We also discussed some of the challenges related to foreign field operations. In upcoming posts, we will discuss some of the bridge's components and the project's milestones and advances in more depth.
