+++
title = "GKR protocol implementation: deep dive into the code"
date = 2025-07-22
slug = "gkr-protocol-implementation-deep-dive-into-the-code"

[extra]
feature_image = "/images/2025/12/The_fall_of_Babylon-_Cyrus_the_Great_defeating_the_Chaldean_Wellcome_V0034440.jpg"
authors = ["LambdaClass"]
+++

## Introduction

The **GKR** (Goldwasser–Kalai–Rothblum) protocol provides an efficient way to verify computations over arithmetic circuits, avoiding re-execution and reducing the verifier’s work. In our previous post, [GKR protocol: a step-by-step example](/gkr-protocol-a-step-by-step-example/), we explored how the protocol works in detail, focusing on its mathematical structure and walking through a concrete hand-worked example. [GKR](https://eprint.iacr.org/2023/1284) is currently used to improve the performance of lookup arguments, which are crucial for proving the execution of zero-knowledge virtual machines.

The goal of this post is to explain [our implementation](https://github.com/lambdaclass/lambdaworks/pull/1011) of the protocol in Lambdaworks, showing how arithmetic circuits are described and validated, and how the prover and verifier operate in practice. We'll also see how the **Fiat-Shamir transform** is applied to make the protocol **non-interactive** , and how the **Sumcheck protocol** is adapted and integrated as the core component for verifying each circuit layer.

If you're not familiar with the protocol or need a refresher, we recommend starting with our previous post linked above.

**Warning:** The GKR implementation presented here is for educational purposes only and should not be used in production. Note that for more general circuits, the protocol is vulnerable to practical attacks, as it relies on the Fiat-Shamir transform (see ["How to Prove False Statements"](https://eprint.iacr.org/2025/118.pdf)).

## Circuit Structure

A GKR circuit is composed of layers. Each layer contains gates, and each gate operates on outputs from the previous layer. Gates can be either addition or multiplication. For protocol compatibility, each layer must have a power-of-two number of gates.

![image](/images/external/BkLEjCjIlx.png)  
_The arithmetic circuit used in the previous post as an example_

In some cases, we can work with more efficient versions if all the gates are, for example, multiplications.

### Circuit API

The main structures for circuit construction are:

        * `Circuit` — Consists of a vector of layers (ordered from top to bottom, starting at the output layer and not including the input layer); the number of inputs; and the number of variables needed to index the input layer.
              
              pub struct Circuit {
                  /// First layer is the output layer. It doesn't include the input layer.
                  layers: Vec<CircuitLayer>,
              
                  /// Number of inputs
                  num_inputs: usize,
                  input_num_vars: usize, // log2 of number of inputs
              }
              

        * `CircuitLayer` — contains a vector of gates and the number of variables needed to index those gates.
              
              pub struct CircuitLayer {
                  pub gates: Vec<Gate>,
                  pub num_of_vars: usize, // log2 of number of gates in this layer
              }
              

        * `Gate` — a single gate, with its type and input indices.
        * `GateType` — either `Add` or `Mul`.

### Circuit Gates

Each gate in the circuit is either an addition (`Add`) or multiplication (`Mul`) gate. The gate type determines how the outputs from the previous layer are combined:

        * `Add`: The gate outputs the sum of its two input wires.
        * `Mul`: The gate outputs the product of its two input wires.

For example:
    
    let gate_1 = Gate::new(GateType::Mul, [0, 1]); //Multiplies outputs at indices 0 and 1 from the previous layer.
    let gate_2 = Gate::new(GateType::Add, [2, 3]); // Adds outputs at indices 2 and 3 from the previous layer.
    

![image](/images/external/SkRvRAjIlx.png)

### Example: The Blog Post Circuit

To illustrate this, let's walk through the construction of the exact circuit used in our [step-by-step GKR blog post](/gkr-protocol-a-step-by-step-example/). This is available as `lambda_post_circuit()` in the codebase, and you can use it directly or as a template for your circuits.
    
    pub fn lambda_post_circuit() -> Result<Circuit, CircuitError> {
        use crate::circuit::{Circuit, CircuitLayer, Gate, GateType};
        Circuit::new(
            vec![
                // Layer 0 (output layer): Two gates
                CircuitLayer::new(vec![
                    Gate::new(GateType::Mul, [0, 1]), // Multiplies outputs 0 and 1 from previous layer
                    Gate::new(GateType::Add, [2, 3]), // Adds outputs 2 and 3 from previous layer
                ]),
                // Layer 1: Four gates
                CircuitLayer::new(vec![
                    Gate::new(GateType::Mul, [0, 1]), // Multiplies the two inputs
                    Gate::new(GateType::Add, [0, 0]), // Adds the first input to itself
                    Gate::new(GateType::Add, [0, 1]), // Adds both inputs
                    Gate::new(GateType::Mul, [0, 1]), // Multiplies the two inputs again
                ]),
            ],
            2, // Two inputs
        )
    }
    

### How to Build Your Circuit

        1. **Decide the number of inputs.** Each input will be referenced by its index (starting from 0).
        2. **Build the first layer:** Each gate in the first layer operates on the inputs. Use `Gate::new(GateType::Add, [i, j])` or `Gate::new(GateType::Mul, [i, j])` to add or multiply input indices `i` and `j`.
        3. **Build subsequent layers:** Each gate operates on outputs from the previous layer. Indices always refer to the order of outputs of the prior layer. Each new layer should be inserted at the beginning of the `layers` vector, since layers are ordered from the top (output layers) to the bottom of the circuit.
        4. **Repeat until you reach the output layer.**
        5. **Wrap your layers in a`Circuit::new(layers, num_inputs)` call.**

**Important:**

        * Each layer must have a power-of-two number of gates.
        * Indices must be valid (i.e., not out of bounds for the previous layer).

### Circuit Automatic Validation

When you construct a `Circuit`, several checks are performed automatically to ensure the circuit is well-formed:

        * **Power-of-two gates** : Each layer must have a number of gates that is a power of two. This is required for the protocol to work efficiently.
        * **Valid input indices** : Each gate's input indices must refer to valid outputs from the previous layer. If an index is out of bounds, the construction fails.
        * **Power-of-two inputs** : The number of circuit inputs must also be a power of two.

If any of these conditions are not met, the constructor returns a descriptive error (as a `Result::Err`). This prevents invalid circuits from being created and helps catch mistakes early in development.

## The GKR Protocol

Let's see how each step of the protocol is implemented in our code. We aim to demonstrate how it leverages the sumcheck protocol to recursively reduce a claim about the correctness of a computation at one layer of a circuit to a claim about the next layer, progressing from the output layer down to the input layer.

Recall that in our implementation, we utilize the Fiat-Shamir transform to render the protocol non-interactive, which results in a slightly different appearance from the version described in the previous post.

### Prover

#### The proof structure

The prover is responsible for evaluating the circuit and constructing a proof that convinces the verifier of the correctness of this evaluation. The core logic for the prover resides in `prover.rs`, where you can find the struct `GKRProof` that consists of:

        * The input and the output values of the circuit.
        * A sumcheck proof for each circuit layer having: 
          * The round univariate polynomials $g_j$.
          * The composition of the univariate polynomial $q$.

Let's recall what the polynomials $g_j$ and $q$ are. In each circuit layer and for each round $j$ of its sumcheck, the prover has to compute the univariate polynomial $g_j$ by fixing the first variable and summing over all the others. For example, in our previous post, in the layer $0$, the sumcheck had four rounds leading to these polynomials:

$$\begin{align}  
g_1 (z) &= \sum_{(b_2, c_1, c_2) : \in {0, 1}^3} \tilde f_{ r_0 }^{ (0) } (z, b_2, c_1, c_2), \ \newline  
g_2 (z) &= \sum_{(c_1, c_2) : \in {0, 1}^2} \tilde f_{ r_0 }^{ (0) } (s_1, z, c_1, c_2), \ \newline  
g_3 (z) &= \sum_{c_2 : \in {0, 1}} \tilde f_{ r_0 }^{ (0) } (s_1, s_2, z, c_2),\ \newline  
g_4 (z) &= \tilde f_{ r_0 }^{ (0) } (s_1, s_2, s_3, z),  
\end{align}$$

where $s_j$ are random challenges.

On the other hand, for each layer $i$, the polynomial $q$ is the composition $q = \tilde W_{i + 1} \circ \ell$, where $\tilde W_{i + 1}$ is the multilinear polynomial extension of the function that maps a node’s position to its actual value, and $\ell$ is the line that goes from $b^\star$ to $c^\star$. In the previous example, $\ell (0) = (s_1, s_2)$ and $\ell (1) = (s_3, s_4)$.

In the codebase, you'll see it as:
    
    pub struct GKRProof<F: IsField> {
        pub input_values: Vec<FieldElement<F>>,
        pub output_values: Vec<FieldElement<F>>,
        pub layer_proofs: Vec<LayerProof<F>>,
    }
    

The proof for each circuit layer is:
    
    pub struct LayerProof<F: IsField> {
        pub sumcheck_proof: GKRSumcheckProof<F>,
        pub poly_q: Polynomial<FieldElement<F>>,
    }
    

Finally, the `sumcheck_proof` contains the round polynomials $g_j$ and the challenges used in those rounds, so that both prover and verifier can calculate the line $\ell$.
    
    pub struct GKRSumcheckProof<F: IsField> {
        pub round_polynomials: Vec<Polynomial<FieldElement<F>>>,
        pub challenges: Vec<FieldElement<F>>,
    }
    

#### Building the proof

The prover constructs the proof using the `Prover::generate_proof()` method. This function takes the circuit and its inputs, evaluates the circuit on them, and generates the proof. Let's break down this function into the following steps:

        1. **Circuit Evaluation:** The Prover evaluates the whole circuit in the given inputs.
               
               let evaluation = circuit.evaluate(input);
               

        2. **Transcript Initialization** :

Since we implemented the non-interactive version of the protocol, the prover must **commit to the circuit, its inputs, and its outputs**. This is done by defining a `DefaultTranscript`, from which we can commit to and sample new values. Both prover and verifier append this data to the transcript. To append the circuit, they need to convert it into bytes, and they do so using the function `circuit_to_bytes()` that you can find in the file `lib.rs`. We'll see more about the transcript later on in the Fiat-Shamir subsection.

        3. **Sample $r_0$** :  
The prover samples the first $r_0$ to fix the variable $a$ and begin the sumcheck. Recall that the variable $a$ could have more than one bit, so $r_0$ has the same size as $a$ called $k_0$
               
               let k_0 = circuit.num_vars_at(0).ok_or(ProverError::CircuitError)?;
               let mut r_i: Vec<FieldElement<F>> = (0..k_0)
                   .map(|_| transcript.sample_field_element())
                   .collect();
               

        4. **Sumcheck layer iteration:** For each layer, the prover applies the sumcheck protocol following these steps:

           * **Building the function** :  
The prover builds the function to which he wants to apply the sumcheck,  
$$\tilde f_{ r_i } (b, c) = \widetilde{\text{add_i}} (r_i, b, c) \cdot (\widetilde W_{i + 1}(b) + \widetilde W_{i + 1}(c)) + \widetilde{\text{mul_i}} (r_i, b, c) \cdot (\widetilde{W_{i + 1}} (b) \cdot \widetilde{W_{i + 1}} (c)),$$  
using the method `Prover::build_gkr_polynomial()`. Note that this method returns two terms instead of just one. More specifically, it returns a 2-item vector whose elements are themselves vectors of two multilinear polynomials:  
First term or vector:  
$$[\widetilde{\text{add_i}} (r_i, b, c), \widetilde{W_{i + 1}} (b) + \widetilde{W_{i + 1}} (c)]$$  
Second term or vector:  
$$[\widetilde{\text{mul_i}} (r_i, b, c), \widetilde{W_{i + 1}} (b) \cdot \widetilde{W_{i + 1}} (c)]$$

This is necessary because the sumcheck implementation at lambdaworks only accepts a product of multilinear polynomials. That is why we separate our polynomial $\tilde f_{r_i}$ into two terms of products of multilinear polynomials.
                 
                 let gkr_poly_terms =
                         Prover::build_gkr_polynomial(circuit, &r_i, w_next_evals, layer_idx)?;
                 

           * **Apply the GKR Sumcheck Prover:**  
We use a sumcheck implementation specifically designed for the GKR protocol. We’ll go into more detail about this new sumcheck later, but there are three **key changes** to keep in mind:  
**I)** We need a sumcheck prover that **takes a transcript as input** , so we can maintain the same transcript for both the prover and the verifier, which is created at the start.  
**II)** This new sumcheck also **returns the random values sampled during execution**. This allows both the prover and verifier to compute the function $\ell$ later, which depends on those values.  
**III)** The GKR sumcheck allows us to **work with both terms** of $\tilde f_{ r_i } (b,c)$ at the same time.
                 
                 let sumcheck_proof = gkr_sumcheck_prove(gkr_poly_terms, &mut transcript)?;
                 

           * **Sumcheck final claim:**  
The prover samples a new field element $r^\star$ (called `r_new`in the code), evaluates the line $\ell$ at it, and calculates the composition polynomial $q$. The evaluation of $\ell$ is computed using the function `line()` that you can find in `lib.rs` (since it is used by both prover and verifier). On the other hand, the polynomial $q$ is calculated using the method `Prover::build_polynomial_q()`. To calculate this polynomial, the prover needs to interpolate three points, since $q$ has degree 2 (as $\ell$ is linear and $\tilde W_{i + 1}$ multilinear in each variable).
                 
                 // r* in our blog post <https://blog.lambdaclass.com/gkr-protocol-a-step-by-step-example/>
                 let r_new = transcript.sample_field_element();
                 
                 // Construct the next round's random point using line function
                 //  l(x) = b + x * (c - b)
                 let (b, c) = sumcheck_challenges.split_at(num_vars_next);
                 // r_i = l(r_new)
                 r_i = crate::line(b, c, &r_new);
                 
                 let poly_q = Prover::build_polynomial_q(b, c, w_next_evals.clone())?;
                 

        5. **Make the proof:** Finally, the prover has all the ingredients to make the proof.
               
               let proof = GKRProof {
                   input_values: input.to_vec(),
                   output_values,
                   layer_proofs,
               };
               

### Verifier

Once we understand what the prover does, it’s easy to see what the verifier needs to do. It simply follows the same steps as the prover, using the elements of the proof and performing the necessary checks at each step. She verifies the proof using the method `Verifier::verify()` following these steps:

        1. **Transcript Initialization:**  
Just as the prover, start by creating a transcript and appending the **circuit** (which is known to both parties), the **inputs** , and the **outputs** sent in the proof by the prover.

        2. **Initial Sum Calculation:**  
Sample field elements for $r_0$ to fix the variable $a$ and set the initial sum as $m_0 = \tilde D (r_0)$, where $\tilde D$ is the multilinear polynomial extension of the function that maps the output gates to the evaluation values. The prover sent these values as part of the proof.
               
               let output_poly_ext = DenseMultilinearPolynomial::new(proof.output_values.clone());
               let mut claimed_sum = output_poly_ext
                   .evaluate(r_i.clone())
                   .map_err(|_e| VerifierError::MultilinearPolynomialEvaluationError)?;
               

        3. **Layer-by-Layer Verification:** For each layer $i$, the verifier performs the following:

           * **Verify the sumcheck proof:**  
The verifier checks the sumcheck proof for the current layer using the function `gkr_sumcheck_verify`. This function ensures that the sequence of univariate polynomials $g_j$ provided by the prover has degree 2 and is consistent with the claimed sum in each sumcheck round $j$; that is,  
$$ deg(g_j) \leq 2,$$$$g_j (0) + g_j (1) == g_{j - 1} (s_{ j - 1 }).$$
                 
                 let (sumcheck_verified, sumcheck_challenges) = gkr_sumcheck_verify(
                     claimed_sum.clone(),
                     &layer_proof.sumcheck_proof,
                     &mut transcript,
                 )?;
                 if !sumcheck_verified {
                     return Ok(false);
                 }
                 

           * **Check the final round $n$ using the composition polynomial $q$:**  
To verify the final claim of the sumcheck in the last round, the verifier needs the values $\tilde W_{ i + 1}(b^\star)$ and $\tilde W_{i + 1}(c^\star)$. However, the polynomial $\tilde W_{ i + 1}$ is unknown to her: the verifier doesn't have the circuit evaluations. That is why she performs this final check using the composition polynomial $q$ provided by the prover. Recall that if the prover didn't cheat, $q(0) = \tilde W_{ i + 1}(b^\star)$ and $q(1) = \tilde W_{ i + 1}(c^\star)$. Therefore, the verifier must check that  
$$g_n (s_n) = \widetilde{\text{add_i}} (r_i, b^\star, c^\star) \cdot (q(0) + q(1)) + \widetilde{\text{mul_i}} (r_i, b^\star, c^\star) \cdot (q(0) \cdot q(1))$$
                 
                 let last_poly = layer_proof.sumcheck_proof.round_polynomials.last().unwrap();
                 let last_challenge = sumcheck_challenges.last().unwrap();
                 let expected_final_eval = last_poly.evaluate::<F>(last_challenge);
                 
                 let q_at_0 = layer_proof.poly_q.evaluate(&FieldElement::zero());
                 let q_at_1 = layer_proof.poly_q.evaluate(&FieldElement::one());
                 
                 let add_eval = circuit.add_i_ext(&r_i, layer_idx).evaluate(sumcheck_challenges.clone())?;
                 let mul_eval = circuit.mul_i_ext(&r_i, layer_idx).evaluate(sumcheck_challenges.clone())?;
                 
                 let final_eval = add_eval * (&q_at_0 + &q_at_1) + mul_eval * q_at_0 * q_at_1;
                 if final_eval != expected_final_eval {
                     return Ok(false);
                 }
                 

           * **Sample a new challenge and update the evaluation point:**  
The verifier samples a new field element $r^\star$ from the transcript, then uses the line function to compute the next evaluation point $r_{ i + 1} = \ell (r^\star)$ for the following layer. The claimed sum is updated by evaluating the composition polynomial $q$ at the new challenge: $q(r^\star)$.
                 
                 let r_new = transcript.sample_field_element();
                 let num_vars_next = circuit.num_vars_at(layer_idx + 1).ok_or(VerifierError::CircuitError)?;
                 let (b, c) = sumcheck_challenges.split_at(num_vars_next);
                 r_i = crate::line(b, c, &r_new);
                 claimed_sum = layer_proof.poly_q.evaluate(&r_new);
                 

        4. **Final Input Check:**  
After all layers have been processed, the verifier checks that the final claimed sum matches the evaluation of the multilinear extension of the input values at the final evaluation point $r_i$. In the previous post example, that would be $$q(r^\star) == \tilde W_2 (r_2).$$ This ensures that the entire computation, from outputs down to the inputs, is consistent.
               
               let input_poly_ext = DenseMultilinearPolynomial::new(proof.input_values.clone());
               if claimed_sum
                   != input_poly_ext
                       .evaluate(r_i)
                       .map_err(|_| VerifierError::MultilinearPolynomialEvaluationError)?
               {
                   return Ok(false);
               }
               

If all checks pass, the verifier accepts the proof as valid. Otherwise, the proof is rejected at the first failed check. This process allows the verifier to efficiently confirm the correctness of the computation without re-executing the entire circuit.

## The Sumcheck Protocol

The Sumcheck protocol is a central component of the GKR protocol. Its role is to allow the prover to convince the verifier that a sum over a product of multilinear polynomials is correct, without requiring the verifier to compute the sum directly. This is achieved by reducing the original sum to a sequence of univariate polynomial checks, one for each variable.

### Quick Recap: What is the sum being checked?

At each layer $i$ of the GKR protocol, the prover and verifier need to check a sum of the form:

$$  
S = \sum_{x_1, \ldots, x_n \in {0,1}} \tilde f_{ r_i }(x_1, \ldots, x_n)  
$$

where $\tilde f_{ r_i } (x_1, \ldots, x_n)$ is a multilinear polynomial that encodes the wiring and values of the circuit at that layer, and $n$ is the number of variables for that layer (which depends on the number of bits needed to index the gates of the next layer).

The sumcheck protocol allows the prover to convince the verifier that the claimed value $S$ is correct, by sending a sequence of univariate polynomials $g_1, g_2, \ldots, g_n$ such that, in round $j$:

$$  
g_j(z) = \sum_{x_{j + 1}, \ldots, x_n} f_{r} (s_1, \ldots, s_{j - 1}, z, x_{j + 1}, \ldots, x_n)  
$$

where $s_1, \ldots, s_{j - 1}$ are the challenges sampled in previous rounds, $z$ is the variable for the current round, and the remaining variables are summed over. The number of rounds (and thus the number of $g_j$ polynomials) is always equal to the number of variables of $\tilde f_{ r_i }$ for the layer being checked.

At each round, the verifier checks the key sumcheck property:

$$deg(g_j) \leq 2$$

$$  
g_j(0) + g_j(1) = \text{previous sum}  
$$

and then samples a new challenge $s_j$ for the next round. After all rounds, the verifier is left with a claim about $f_{r} (s_1, \ldots, s_n)$, which is checked against the next layer.

### Splitting the GKR Polynomial for Sumcheck

The GKR polynomial $\tilde f_{ r_i } (b, c)$, which encodes the relationship between two adjacent layers, is given by:

$$  
\tilde f_{r_i}(b, c) = \widetilde{\text{add_i}} (r_i, b, c) \cdot \left( W_{ i + 1} (b) + W_{ i + 1} (c) \right) + \widetilde{\text{mul_i}} (r_i, b, c) \cdot \left( W_{ i + 1 }(b) \cdot W_{ i + 1}(c) \right)  
$$

To apply the sumcheck protocol, this polynomial is split into two terms, each being a product of two multilinear polynomials:

        * The first term:  
$$  
\widetilde{\text{add_i}} (r_i, b, c) \cdot \left( W_{ i + 1}(b) + W_{ i + 1}(c) \right)  
$$
        * The second term:  
$$  
\widetilde{\text{mul_i}} (r_i, b, c) \cdot \left( W_{ i + 1 }(b) \cdot W_{ i + 1}(c) \right)  
$$

This splitting is necessary because the sumcheck implementation expects a product of multilinear polynomials. In the code, this is handled by the function `Prover::build_gkr_polynomial` (see the Prover section), which returns a vector with two entries, each being a vector of two multilinear polynomials (the factors of each term). These are then passed to the sumcheck prover, which processes both terms together in each round.

### Implementation in the Codebase

The logic for the sumcheck protocol is implemented in [`sumcheck.rs`](./src/sumcheck.rs). This file contains the functions used by both the prover and the verifier to perform the sumcheck rounds for each circuit layer.

#### Prover: Step-by-step sumcheck proof generation:

At each layer, the prover constructs the sumcheck proof as follows:

**1\. Build the GKR polynomial terms**

For the current layer, construct the GKR polynomial and split it into two terms as required by the protocol:
    
    let factors_term_1 = terms[0].clone();
    let factors_term_2 = terms[1].clone();
    
    let mut prover_term_1 = Prover::new(factors_term_1)?;
    let mut prover_term_2 = Prover::new(factors_term_2)?;
    

**2\. Compute the initial claimed sum**

The prover computes the initial sum for both terms and adds them:
    
    let claimed_sum_term_1 = prover_term_1.compute_initial_sum()?;
    let claimed_sum_term_2 = prover_term_2.compute_initial_sum()?;
    let claimed_sum = claimed_sum_term_1 + claimed_sum_term_2;
    

**3\. Apply the sumcheck protocol round by round**

For each round, the prover computes the univariate polynomial for each term, sums them, and appends the result to the transcript. Each resulting polynomial $g_j$ is collected in a vector:
    
    let mut proof_polys = Vec::with_capacity(num_vars);
    for j in 0..num_vars {
        let g_j_term_1 = prover_term_1.round(current_challenge.as_ref())?;
        let g_j_term_2 = prover_term_2.round(current_challenge.as_ref())?;
        let g_j = g_j_term_1 + g_j_term_2;
        // ...append g_j to transcript...
        proof_polys.push(g_j);
        // ...sample challenge, update current_challenge...
    }
    

**4\. Collect the proof data**

After all rounds, the vector of polynomials and the challenges are used to construct the sumcheck proof object:
    
    let sumcheck_proof = GKRSumcheckProof {
        round_polynomials: proof_polys,
        challenges,
    };
    

**5\. Send to verifier**

Include the sumcheck proof as part of the overall GKR proof, which the verifier will check in the next phase.

#### Verifier: Step-by-step sumcheck verification:

At each layer, the verifier processes the sumcheck proof as follows:

**1\. For each round, check the degree and sum property**

For each univariate polynomial $g_j$ received, check that the degree is at most two and that the sum of its evaluations at 0 and 1 matches the expected value (either the initial claim or the previous polynomial evaluated at the previous challenge):
    
    // Check that the degree of g_j does not exceed the theoretical bound
    if g_j.degree() > 2 {
        return Err(crate::verifier::VerifierError::InvalidDegree);
    }
    let g_j_0 = g_j.evaluate::<F>(&FieldElement::zero());
    let g_j_1 = g_j.evaluate::<F>(&FieldElement::one());
    let sum_evals = &g_j_0 + &g_j_1;
    
    let expected_sum = if j == 0 {
        claimed_sum.clone()
    } else {
        let prev_poly = &proof_polys[j - 1];
        let prev_challenge = &challenges[j - 1];
        prev_poly.evaluate::<F>(prev_challenge)
    };
    
    if sum_evals != expected_sum {
        return Ok((false, challenges));
    }
    

**2\. Update the transcript and sample the next challenge**

After each round, the verifier appends the polynomial to the transcript and samples the next challenge:
    
    let r_j = transcript.sample_field_element();
    challenges.push(r_j.clone());
    

**3\. Accept or reject**

If all rounds pass the checks, accept the sum as correct, without needing to evaluate the full sum directly. If any check fails, reject the proof immediately.

Each round of the sumcheck protocol reduces the number of variables by one, transforming a multivariate sum into a sequence of univariate checks. The prover performs the main computations, while the verifier only needs to check a small number of polynomial evaluations and field operations. The use of the Fiat-Shamir transform ensures that the protocol is non-interactive, with all challenges derived from the transcript.

## Fiat-Shamir Transform: Making it Non-Interactive

The original GKR protocol is interactive, meaning it requires a series of back-and-forth communications between the prover and the verifier. While interactive proofs are theoretically sound, they can be impractical for many real-world applications due to latency and communication overhead. The Fiat-Shamir transform is a cryptographic technique used to convert interactive proof systems into non-interactive ones.

### How Fiat-Shamir is Applied

In our implementation, the Fiat-Shamir transform replaces the verifier's random challenges with outputs from a cryptographic hash function, specifically a `DefaultTranscript` from the `lambdaworks_crypto` crate. This allows the prover to generate all necessary challenges deterministically, without any interaction with the verifier.

        1. **Transcript Initialization** : A transcript is created and seeded with public information relevant to the proof. This includes:

           * The circuit structure (serialized via `circuit_to_bytes(circuit)`).
           * The public input values.
           * The claimed output values.

By including this information, any party can reconstruct the same transcript and verify the challenges generated.

        2. **Challenge Generation** : At each step where the interactive protocol would require a random challenge from the verifier, the implementation instead:

           * Appends the current state of the proof (e.g., the coefficients of a polynomial sent by the prover) to the transcript.
           * Samples a random field element from the transcript using `transcript.sample_field_element()`. This element is cryptographically derived from all previous information in the transcript, making it unpredictable to the prover before the relevant information is committed.

### Key Challenge Points

The Fiat-Shamir transform is applied at several critical junctures in the GKR protocol:

        * **Initial Random Values** ($r_0$): For the output layer, initial random challenges are sampled to begin the layer-by-layer reduction.
        * **Sumcheck Challenges** ($s_j$): In each round of the Sumcheck protocol, challenges are generated from the transcript. These challenges are essential for the verifier to check the consistency of the prover's univariate polynomials.
        * **Line Function Parameter** ($r^\star$ or `r_new`): After each layer's sumcheck, a new challenge `r_new` is sampled. This challenge is used in the `line` function to derive the evaluation point for the next layer's claimed sum, effectively linking the layers in the proof.

By leveraging the Fiat-Shamir transform, our GKR implementation achieves non-interactivity, making it more practical for real-world applications where continuous communication between prover and verifier might be infeasible or introduce undesirable latency. This transformation is a cornerstone of many modern zero-knowledge proof systems, enabling efficient and verifiable computation in a wide range of scenarios.

## Summary

In this post, we showed how we implemented the GKR protocol. Starting from a circuit description, the prover evaluates each layer, constructs the corresponding polynomial, and runs a tailored Sumcheck protocol whose challenges are generated through a Fiat–Shamir transcript. The verifier, working with the same transcript, replays the Sumcheck rounds, checks the final claim with the composition polynomial $q$, and ultimately confirms that the computation is correct all the way down to the public inputs. In this way, a potentially expensive re-execution of the circuit is reduced to a series of lightweight algebraic checks.  
Although this implementation is intended for educational use, it captures every essential step of the protocol.
