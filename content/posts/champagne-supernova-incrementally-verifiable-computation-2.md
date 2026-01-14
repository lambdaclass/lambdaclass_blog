+++
title = "Champagne SuperNova, incrementally verifiable computation"
date = 2023-02-02
slug = "champagne-supernova-incrementally-verifiable-computation-2"

[extra]
feature_image = "/content/images/2025/12/Abel-_Joseph_-_Self-Portrait_in_the_Studio_-_Google_Art_Project.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["zero knowledge proofs"]
+++

## Introduction

In the lasts posts we've been writing about proving systems and incremental verifiable computation:

        * [Pinocchio Virtual Machine: Nearly Practical Verifiable Computation](/pinocchio-virtual-machine-nearly-practical-verifiable-computation/)
        * [Decentralized private computation: ZEXE and VERI-ZEXE](/decentralized-private-computations-zexe-and-veri-zexe/)
        * [Incrementally verifiable computation: NOVA](/incrementally-verifiable-computation-nova/)

Incremental proof systems offer some advantages over conventional proving systems:

        * They do not require static bounds on loop iterations, making them better suited for programs with dynamic flow control.
        * They require minimal memory overhead, as the prover only needs space proportional to the necessary space to perform the step instead of storing the whole computation trace.
        * They are well suited for the distribution and parallelization of proof generation.  
The prover can run the program, keeping track of the input and output variables and state changes, and then generate the proofs in parallel using CPU or GPU for each step of the computation. Better still, the proofs can be conveniently aggregated into a single one, which the verifier can check.

* * *

[Incrementally verifiable computation](/incrementally-verifiable-computation-nova/) (IVC) offers an approach to prove the integrity of machine executions. To use ICV, we need to design a universal circuit that can perform any machine-supported instruction. At each step, we have to call this circuit. This is inconvenient since the cost of proving a step is proportional to the size of the universal circuit, even if the program only executes one of the supported instructions at a much lower cost. One way to deal with this shortcoming is by constructing virtual machines with a minimal instruction set to bound the size of the universal circuit.

