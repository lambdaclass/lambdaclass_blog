+++
title = "Speeding up sumcheck for Ethereum's Lean zkVM: an in-depth walkthrough of our implementation"
date = 2025-11-28
slug = "speeding-up-sumcheck-an-in-depth-walkthrough-of-our-implementation"

[extra]
math = true
feature_image = "/images/2025/12/The-age-of-augustus---Jeon-Leon-Gerome.jpg"
authors = ["LambdaClass"]
+++

## Introduction

In this post, we'll present an in-depth walkthrough of our implementation of the sumcheck optimizations proposed by Bagad, Dao, Domb, and Thaler (BDDT) in their [paper](https://eprint.iacr.org/2025/1117). In previous posts, we've explained the main theoretical ideas (see [part I](/optimizing-sumcheck/) and [part II](/how-factoring-equality-polynomials-optimizes-sumcheck/)). Here, we dive deep into the implementation details, showing exactly how we implemented _Algorithm 6_ from that paper within the [whir-p3](https://github.com/tcoratger/whir-p3) repository.

This work was motivated by the Lean Ethereum team, which uses Whirlaway, a multilinear protocol that relies on Whir as its Polynomial Commitment Scheme (PCS). The team identified that the sumcheck protocol could benefit from existing optimizations ([see issue #280](https://github.com/tcoratger/whir-p3/issues/280)). To address this, we stepped in to implement the BDDT optimizations in their codebase.

**Disclaimer:** The code snippets presented in this post correspond to the implementation merged in this [PR](https://github.com/tcoratger/whir-p3/pull/322). While the whir-p3 repository is under active and constant development, we have chosen to analyze this specific snapshot because it offers the highest didactic clarity. [This version](https://github.com/lambdaclass/whir-p3/tree/eec71d03a5ec81f30acc6d591f42f318941c6df5) — which you can find in our repository fork — maintains a faithful one-to-one mapping with the theoretical concepts of the BDDT paper, making it the ideal reference for understanding the core logic before further engineering optimizations are applied.

## I. The Core Idea: Delaying Expensive Field Arithmetic

The naive sumcheck prover forces expensive extension field arithmetic too early. The goal of the BDDT optimizations is simple: **delay the introduction of extension field operations as long as possible**.

### Extension Field Computation

In systems like Jolt (which motivated the paper) or Whir, the underlying computation (e.g., an execution trace) operates over small base field values—32-bit or 64-bit integers. However, cryptographic security requires the sumcheck protocol to use extension field random challenges. In our implementation, we work with base fields like _Baby Bear_ (31-bit), _Koala Bear_ , or _Goldilocks_ (64-bit), along with their extensions (e.g., `BinomialExtensionField<BabyBear, 4>`).

The performance gap between these operations is dramatic. The BDDT paper introduces a precise cost model:

        * **𝔰𝔰 (small-small)** : Multiplying two base field elements, e.g., `BabyBear * BabyBear`. This is the fastest—just a single base field multiplication.
        * **𝔰𝔩 (small-large)** : Multiplying a base field element by an extension field element, e.g., `BabyBear * BinomialExtensionField<BabyBear, 4>` requires 4 base field multiplications (one per extension coefficient).
        * **𝔩𝔩 (large-large)** : Multiplying two extension field elements, e.g., `BinomialExtensionField<BabyBear, 4> * BinomialExtensionField<BabyBear, 4>` is dramatically slower, requiring 16 base field multiplications plus additional operations—often an order of magnitude slower than 𝔰𝔰.

### The Cost Problem

The naive (or classical) sumcheck prover (_Algorithm 1_ in the paper) suffers from premature extension field propagation:

        * **Round 1** : The prover computes sums of products of base field values—all cheap 𝔰𝔰 operations.
        * **Round 2 onward** : The verifier sends a random challenge $r_1 \in \mathbb{F_{\text{ext}}}$, an extension field element. This forces all subsequent computations to use extension field arithmetic. From this point on, the prover must perform expensive 𝔩𝔩 operations for all remaining rounds.

**The key insight:** Delay this transition as long as possible. It is better to perform more operations, but in the base field. That’s the whole idea.

## II. The Two Optimizations: SVO and Eq-Poly

_Algorithm 6_ synthesizes two complementary optimizations. Understanding each in isolation clarifies how they work together.

### A. Small Value Optimization (SVO)

The Small Value Optimization (_Algorithm 4_) is a computational strategy: **to delay extension field operations**.

A naive approach (_Algorithm 3_) would expand the polynomial into $\mathcal{O}( 2^{ d \cdot \ell_0})$ terms to keep base field and extension field components separated. This is exponentially expensive and infeasible for practical values.

**The SVO insight:** Use **Lagrange Interpolation** instead of expansion. This is the same principle behind Toom-Cook multiplication. By treating the round polynomial as something to be interpolated (from a small number of evaluation points) rather than expanded (into exponentially many monomials), we reduce precomputation cost from $\mathcal{O} (2^{ d \cdot \ell_0})$ to $\mathcal{O}(( d + 1)^{ \ell_0})$.

You can see [part I](/optimizing-sumcheck/) of our series for the intuition behind this optimization.

### B. Eq-Poly Optimization (Algorithm 5)

The second optimization (_Algorithm 5_) addresses the specific case

$$  
g(X) = \mathrm{eq}(w, X)p(X).  
$$

It is based on Gruen's optimization, and the idea is to reduce 𝔩𝔩 multiplications associated with the $\mathrm{eq}$ polynomial.

Instead of summing over all remaining variables at once, the algorithm "splits the sum" into two halves.

See [part II](/how-factoring-equality-polynomials-optimizes-sumcheck/) of our series for the full explanation.

## III. The Protocol Architecture: Two-Phase Strategy

Our implementation is essentially encapsulated within the function [`from_base_evals_svo`](https://github.com/lambdaclass/whir-p3/blob/eec71d03a5ec81f30acc6d591f42f318941c6df5/src/sumcheck/sumcheck_single_svo.rs#L22), which is called by the prover to execute the sumcheck protocol following _Algorithm 6_. It combines both SVO and Eq-Poly optimization. In our implementation, we chose:

        * $\ell_0 = 3$: We just do three SVO rounds since this optimization is efficient only for a few rounds, as we'll explain in detail later on.
        * $d = 1$: We only accept one multilinear polynomial, instead of a product of polynomials as shown in the BDDT paper. This choice is due to the fact that in the use case that interests us (that is, in the context of Whir) we only have one polynomial.

Given the base field evaluations of the multilinear polynomial $p$ on the hypercube (`evals`) and an eq-poly constraint (`constraint`), it applies a certain number of sumcheck rounds (`folding_factor`), returning a new `SumcheckSingle` and the challenges used.

It is important to point out that this implementation is designed for a `folding_factor` greater than 5 and a `constraint` containing only **one equality statement** , since we want to use Whir as a PCS.

So, the goal of this function is to prove an equality constraint

$$  
\sigma = p(w),  
$$

where we can rewrite the evaluation as a sum:

$$  
p(w) = \sum_{x \in \\{0, 1\\}^\ell} \mathrm{eq}(w, x) p(x).  
$$

The core insight of this algorithm: **use different strategies for different phases**. Here's the high-level structure:
    
    /// Run a Sumcheck prover following Algorithm 6.
    pub fn from_base_evals_svo<Challenger>(
        evals: &EvaluationsList<F>,
        prover_state: &mut ProverState<F, EF, Challenger>,
        folding_factor: usize,
        pow_bits: usize,
        constraint: &Constraint<F, EF>,
    ) -> (Self, MultilinearPoint<EF>) {
    
        let mut challenges = Vec::with_capacity(folding_factor);
        // Here we are assuming the equality statement has only one constraint.
        let mut sum = constraint.eq_statement.evaluations[0];
        let w = &constraint.eq_statement.points[0];
    
        // Create the unified equality polynomial evaluator
        let mut eq_poly = SumcheckEqState::<_, NUM_SVO_ROUNDS>::new(w);
    
        // --- PHASE 1: SVO for first 3 rounds ---
        let (r_1, r_2, r_3) = svo_three_rounds(prover_state, evals, w, &mut sum, pow_bits);
        challenges.extend([r_1, r_2, r_3]);
    
        // --- THE SWITCHOVER: Fold polynomial with the 3 challenges ---
        // We fold to obtain p(r1, r2, r3, x).
        let mut folded_evals = fold_evals_with_challenges(evals, &challenges);
    
        // --- PHASE 2: Algorithm 5 for remaining rounds ---
        algorithm_5(prover_state, &mut folded_evals, w, &mut challenges, &mut sum, pow_bits);
    
        let challenge_point = MultilinearPoint::new(challenges);
    
        // Final weight: eq(w, r)
        let weights = EvaluationsList::new(vec![w.eq_poly(&challenge_point)]);
        let sumcheck = Self::new(folded_evals, weights, sum);
    
        (sumcheck, challenge_point)
    }
    

Let's explain each phase in detail.

## IV. Phase 1: The First Three Rounds

The first three sumcheck rounds are implemented by [`svo_three_rounds`](https://github.com/lambdaclass/whir-p3/blob/eec71d03a5ec81f30acc6d591f42f318941c6df5/src/sumcheck/sumcheck_small_value.rs#L220). In each round $i$, the prover needs to:

        * Compute the univariate polynomial evaluations $S_i (0)$ and $S_i (\infty)$ (i.e., the leading coefficient).
        * Add these evaluations to the prover state.
        * Sample a new challenge $r_i$.
        * Fold the polynomial $p$.
        * Update the claimed sum $\sigma$.

The only heavy step is the first one. We want the prover to compute $S_i$ efficiently. That is where SVO comes into play.

### Factoring the Univariate Round Polynomial

Recall that the claimed sum we want to prove is:

$$  
\sigma = p(w) = \sum_{x \in \\{0, 1\\}^\ell} \mathrm{eq}(w, x) p(x).  
$$

Then, for each round $i$, the prover needs to compute the univariate round polynomial $S_i (u)$ where:

$$  
S_i(u) = \sum_{x \in \\{0, 1\\}^{ \ell - i}} \mathrm{eq} \bigl(w_{[1, i -1]} ; r_{[1, i - 1]}, u, x\bigr) \cdot p(r_{[1, i - 1]}, u, x).  
$$

Splitting the eq-poly, we can factorize $S_i$ in the following way, with $\ell$ the easy part and $t$ the hard part:

$$  
\begin{aligned}  
S_i(u) &= \ell_i(u) t_i(u), \newline  
\ell_i(u) &=  
\mathrm{eq}\bigl(w_{[1,i - 1]} ; r_{[1,i - 1]}\bigr)  
\mathrm{eq}(w_i; u), \newline  
t_i(u) &=  
\sum_{x \in \\{0,1 \\}^{\ell - i}}  
\mathrm{eq}\bigl(w_{[i+1,\ell]}; x\bigr)  
p(r_{[1,i - 1]}, u, x).  
\end{aligned}  
$$

where:

        * $\ell_i(u)$ is the **linear part** : it comes from the eq-poly portion for variables $1$ to $i$. This is a linear polynomial in $u$ and is easy to compute.
        * $t_i(u)$ is the **heavy part** : it incorporates the sum over all remaining variables $x$ as well as the polynomial $p$. This is where all the complexity lives.

Note that computing $\ell_i (0)$ and $\ell_i(1)$ is essentially "free", but computing $t_i(0)$ and $t_i(1)$ naively would require summing over exponentially many terms. That's where **accumulators** come in.

### Accumulator Computation (Procedure 9)

The "heavy part" $t_i (u)$ is where SVO (_Algorithm 4_) and Eq-Poly (_Algorithm 5_) combine. We apply the Toom-Cook insight by using Lagrange interpolation on the challenges $r_{[1, i - 1]}$ and the sum-splitting insight on the remaining variables $x$.

This gives us the reformulation of $t_i(u)$ in terms of the precomputed accumulators $A_i(v, u)$:

$$  
t_i(u) =  
\sum_{v \in \\{0, 1\\}^{i - 1}}  
L_v(r_{[1, i - 1]}) \cdot  
\underbrace{  
\left(  
\sum_{x_L} \mathrm{eq}(w_{[i + 1, \ell/2]}; x_L)  
\sum_{x_R} \mathrm{eq}(w_{[\ell/2 + 1, \ell]}; x_R)  
\cdot p(v, u, x_L, x_R)  
\right)  
}_{A_i(v, u)}  
$$

Here, $L_v$ is the Lagrange basis polynomial. This formula is the core of _Algorithm 6_ ’s precomputation. The "how" of computing these $A_i(v,u)$ accumulators is _Procedure 9_.

We can rewrite the inner part of the previous equation in the following way:

$$  
\begin{aligned}  
A_i(v,u) =  
\sum_{y \in {0,1}^{\ell_0 - i}}  
\sum_{x_{\mathrm{out}} \in {0,1}^{\ell/2 - \ell_0}}  
\mathrm{eq} \left(  
\left( w_{[(i + 1):\ell_0]}, w_{[(\ell/2 + \ell_0+1):]} \right),  
(y, x_{\mathrm{out}})  
\right)  
\cdot \newline  
\sum_{x_{\mathrm{in}} \in \\{0 , 1 \\}^{ \ell/2 }}  
\mathrm{eq} \left(  
w_{[(\ell_0+1):(\ell_0+\ell/2)]}, x_{\mathrm{in}}  
\right)  
\cdot  
p \left( v,u,y,, x_{\mathrm{in}}, x_{\mathrm{out}} \right)  
\end{aligned}  
$$

In the paper, we can see that _Procedure 9_ cleverly inverts the loops: instead of iterating by accumulator $A_i(v,u)$, it iterates over the data $(x_{\mathrm{out}}, x_{\mathrm{in}}, \beta)$ and "distributes" each result to the correct $A_i(v,u)$ bin. This is done in two stages:

        1. **Temporal Accumulation** ($\mathrm{tA}[\beta]$): For a fixed $x_{\mathrm{out}}$, the algorithm computes the entire inner sum for every prefix $\beta \in \\{0,1 \\}^{ \ell_0 }$. This loop contains the dominant 𝔰𝔩 operation: `e_in_value * poly_evals[index]`.

$$  
\mathrm{tA}[\beta] =  
\sum_{x_{\mathrm{in}} \in \\{0,1\\}^{ \ell/2}}  
E_{\mathrm{in}}[x_{\mathrm{in}}] \cdot  
p(\beta, x_{\mathrm{in}}, x_{\mathrm{out}})  
$$

$$  
E_{\mathrm{in}}[x_{\mathrm{in}}]  
=\mathrm{eq} \left(w_{[(\ell_0 + 1):(\ell_0 + \ell/2)]}, x_{\mathrm{in}}\right)  
$$

        2. **Distribution** : Once the $\mathrm{tA}$ vector is computed, the algorithm "distributes" these values to the correct final accumulators $A_i (v,u)$, multiplying them by their respective $E_{\mathrm{out}}$ weights.

Let's dive into our implementation.

First, we have an `Accumulators` struct where we store the values, along with a couple of basic methods to create, modify, and read them:
    
    #[derive(Debug, Clone, Eq, PartialEq)]
    pub struct Accumulators<F: Field> {
        /// One accumulator vector per SVO round.
        /// - `accumulators[0]` has 2^1 = 2 elements for A_0(u)
        /// - `accumulators[1]` has 2^2 = 4 elements for A_1(v, u)
        /// - `accumulators[2]` has 2^3 = 8 elements for A_2(v, u)
        pub accumulators: [Vec<F>; NUM_SVO_ROUNDS],
    }
    
    impl<F> Accumulators<F>
    where
        F: Field,
    {
        #[must_use]
        pub fn new_empty() -> Self {
            Self {
                // In round 0, we have 2 accumulators: A_0(u) with u in {0, 1}.
                // In round 1, we have 4 accumulators: A_1(v, u) with v in {0, 1} and u in {0, 1}.
                // In round 2, we have 8 accumulators: A_2(v, u) with v in {0, 1}^2 and u in {0, 1}.
                // We won't need accumulators with any digit as infinity.
                accumulators: [F::zero_vec(2), F::zero_vec(4), F::zero_vec(8)],
            }
        }
    
        /// Adds a value to a specific accumulator.
        pub fn accumulate(&mut self, round: usize, index: usize, value: F) {
            self.accumulators[round][index] += value;
        }
        /// Gets the slice of accumulators for a given round.
        #[must_use]
        pub fn get_accumulators_for_round(&self, round: usize) -> &[F] {
            &self.accumulators[round]
        }
    }
    

Notice that in the code we only compute the accumulators for $u \in \\{0,1 \\}$, even though initially, since $S(u)$ has degree 2, we should have three evaluations: at $0$, $1$, and at $\infty$. We'll explain this later on.

So let's see how we adapt _Procedure 9_ to our specific use case.
    
    /// Procedure 9. Page 37.
    /// We compute only the accumulators that we'll use, that is,
    /// A_i(v, u) for i in {0, 1, 2}, v in {0, 1}^{i}, and u in {0, 1}.
    fn compute_accumulators<F: Field, EF: ExtensionField<F>>(
        poly: &EvaluationsList<F>,
        e_in: &[EF],
        e_out: &[Vec<EF>; NUM_SVO_ROUNDS],
    ) -> Accumulators<EF> {
        [...]
    }
    

The function receives as input the evaluations of $p(x)$, $E_{\mathrm{in}}$, and $E_{\mathrm{out}}$.

We can see in the paper that these are computed as follows:

$$  
E_{\text{in}} :=\left(\mathrm{eq} \left(  
w_{\left[\ell_0 + 1 : (\ell_0 + \ell/2)\right]}, x_{\text{in}}  
\right) \right) \quad \text{with} \quad { x_{\text{in } } \in \\{0,1 \\}^{ \ell/2 }}  
$$

$$  
E_{\text{out},i} := \left( \mathrm{eq} \left(  
\left( w_{\left[(i+1):\ell_0\right]}, w_{\left[(\ell/2+\ell_0+1):\right]} \right),  
(y, x_{\text{out}})  
\right)  
\right)\quad \text{with} \quad {(y, x_{ \text{out} }) \in \\{0, 1\\}^{ \ell_0 } \times \\{0, 1 \\}^{ \ell/2 - \ell_0 }}  
$$

These values depend only on our challenge $w$, so we can precompute them as follows:
    
    /// Precomputation needed for Procedure 9 (compute_accumulators).
    /// Compute the evaluations eq(w_{l0 + 1}, ..., w_{l0 + l/2} ; x) for all x in {0,1}^l/2
    fn precompute_e_in<F: Field>(w: &MultilinearPoint<F>) -> Vec<F> {
        let half_l = w.num_variables() / 2;
        let w_in = &w.0[NUM_SVO_ROUNDS..NUM_SVO_ROUNDS + half_l];
        eval_eq_in_hypercube(w_in)
    }
    
    /// Precomputation needed for Procedure 9 (compute_accumulators).
    /// Compute three E_out vectors, one per round i in {0, 1, 2}.
    /// For each i, E_out = eq(w_{i+1}, ..., l0, w_{l/2 + l0 + 1}, ..., w_l ; x)
    fn precompute_e_out<F: Field>(w: &MultilinearPoint<F>) -> [Vec<F>; NUM_SVO_ROUNDS] {
        let half_l = w.num_variables() / 2;
        let w_out_len = w.num_variables() - half_l - 1;
    
        std::array::from_fn(|round| {
            let mut w_out = Vec::with_capacity(w_out_len);
            w_out.extend_from_slice(&w.0[round + 1..NUM_SVO_ROUNDS]);
            w_out.extend_from_slice(&w.0[half_l + NUM_SVO_ROUNDS..]);
            eval_eq_in_hypercube(&w_out)
        })
    }
    

Once we have computed these values, we can return to our `compute_accumulators` function.

The first thing we do is compute the number of variables in $x_{\mathrm{out}}$ as $\ell/2 - \ell_0$, where $\ell$ is the number of variables of $p(X)$ and $\ell_0$ is the number of SVO rounds, taking into account the case where $\ell$ is odd.
    
    [...]
        let l = poly.num_variables();
        let half_l = l / 2;
    
        let x_out_num_vars = half_l - NUM_SVO_ROUNDS + (l % 2);
        let x_num_vars = l - NUM_SVO_ROUNDS;
        debug_assert_eq!(half_l + x_out_num_vars, x_num_vars);
    
        let poly_evals = poly.as_slice();
        [...]
    

Now we can run the outer loop, where for each value of $x_{\mathrm{out}}$ we will:

        1. Initialize the temporary accumulators and compute the number of variables in $x_{\mathrm{in}}$:
    
    (0..1 << x_out_num_vars)
            .into_par_iter()
            .map(|x_out| {
                // Each thread will compute its own set of local accumulators.
                // This avoids mutable state sharing and the need for locks.
                let mut local_accumulators = Accumulators::<EF>::new_empty();
    
                let mut temp_accumulators = [EF::ZERO; 1 << NUM_SVO_ROUNDS];
    
                let num_x_in = 1 << half_l;
            })
    

        2. For each value of $x_{\mathrm{in}}$ we compute the $\mathrm{tA}$ values using:

$$  
\mathrm{tA}(x_{\mathrm{out}}) =  
\sum_{\beta \in \\{0,1 \\}^{3}}  
E_{\mathrm{in}}[x_{\mathrm{in}}] \cdot p(\beta, x_{\mathrm{in}}, x_{\mathrm{out}})  
$$
    
    for (x_in, &e_in_value) in e_in.iter().enumerate().take(num_x_in) {
                    // For each beta in {0,1}^3, we update tA(beta) += e_in[x_in] * p(beta, x_in, x_out)
                    #[allow(clippy::needless_range_loop)]
                    for i in 0..(1 << NUM_SVO_ROUNDS) {
                        let beta = i << x_num_vars;
                        let index = beta | (x_in << x_out_num_vars) | x_out; // beta | x_in | x_out
                        temp_accumulators[i] += e_in_value * poly_evals[index]; // += e_in[x_in] * p(beta, x_in, x_out)
                    }
                }
    

        3. Once we have all the temporary accumulators, we unpack them and collect all the $E_{\mathrm{out}}$ values we will need.

Remember that $E_{\mathrm{out}}$ depends only on $y$. So in the first round, $y$ has 2 variables, giving us 4 possible $E_{\mathrm{out}}$ values. In the second round, $y$ has 1 variable, so there are 2 possible $E_{\mathrm{out}}$ values. In the third round, it does not depend on $y$, so we have a single $E_{\mathrm{out}}$ value.
    
    // Destructure things since we will access them many times later
        let [t0, t1, t2, t3, t4, t5, t6, t7] = temp_accumulators;
        // Get E_out(y, x_out) for this x_out
        // Round 0 (i=0) -> y=(b1,b2) -> 2 bits
        let e0_0 = e_out[0][x_out]; // y=00
        let e0_1 = e_out[0][(1 << x_out_num_vars) | x_out]; // y=01
        let e0_2 = e_out[0][(2 << x_out_num_vars) | x_out]; // y=10
        let e0_3 = e_out[0][(3 << x_out_num_vars) | x_out]; // y=11
        // Round 1 (i=1) -> y=(b2) -> 1 bit
        let e1_0 = e_out[1][x_out]; // y=0
        let e1_1 = e_out[1][(1 << x_out_num_vars) | x_out]; // y=1
        // Round 2 (i=2) -> y=() -> 0 bits
        let e2 = e_out[2][x_out]; // y=()
    

        4. Once we have all these values, we can start adding them to the corresponding accumulators. In _Procedure 9_ , this is done by iterating over $(i, v, u, y) \in \mathrm{idx4}(\beta)$, but since we only need to compute 3 rounds and the values for $u = 0$ and $u = 1$, we can do it directly using the following sum:

$$  
\sum_{\beta \in U_d^{\ell_0}}  
\sum_{\substack{(i^\prime, v^\prime, u^\prime, y) \in \mathrm{idx4}(\beta) \ i^\prime = i, v^\prime = v, u^\prime = u}}  
E_{\mathrm{out}, i^\prime}[y, x_{\mathrm{out}}] \cdot \mathrm{tA}[\beta]  
$$
    
    // Round 0 (i=0)
         // A_0(u=0) = Σ_{y} E_out_0(y) * tA( (u=0, y), x_out )
         local_accumulators.accumulate(0, 0, e0_0 * t0 + e0_1 * t1 + e0_2 * t2 + e0_3 * t3);
         // A_0(u=1) = Σ_{y} E_out_0(y) * tA( (u=1, y), x_out )
         local_accumulators.accumulate(0, 1, e0_0 * t4 + e0_1 * t5 + e0_2 * t6 + e0_3 * t7);
         // Round 1 (i=1)
         // A_1(v, u) = Σ_{y} E_out_1(y) * tA( (v, u, y), x_out )
         // v=0, u=0
         local_accumulators.accumulate(1, 0, e1_0 * t0 + e1_1 * t1);
         // v=0, u=1
         local_accumulators.accumulate(1, 1, e1_0 * t2 + e1_1 * t3);
         // v=1, u=0
         local_accumulators.accumulate(1, 2, e1_0 * t4 + e1_1 * t5);
         // v=1, u=1
         local_accumulators.accumulate(1, 3, e1_0 * t6 + e1_1 * t7);
         // Round 2 (i=2)
         // A_2(v, u) = E_out_2() * tA( (v, u), x_out )
         #[allow(clippy::needless_range_loop)]
         for i in 0..8 {
              local_accumulators.accumulate(2, i, e2 * temp_accumulators[i]);
              }
    

Finally, the only thing left is to perform the final sum over (x_{\mathrm{out}}).
    
    .par_fold_reduce(
                || Accumulators::<EF>::new_empty(),
                |a, b| a + b,
                |a, b| a + b,
            )
    

## V. Phase 2: The Switchover to Algorithm 5

The switchover strategy is critical. SVO is only cheaper for the first few rounds. That's why after the first three rounds, we need to "apply" the challenges we've collected to the remaining polynomial evaluations. This process is formally known as **folding** or partial evaluation. We transform our original polynomial $p(x_1, \dots, x_\ell)$ into a smaller polynomial $p^{(3)}(x_4, \dots, x_\ell)$ by binding the first three variables:

$$  
p^{(3)} (x_4, \dots, x_\ell) =  
\sum_{b \in \\{0,1 \\}^3} \mathrm{eq}\left((r_1, r_2, r_3), b\right) \cdot p(b, x_4, \dots, x_\ell)  
$$

The polynomial folding is done in the following line:
    
    // Fold to obtain p(r1, r2, r3, x)
    let mut folded_evals = fold_evals_with_challenges(evals, &challenges); 
    

This operation contracts our evaluation domain from $2^\ell$ down to $2^{\ell - 3}$. In our implementation the function `fold_evals_with_challenges` handles this folding operation in parallel.

Since multilinear evaluations are stored in lexicographic order, fixing the first 3 variables conceptually slices the hypercube into $2^3 = 8$ large contiguous blocks. To compute the value for a point $i$ in the new, smaller domain, we need to gather the value at offset $i$ from each of these 8 blocks.

The index logic `(j * num_remaining_evals) + i` allows us to jump to the correct block $j$ and access the specific element $i$, accumulating the weighted sum into the result.
    
    pub fn fold_evals_with_challenges<F, EF>(
        evals: &EvaluationsList<F>,
        challenges: &[EF],
    ) -> EvaluationsList<EF> {
        let n = evals.num_vars();
        let k = challenges.len(); // k = 3 in our case
        // The size of the new, smaller hypercube (2^{l-3})
        let num_remaining_evals = 1 << (n - k); 
    
        // 1. Precompute weights eq(r, b) for all 8 prefixes b in {0,1}^3
        let eq_evals: Vec<EF> = eval_eq_in_hypercube(challenges);
    
        // 2. Parallel Fold
        let folded_evals_flat: Vec<EF> = (0..num_remaining_evals)
            .into_par_iter()
            .map(|i| {
                 // For each point 'i' in the destination domain, sum over the 8 source prefixes.
                eq_evals
                    .iter()
                    .enumerate()
                    .fold(EF::ZERO, |acc, (j, &eq_val)| {
                        // Reconstruct the index: prefix (j) + suffix (i)
                        let original_eval_index = (j * num_remaining_evals) + i;
    
                        let p_b_x = evals.as_slice()[original_eval_index];
                        acc + eq_val * p_b_x
                    })
            })
            .collect();
    
        EvaluationsList::new(folded_evals_flat)
    }
    

### The SVO-to-Standard Handover

Why do we stop SVO exactly here? The decision is dictated by the cost of field multiplications, as analyzed in the paper:

        1. **Before Folding ($\mathfrak{ss}$ Regime):** Our polynomial evaluations are in the base field (small). SVO exploits this by using efficient interpolation on small values, avoiding expensive extension field arithmetic.

        2. **The Folding Operation:** The folding operation itself is a linear combination involving the challenges $r_i$. Since $r_i \in \mathbb{F_{\text{ext}}}$, the output of the fold must be in the extension field.

        3. **After Folding ($\mathfrak{ll}$ Regime):** Once our evaluations are promoted to the extension field, the benefits of SVO evaporate. SVO introduces an overhead of $\mathcal{O} (d^2 )$ operations to save on multiplications.

After three rounds the folded multilinear polynomial is sufficiently small so that the standard linear-time prover (_Algorithm 5_) becomes more efficient than SVO. By switching immediately after the fold, we ensure we treat base field values with SVO and extension field values with the standard approach, maintaining optimal performance across the entire protocol execution.

### Algorithm 5

Once we have folded the polynomial, we proceed to use _Algorithm 5_ to execute the remaining $\ell - \ell_0$ rounds. You'll find our implementation in the function called [`algorithm_5`](https://github.com/lambdaclass/whir-p3/blob/eec71d03a5ec81f30acc6d591f42f318941c6df5/src/sumcheck/sumcheck_small_value.rs#L402).
    
    pub fn algorithm_5<Challenger, F: Field, EF: ExtensionField<F>>(
        prover_state: &mut ProverState<F, EF, Challenger>,
        poly: &mut EvaluationsList<EF>,
        w: &MultilinearPoint<EF>,
        challenges: &mut Vec<EF>,
        sum: &mut EF,
        pow_bits: usize,
    ) where
        Challenger: FieldChallenger<F> + GrindingChallenger<Witness = F>,
    {
        [...]
    }
    

In each round $j$, the prover’s goal is the same as in the first three rounds. We need to:

        * Compute and send the univariate polynomial evaluations $S_j (u)$ for $u \in \\{0,\infty \\}$.
        * Update variables for the next round.

To do so, we'll continue using the factorization of $S_j$ in:

$$  
S_j(u) = \ell_j(u) \cdot t_j(u)  
$$

where, recall,

$$  
\begin{align}  
\ell_j (u) &= \mathrm{eq}(w_{[1, j - 1]} ; r_{[1, j - 1]}) \cdot \mathrm{eq}(w_j; u) \newline  
t_j (u) &= \sum_{x \in \\{0, 1\\}^{\ell - j}} \mathrm{eq}(w_{[j + 1, \ell]}; x)\cdot p(r_{[1, j - 1]}, u, x)  
\end{align}  
$$

However, to compute $t_j$ we won't use SVO and accumulators, as we did before. Instead, we'll simply split its eq-poly into two halves, taking advantage of the fact that one part can be precomputed, thus avoiding recomputation in each round.

Let's break down the function `algorithm_5` step by step. Before the round loop you'll see this code snippet:
    
    let num_vars = w.num_variables();
    let half_l = num_vars / 2;
    
    // Precompute eq_R = eq(w_{l/2+1..l}, x_R)
    let eq_r = eval_eq_in_hypercube(&w.0[half_l..]);
    let num_vars_x_r = eq_r.len().ilog2() as usize;
    
    // The number of variables of x_R is: l/2 if l is even and l/2 + 1 if l is odd.
    debug_assert_eq!(num_vars_x_r, num_vars - half_l);
    
    // start_round should be NUM_SVO_ROUNDS.
    let start_round = challenges.len();
    challenges.reserve(num_vars - start_round);
    

Here we define several parameters, such as the total number of variables $(\ell)$ and the round where we currently are $(\ell_0)$. But, most importantly, we precompute the right (or final) half of the eq-poly:

$$  
\mathrm{eq_R} = \mathrm{eq} (w_{\ell/2 + 1}, \ldots, w_\ell; x_{ \ell/2 + 1}, \ldots, x_\ell).  
$$

After that, we start the loop. In each round $j$ we need to compute $t_j(0)$ and $t_j(1)$. To do so, we consider two cases: on one hand, the first rounds until round $\ell/2 - 1$, and on the other hand, the last rounds starting at round $\ell/2$.

_Disclaimer:_ You'll see that in the code the loop starts at $i = \ell_0$, but the first round that should be computed is $\ell_0 + 1$. That's why we have the variable `round = i + 1` in the code. Here in the post, to simplify the notation we call $j =$ `round`.
    
    // Compute the remaining rounds, from l_0 + 1 to the end.
    for i in start_round..num_vars {
        // `i` is the 0-indexed variable number, so `round = i + 1`.
        let round = i + 1;
        let num_vars_poly_current = poly.num_variables();
        let poly_slice = poly.as_slice();
    
        [...]
    

#### First Half Rounds

For the cases where $j < \frac{\ell}{2}$, we use the function `compute_t_evals_first_half` to obtain $t_j(0)$ and $t_j(1)$ in parallel. These values are computed using the following sum-splitting:

$$  
\begin{align}  
t(0) &=  
\sum_{x_R} \mathrm{eq}(w_{[\ell/2 + 1, \ell]}, x_R)  
\sum_{x_L} \mathrm{eq}(w_{[j + 1, \ell/2]}, x_L) \cdot  
p(r_{[1,j - 1]}, 0, x_L, x_R) \newline  
t(1) &=  
\sum_{x_R} \mathrm{eq}(w_{[\ell/2 + 1, \ell]}, x_R)  
\sum_{x_L} \mathrm{eq}(w_{[j+1, \ell/2]}, x_L) \cdot  
p(r_{[1,j - 1]}, 1, x_L, x_R)  
\end{align}  
$$
    
    // Compute t(u) for u in {0, 1}.
    let t_evals: [EF; 2] = if round <= half_l {
        // Case i+1 <= l/2: Compute eq_L = eq(w_{i+2..l/2}, x_L)
        let eq_l = eval_eq_in_hypercube(&w.0[round..half_l]);
        let (t_0, t_1) = join(
            || compute_t_evals_first_half(&eq_l, &eq_r, poly_slice, num_vars_x_r, 0),
            || {
                compute_t_evals_first_half(
                    &eq_l,
                    &eq_r,
                    poly_slice,
                    num_vars_x_r,
                    1 << (num_vars_poly_current - 1), // offset for u=1
                )
            },
        );
        (t_0, t_1).into()
    
        [...]
    

#### Second Half Rounds

Similarly, in the case $j \geq \frac{\ell}{2}$, we compute $t_j(0)$ and $t_j(1)$ using `compute_t_evals_second_half`. Note that since $j \geq \frac{\ell}{2}$, we don't have the sum involving the $\mathrm{eq_L}$ polynomial. So:

$$  
\begin{align}  
t(0) &= \sum_x \mathrm{eq}(w_{[j + 1, \ell]}, x) \cdot p(r_{[1,j - 1]}, 0, x) \newline  
t(1) &= \sum_x \mathrm{eq}(w_{[j + 1, \ell]}, x) \cdot p(r_{[1,j - 1]}, 1, x)  
\end{align}  
$$
    
    } else {
        // Case i+1 > l/2: Compute eq_tail = eq(w_{i+2..l}, x_tail)
        let eq_tail = eval_eq_in_hypercube(&w.0[round..]);
        let half_size = 1 << (num_vars_poly_current - 1);
        let (t_0, t_1) = join(
            || compute_t_evals_second_half(&eq_tail, &poly_slice[..half_size]),
            || compute_t_evals_second_half(&eq_tail, &poly_slice[half_size..]),
        );
        (t_0, t_1).into()
    };
    

#### Send, Sample and Update

Once we have $t_j(0)$ and $t_j(1)$, we compute $\ell_j(0)$ and $\ell_j(1)$ and get:

$$  
\begin{aligned}  
S_j(0) &= \ell_j(0) \cdot t_j(0) \newline  
S_j(\infty) &= \bigl(\ell_j(1) - \ell_j(0)\bigr) \cdot \left(t_j (1) - t_j(0)\right)  
\end{aligned}  
$$

Then we add these evaluations to the prover state and sample an extension field element $r_j$. After that, we fold the polynomial and obtain:

$$  
p(r_1, \ldots, r_j, x_{j+1}, \ldots, x_\ell).  
$$

Finally, we update the claimed sum:

$$  
\sigma_{j+1} = S_j (r_j).  
$$
    
    // Compute S_i(u) = t_i(u) * l_i(u) for u in {0, inf}:
    let linear_evals = compute_linear_function(&w.0[..round], challenges);
    let [s_0, s_inf] = get_evals_from_l_and_t(&linear_evals, &t_evals);
    
    // Send S_i(u) to the verifier.
    prover_state.add_extension_scalars(&[s_0, s_inf]);
    
    prover_state.pow_grinding(pow_bits);
    
    // Receive the challenge r_i from the verifier.
    let r_i: EF = prover_state.sample();
    challenges.push(r_i);
    
    // Fold and update the poly.
    poly.compress_svo(r_i);
    
    // Update claimed sum
    let eval_1 = *sum - s_0;
    *sum = s_inf * r_i.square() + (eval_1 - s_0 - s_inf) * r_i + s_0;
    

## VI. Communication Optimization

Independent of the prover computation (SVO), we also optimize the communication. In a standard sumcheck, the prover sends three field elements per round (since the polynomial that needs to be sent has degree 2). However, we only send two, reducing the proof size.

The trick is that the verifier can derive the third value. For any round $i$, the prover sends:

        * $S_i (0)$ — the evaluation at zero.
        * $S_i (\infty)$ — the leading coefficient.

The verifier, who knows the claimed sum $\sigma_i = S_{i - 1} (r_{i - 1})$ from the previous round, derives the third evaluation:

$$  
S_i(1) = \sigma_i - S_i(0)  
$$

This holds due to the sum constraint $S_i (0) + S_i (1) = \sigma_i$.

You can find this implemented for the prover in both `svo_three_rounds` and `algorithm_5` functions. For example, for the first round you'll see:
    
    // Prover side
    
    // [...]
    
    // Round 1
    prover_state.add_extension_scalars(&[s_0, s_inf]); // Send 2 values.
    let r_1: EF = prover_state.sample(); // Sample a random challenge.
    let s_1 = *sum - s_0; // Derive 3rd value. 
    *sum = s_inf * r_1.square() + (s_1 - s_0 - s_inf) * r_1 + s_0; // Update sum.
    
    // [...]
    

The verifier's job is simpler: it reads the proof, derives missing values, and verifies consistency. You can find the implementation in [`verify_sumcheck_round_svo`](https://github.com/lambdaclass/whir-p3/blob/eec71d03a5ec81f30acc6d591f42f318941c6df5/src/whir/verifier/sumcheck.rs#L144):
    
    // Verifier Side
    
    // [...]
    
    for _ in 0..rounds {
        // Extract the first and third evaluations of the sumcheck polynomial
        // and derive the second evaluation from the latest sum.
        let c0 = verifier_state.next_extension_scalar()?;
    
        let c1 = *claimed_sum - c0;
    
        let c2 = verifier_state.next_extension_scalar()?;
    
        // PoW interaction (grinding resistance)
        verifier_state.check_pow_grinding(pow_bits)?;
    
        // Sample the next verifier folding randomness rᵢ.
        let rand: EF = verifier_state.sample();
    
        // Update sum.
        *claimed_sum = c2 * rand.square() + (c1 - c0 - c2) * rand + c0;
    
        randomness.push(rand);
    }
    
    // [...]
    

The verifier never computes accumulators or evaluates polynomials directly. It only reads two field elements from the proof and derives the third value. This is significantly more efficient than the classical sumcheck verifier, which needs to read three elements and verify the sum constraint explicitly.

## VII. Conclusion

In this post we present a complete implementation in Rust of _Algorithm 6_ from the BDDT paper, bringing together both optimization techniques (SVO and Eq-Poly) into a working prover.

As a bonus, we also reduce the proof size by sending only two field elements per round, exploiting the sum constraint to let the verifier derive the missing value.

These optimizations are now part of [our whir-p3 fork](https://github.com/lambdaclass/whir-p3) and have been [merged into the original repository](https://github.com/tcoratger/whir-p3/pull/322).

## References

        * [Small Value Optimization Paper](https://eprint.iacr.org/2025/1117)
        * [Optimizing Sumcheck (Part I)](/optimizing-sumcheck/)
        * [How factoring equality polynomials optimizes sumcheck (Part II)](/how-factoring-equality-polynomials-optimizes-sumcheck/)
        * [Whirlaway: Multilinear STARKs using WHIR](/whirlaway-multilinear-starks-using-whir-as-polynomial-commitment-scheme/)
        * [whir-p3 Repository](https://github.com/tcoratger/whir-p3)
        * [Our fork of whir-p3 Repository](https://github.com/lambdaclass/whir-p3)
