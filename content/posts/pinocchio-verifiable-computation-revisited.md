+++
title = "Pinocchio: verifiable computation revisited"
date = 2024-07-31
slug = "pinocchio-verifiable-computation-revisited"

[extra]
math = true
feature_image = "/images/2025/12/Massacre_of_the_Mamelukes_at_Cairo_-jpg_version_and_without_frame-.jpg"
authors = ["LambdaClass"]
+++

## 1\. Introduction

### 1.1 Motivation

Imagine you want to do a complex computation, that you cannot carry out in your computer, or you need to get the results from a computer that you don't trust. How can you be sure it was done correctly without redoing it yourself or understanding the intricate details? Introduced in 2013, [Pinocchio](https://eprint.iacr.org/2013/279.pdf) provides a solution using SNARKs. This technology enables a prover to demonstrate the correctness of their computations succinctly and be able to verify them, without revealing the details. Although Pinocchio itself has evolved and is no longer used in its original form, understanding it helps us appreciate the SNARKs that power today's blockchain technologies, including ZK Rollups, enhancing scalability and privacy.

### 1.2 What is a SNARK?

So, Pinocchio is a SNARK protocol, but what is a SNARK? SNARK stands for Succinct, Non-Interactive Argument of Knowledge. _Succinct_ , because we will have small proofs which are easy to verify. _Non-Interactive_ , because the proof generated can be used to convince any number of verifiers without requiring direct interactions with the prover. _Arguments of Knowledge_ , because we know with very high probability that the prover is not cheating. Essentially, SNARK protocols offer us a method to "compress" a complex computation into a small, easy-to-verify proof.

### 1.3 Why do we need SNARKs?

It sounds cool to be able to prove the validity of a computation without having to give its code, but what are the applications in the real world? Where is it used?

