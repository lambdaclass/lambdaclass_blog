+++
title = "A walkthrough on the open source Aleo VM implemented with Arkworks and blockchain implemented with Tendermint"
date = 2023-02-03
slug = "open-source-aleo-vm-implemented-with-arkworks-and-blockchain-implemented-with-tendermint"

[extra]
feature_image = "/content/images/2025/12/Ani--bal_vencedor_que_por_primera_vez_mira_Italia_desde_los_Alpes_-_Francisco_Goya.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["Vm", "Distributed Systems"]
+++

## Introduction

For the last 12 weeks, at LambdaClass, we have been developing an alternative implementation of the Aleo Blockchain. We want to thank Alex Pruden and Howard Wu from Aleo for their support throughout the process.

At a high level, the project consists of a Consensus Layer using Tendermint and a Zero-Knowledge Virtual Machine targeting Aleo instructions implemented with the arkworks framework.

You can check out the code:

        * [Tendermint Blockchain implementation](https://github.com/lambdaclass/aleo_lambda_blockchain)
        * [Virtual Machine implemented with Arkworks](https://github.com/lambdaclass/aleo_lambda_vm)

The key features of this blockchain revolve around the fact that it is designed to be a fully-private platform for users to develop applications that can then be built and executed off-chain, generating a proof of execution which is then sent to the blockchain nodes for verification and storage.

* * *

If you're in need of a team of engineers and researchers who've been working together for a decade in areas like distributed systems, machine learning, compilers, and cryptography, we're your guys. Wanna chat more about it? Book a meeting with us by sending us an [email](https://calendly.com/federicocarrone)

* * *

## Consensus Layer

The consensus layer is in charge of validating incoming transactions which perform state changes and replicating these transactions (and the order in which they were performed) on an arbitrary number of nodes.

To achieve this, we decided to utilize [Tendermint Core](https://github.com/tendermint/tendermint), an implementation of a consensus mechanism written in Go. Alongside the Tendermint Core binaries, you need to run your implementation of an _Application Blockchain Interface_ (or _ABCI_ for short). This ABCI needs to implement specific hooks that Tendermint Core calls through a socket whenever required. For example, when receiving a transaction, it will call `CheckTx`, which is supposed to validate the transaction before entering it into the mempool and relaying it to other nodes. This flexible approach allows for the ABCI to be written in any language as long as it responds to the calls appropriately. We decided to write our implementation in Rust.

You can see the code for this implementation [here](https://github.com/AleoHQ/aleo_lambda_blockchain). The repository also contains a CLI application to compile, deploy and execute programs and send these transactions to the blockchain easily. It also has several other features related to accounts, such as retrieving a user's balance or seeing which _records_ the account possesses. We will explain the motivation behind records in the integration section of this post, but they are essentially a way to encapsulate state and ownership functionality in the blockchain.

### Design considerations

![](https://github.com/lambdaclass/aleo_lambda_blockchain/blob/main/doc/architecture.png?raw=true)

Considering the VM implementation and the requirements from the blockchain, we had to make several design decisions on the consensus layer. Here's a general overview of how Tendermint Core was implemented:

        * The Tendermint Core and the ABCI need to run side by side in the same node and are coupled by the interface defined by the protocol's hooks.
        * All code executed on the ABCI needs to be deterministic and isolated from external services since we want to ensure all transactions perform deterministic state changes on every node in the network.
        * The ABCI implements two databases to maintain the current state of the blockchain: The program store and the record store. 
          * The program store keeps track of every deployed program's verifying keys and uses. The store contains the `credits` program's keys as a built-in default. This program defines credit records. It is essentially a native Aleo program that has functions for managing credit records.
          * The record store encapsulates functionality related to validating whether the records utilized in incoming transactions have already been spent. 
            * The privacy requirements imply that we cannot disclose what records have been spent and which have not. Due to this, any record in the blockchain (i.e., it was output from the execution of a program) is stored separately from records that have been spent, of which we only store serial numbers.
        * The genesis block needs to be provided to Tendermint on startup and is done through a JSON file. We have written a particular binary to generate it for any number of nodes and give each of them a fixed amount of starting credits.
        * To make testing simple, we have created several `make` targets to initialize and start multiple validators that can run locally or on a remote network.
        * Both the CLI and the consensus layer support Aleo's SnarkVM and our own LambdaVM and are currently interchangeable through a compiler flag

### Staking

Tendermint supports adding new nodes to the network. In general, nodes in the network can work in two different modes:

        * Non-validator: The node catches up with the blockchain by performing every transaction but does not have voting power to validate and commit blocks.
        * Validator: The node is part of the network and can vote and sign blocks.

To add a non-validator, the node needs to have the same Genesis block and point to persistent peers (IP addresses acting as fixed nodes in the network). To transform a node into a validator, the ABCI needs to implement functionality to update the voting power of a Tendermint node.

For this, we implemented a `stake` command to "freeze" credits by exchanging them for staking records (and increase the voting power of a validator), which you can, in turn, `unstake` whenever you desire (decreasing the voting power accordingly).

When a node is a validator, it gets rewards on each block commit where it was involved.

## Virtual Machine

At a high level, our VM provides an API to take an Aleo program that looks like this:
    
    program main.aleo;
            
    function add:
        input r0 as u16.public;
        input r1 as u16.private;
        add r0 r1 into r2;
        output r2 as u16.public;
    

And generate a pair of proving and verifying keys for it (this is usually called _building_ or _synthesizing_ the program), allowing anyone to execute the program and provide proof of it or verify said proof. The consensus layer uses this to deploy programs (i.e., upload their verifying key along with the code), execute them, and verify them.

Internally, this VM uses [Arkworks](https://github.com/arkworks-rs) as a backend. Programs are turned into a Rank One Constraint System (`R1CS`), which is then passed on to the [Marlin](https://github.com/arkworks-rs/marlin) prover for execution. As we started using Arkworks, we noticed some aspects of the API and its genericity were becoming a burden for developers, so we created a thin wrapper around it called [Simpleworks](https://github.com/lambdaclass/simpleworks), along with [some basic documentation](https://lambdaclass.github.io/simpleworks/overview.html).

### Example

Given the following Aleo program
    
    program foo.aleo;
    
    function main:
        input r0 as u64.public;
        input r1 as u64.public;
        add r0 r1 into r2;
        output r2 as u64.public;
    

Executing the function `main` would look like this:
    
    use lambdavm::jaleo::UserInputValueType::U16;
    
    fn main() {
        use lambdavm::{build_program, execute_function};
    
        // Parse the program
        let program_string = std::fs::read_to_string("./programs/add/main.aleo").unwrap();
        let (program, build) = build_program(&program_string).unwrap();
        let function = String::from("main");
        // Declare the inputs (it is the same for public or private)
        let user_inputs = vec![U16(1), U16(1)];
    
        // Execute the function
        let (_execution_trace, proof) = execute_function(&program, &function, &user_inputs).unwrap();
        let (_proving_key, verifying_key) = build.get(&function).unwrap();
    
        assert!(lambdavm::verify_proof(verifying_key.clone(), &user_inputs, &proof).unwrap())
    }
    

### Internals

The most significant task our VM has to perform is turning the program into an arithmetic circuit, as the rest of the work, namely generating the proof and verifying it, is pretty straightforward with the Arkworks API.

Before continuing, you should have at least a basic understanding of arithmetic circuits and how Arkworks lets you work with them. You can read about it [here](https://lambdaclass.github.io/simpleworks/overview.html).

To generate the circuit, we go through the following steps:

        * Take the program's source code and parse it into a `Program` containing all the relevant information about it (a list of all input and output instructions, whether they are public or private, a list of all regular instructions like add and its operands, etc.). We currently rely on SnarkVM's parser but plan to write our own.
        * Instantiate an Arkworks `ConstraintSystem`, which will hold all our circuit's constraints by the end.
        * For every input instruction, instantiate its corresponding `Gadget`. You can think of a gadget as the equivalent of a native type (like `u8`) inside an arithmetic circuit. If the input is public, the gadget is made public; otherwise, it's made a `witness`, i.e., private. In our example, the first instruction `input r0 as u16.public` becomes a call to `UInt16Gadget.new_input(...)` and the second instruction becomes `UInt16Gadget.new_witness(...)`.
        * For every regular instruction, we use the gadget's associated function to perform the operation and generate its constraints inside our `ConstraintSystem`. In our example, when we encounter the `add r0 r1 into r2;` instruction, we call `UInt16Gadget.addmany(...)`. This is an arkworks provided function that will take a list of `UInt16's, add them, implicitly mutate the `ConstraintSystem` with all the associated constraints, then return the value of the sum. Not all instructions have a corresponding arkworks function implemented, so for those, we had to roll our own.
        * For every output instruction, assign to the register the computed value.

Because a program can have multiple registers interacting with each other, to do the above, we have to keep track of each register and its value as we go. For this, we keep an internal hash table throughout execution.

Additionally, we ran some benchmarks comparing our VM with Aleo's `SnarkVM`, and our results show we are a few times faster than it; details will be published in a separate post. The code for benchmarks is in [our VM Repo](https://github.com/lambdaclass/aleo_lambda_vm).

## VM-Consensus Integration Layer

Above, we discussed how the VM allows running arbitrary Aleo programs that can be deployed, executed locally, and then verified on the Aleo blockchain. Each Aleo transaction is either the deployment or the proof of execution of a program (this is technically inaccurate, as there can be multiple of these per transaction, but we'll ignore that for simplicity). In the case of executions, nodes use the program's verifying key to verify the correct execution before committing transactions to a block.

After we got a basic VM version working, we realized that getting a fully functional Aleo blockchain required more work than just the above. Transactions would be of very little use if they proved that some computation was done correctly. To be useful, they also need to _modify the state_. In Aleo, the state is managed through _records_ in what is essentially a [UTXO](https://en.wikipedia.org/wiki/Unspent_transaction_output) model similar to Bitcoin. Typically, when a user sends a transaction, they will spend some records they own to create new ones in their place.

Because Aleo is entirely private, a transaction can't just publish the records it wants to spend along with a signature; it has to _prove_ ownership and existence of records in zero knowledge, then _encrypt_ the records so only its owner can decrypt on-chain.

This means that, to integrate with the consensus layer and get a fully functional blockchain, we need a bit more. The VM can prove the correct execution of programs, but the Zero-Knowledge proof that comes with a transaction also needs to include the following:

        * A signature in Zero-Knowledge, proof that the signature provided is the correct one. Remember, we can't just show the user's address sending the transaction.
        * A proof that the caller of the transaction actually _owns_ the record they're spending.
        * A proof that the records being spent are on-chain. This is essentially verifying a Merkle path in Zero-Knowledge.
        * A proof that the input records have not been spent. This is a bit involved as it requires deriving a record's `serial number` (think of it as the `nullifier` if you know ZCash) in Zero-Knowledge.

We also talked about how records should be stored encrypted on-chain so that only someone possessing the record owner's view key can decrypt them (in Aleo, the `view key` is just another key tied to an account that allows record decryption).

There's a catch here, though. When, for instance, user A wants to send money to user B, they have to create a record owned by B and encrypt it so that only B can decrypt it. But `A` does not necessarily have `B`'s view key, only their address. This means the encryption scheme used by Aleo cannot be symmetric, as that would require user `A` to have `B`'s view key to send them money, not just their address.

To accomplish this, records are encrypted using a scheme called `ECIES` (Elliptic Curve Integrated Encryption Scheme). We're not going to go into detail about how it works, but it's a combination of a Diffie-Hellman key exchange with a symmetric encryption scheme.

We introduced a middle layer between our VM and the Consensus Layer to solve all the problems discussed above. This middle layer handles everything related to records, their encryption, and the snarks required for the state transition proofs.

In the original SnarkVM implementation, this middle layer does not really exist, as it's part of the VM itself, but we found it more beneficial to separate these two concerns.

## Work in Progress

This project is still in active development, and a few things are being worked on. They include:

        * Support for some data types and instructions on the VM, including the `group` data type (elliptic curve elements) and things like `BHP` commitments. You can check out a complete list on [the README](https://github.com/lambdaclass/aleo_lambda_vm).
        * Some of the circuits mentioned above prove the correctness of state transitions.
        * The generation of the proof that input records exist on-chain.
        * Due to how we store record information on the blockchain and considering the privacy requirements of the blockchain, asking for a user balance or unspent records from the CLI is currently not trivial: We need to ask for all records that have ever existed in addition to all serial numbers from records that have been spent and attempt to decrypt them on the user's side. Some strategies to optimize this process include keeping track of records locally and only adding newly-created ones as the blockchain grows.

We plan to finish these tasks in the next four weeks. While many things could be improved, the project is already production ready.

We have many ideas and comments about improving the SnarkVM and Aleo in general, but we will leave that for another series of posts.
