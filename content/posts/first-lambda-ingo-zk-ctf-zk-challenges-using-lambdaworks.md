+++
title = "First Lambda-Ingo ZK CTF: ZK challenges using LambdaWorks"
date = 2023-07-30
slug = "first-lambda-ingo-zk-ctf-zk-challenges-using-lambdaworks"

[extra]
feature_image = "/images/2025/12/The-Sculpture-Gallery-of-the-Felix-Meritis-Society.jpg"
authors = ["LambdaClass"]
+++

# Introduction

From July 14th to 16th, we organized, together with [Ingonyama](https://www.ingonyama.com/), the [first Lambda-Ingo ZK capture the flag](https://ctf.ingonyama.com/) (CTF), where more than 60 teams and 160 people participated. The CTF involved several challenges related to zero-knowledge proofs (using [Lambdaworks](https://github.com/lambdaclass/lambdaworks)) and fully-homomorphic encryption. We are thrilled with the whole experience, especially our second collaboration with Ingonyama and all the sponsors of the Lambda ZK week in Paris.

The challenges were meant as example exercises to learn how to use Lambdaworks (especially the [Starknet Stack](https://github.com/lambdaclass/starknet_stack_prover_lambdaworks) and [Plonk](https://github.com/lambdaclass/lambdaworks_plonk_prover) provers) and get an intuition of different vulnerabilities and bugs that can arise in those systems. If you want to know more about the development of the library or wish to contribute, join our [telegram group](https://t.me/+98Whlzql7Hs0MDZh).

This post will present the challenges we submitted for the CTF and explain how they can be solved.

# Plonk challenges

There were two challenges related to Plonk and possible vulnerabilities: [frozen heart](https://blog.trailofbits.com/2022/04/18/the-frozen-heart-vulnerability-in-plonk/) and lack of blinding polynomials.

## Obi-Wan's search

### Challenge

In his quest to stop the Sith's menace, Obi-Wan Kenobi finds a (Sith) holocron, giving a zero-knowledge proof of the existence of the Sith's galactic foundry (using galactic Plonk).

This place is rumored to contain several artifacts that could aid the Galactic Republic in its war efforts. The position, given by $(x , h , y)$, satisfies the equation $y = x \times h + b$.

After some study, Obi-Wan finds the values of $y$ and $b$ (which belong to Sith lore). The only problem is that, even with this knowledge, it may take him quite long to find the mysterious planet, and the situation in the Republic is desperate.

He also finds, together with the Holocron, a second item containing the SRS used to generate the proof, the prover, and a description of the circuit used.

Will he be able to find the position of the foundry before it is too late?

All the additional information is in this [repo](https://github.com/lambdaclass/obi_wan_search).

FLAG FORMAT: XXXX........XXXX The flag consists of the x and h concatenated and written in hex (for example, x=0x123, h=0x789, the FLAG=123789)

### Solution

The challenge is finding the witness variables $x$ and $h$, given the values $y$ and $b$. Usually, we could not get access to these values, given the zero-knowledge property the Plonk system has. However, in this case, there is one fault in the prover: there are no blinding polynomials, and we can exploit this vulnerability to recover the unknowns.

The first round of PLONK reads as follows:
    
    Compute polynomials a',b',c' as the interpolation polynomials of the columns of T at the domain H.
    Sample random b_1, b_2, b_3, b_4, b_5, b_6
    Let
    
    a := (b_1X + b_2)Z_H + a'
    
    b := (b_3X + b_4)Z_H + b'
    
    c := (b_5X + b_6)Z_H + c'
    
    Compute [a]_1, [b]_1, [c]_1 and add them to the transcript.
    

The multiples of $Z_H$ added to $ a', b', c'$ are called the blindings. In subsequent rounds, the polynomials $a, b, c$ are opened at the verifier's chosen point.

The polynomials $Z_H$ are the vanishing polynomials over the interpolation domain; they are equal to zero at each point in the set $H$. Therefore, adding that polynomial (or any combination) will not change the value of the $a^\prime$, $b^\prime$, and $c^\prime$ polynomials, which must satisfy the circuit equations. However, at any other point, they will add some randomness and help conceal the values.

By checking the code of the challenge, the participants can find the following in `circuit.rs.`
    
    /// Witness generator for the circuit `ASSERT y == x * h + b`
    pub fn circuit_witness(
        b: &FrElement,
        y: &FrElement,
        h: &FrElement,
        x: &FrElement,
    ) -> Witness<FrField> {
        let z = x * h;
        let w = &z + b;
        let empty = b.clone();
        Witness {
            a: vec![
                b.clone(),
                y.clone(),
                x.clone(),
                b.clone(),
                w.clone(),
                empty.clone(),
                empty.clone(),
                empty.clone(),
            ],
            ...
    

This code reveals that the way prover constructs the $V$ matrix is

A | B | C  
---|---|---  
b | - | -  
y | - | -  
x | h | z  
b | z | w  
w | y | -  
- | - | -  
- | - | -  
- | - | -  
  
Where `-` are empty values. The PLONK implementation of `lambdaworks-plonk` requires the empty values to be filled in with the first public input. So, in this case, the values `-` will be replaced by $b$. This can be seen directly from the code of the challenge.

Therefore, the polynomial $a'$, being the interpolation of the column `A` is

$$a' = b L_1 + y L_2 + x L_3 + b L_4 + w L_5 + b L_6 + b L_7 + b L_8,$$

where $L_i$ is the $i$-th polynomial of the Lagrange basis. Also, the value $w$ is equal to $y$. That can be seen from the code and the fact that the last row of the $V$ matrix corresponds to the assertion that the actual output of the circuit is equal to the claimed output $y$.

During the proof, the verifier sends a challenge $\zeta$ and the prover opens, among other things, the polynomial $a$ at $\zeta$. Since the implementation of the challenge omits blindings, $a(\zeta) = a' (\zeta)$, and we get

$$a(\zeta) = b L_1(\zeta) + y L_2(\zeta) + x L_3(\zeta) + b L_4(\zeta) + y L_5(\zeta) + b L_6(\zeta) + b L_7(\zeta) + b L_8(\zeta).$$

All the terms in this expression are known to the participants except for $x$, which can be cleared from the equation. To do so, the participants need to know how to recover the challenges to get $\zeta$ and how to compute the Lagrange polynomials evaluated at it.

The second private input $h$ can be computed as $h = (y - b) / x$. The following piece of code recovers the challenge $\zeta$, computes the Lagrange polynomials at $\zeta$ and recovers $x$ and $h$:
    
    fn compute_private_input<F, CS>(
        proof: &Proof<F, CS>,
        vk: &VerificationKey<CS::Commitment>,
        public_input: &[FieldElement<F>],
        common_preprocessed_input: &CommonPreprocessedInput<F>,
    ) -> (FieldElement<F>, FieldElement<F>)
    where
        F: IsField,
        CS: IsCommitmentScheme<F>,
        CS::Commitment: Serializable,
        FieldElement<F>: ByteConversion,
    {
        // Replay interactions to recover challenges. We are only interested in \zeta
        let mut transcript = new_strong_fiat_shamir_transcript::<F, CS>(vk, public_input);
        transcript.append(&proof.a_1.serialize());
        transcript.append(&proof.b_1.serialize());
        transcript.append(&proof.c_1.serialize());
        let _beta = FieldElement::from_bytes_be(&transcript.challenge()).unwrap();
        let _gamma = FieldElement::from_bytes_be(&transcript.challenge()).unwrap();
    
        transcript.append(&proof.z_1.serialize());
        let _alpha = FieldElement::from_bytes_be(&transcript.challenge()).unwrap();
    
        transcript.append(&proof.t_lo_1.serialize());
        transcript.append(&proof.t_mid_1.serialize());
        transcript.append(&proof.t_hi_1.serialize());
        let zeta = FieldElement::from_bytes_be(&transcript.challenge()).unwrap();
    
        // Compute `x` and `h`
        let [b, y] = [&public_input[0], &public_input[1]];
        let n = common_preprocessed_input.n as u64;
        let omega = &common_preprocessed_input.omega;
        let domain = &common_preprocessed_input.domain;
        // Compute L_1(\zeta). This polynomial is equal to zero at
        //each point in the domain, except for the first one
        //where it is equal to unity
        let l1_zeta =
            (zeta.pow(n) - FieldElement::one()) / (&zeta - FieldElement::one()) / FieldElement::from(n);
    
        let mut li_zeta = l1_zeta;
        let mut lagrange_basis_zeta = Vec::new();
        lagrange_basis_zeta.push(li_zeta.clone());
        // Compute all other Lagrange polynomials using
        // the relationship among them
        for i in 1..domain.len() {
            li_zeta = omega * &li_zeta * ((&zeta - &domain[i - 1]) / (&zeta - &domain[i]));
            lagrange_basis_zeta.push(li_zeta.clone());
        }
        // Recover x by relating a at \zeta and the public inputs
    
        let x = (&proof.a_zeta
            - b * &lagrange_basis_zeta[3]
            - y * &lagrange_basis_zeta[4]
            - b * &lagrange_basis_zeta[0]
            - y * &lagrange_basis_zeta[1]
            - b * &lagrange_basis_zeta[5]
            - b * &lagrange_basis_zeta[6]
            - b * &lagrange_basis_zeta[7])
            / &lagrange_basis_zeta[2];
        // Recover h given that x is known    
        let h = (y - b) / &x;
        (x, h)
    }
    

The solution for the coordinates is:

        1. `x: "2194826651b32ca1055614fc6e2f2de86eab941d2c55bd467268e9"`,
        2. `h: "432904cca36659420aac29f8dc5e5bd0dd57283a58ab7a8ce4d1ca"`.

The flag is the concatenation of the two: `FLAG: 2194826651b32ca1055614fc6e2f2de86eab941d2c55bd467268e9432904cca36659420aac29f8dc5e5bd0dd57283a58ab7a8ce4d1ca`

## Loki's trapdoor

### Challenge

After successfully breaking into Loki's vault and getting access to some of his finest treasures and weapons, you spot a small trapdoor under a carpet.

The trapdoor is locked and contains a device with a PLONK prover. It says: Prove that the point $( 1 , y)$ belongs to the elliptic curve $y^2 = x^3 + 4$.

You see that, in order to prove this, you need that $y^2 − x^3 − 4$ is equal to zero, which corresponds to the circuit for the prover provided by Loki.

Can you open the trapdoor?

nc 44.203.113.160 4000

Additional information is in this [repo](https://github.com/ingonyama-zk/ZKCTF-lokis-trapdoor).

FLAG FORMAT: ZKCTF{XXX...XXX}

### Solution

This challenge exploits the frozen heart vulnerability, which arises when the Fiat-Shamir transformation is not implemented correctly. The main problem is that $(1,y)$ is not a point belonging to the BLS12-381 elliptic curve. If so, $y^2 = 1^3 + 4 = 5$ but $5$ is not a quadratic residue modulo the BLS12-381 prime. Therefore, the way to solve the challenge must be by creating a false proof.

The circuit is:
    
    PUBLIC INPUT: x
    PUBLIC INPUT: y
    
    ASSERT 0 == y^2 - x^3 - 4
    

And it instantiated over the `BLS12 381` scalar field.

The vulnerability stems from a bug in the implementation of strong Fiat-Shamir. A correct implementation should add, among other things, all the public inputs to the transcript at initialization. If a public input is not added to the transcript and is in control of the attacker, they can forge a fake proof. Fixing `x=1` leaves `y` under the user's control. We can see that the Fiat-Shamir transcript does not incorporate the public input, as shown [here](https://github.com/ingonyama-zk/ZKCTF-lokis-trapdoor/blob/69eba0d41d56a7831b4532d5adc2c21720764885/lambdaworks_plonk_prover/src/setup.rs#L70C1-L73C23)
    
    pub fn new_strong_fiat_shamir_transcript<F, CS>(
        vk: &VerificationKey<CS::Commitment>,
        _public_input: &[FieldElement<F>],
    ) -> DefaultTranscript
    

The attack is described in Section V of [Weak Fiat-Shamir Attacks on Modern Proof Systems](https://eprint.iacr.org/2023/691.pdf).

Here is a summary of the attack:

![](/images/external/B10en9A93.png)

Instead of taking random polynomials (steps (1) to (7)), the current solution takes a valid proof for the pair `x=0`, `y=2` and uses it to forge a `y` for `x=1` that's compatible with the original proof.
    
    #[allow(unused)]
    fn forge_y_for_valid_proof<F: IsField, CS: IsCommitmentScheme<F>>(
        proof: &Proof<F, CS>,
        vk: &VerificationKey<CS::Commitment>,
        common_preprocessed_input: CommonPreprocessedInput<F>,
    ) -> FieldElement<F>
    where
        CS::Commitment: Serializable,
        FieldElement<F>: ByteConversion,
    {
        // Replay interactions like the verifier
        let mut transcript = new_strong_fiat_shamir_transcript::<F, CS>(vk, &[]);
    
        transcript.append(&proof.a_1.serialize());
        transcript.append(&proof.b_1.serialize());
        transcript.append(&proof.c_1.serialize());
        let beta = FieldElement::from_bytes_be(&transcript.challenge()).unwrap();
        let gamma = FieldElement::from_bytes_be(&transcript.challenge()).unwrap();
    
        transcript.append(&proof.z_1.serialize());
        let alpha = FieldElement::from_bytes_be(&transcript.challenge()).unwrap();
    
        transcript.append(&proof.t_lo_1.serialize());
        transcript.append(&proof.t_mid_1.serialize());
        transcript.append(&proof.t_hi_1.serialize());
        let zeta = &FieldElement::from_bytes_be(&transcript.challenge()).unwrap();
    
        // Forge public input
        let zh_zeta = zeta.pow(common_preprocessed_input.n) - FieldElement::one();
    
        let omega = &common_preprocessed_input.omega;
        let n = common_preprocessed_input.n as u64;
        let one = &FieldElement::one();
    
        let l1_zeta = ((zeta.pow(n) - one) / (zeta - one)) / FieldElement::from(n);
    
        let l2_zeta = omega * &l1_zeta * (zeta - one) / (zeta - omega);
    
        let mut p_constant_zeta = &alpha
            * &proof.z_zeta_omega
            * (&proof.c_zeta + &gamma)
            * (&proof.a_zeta + &beta * &proof.s1_zeta + &gamma)
            * (&proof.b_zeta + &beta * &proof.s2_zeta + &gamma);
        p_constant_zeta = p_constant_zeta - &l1_zeta * &alpha * &alpha;
    
        let p_zeta = p_constant_zeta + &proof.p_non_constant_zeta;
        -(p_zeta + l1_zeta * one - (&zh_zeta * &proof.t_zeta)) / l2_zeta
    }
    
    

# STARKs challenge

## Challenge

Good morning hacker.

If you are reading this, the date should be July 7th, 2023, and you should be checking the Lambda-Ingoyama CTF challenges site.

Hopefully, we managed to hijack the site, and you are reading this now. We are not allowed to say much, but you must know it's of utmost importance that you win this challenge.

So, we have decided to help. Don't worry; it should be easy. We have found the right exploit to solve and are forwarding the solution to you.

If something goes wrong, we leave some additional data we have collected. We don't know if it's helpful, but we hope it can help.

It's now up to you to take the flag. We wish you good luck.

<https://github.com/ingonyama-zk/ZKCTF-ch3-client>

FLAG FORMAT: ZKCTF{XXX...XXX}

## Solution

The key point here is that the STARK prover does only one query, which makes the soundness error significant. This vulnerability was present in an early implementation of Lambdaworks (see this [PR](https://github.com/lambdaclass/starknet_stack_prover_lambdaworks/pull/66)) and was discovered by [Michael Carilli](https://github.com/mcarilli) (to whom we are really grateful).

The first step is to send the data to an endpoint of the server, which should reply with something like "Expired proof." After that, the next step is to inspect the proof. Most of the data will not be relevant. Counting the number of queries, we realize there is only 1. Now it remains to see how to exploit it.

Some additional data needs to be used, such as the offset, the constraints, and the blowup factor. Offsets and constraints are hinted at in the data. The blowup factor can be guessed or hinted at.

We can now move to break the STARK protocol, taking advantage of the FRI soundness error, which is quite large for one query. We must first pass the consistency check at the out-of-domain point $z$ between the composition polynomial and the trace polynomials. The verifier performs this check in [step 2](https://github.com/lambdaclass/starknet_stack_prover_lambdaworks/blob/23eb9df082ec4de4f1d44c6760be4b7a13ea24b1/src/starks/verifier.rs#L208). We can pass this test automatically if we calculate the value of the polynomial directly from the trace polynomials:
    
    pub fn composition_poly_ood_evaluation_exact_from_trace<F: IsFFTField, A: AIR<Field = F>>(
        air: &A,
        trace_ood_frame_evaluations: &Frame<F>,
        domain: &Domain<F>,
        z: &FieldElement<F>,
        rap_challenges: &A::RAPChallenges,
        boundary_coeffs: &[(FieldElement<F>, FieldElement<F>)],
        transition_coeffs: &[(FieldElement<F>, FieldElement<F>)],
    ) -> FieldElement<F> {
        let _public_input = air.pub_inputs();
        let boundary_constraints = air.boundary_constraints(rap_challenges);
    
        let n_trace_cols = air.context().trace_columns;
    
        let boundary_constraint_domains =
            boundary_constraints.generate_roots_of_unity(&domain.trace_primitive_root, &[n_trace_cols]);
    
        let values = boundary_constraints.values(&[n_trace_cols]);
    
        // Following naming conventions from https://www.notamonadtutorial.com/diving-deep-fri/
        let mut boundary_c_i_evaluations = Vec::with_capacity(n_trace_cols);
        let mut boundary_quotient_degrees = Vec::with_capacity(n_trace_cols);
    
        for trace_idx in 0..n_trace_cols {
            let trace_evaluation = &trace_ood_frame_evaluations.get_row(0)[trace_idx];
            let boundary_constraints_domain = &boundary_constraint_domains[trace_idx];
            let boundary_interpolating_polynomial =
                &Polynomial::interpolate(boundary_constraints_domain, &values[trace_idx])
                    .expect("xs and ys have equal length and xs are unique");
    
            let boundary_zerofier =
                boundary_constraints.compute_zerofier(&domain.trace_primitive_root, trace_idx);
    
            let boundary_quotient_ood_evaluation = (trace_evaluation
                - boundary_interpolating_polynomial.evaluate(z))
                / boundary_zerofier.evaluate(z);
    
            let boundary_quotient_degree = air.trace_length() - boundary_zerofier.degree() - 1;
    
            boundary_c_i_evaluations.push(boundary_quotient_ood_evaluation);
            boundary_quotient_degrees.push(boundary_quotient_degree);
        }
    
        let trace_length = air.trace_length();
    
        let boundary_term_degree_adjustment = air.composition_poly_degree_bound() - trace_length;
    
        let boundary_quotient_ood_evaluations: Vec<FieldElement<F>> = boundary_c_i_evaluations
            .iter()
            .zip(boundary_coeffs)
            .map(|(poly_eval, (alpha, beta))| {
                poly_eval * (alpha * &z.pow(boundary_term_degree_adjustment) + beta)
            })
            .collect();
    
        let boundary_quotient_ood_evaluation = boundary_quotient_ood_evaluations
            .iter()
            .fold(FieldElement::<F>::zero(), |acc, x| acc + x);
    
        let transition_ood_frame_evaluations =
            air.compute_transition(trace_ood_frame_evaluations, rap_challenges);
    
        let transition_exemptions = air.transition_exemptions();
    
        let x_n = Polynomial::new_monomial(FieldElement::<F>::one(), trace_length);
        let x_n_1 = x_n - FieldElement::<F>::one();
    
        let divisors = transition_exemptions
            .into_iter()
            .map(|exemption| x_n_1.clone() / exemption)
            .collect::<Vec<Polynomial<FieldElement<F>>>>();
    
        let mut denominators = Vec::with_capacity(divisors.len());
        for divisor in divisors.iter() {
            denominators.push(divisor.evaluate(z));
        }
        FieldElement::inplace_batch_inverse(&mut denominators);
    
        let mut degree_adjustments = Vec::with_capacity(divisors.len());
        for transition_degree in air.context().transition_degrees().iter() {
            let degree_adjustment =
                air.composition_poly_degree_bound() - (air.trace_length() * (transition_degree - 1));
            degree_adjustments.push(z.pow(degree_adjustment));
        }
        let transition_c_i_evaluations_sum =
            ConstraintEvaluator::<F, A>::compute_constraint_composition_poly_evaluations_sum(
                &transition_ood_frame_evaluations,
                &denominators,
                &degree_adjustments,
                transition_coeffs,
            );
    
        &boundary_quotient_ood_evaluation + transition_c_i_evaluations_sum
    }
    

The prover splits the composition polynomial between even and odd terms, $H_1 (z^2 )$ and $H_2 (z^2 )$. The verifier has to compute $H(z)$ from the trace polynomials and then check that  
$H(z) = H_1 (z^2 ) + z H_2 (z^2 )$  
We can enforce this check by making sure that the verifier gets $H_1 (z^2 ) = H(z)$ and $H_2 (z^2 ) = 0$. Of course, this will generate some issues at other parts of the verifier, such as the DEEP composition polynomial. The DEEP composition polynomial allows us to check that all polynomials have been appropriately evaluated at $z$,  
$P_0 (x) = \sum_j \gamma_j \frac{t_j (x) - t_j (z)}{x - z} + \sum_j \gamma^\prime_j \frac{t_j (x) - t_j (g z)}{x - gz} + \gamma \frac{H_1 (x) - H_1 (z^2 )}{x - z^2} + \gamma^\prime \frac{H_2 (x) - H_2 (z^2 )}{x - z^2}$

Of course, if we send false evaluations of the polynomials $H_1(x^2 )$ and $H_2 (x^2 )$, the last terms will not be low-degree polynomials and should not satisfy FRI testing. However, we can evaluate exactly the values of $(H_k (\omega_j) - H_k(z^2 ))/( \omega_j - z^2 )$ and create a polynomial which passes through as many evaluations as the low-degree test allows us (which is the trace length) by interpolation. The following function computes the DEEP composition polynomial
    
    fn compute_deep_composition_poly_evil<A: AIR, F: IsFFTField>(
        air: &A,
        domain: &Domain<F>,
        trace_polys: &[Polynomial<FieldElement<F>>],
        round_2_result: &Round2<F>,
        round_3_result: &Round3<F>,
        z: &FieldElement<F>,
        primitive_root: &FieldElement<F>,
        composition_poly_gammas: &[FieldElement<F>; 2],
        trace_terms_gammas: &[FieldElement<F>],
    ) -> Polynomial<FieldElement<F>>
    where
        lambdaworks_math::field::element::FieldElement<F>: lambdaworks_math::traits::ByteConversion,
    {
        // Compute composition polynomial terms of the deep composition polynomial.
        let h_1 = &round_2_result.composition_poly_even;
        let h_1_z2 = &round_3_result.composition_poly_even_ood_evaluation;
        let h_2 = &round_2_result.composition_poly_odd;
        let h_2_z2 = &round_3_result.composition_poly_odd_ood_evaluation;
        let gamma = &composition_poly_gammas[0];
        let gamma_p = &composition_poly_gammas[1];
        let z_squared = z.square();
    
        // 𝛾 ( H₁ − H₁(z²) ) / ( X − z² )
        let h_1_term = {
            let x = Polynomial::new_monomial(FieldElement::one(), 1);
            let h_1_num = gamma * (h_1 - h_1_z2);
            let h_1_denom = &x - &z_squared;
            interp_from_num_denom(&h_1_num, &h_1_denom, domain)
        };
    
        // 𝛾' ( H₂ − H₂(z²) ) / ( X − z² )
        let h_2_term = {
            let x = Polynomial::new_monomial(FieldElement::one(), 1);
            let h_2_num = gamma_p * (h_2 - h_2_z2);
            let h_2_denom = &x - &z_squared;
            interp_from_num_denom(&h_2_num, &h_2_denom, domain)
        };
    
        // Get trace evaluations needed for the trace terms of the deep composition polynomial
        let transition_offsets = &air.context().transition_offsets;
        let trace_frame_evaluations = &round_3_result.trace_ood_evaluations;
    
        // Compute the sum of all the deep composition polynomial trace terms.
        // There is one term for every trace polynomial and every row in the frame.
        // ∑ ⱼₖ [ 𝛾ₖ ( tⱼ − tⱼ(z) ) / ( X − zgᵏ )]
    
        let mut trace_terms = Polynomial::zero();
        for (i, t_j) in trace_polys.iter().enumerate() {
            let i_times_trace_frame_evaluation = i * trace_frame_evaluations.len();
            let iter_trace_gammas = trace_terms_gammas
                .iter()
                .skip(i_times_trace_frame_evaluation);
            for ((evaluations, offset), elemen_trace_gamma) in trace_frame_evaluations
                .iter()
                .zip(transition_offsets)
                .zip(iter_trace_gammas)
            {
                
                let t_j_z = evaluations[i].clone();
                
                let z_shifted = z * primitive_root.pow(*offset);
                
                let mut poly = t_j - t_j_z;
                poly.ruffini_division_inplace(&z_shifted);
                trace_terms = trace_terms + poly * elemen_trace_gamma;
            }
        }
    
        h_1_term + h_2_term + trace_terms
    }
    

which uses the following function to interpolate
    
    pub fn interp_from_num_denom<F: IsFFTField>(
        num: &Polynomial<FieldElement<F>>,
        denom: &Polynomial<FieldElement<F>>,
        domain: &Domain<F>,
    ) -> Polynomial<FieldElement<F>> {
        let target_deg = domain.lde_roots_of_unity_coset.len() / domain.blowup_factor;
        let num_evals = evaluate_polynomial_on_lde_domain(
            num,
            domain.blowup_factor,
            domain.interpolation_domain_size,
            &domain.coset_offset,
        )
        .unwrap();
        let denom_evals = evaluate_polynomial_on_lde_domain(
            denom,
            domain.blowup_factor,
            domain.interpolation_domain_size,
            &domain.coset_offset,
        )
        .unwrap();
        let evals: Vec<_> = num_evals
            .iter()
            .zip(denom_evals)
            .map(|(num, denom)| num / denom)
            .collect();
    
        Polynomial::interpolate(
            &domain.lde_roots_of_unity_coset[..target_deg],
            &evals[..target_deg],
        )
        .unwrap()
    }
    

This way, we can choose $n$ points where the fake DEEP composition polynomial will pass all the tests. Since the verifier can choose among $\beta n$ points, the prover gets a $1/\beta$ chance to pass the test.

We can now create a malicious prover that will likely pass the verifier's checks, even if he uses false execution traces. Step_2 is modified to calculate the exact composition polynomial:
    
    fn step_2_evil_eval<F: IsFFTField, A: AIR<Field = F>>(
        air: &A,
        domain: &Domain<F>,
        transition_coeffs: &[(FieldElement<F>, FieldElement<F>)],
        boundary_coeffs: &[(FieldElement<F>, FieldElement<F>)],
        rap_challenges: &A::RAPChallenges,
        z: &FieldElement<F>,
        trace_ood_frame_evaluations: &Frame<F>,
    ) -> FieldElement<F> {
        // BEGIN TRACE <-> Composition poly consistency evaluation check
        // These are H_1(z^2) and H_2(z^2)
    
        let boundary_constraints = air.boundary_constraints(rap_challenges);
    
        //let n_trace_cols = air.context().trace_columns;
        // special cases.
        let trace_length = air.trace_length();
        let composition_poly_degree_bound = air.composition_poly_degree_bound();
        let boundary_term_degree_adjustment = composition_poly_degree_bound - trace_length;
        let number_of_b_constraints = boundary_constraints.constraints.len();
    
        // Following naming conventions from https://www.notamonadtutorial.com/diving-deep-fri/
        let (boundary_c_i_evaluations_num, mut boundary_c_i_evaluations_den): (
            Vec<FieldElement<F>>,
            Vec<FieldElement<F>>,
        ) = (0..number_of_b_constraints)
            .map(|index| {
                let step = boundary_constraints.constraints[index].step;
                let point = &domain.trace_primitive_root.pow(step as u64);
                let trace_idx = boundary_constraints.constraints[index].col;
                let trace_evaluation = &trace_ood_frame_evaluations.get_row(0)[trace_idx];
                let boundary_zerofier_challenges_z_den = z - point;
    
                let boundary_quotient_ood_evaluation_num =
                    trace_evaluation - &boundary_constraints.constraints[index].value;
    
                (
                    boundary_quotient_ood_evaluation_num,
                    boundary_zerofier_challenges_z_den,
                )
            })
            .collect::<Vec<_>>()
            .into_iter()
            .unzip();
    
        FieldElement::inplace_batch_inverse(&mut boundary_c_i_evaluations_den);
    
        let boundary_degree_z = z.pow(boundary_term_degree_adjustment);
        let boundary_quotient_ood_evaluation: FieldElement<F> = boundary_c_i_evaluations_num
            .iter()
            .zip(&boundary_c_i_evaluations_den)
            .zip(boundary_coeffs)
            .map(|((num, den), (alpha, beta))| num * den * (alpha * &boundary_degree_z + beta))
            .fold(FieldElement::<F>::zero(), |acc, x| acc + x);
    
        let transition_ood_frame_evaluations =
            air.compute_transition(trace_ood_frame_evaluations, rap_challenges);
    
        let divisor_x_n = (z.pow(trace_length) - FieldElement::<F>::one()).inv();
    
        let denominators = air
            .transition_exemptions_verifier()
            .iter()
            .map(|poly| poly.evaluate(z) * &divisor_x_n)
            .collect::<Vec<FieldElement<F>>>();
    
        let degree_adjustments = air
            .context()
            .transition_degrees()
            .iter()
            .map(|transition_degree| {
                let degree_adjustment =
                    composition_poly_degree_bound - (trace_length * (transition_degree - 1));
                z.pow(degree_adjustment)
            })
            .collect::<Vec<FieldElement<F>>>();
    
        let transition_c_i_evaluations_sum =
            ConstraintEvaluator::<F, A>::compute_constraint_composition_poly_evaluations_sum(
                &transition_ood_frame_evaluations,
                &denominators,
                &degree_adjustments,
                transition_coeffs,
            );
    
        &boundary_quotient_ood_evaluation + transition_c_i_evaluations_sum
    }
    

Then, step_3 is changed to
    
    fn round_3_evil<F: IsFFTField, A: AIR<Field = F>>(
        air: &A,
        domain: &Domain<F>,
        round_1_result: &Round1<F, A>,
        z: &FieldElement<F>,
        boundary_coeffs: &[(FieldElement<F>, FieldElement<F>)],
        transition_coeffs: &[(FieldElement<F>, FieldElement<F>)],
    ) -> Round3<F>
    where
        FieldElement<F>: ByteConversion,
    {
        let trace_ood_evaluations = Frame::get_trace_evaluations(
            &round_1_result.trace_polys,
            z,
            &air.context().transition_offsets,
            &domain.trace_primitive_root,
        );
    
        let (composition_poly_even_ood_evaluation, composition_poly_odd_ood_evaluation) = {
            let trace_ood_frame_evaluations = Frame::new(
                trace_ood_evaluations.iter().flatten().cloned().collect(),
                round_1_result.trace_polys.len(),
            );
    
            let hz_exact_from_trace = step_2_evil_eval(
                air,
                domain,
                transition_coeffs,
                boundary_coeffs,
                &round_1_result.rap_challenges,
                z,
                &trace_ood_frame_evaluations,
            );
    
            (hz_exact_from_trace, FieldElement::<F>::from(0))
        };
    
        Round3 {
            trace_ood_evaluations,
            composition_poly_even_ood_evaluation,
            composition_poly_odd_ood_evaluation,
        }
    }
    

Finally, round_4 is
    
    fn round_4_evil<F: IsFFTField, A: AIR<Field = F>, T: Transcript>(
        air: &A,
        domain: &Domain<F>,
        round_1_result: &Round1<F, A>,
        round_2_result: &Round2<F>,
        round_3_result: &Round3<F>,
        z: &FieldElement<F>,
        transcript: &mut T,
    ) -> Round4<F>
    where
        FieldElement<F>: ByteConversion,
    {
        let coset_offset_u64 = air.context().proof_options.coset_offset;
        let coset_offset = FieldElement::<F>::from(coset_offset_u64);
    
        // <<<< Receive challenges: 𝛾, 𝛾'
        let composition_poly_coeffients = [
            transcript_to_field(transcript),
            transcript_to_field(transcript),
        ];
        // <<<< Receive challenges: 𝛾ⱼ, 𝛾ⱼ'
        let trace_poly_coeffients = batch_sample_challenges::<F, T>(
            air.context().transition_offsets.len() * air.context().trace_columns,
            transcript,
        );
    
        // Compute p₀ (deep composition polynomial)
        let deep_composition_poly = compute_deep_composition_poly_evil(
            air,
            domain,
            &round_1_result.trace_polys,
            round_2_result,
            round_3_result,
            z,
            &domain.trace_primitive_root,
            &composition_poly_coeffients,
            &trace_poly_coeffients,
        );
    
        let domain_size = domain.lde_roots_of_unity_coset.len();
    
        // FRI commit and query phases
        let (fri_last_value, fri_layers) = fri_commit_phase(
            domain.root_order as usize,
            deep_composition_poly,
            transcript,
            &coset_offset,
            domain_size,
        );
        let (query_list, iotas) = fri_query_phase(air, domain_size, &fri_layers, transcript);
        let fri_layers_merkle_roots: Vec<_> = fri_layers
            .iter()
            .map(|layer| layer.merkle_tree.root)
            .collect();
    
        let deep_poly_openings =
            open_deep_composition_poly(domain, round_1_result, round_2_result, &iotas);
    
        // grinding: generate nonce and append it to the transcript
        let grinding_factor = air.context().proof_options.grinding_factor;
        let transcript_challenge = transcript.challenge();
        let nonce = generate_nonce_with_grinding(&transcript_challenge, grinding_factor)
            .expect("nonce not found");
        transcript.append(&nonce.to_be_bytes());
    
        Round4 {
            fri_last_value,
            fri_layers_merkle_roots,
            deep_poly_openings,
            query_list,
            nonce,
        }
    }
    

This way, we generate a proof that will always pass the out-of-domain point consistency check and will have a high probability of passing the low-degree test.

# Summary

This post covered the challenges we presented at the first Lambda-Ingo ZK CTF and their solutions. The challenges involved some common attacks on Plonk (frozen heart and lack of blinding polynomials) and FRI to generate fake proofs or recover information from the witnesses. We will be adding more exercises and case studies to the [Lambdaworks exercises repo](https://github.com/lambdaclass/lambdaworks_exercises/tree/main) so that anyone can learn how to build a proving system and some common pitfalls and vulnerabilities that may arise in their implementation. We would like to thank Ingonyama again for their fantastic work and all the sponsors at LambdaZK week in Paris. Stay tuned for more challenges on ZK!