A prime example are [ZK Rollups](https://ethereum.org/es/developers/docs/scaling/zk-rollups/). Blockchains are verifiable computers; they achieve this verifiability by having each node re-execute every transaction and reach a consensus. The problem is that the weakest devices become the bottleneck. Adding more hardware does not make them faster, contrary to what happens in web2: the system becomes more robust and reliable, but the weakest devices continue limiting it. Using SNARKs, we can replace the re-execution with the verification of a proof, which is significantly faster (increasing throughput). Moreover, we can create proofs containing entire blocks of transactions, leading to effective scaling. In summary, we can move the execution off-chain to rollups and verify their proofs on-chain, allowing the system to scale.

## 2\. Protocol's Preliminaries: From code to QAP

### 2.1 Arithmetic Circuits

The first thing we must do to be able to use any SNARK protocol is to find an efficient and systematic way to represent a computational code. And that's what arithmetic circuits do: An arithmetic circuit is a computational model used to represent arithmetic operations in a structured way. It provides a systematic way to describe and compute complex mathematical functions. To learn more about arithmetic circuits you can see our post [How to transform code into arithmetic circuits](/how-to-transform-code-into-arithmetic-circuits/).

Now, if the prover wanted to demonstrate that given specific inputs, a particular code returns certain outputs, she could simply send the corresponding arithmetic circuit to the verifier, without any other protocol needed. The problem is that such a test would not be succinct at all, in fact it would practically be like sending the inputs and the code completely. That is why, in order to achieve a succinct proof, we will have to convert the arithmetic circuit to what we call a R1CS and then transform the R1CS obtained into a QAP.

Below we will broadly explain what R1CSs and QAPs are. Note that it may be constructive to accompany this explanation with its respective implementations that can be found in [Pinocchio from Lambdaworks library](https://github.com/lambdaclass/lambdaworks/pull/884).

### 2.2 R1CS

R1CS stands for Rank-1 Constraint System. It allows us to express relationships between the circuit's variables in a structured way using [matrix](https://en.wikipedia.org/wiki/Matrix_\(mathematics\)) equations. More specifically, given an arithmetic circuit with a valid solution $c$, our goal will be to create a system of equations of the form $Ac \odot Bc = Cc$ with $A$, $B$ and $C$ matrices:

To fully understand what R1CS are and how to build them, we recommend reading [this article](https://www.rareskills.io/post/rank-1-constraint-system). Nevertheless, we enumerate here the steps to transform an arithmetic circuit into an R1CS.

        1. Identify all the variables used in the circuit. Let's call them $c = (1, c_1 , \ldots, c_N , c_{N + 1}, \ldots, c_m)$ where $\\{ c_1, \ldots, c_N \\}$ are the public variables and $\\{c_{ N + 1}, \ldots, c_m \\}$ are the intermediate and private variables of the circuit.
        2. Represent the circuit as a system of equations with variables $\\{ c_i \\}_{i = 1}^{m}$ and just one multiplication per equation. We will call each equation a _constraint_ and $n$ the number of constraints.
        3. Construct matrix $A \in { \mathbb{F_p} }^{n \times m}$ in the following way: $a_{ik}$ is the coefficient of the variable $c_k$ at the left entry of the constraint $i$.  
(If you don't know what ${ \mathbb{F_p} }^{n \times m}$ means, don't worry you could think it as ${\mathbb{R}}^{n \times m}$, so $A$ is just a matrix of numbers).
        4. Analogously, construct matrix $B$ whose rows represent the right side of the multiplication of each constraint.
        5. Construct matrix $C$ whose rows represent the result value of each constraint.
        6. Finally, $c$ is a solution of the arithmetic circuit if and only if $Ac \odot Bc = Cc$, where $\odot$ represents the [Hadamard Product](https://en.wikipedia.org/wiki/Hadamard_product_\(matrices\)).

### 2.3 QAP

So now we know that programs can be represented as arithmetic circuits and further converted into an R1CS. However, directly evaluating R1CS for verification purposes still isn't succinct due to the large number of operations required, especially for complex computations. Quadratic Arithmetic Programs (QAPs) address this issue by providing a more efficient representation.

QAPs encode the constraints of an R1CS into sets of [polynomials](https://en.wikipedia.org/wiki/Polynomial). This allows multiple constraints to be batched into a single polynomial equation. But why does using polynomials make the proof succinct? It's all thanks to the mathematical result known as the [Schwartz-Zippel Lemma](https://en.wikipedia.org/wiki/Schwartz%E2%80%93Zippel_lemma). To see in detail why this lemma makes the proof succinct and how we transform an R1CS into a QAP we recommend reading [this chapter](https://www.rareskills.io/post/quadratic-arithmetic-program) of The RareSkills Book of ZK. Our goal is to be able to test the validity of a solution of the R1CS, checking that a certain polynomial has a given property. We leave here the steps with the notation that we will use below in the protocol:

        1. Recieve the R1CS: $Ac \odot Bc = Cc$ where $A, B, C \in {\mathbb{F }_p }^{n \times m}$ and $c \in {\mathbb{F }_p }^m$.
        2. Transform each column of $A$, $B$ and $C$ into polynomials:  
For each $k \in {1, \ldots, m}$, interpolate $(1, \ldots, n)$ with $(a_{1k} , \ldots , a_{nk} )$ the column $k$ of $A$. We will call the resulting polynomial $v_k(x)$.  
Analogously, $w_k(x)$ and $y_k(x)$ interpolate the columns of $B$ and $C$ respectively.
        3. Define the polynomials $$\begin{align}  
p(x) &= \left(\sum_{k = 1 }^m c_k v_k(x) \right) \left(\sum_{k = 1 }^m c_k w_k(x) \right) - \sum_{k = 1 }^m c_k y_k(x), \ \newline  
t(x) &= (x - 1)( x - 2)\ldots( x - n).  
\end{align}$$We will call $t(x)$ the _vanishing polynomial_.
        4. Finally, $c$ is a solution of the R1SC if and only if there exists a polynomial $h$ such that $p(x) = h(x)t(x)$. This can be checked by choosing a random $s$ and verifying that $p(s) = h(s)t(s)$.

## 3\. Pinocchio's Protocol

### 3.1 The idea behind

Now we are ready to understand the protocol. It starts with a one-time setup, where two keys are generated for proving and verifying these computations. The prover, who performs the computation, uses her key to create a proof that is small and constant in size, regardless of the computation's complexity. This proof is then verified efficiently through mathematical checks that ensure the computation was done correctly. The system not only supports public verification, allowing anyone with the verification key to check the proof, but it can also be extended to provide privacy-protecting zero-knowledge proofs.

### 3.2 Math Prelimenaries

Understanding Pinocchio's protocol requires familiarity with key mathematical concepts, primarily elliptic curves, finite fields, and group theory. These form the foundation of the cryptographic operations and security proofs in Pinocchio (and SNARK protocols in general). For a detailed exploration of elliptic curves, refer to our [post](/what-every-developer-needs-to-know-about-elliptic-curves/) where we talk about them. For a primer on fundamental structures like groups and fields, see our [Math Survival Kit for Developers](/math-survival-kit-for-developers/). These resources provide the necessary background to appreciate Pinocchio's intricate design.

### 3.3 Some observations to understand the protocol

        * The prover and verifier agree on a pairing-friendly elliptic curve and generators of the groups $G_1$ and $G_2$ denoted by $g_1$ and $g_2$, respectively. In our case, we choose BLS12-381.
        * Technically, it is not necessary to work with two groups to implement the protocol. That is, the entire implementation can be interpreted using $G_1 = G_2 = G$ and $g_1 = g_2 = g$. In fact in the original Pinocchio's Paper you can find it that way. However, Type I pairings (that is, those whose domain is of the form $G \times G$) are very inefficient. Furthermore, BLS12-381 and BN254 are curves that have relevance for Ethereum and that is why we choose to work on them in general.
        * We are using $+$ to denote the operation of the groups $G_1$ and $G_2$. For example, $\alpha_v \cdot g_2 = \underbrace{g_2 + \ldots + g_2}_{\alpha_v \text{ times}}$.

### 3.4 The protocol

In the following section we present the protocol with some code snipets from the [implementation](link-here) we made using the Lambdaworks library.

#### Setup

Select eight private random elements $s$, $\alpha_v$, $\alpha_w$, $\alpha_y$, $\beta$, $r_v$, $r_w$, $\gamma$ from $\mathbb{F_p}$, and set $r_y = r_v \cdot r_w$. This set of elements are called _toxic waste_ and should be discarded and wholly forgotten once the keys have been generated.
    
    pub struct ToxicWaste {
        rv: FE,
        rw: FE,
        s: FE,
        // .... (other elements)
    
    
    impl ToxicWaste {
        pub fn sample() -> Self {
            Self {
                s: sample_fr_elem(),
                alpha_v: sample_fr_elem(),
                // ... (other elements)
            }
        }
        
        pub fn ry(&self) -> FE {
            &self.rv * &self.rw
        }
    }
    

Two public keys are generated in the Setup: the evaluation key, that is sent to the prover and the verification key, that is send to the verifier.

##### The verification key

        1. $g_2$
        2. $\alpha_v \cdot g_2$
        3. $\alpha_w \cdot g_2$
        4. $\alpha_y \cdot g_2$
        5. $\gamma \cdot g_2$
        6. $\beta \gamma \cdot g_2$
        7. $r_y t(s) \cdot g_1$
        8. $\\{r_v v_k(s) \cdot g_1 \\}_{k \in \\{0,\ldots, N \\} }$
        9. $\\{r_w w_k(s) \cdot g_2 \\}_{k \in \\{0,\ldots, N \\} }$
        10. $\\{r_y y_k(s) \cdot g_1 \\}_{k \in \\{0,\ldots, N \\} }$

To implement this in rust, we first need to create a struct VerificationKey with each element and then generate it.
    
    pub struct VerificationKey {
        pub g2: G2Point,
        pub g2_alpha_v: G2Point,
        pub g2_alpha_w: G2Point,
        // ...
    }
    
    
    pub fn generate_verification_key(
        qap: QuadraticArithmeticProgram,
        toxic_waste: &ToxicWaste,
    ) -> VerificationKey {
        let g1: G1Point = Curve::generator();
        let g2: G2Point = TwistedCurve::generator();
        
        // declare the rest of the variables needed
        // ...
    
        VerificationKey {
            g2: g2.clone(),
            g2_alpha_v: g2.operate_with_self(toxic_waste.alpha_v.representative()),
            // ... 
        }
    }
    

##### The evaluation key

        1. $\\{r_v v_k(s) \cdot g_1 \\}_{k \in \\{N + 1, \ldots, m \\}}$
        2. $\\{r_w w_k(s) \cdot g_1 \\}_{k \in \\{N + 1, \ldots, m \\}}$
        3. $\\{r_w w_k(s) \cdot g_2 \\}_{k \in \\{N + 1, \ldots, m \\}}$
        4. $\\{r_y y_k(s) \cdot g_1 \\}_{k \in \\{N + 1, \ldots, m \\}}$
        5. $\\{r_v \alpha_v v_k(s) \cdot g_1 \\}_{k \in \\{N + 1, \ldots, m \\}}$
        6. $\\{r_w \alpha_w w_k(s) \cdot g_1 \\}_{k \in \\{N + 1, \ldots, m \\}}$
        7. $\\{r_y \alpha_y y_k(s) \cdot g_1 \\}_{k \in \\{N + 1, \ldots, m \\}}$
        8. $(r_v \beta v_k(s) + r_w \beta w_k(s) + r_y \beta y_k(s)) \cdot g_1$
        9. $\\{ s^i \cdot g_2 \\}_{i \in \\{ 1,\ldots,d \\} }$ where $d$ is the degree of $t(x) = (x - 1) \ldots (x - n)$. That is, $d = n$ the number of raws of the R1SC matrices (i.e. the number of constraints).
    
    pub struct EvaluationKey {
        pub g1_vk: Vec<G1Point>,
        pub g1_wk: Vec<G1Point>,
        pub g2_wk: Vec<G2Point>,
        // ... 
    }
    
    
    pub fn generate_evaluation_key(
        qap: &QuadraticArithmeticProgram,
        toxic_waste: &ToxicWaste,
    ) -> EvaluationKey {
        let g1: G1Point = Curve::generator();
        let g2: G2Point = TwistedCurve::generator();
        let (v_mid, w_mid, y_mid) = (qap.v_mid(), qap.w_mid(), qap.y_mid());
        
        // declare the rest of the variables needed
        // ...
        
        EvaluationKey {
            g1_vk: vs_mid.iter()
                .map(|vk| g.operate_with_self((rv * vk.evaluate(&s))
                .representative()))
                .collect(),
    ,
            // ... 
        }
    }
    

Having EvaluationKey and VeifiationKey, we can then implement the setup:
    
    pub fn setup(
        qap: &QuadraticArithmeticProgram,
        toxic_waste: ToxicWaste,
    ) -> (EvaluationKey, VerificationKey) {
        (generate_evaluation_key(&qap, &toxic_waste),
         generate_verification_key(qap.clone(), &toxic_waste))
    }
    

#### Prove

The steps for the prover are as follows:

        1. Evaluate the circuit with the input values and obtain ${c_{N + 1}, \ldots, c_m }$ the intermediate values.

        2. Compute the polynomial $$p(x) = \left(\sum_{k = 1}^m c_k v_k(x) \right) \left(\sum_{k = 1}^m c_k w_k(x) \right) - \sum_{k = 1}^m c_k y_k(x).$$

        3. Calculate the polynomial $h(x) = \frac{p(x)}{t(x)}$.

        4. Produce the proof $$\pi = (V, W_1, W_2, Y, V', W', Y', Z, H),$$ computing its elements:

           * $V = \sum\limits_{k = N + 1}^m c_k \cdot \underbrace{\style{color: olive;}{r_v v_k(s) \cdot g_1}}_{\style{color: olive;}{\begin{array}{c} \text{From the} \ \text{evaluation key} \end{array}}}$
           * $W_1 = \sum\limits_{k = N + 1}^m c_k \cdot \style{color: olive;}{r_w w_k(s) \cdot g_1}$
           * $W_2 = \sum\limits_{k = N + 1}^m c_k \cdot \style{color: olive;}{r_w w_k(s) \cdot g_2}$
           * $Y = \sum\limits_{k = N + 1}^m c_k \cdot \style{color: olive;}{r_y y_k(s) \cdot g_1}$
           * $V' = \sum\limits_{k = N + 1}^m c_k \cdot \style{color: olive;}{r_v \alpha_v v_k(s) \cdot g_1}$
           * $W' = \sum\limits_{k = N + 1}^m c_k \cdot \style{color: olive;}{r_w \alpha_w w_k(s) \cdot g_1}$
           * $Y' = \sum\limits_{k = N + 1}^m c_k \cdot \style{color: olive;}{r_y \alpha_y y_k(s) \cdot g_1}$
           * $Z = \sum\limits_{k = N + 1}^m c_k \cdot \style{color: olive;}{(r_v \beta v_k(s) + r_w \beta w_k(s) + r_y \beta y_k(s)) \cdot g_1}$
           * $H = h(s) \cdot g_2 = \sum\limits_{i = 1 }^d h_i \cdot \style{color: olive;} {s^i \cdot g_2}$
        5. Send the public values $(c_1, \ldots, c_N)$ and the proof $\pi$.
    
    pub fn generate_proof(
        evaluation_key: &EvaluationKey,
        qap: &QuadraticArithmeticProgram,
        qap_c_coefficients: &[FE],
    ) -> Proof {
        // We will call {c_{N+1}, ... , c_m} cmid.
        let cmid = &qap_c_coefficients[qap.number_of_inputs
        ..qap_c_coefficients.len() - qap.number_of_outputs];
        
        // We transform each FieldElement of the cmid into an UnsignedInteger so we can multiply them to g1.
        let c_mid = cmid
            .iter()
            .map(|elem| elem.representative())
            .collect::<Vec<_>>();
    
        let h_polynomial = qap.h_polynomial(qap_c_coefficients);
        let h_coefficients = h_polynomial.coefficients
            .iter()
            .map(|elem| elem.representative())
            .collect::<Vec<_>>();
        let h_degree = h_polynomial.degree();
    
        Proof {
            v: msm(&c_mid, &evaluation_key.g2_vk_s).unwrap(),
            w1: msm(&c_mid, &evaluation_key.g2w_wk).unwrap(),
            w2: msm(&c_mid, &evaluation_key.g2w_wk).unwrap(),
            //...
    
    
        }
    }
    

#### Verify

So that no malicious prover deceives the verifier, he has to ensure two things: Firstly, that the requested condition (number 4) of the QAP's polynomial is satisfied; and secondly, that the proof's elements have been generated from the QAP correctly. To achieve this, the verifier will do three checks. The first check will ensure the validity of the QAP and the other two checks, the correct construction of the proof's elements.

We will denote $e$ to the pairing whose first argument is a point from $G_1,$ and the second from $G_2$.

**Check 1: Correctness of the QAP**  
To be sure that the provided proof corresponds to a valid solution of the QAP, and thus a correct computation result, the verifier needs to be convinced that $p(s) = h(s)t(s)$. To achieve this he can simply check $$e(V_{io} + V, W_{io} + W_2 ) = e( \style{color: teal}{r_y t(s) \cdot g_1} , H ) e(Y_{io} + Y, \style{color: teal}{g_2} ),$$ where to simplify the notation we call

        * $V_{io} = \style{color: teal}{r_v v_0(s) \cdot g_1} + \sum\limits_{k=1}^N c_k \style{color: teal} {r_v v_k(s) \cdot g_1}$
        * $W_{io} = \style{color: teal}{r_w w_0(s) \cdot g_2} + \sum\limits_{k=1}^N c_k \style{color: teal} {r_w w_k(s) \cdot g_2}$
        * $Y_{io} = \style{color: teal}{r_y y_0(s) \cdot g_1} + \sum\limits_{k=1}^N c_k \style{color: teal} {r_y y_k(s) \cdot g_1}$
    
    pub fn check_divisibility(
        verification_key: &VerificationKey,
        proof: &Proof,
        c_io: &[FE],
    ) -> bool {
        // We will use hiding_v, hiding_w and hiding_y as arguments of the pairings.
        
        // We transform the c_io into UnsignedIntegers.
        let c_io = c_io
        .iter()
        .map(|elem| elem.representative())
        .collect::<Vec<_>>();
        
        let v_io = verification_key.g1_vk[0]
            .operate_with(&msm(&c_io, &verification_key.g1_vk[1..]).unwrap());
            
        // The same with w_io and y_io.
        //...
        
        Pairing::compute(
            &v_io.operate_with(proof.v), 
            &w_io.operate_with(proof.w)
        ).unwrap()
        == Pairing::compute( ... , ...).unwrap() 
        * Pairing::compute( ... , ...).unwrap()
        
    }
    

**Correct construction of $V$, $W$ and $Y$:**

**Check 2:** The veifier checks that the prover used the polynomials of the QAP to construct $V$, $W$ and $Y$, and that he didn't provide arbitrary values that simply pass the previous check.

So, in this check the goal is to verify that $V$ is $g_1$ multiplied by some linear combination of ${v_k(s)}_{k \in {1,\ldots,m}}$, and analogously, with $W$ and $Y$:

        * $e(V', \style{color: teal} {g_2}) = e(V, \style{color: teal} {\alpha_v \cdot g_2})$
        * $e(W', \style{color: teal} {g_2}) = e(W, \style{color: teal} {\alpha_w \cdot g_2})$
        * $e(Y', \style{color: teal} {g_2}) = e(Y, \style{color: teal} {\alpha_y \cdot g_2})$
    
    pub fn check_appropriate_spans(
        verification_key: &VerificationKey,
        proof: &Proof
    ) -> bool {
        let b1 = Pairing::compute(&proof.v_prime, &verification_key.g2) 
            == Pairing::compute(&proof.v, &verification_key.g2_alpha_v);
        let b2 = Pairing::compute( ... , ... ) 
            == Pairing::compute(... , ... );
        let b3 = // ...
        
        b1 && b2 && b3
    }
    

Why does this work?

If this check passes, the verifier can be sure that, for example, $V' = \alpha_v V$. Looking at the evaluation key, he sees that the prover doesn't know the raw value of $\alpha_v$. So the only way the prover could have constructed $V$ and $V'$ such that they satisfy this equality is using a linear combination of ${v_k(s)}_{k \in {1,\ldots,m }}$. Similarly, he can be convinced that $W$ and $Y$ were constructed that way.

**Check 3:** The previous check is not enough to ensure that the proof elements were constructed correctly. We also need to verify that the prover used the same set of coefficients ${c_1,\ldots,c_m}$ in each linear combination $V$, $W$ and $Y$ of the previous check.

$$e(Z, \style{color: teal} {\gamma \cdot g_2}) = e(V+W+ Y, \style{color: teal} {\beta \gamma \cdot g_2}) $$
    
    pub fn check_same_linear_combinations(
        verification_key: &VerificationKey,
        proof: &Proof
    ) -> bool {
        Pairing::compute(&proof.z, &verification_key.g2_gamma)
        == Pairing::compute(
            &proof.v
                .operate_with(&proof.w)
                .operate_with(&proof.y),
            &verification_key.g2_beta_gamma
        )
    }
    

Putting it all together
    
    pub fn verify(verification_key:&VerificationKey,
        proof: &Proof,
        c_inputs_outputs: &[FE]
    ) -> bool {
        let b1 = check_divisibility(verification_key, proof, c_inputs_outputs);
        let b2 = check_appropriate_spans(verification_key, proof);
        let b3 = check_same_linear_combinations(verification_key, proof);
        
        b1 && b2 && b3
    }
    

## 6\. Turning a SNARK into a ZK-SNARK

What does it mean zero-knowledge? We would like to be impossible for the verifier to gain any information from the proof, as it appears indistinguishable from random data.

To make it zero-knowledge, the prover has to sample some random values $\delta_v,\delta_w,\delta_y$ and make the following changes to the polynomials:

$v_{mid}(x) + \delta_v t(x), v(x) + \delta_v t(x),w(x) + \delta_w t(x) \text{ and } y(x) + \delta_y t(x).$

You can see in detail the zk adaptation of the protocol in the [Chapter 4.13](https://arxiv.org/abs/1906.07221) of _Why and How zk-SNARK Works_.

## 7\. Summary

In this post we covered the main ideas behind Pinocchio's protocol and our implementation using Lambdaworks library. We first saw the steps to transform code into a QAP. Then, we presented the actual protocol explaining how it works and why we need each different check to achieve security. Finally, we observed that while its primary objective is to achieve verifiable computation, it can incorporate zero-knowledge properties with minimal additional effort.