[SuperNova](https://eprint.iacr.org/2022/1758) provides a cryptographic proof system (comprising a prover and a verifier) based on a virtual machine and a program designed to run over such a machine, satisfying the following properties:

        * Succinctness: the size of the proof and the time to verify said proof are at most polylogarithmic in the execution time of the program.
        * Zero-knowledge: The proof does not reveal anything other than the correct execution of the problem.
        * Convenient cost profile: The cost of proving a step of the program is proportional to the size of the circuit representing such instruction.
        * Incremental proof generation: the prover can generate a proof for each step of the program's execution independently and later combine those proofs into a single one without increasing the size of the proofs.

SuperNova leverages folding schemes (a cryptographic primitive used previously by [Nova](https://github.com/microsoft/Nova)), using relaxed-committed [R1CS](/incrementally-verifiable-computation-nova/), to realize a non-uniform IVC. SuperNova is a generalization of Nova, as it supports machines with a rich instruction set (Nova was limited to one instruction). In the following sections, we will break down the different components needed for SuperNova and how to achieve non-uniform IVC.

## Commitment scheme for vectors

A [commitment scheme](/the-hunting-of-the-zk-snark/) for vectors is a collection of three efficient algorithms:

        * Parameter generation, $\mathrm{Gen}(1^\lambda)=pp$: given a security level parameter, $\lambda$, the algorithm outputs public parameters $pp$.
        * Commit, $\mathrm{commit}(pp,x,r)=\mathrm{cm}$: given the public parameters, a vector, and some randomness, $r$, outputs a commitment $\mathrm{cm}$.
        * Open, $\mathrm{open}(pp,\mathrm{cm},x,r)={0,1}$: given a commitment, the vector, randomness, and public parameters, the algorithm verifies whether the commitment given corresponds to the vector $x$.

The commitment scheme has to satisfy the following properties:

        * Binding: given a commitment $\mathrm{cm}$, it is impossible to find two $x_1$, $x_2$ such that $\mathrm{commit}(pp,x_1,r)=\mathrm{commit}(pp,x_2,r)$. Simply put, the commitment binds us to our original value $x$.
        * Hiding: the commitment reveals nothing from $x$.

The following two properties are useful in our context and satisfied by some commitment schemes, such as Pedersen's:

        * Additively homomorphic: given $x_1$, $x_2$ a commitment is additively homomorphic if $\mathrm{commit}(pp,x_1+x_2,r_1+r_2)=\mathrm{commit}(pp,x_1,r_1)+\mathrm{commit}(pp,x_2,r_2)$.
        * Succinct: the size of the commitment is much smaller than the corresponding vector (for example, $\mathrm{commit}(pp,x,r)=\mathcal{O}(\log(x))$).

SuperNova can be instantiated with any commitment scheme satisfying the four properties above, such as Pedersen's, KZG, or Dory.

## Computational model of non-uniform IVC (NIVC)

We can think of the program as a collection of $n+1$ non-deterministic, polynomial time computable functions, ${f_1,f_2,...,f_n,\phi}$, where each function receives $k$ input and $k$ output variables; each $f_j$ can also take non-deterministic input. The function $\phi$ can take non-deterministic input variables and output an element $j=\phi(z=(x,w))$, choosing one of the $f_i$. Each function is represented as a quadratic rank-one constraint system (R1CS), an NP-complete problem. In IVC, the prover takes as input at step $k$ $(k,x_0,x)$ and a proof $\Pi_k$ that proves knowledge of witnesses $(w_0,w_1,...,w_{k-1})$ such that  
$$ x_{j+1}=F(x_j,w_j) $$  
for all $j=0,1,...,k$ we have $x=x_{k+1}$. In other words, given a proof that shows that the previous step has been computed correctly and the current state $x_k$, we get the next state $x_{k+1}$ and a proof $\Pi_{k+1}$ showing that we computed step $k$ correctly. In the NIVC setting, $\phi$ selects which function we are going to use,  
$$ x_{j+1}=F_{\phi(x_j,w_j)} (x_j,w_j) $$

At each step, SuperNova folds an R1CS instance and its witness, representing the last step of the program's execution into a running instance (it takes two $N$-sized NP instances into a single $N$-sized NP instance). The prover uses an augmented circuit containing a verifier circuit and the circuit corresponding to the function $f_j$ being executed. The verifier circuit comprises the non-interactive folding scheme and a circuit for computing $\phi$. We will represent the augmented functions as $f^\prime_j$.

One problem with the folding scheme is that we have multiple instructions, each having its R1CS representation. We could take the path of universal circuits, but this would make us pay a high cost for many cheap instructions. In Nova, we avoided the problem since we only had one type of instruction. To deal with multiple instructions, SuperNova works with $n$ running instances $U_i$, where $U_i(j)$ attests to all previous executions of $f^\prime_j$, up to step $i-1$. Therefore, checking all $U_i$ is equivalent to checking all $i-1$ steps. Each $f^\prime_j$ takes as input $u_i$, corresponding to step $i$, and folds it to the corresponding $U_i$ instance. We can think of it as looking at the function we want to execute and performing the instance folding with the one related to the previous executions. By doing so, we pay the cost for each instruction only when it is used, at the expense of keeping more running instances and updating accordingly.

The verifier circuit corresponding to $f_j^\prime$ does the following steps:

        1. Checks that $U_i$ and $pc_i=\phi(x_{i-1},w_{i-1})$ (the index of the function executed previously) are contained in the public output of the instance $u_i$. This enforces that the previous step produces both $U_i$ and $pc_i$.
        2. Runs the folding scheme's verifier to fold an instance and updates the running instances, $U_{i+1}$.
        3. Calls $\phi(x_i,w_i)=pc_{i+1}$ to obtain the index of the following function to invoke.

## Summary

IVC is a powerful cryptographic primitive which allows us to prove the integrity of computation in an incremental fashion. This strategy is well-suited for virtual machine executions and general programs with dynamic flow control. We could achieve this by using universal circuits, but at the expense of a considerable cost for each instruction, no matter how cheap it could be. Nova introduced folding schemes, allowing one to realize IVC for a single instruction. SuperNova generalizes Nova to multiple instructions by adding a selector function $\phi$, choosing the instruction to be executed at each step. To support several instructions, SuperNova needs to maintain separate bookkeeping for each function's execution. This construction has many exciting applications since we could realize IVC without requiring expensive arbitrary circuits.
