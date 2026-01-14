+++
title = "Lambda's new strategic partnership with Miden: the Edge blockchain"
date = 2025-05-05
slug = "lambdas-new-strategic-partnership-with-miden-the-edge-blockchain"

[extra]
feature_image = "/content/images/2025/12/La_Bataille_du_Pont_d-Arcole.jpg"
authors = ["LambdaClass"]
+++

We are very proud to celebrate over 18 months of collaboration between Miden and LambdaClass. The partnership began by helping Miden develop the client, facilitating the execution and proving of transactions for the Miden network. Over time, our collaboration deepened, and we expanded our efforts to support the development of the protocol and node, focusing on various aspects. More recently, we've started assisting with the compiler effort, further expanding our involvement in the Miden ecosystem.

Miden is the edge blockchain: a rollup for high-throughput, private applications, powered by the [Miden-VM](https://github.com/0xPolygonMiden/miden-vm), a STARK-based virtual machine. It has been designed using ZK technology, aiming to achieve two goals simultaneously: private state management and high scalability. These are crucial properties for real-world applications, allowing users to choose the data they want to share and process a large number of transactions. The actor-based model allows for concurrent transactions and ensures that transaction data is not revealed in the blockchain, enabling digital cash and giving users the choice of which information to keep publicly in the ledger. Thus, Miden enables applications to scale efficiently with both public and private transactions, meeting their diverse requirements.

In Miden, accounts hold assets and can define rules for transferring them. The data can be public or private and is kept in a Miden node. Notes are a way to transfer assets and interact with other accounts, and they contain a script that indicates how the note can be consumed. The transfer of notes can be done asynchronously and privately. If the note is private, only its hash is stored on the chain. Asset transfer is done in two steps: first, the sender generates a note and updates its internal state. Secondly, the receiver account executes a new transaction to consume the note and update its internal state. Miden keeps track of the accounts’ state, the created notes, and the nullifiers for consumed notes.

The Miden-VM is a STARK-based virtual machine with its customized instruction set architecture (ISA), using ZK-friendly primitives to make proving efficient. The VM works with the MiniGoldilocks field and its extensions, which have fast arithmetic. With its specialized ISA, programs need to be written in Miden assembly language. The development and use of compilers for general-purpose languages, such as Rust, will enable us to write high-level code and then compile it to Miden assembly to prove it, simplifying the development of provable applications.

Achieving all these features requires a lot of engineering effort and thought, and Miden has made the right choices, focusing on what they want to offer users and clients, all while working fully open-source and sharing their work and insights with others.

Our enthusiasm over Miden stems from the fact that it provides an innovative approach for blockchains: It leverages fast client-side proving for compliant privacy. Its design and architecture, inspired by the actor model, is simple yet elegant and very powerful, facilitating parallel transaction execution and batching for an incredible increase in throughput and scalability with minimal state bloat. With a mature codebase that empowers developers to solve complex problems, it sits right at the core of Lambda's values.

Looking ahead, we remain committed to advancing Miden's mission and enabling all the possibilities it unlocks for users and developers alike.
