+++
title = "EVM performance boosts with MLIR"
date = 2024-06-14
slug = "evm-performance-boosts-with-mlir"

[extra]
feature_image = "/content/images/2025/12/GericaultHorseman.jpg"
authors = ["LambdaClass"]
+++

We implemented 75% of the functionality of the Ethereum Virtual Machine, in two weeks, with five new hires, compiling the VM opcode logic to native machine code with a state of the art compiler backend. Why did we do this? How?  
The TL;DR is: to get a performance boost (recent benchmark results show a throughput 300% to 600% times higher than _revm_ , when running factorial and fibonacci programs), to increase implementation diversity, and to use it in our upcoming implementation of an Ethereum Execution client.

Seeing as many other VMs compile bytecode to native instructions, it struck us as odd that Ethereum Virtual Machine (EVM) implementations don't do the same. Doing Cairo Native we [learned a lot about MLIR/LLVM](/cairo-and-mlir/), and so we started the EVM-MLIR project with the objective of having a faster alternative to _revm_.

We wanted to get a sense of feasibility as soon as possible, so we started by specifying the problem (and solution) well, laying out the project skeleton and utilities, and making sure the new team had a solid base to work on. With clear tasks ready to be assigned, we managed to implement 111 out of 149 opcodes from mainnet in two weeks!

## Applying MLIR to the EVM

The EVM is a stack-based virtual machine whose compiled bytecode represents a sequence of instructions consisting of 1-byte opcodes with implicit parameters. Push operations also include up to 32 bytes of extra data (the number to push to the stack).

Its memory architecture consists of five components:

        * Stack: stores up to 1024 256-bit wide integers. Each operation pops operands from it, and/or pushes results to it. If a program runs out of stack it terminates.
        * Memory: byte array, which allows random addressing by byte. Used for storing and accessing volatile data in an ordered manner.
        * Calldata: a read-only byte array similar to the _Memory_ sent as input on each transaction. Some operands allow copying data from the calldata to the stack or memory.
        * Storage: dictionary with 256-bit keys and values. Changes are persisted, unless the transaction is reverted.
        * Transient storage: similar to _Storage_ , but changes are discarded at the end of a transaction.

We can see that the execution model of the EVM is exceedingly simple, on purpose.

A naive interpreter loop on the instruction sequence is simple to implement but difficult to optimize. There are many approaches to implementing bytecode interpreters (it's a fun and educating project!) but removing interpreter overhead by directly translating each opcode to machine instructions is very efficient. The only difficulty is needing a compiler backend and a way to link and invoke the generated code.

We decided to take advantage of our recent experience with MLIR and write a library to translate each operation to a sequence of MLIR blocks containing the MLIR operations that implement each opcode's behaviour, string them up by connect each one to the next. Finally this representation can be translated to LLVM IR and be put through LLVM's optimizer passes.

Not only did we have to translate each opcode's logic in terms of MLIR operations, we also needed to translate the memory architecture:

        * Stack: we pre-allocate the max stack size (1024 elements) before starting the aforementioned sequence. Current and base pointers are used to maintain the stack and check for overflows or underflows.
        * Memory: we handle the memory allocation in Rust, extended as needed by FFI callbacks.
        * Calldata: we store it on Rust's side, and give it as input to the EVM.
        * Storage/Transient storage: will be handled via syscalls, with an API similar to _revm_.

### Benchmarks

#### Factorial

This program computed the Nth factorial number, with N passed via calldata. We chose 1000 as N and ran the program on a loop 100,000 times.

##### MacBook Air M1 (16 GB RAM)

| Mean [s] | Min [s] | Max [s] | Relative  
---|---|---|---|---  
EVM-MLIR | 1.062 ± 0.004 | 1.057 | 1.070 | 1.00  
revm | 6.747 ± 0.190 | 6.497 | 7.002 | 6.36 ± 0.18  
  
##### AMD Ryzen 9 5950X 16-Core Processor (128 GB RAM)

| Mean [s] | Min [s] | Max [s] | Relative  
---|---|---|---|---  
EVM-MLIR | 1.363 ± 0.151 | 1.268 | 1.691 | 1.00  
revm | 5.081 ± 0.685 | 4.839 | 7.025 | 3.73 ± 0.65  
  
#### Fibonacci

This program computed the Nth fibonacci number, with N passed via calldata. Again, we chose 1000 as N and ran the program on a loop 100,000 times.

##### MacBook Air M1 (16 GB RAM)

| Mean [s] | Min [s] | Max [s] | Relative  
---|---|---|---|---  
EVM-MLIR | 1.010 ± 0.016 | 0.990 | 1.040 | 1.00  
revm | 6.192 ± 0.119 | 6.094 | 6.374 | 6.13 ± 0.15  
  
##### AMD Ryzen 9 5950X 16-Core Processor (128 GB RAM)

| Mean [s] | Min [s] | Max [s] | Relative  
---|---|---|---|---  
EVM-MLIR | 1.496 ± 0.236 | 1.243 | 1.756 | 1.00  
revm | 4.586 ± 0.066 | 4.537 | 4.727 | 3.07 ± 0.49  
  
Code for these benchmarks can be seen in our repo: [lambdaclass/evm_mlir](https://github.com/lambdaclass/evm_mlir), along with documentation on how to reproduce them. We're currently running them on our CI to detect performance regressions, and we'll be adding more complex programs in the near future.

### Next steps

We now leave a skeleton crew to finish the remaining functionality and to continue optimizations, and focus on our new Execution Client -- nicknamed _ethrex_ after ETHereum Rust EXecution.

As said, our objective for our new Execution Client is giving the Ethereum ecosystem an alternative Rust Execution client with simple, straightforward code in the coming two months. After the MLIR EVM is ready, we intend to integrate it to _ethrex_ , as part of a dog-fooding effort.
