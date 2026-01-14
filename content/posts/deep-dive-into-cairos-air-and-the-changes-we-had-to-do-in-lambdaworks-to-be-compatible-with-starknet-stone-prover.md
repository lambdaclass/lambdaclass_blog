+++
title = "Deep dive into Cairo's AIR and the changes we had to do in Lambdaworks to be compatible with Starknet Stone Prover"
date = 2024-01-25
slug = "deep-dive-into-cairos-air-and-the-changes-we-had-to-do-in-lambdaworks-to-be-compatible-with-starknet-stone-prover"

[extra]
feature_image = "/content/images/2025/12/Bonaparte_ante_la_Esfinge-_por_Jean-Le--on_Ge--ro--me.jpg"
authors = ["LambdaClass"]
+++

## Introduction

During the last months, we have been working to make [Lambdaworks](https://github.com/lambdaclass/lambdaworks) STARK Platinum prover with Starknet's Stone prover. We also want STARK Platinum to be flexible enough to be used as a drop-in replacement for other STARK provers, such as Winterfell (employed as the default prover in Miden). One of the main difficulties is related to how we provide the algebraic intermediate representation (AIR) and constraints in a simple yet expressible way and be able to try and test several trace configuration layouts. In a [previous post](/comparing-stark-provers/), we discussed different design choices for STARK provers, such as using virtual columns, built-ins, and chiplets and their tradeoffs. We would like the prover to be as modular as possible so that we can try different design options, incorporate new tools or fields, and assess performance. One inconvenience with previous approaches was that changes in the AIR or selecting a new layout needed extensive rewriting. Moreover, when using virtual columns, the prover must supply the zerofiers for each constraint, which depends on how the columns are interleaved, making it difficult and error-prone.

In this post, we will cover the new way of implementing transition constraints and AIRs in STARK Platinum, which should give us more freedom to test and move things around, making it more straightforward to add new layouts. We also provide tools to evaluate the zerofiers without the user giving the exact expression. If you are unfamiliar with some of the concepts, you can take a look at our posts on STARKs [1](/diving-deep-fri/) and [2](/comparing-stark-provers/).

## Transition constraints

We define the public trait `pub trait TransitionConstraint<F, E>: Send + Sync where F: IsSubFieldOf<E> + IsFFTField + Send + Sync, E: IsField + Send + Sync,`, which contains all the methods we need to deal with transition constraints. It is generic over two fields, `F`, the base field, and `E`, which could be a field extension of `F`. If we do not need an extension field, we will simply have `E` equal to `F`. The base field should also be an FFT-friendly field, that is, it should contain a multiplicative subgroup of size $2^m$ (for example, $p = 2^{64} - 2^{32} +1$ has a multiplicative group of size $2^{64} - 2^{32}$, which is divisible by $2^{32}$). Below, we list the main methods:

        * `fn degree` gives the degree of the transition constraint. All the constraints for the Cairo vm are at most degree 3. The higher the degree of the constraint, the larger the evaluation domain needed to calculate the transition constraints.
        * `fn constraint_idx` gives the constraint identifier, a unique integer between 0 and the total number of transition constraints.
        * `fn evaluate` provides how to evaluate the constraint over the trace's low-degree extension (LDE). Depending on the constraint, `periodic_values` or `rap_challenges` may be needed. The values are stored in the `transition_evaluations` vector, in the position corresponding to the`constraint_idx`.
        * `fn period` indicates how often a constraint is applied. If the constraint is applied at each step, it is set to $1$. Some constraints may apply every several steps (for example, 16 or 256), which is necessary to evaluate the zerofier correctly.
        * `fn offset` indicates where we start applying the constraint, beginning from the first step. If the constraint applies from the first step, we set it to $0$. If a constraint starts at $1$ and has a period of $16$, this means that the constraint is valid for steps 1, 17, 33, 49, etc. We need this to evaluate the zerofier correctly.
        * `fn end_exemptions` indicates whether the constraint applies to the trace's last $n$ steps. If it applies to every step, it is set to $0$. If the last two steps do not enforce the constraint, we put it to $2$.
        * `fn exemptions_period` and `fn periodic_exemptions_offset` are necessary to remove several intermediate steps from a constraint. All the exemptions are needed to evaluate the zerofier correctly.
        * Several methods to evaluate the zerofier for the constraint `fn end_exemptions_poly`, `fn zerofier_evaluations_on_extended_domain` and `fn evaluate_zerofier`. The second function is needed to evaluate the composition polynomial, while the third one is required to evaluate at the out-of-domain point, $z$.

## Understanding exemptions and zerofiers

### Fibonacci sequence

To fix how exemptions work, let us look at some examples. The easiest to grasp is `end_exemptions`. These appear, for example, in the case of the calculation of the Fibonacci sequence:  
$a_0 = a_1 = 1$  
$a_{n + 2} = a_{n + 1} + a_n$  
A single trace column can represent this and can be expressed by the following polynomial relationship:  
$t(g^2 x) - t(g x) - t(x) = 0$  
This constraint is valid for all computation steps except the last two. Remember that we represent each step by a power of $g$, an $n$-th primitive root of unity ($n$ is equal to the trace length). Thus, the zerofier would look like  
$$Z_C (x) = \prod_{i = 0}^{ n - 3} (x - g^i ) = \frac{\prod_{i = 0}^{ n - 1} (x - g^i )}{(x - g^{n - 2} )( x - g^{n - 1} )}$$  
The zerofier is  
$Z (x) = \prod_{i = 0}^{ n - 1} (x - g^i ) = x^n - 1$  
while the exemptions are just  
$E (x) = (x - g^{n - 2} )( x - g^{n - 1} )$  
The combination of both gives the zerofier for the constraint. To represent these constraints, we will have `fn end_exemptions` return $2$, `fn period` return $1$, and `fn offset` yield $0$.

### Cairo Flags example

This example follows the constraints in the virtual column containing all the flags in the Cairo vm. The AIR is provided [here](https://github.com/lambdaclass/lambdaworks/blob/87915f06dab3a899d6e967766c0097a89d8d633b/provers/stark/src/examples/bit_flags.rs#L18). The column consists of repetitions of 15 binary values, followed by a zero value. There are two transition constraints:  
$t (1 - t) = 0$  
$t = 0$

The first constraint holds for all values except every 16th value. On the other hand, the second constraint holds only every 16 rows, starting from row 15. Let's compute the zerofier for the second constraint first:  
$Z_C (x) = (x - g^{15} )(x - g^{31} )(x - g^{47} )...$  
The number of terms is $n/16$. We can take the $g^{15}$ as common factor and call $y = x/g^{15}$. Thus,  
$Z_C (x) = g^{15 n/16} \prod_{j = 0}^{ n/16 - 1} (y - g^{ 16j} )$  
Remember that, if $g$ is an $n$-th root of unity, $g^{16}$ is an $n/16$-th root of unity. Since we are multiplying all the $n/16$ roots of unity, we get  
$Z_C (y) = g^{15 n/16} (y^{n/16} - 1)$  
Distributing and remembering the relationship between $x$ and $y$  
$Z_C (x) = x^{n/16} - g^{ 15n/16 }$  
This zerofier is compatible with `fn offset` equal to $15$ and `fn period` equal to $16$, with no exemptions present.

The zerofier for the first constraint can be calculated by knowing the zerofiers for the whole trace and the zerofier for the zero flag constraint. This is,  
$$Z_F (x) = \frac{x^n - 1}{x^{n/16} - g^{ 15n/16 }}$$

The first constraint has `fn periodic_exemptions_offset` equal to $15$ and `fn exemptions_period` equal to $16$, essentially computing the same zerofier as the zero flag and taking it from the full trace zerofier.

## Algebraic Intermediate Representation

We established an AIR trait, which contains all the methods we need to represent the trace, the constraints, and their evaluation.

The method `fn trace_layout(&self) -> (usize, usize)` provides the number of columns of the main and auxiliary traces (if it exists). The main trace contains elements in the base field (for example, Stark252 or Mini-Goldilocks). In contrast, if needed, the auxiliary trace may have elements from an extension field to achieve cryptographic security.

To evaluate transition constraints, we have the methods `fn compute_transition_prover`, `fn compute_transition_verifier`, `fn transition_constraints` and `fn transition_zerofier_evaluations`.

The `fn transition_zerofier_evaluations` has a default implementation. Given that some constraints might share the same zerofier (because they apply at the same steps of the execution trace), we avoid recomputing zerofiers by checking with a `zerofier_group_key`.
    
    fn transition_zerofier_evaluations(
            &self,
            domain: &Domain<Self::Field>,
        ) -> Vec<Vec<FieldElement<Self::Field>>> {
            let mut evals = vec![Vec::new(); self.num_transition_constraints()];
    
            let mut zerofier_groups: HashMap<ZerofierGroupKey, Vec<FieldElement<Self::Field>>> =
                HashMap::new();
    
            self.transition_constraints().iter().for_each(|c| {
                let period = c.period();
                let offset = c.offset();
                let exemptions_period = c.exemptions_period();
                let periodic_exemptions_offset = c.periodic_exemptions_offset();
                let end_exemptions = c.end_exemptions();
    
                // This hashmap is used to avoid recomputing with an fft the same zerofier evaluation
                // If there are multiple domains and subdomains they can be further optimized
                // as to share computation between them
    
                let zerofier_group_key = (
                    period,
                    offset,
                    exemptions_period,
                    periodic_exemptions_offset,
                    end_exemptions,
                );
                zerofier_groups
                    .entry(zerofier_group_key)
                    .or_insert_with(|| c.zerofier_evaluations_on_extended_domain(domain));
    
                let zerofier_evaluations = zerofier_groups.get(&zerofier_group_key).unwrap();
                evals[c.constraint_idx()] = zerofier_evaluations.clone();
            });
    
            evals
        }
    

## Implementing the CairoAIR

The implementation of the CairoAIR starts [here](https://github.com/lambdaclass/lambdaworks/blob/f271ed876cfa3aa58e36a29e22430eef3703fdc8/provers/cairo/src/air.rs#L535). We begin by defining the `fn new`, which contains the 64 constraints, the transition exemptions and the AIRContext. Since the Stone Prover uses virtual columns, the final number of constraints (counting transition and boundary constraints) will be 46. The main trace has six columns, and the auxiliary trace has 2. The plain layout for one step can be found in the [documentation of our prover](https://github.com/lambdaclass/lambdaworks/blob/main/docs/src/starks/stone_prover/trace_plain_layout.md).

The implementation of the `TransitionConstraint` trait for each of the constraints is done [here](https://github.com/lambdaclass/lambdaworks/blob/main/provers/cairo/src/transition_constraints.rs#L8). This is the list of transition constraints for the CairoAIR using the plain layout:

        * BitPrefixFlag0
        * BitPrefixFlag1
        * BitPrefixFlag2
        * BitPrefixFlag3
        * BitPrefixFlag4
        * BitPrefixFlag5
        * BitPrefixFlag6
        * BitPrefixFlag7
        * BitPrefixFlag8
        * BitPrefixFlag9
        * BitPrefixFlag10
        * BitPrefixFlag11
        * BitPrefixFlag12
        * BitPrefixFlag13
        * BitPrefixFlag14
        * ZeroFlagConstraint
        * InstructionUnpacking
        * CpuOperandsMemDstAddr
        * CpuOperandsMem0Addr
        * CpuOperandsMem1Addr
        * CpuUpdateRegistersApUpdate
        * CpuUpdateRegistersFpUpdate
        * CpuUpdateRegistersPcCondPositive
        * CpuUpdateRegistersPcCondNegative
        * CpuUpdateRegistersUpdatePcTmp0
        * CpuUpdateRegistersUpdatePcTmp1
        * CpuOperandsOpsMul
        * CpuOperandsRes
        * CpuOpcodesCallPushFp
        * CpuOpcodesCallPushPc
        * CpuOpcodesAssertEq
        * MemoryDiffIsBit0
        * MemoryDiffIsBit1
        * MemoryDiffIsBit2
        * MemoryDiffIsBit3
        * MemoryDiffIsBit4
        * MemoryIsFunc0
        * MemoryIsFunc1
        * MemoryIsFunc2
        * MemoryIsFunc3
        * MemoryIsFunc4
        * MemoryMultiColumnPermStep0_0
        * MemoryMultiColumnPermStep0_1
        * MemoryMultiColumnPermStep0_2
        * MemoryMultiColumnPermStep0_3
        * MemoryMultiColumnPermStep0_4
        * Rc16DiffIsBit0
        * Rc16DiffIsBit1
        * Rc16DiffIsBit2
        * Rc16DiffIsBit3
        * Rc16PermStep0_0
        * Rc16PermStep0_1
        * Rc16PermStep0_2
        * Rc16PermStep0_3
        * FlagOp1BaseOp0BitConstraint
        * FlagResOp1BitConstraint
        * FlagPcUpdateRegularBit
        * FlagFpUpdateRegularBit
        * CpuOpcodesCallOff0
        * CpuOpcodesCallOff1
        * CpuOpcodesCallFlags
        * CpuOpcodesRetOff0
        * CpuOpcodesRetOff2
        * CpuOpcodesRetFlags

We will take a look at the implementation for `BitPrefixFlag0` constraint, which we reproduce below:
    
    impl TransitionConstraint<Stark252PrimeField, Stark252PrimeField> for BitPrefixFlag0 {
        fn degree(&self) -> usize {
            2
        }
    
        fn constraint_idx(&self) -> usize {
            0
        }
    
        fn evaluate(
            &self,
            frame: &stark_platinum_prover::frame::Frame<Stark252PrimeField, Stark252PrimeField>,
            transition_evaluations: &mut [Felt252],
            _periodic_values: &[Felt252],
            _rap_challenges: &[Felt252],
        ) {
            let current_step = frame.get_evaluation_step(0);
    
            let constraint_idx = self.constraint_idx();
    
            let current_flag = current_step.get_main_evaluation_element(0, constraint_idx);
            let next_flag = current_step.get_main_evaluation_element(0, constraint_idx + 1);
    
            let one = Felt252::one();
            let two = Felt252::from(2);
    
            let bit = current_flag - two * next_flag;
    
            let res = bit * (bit - one);
    
            transition_evaluations[constraint_idx] = res;
        }
    
        fn end_exemptions(&self) -> usize {
            0
        }
    }
    

This constraint shows that the variable corresponding to Flag0 is binary, that is, $b \in {0 , 1}$. Mathematically, this condition is expressed as $b (1 - b) = 0$.

First, we define the degree of the constraint. Since the polynomial defining the constraint $b (1 - b) = 0$ is quadratic, the degree function will return $2$. Next, we define the constraint index or identifier, which has to be between 0 and 63. We choose 0 for this constraint (but we could change it if we want the constraints to be in another order, which is convenient if we have to rearrange the constraints for compatibility). In this case, since the variable has to be binary at every execution step, the `end_exemptions` is simply 0.

We can now jump to the `evaluate` function for the constraint. To evaluate the constraint, we need the `frame` (containing the elements from the LDE of the main and auxiliary traces) and `transition_evaluations`, which we will modify to add the value corresponding to the constraint. Line 17 gets the evaluation frame for the current step, and with the constraint index, we search for the current and next flags (this is an optimization used in the Stone Prover). We get the bit for the flag in line 27 and compute the constraint expression in line 29 (this should be zero if we evaluate it using the values of a valid trace). Finally, we store the value in `transition_evaluations` at position `constraint_idx`.

## Conclusion

In this post, we covered the changes introduced in STARK Platinum to deal with transition constraints and AIR definition. This will help us play more easily with different layouts and avoid having the user define the zerofiers by providing explicit expressions. We covered how zerofiers are defined and how constraint evaluations are carried out. We also think the changes will help test other features, such as using smaller fields in Starknet (though this may need further changes).
