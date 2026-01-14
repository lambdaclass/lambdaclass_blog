+++
title = "Lambdaworks as a drop-in replacement for Winterfell to prove the Miden-VM"
date = 2023-12-27
slug = "lambdaworks-as-a-drop-in-replacement-for-winterfell"

[extra]
feature_image = "/content/images/2025/12/Hubert_Robert_-_The_Landing_Place_-_Art_Institute_of_Chicago_-_1787-88.jpg"
authors = ["LambdaClass"]
+++

## Introduction

[Lambdaworks](https://github.com/lambdaclass/lambdaworks) is our library for finite fields, elliptic curves, and proof systems. Among them, we have a [STARK](https://github.com/lambdaclass/lambdaworks/tree/main/provers/stark), [Plonk](https://github.com/lambdaclass/lambdaworks/tree/main/provers/plonk), [Groth 16](https://github.com/lambdaclass/lambdaworks/tree/main/provers/groth16) provers and we are on the way to having a fully compatible [Cairo prover using STARKs](https://github.com/lambdaclass/lambdaworks/tree/main/provers/cairo). We want to continue adding new proof systems and polynomial commitment schemes so that users have a library suited to their particular needs and where experimentation is easy.

During the last months, we have been working towards compatibility with [Winterfell](https://github.com/facebook/winterfell/tree/main), a popular general-purpose STARK prover. Polygon uses Winterfell to prove the execution of the [Miden-VM](https://github.com/0xPolygonMiden/miden-vm), which is a ZK-friendly VM to enable features and benefits that EVM-based L1s and L2s do not currently offer.

Even though the main components are the same, such as execution trace, auxiliary trace, using Merkle trees for commitments, and the FRI protocol, there are some parts where it was not straightforward to use Lambdaworks as a drop-in replacement for Winterfell. One obstacle is related to the field backend. Miden was designed to work over the prime $2^{64} - 2^{32} + 1$ (known by some as Mini-Goldilocks) and has to deal with extension fields to achieve cryptographic security, whereas our STARK prover worked with a 252-bit field. In this first part, we focused purely on compatibility and left behind optimizations that we could add to improve the performance.

In this post, we will cover the major work we have been doing toward compatibility with Winterfell so that you can replace it in your project if needed. This adds redundancy and robustness since we have different provers with different design choices and can help detect bugs.

## Fields and Traces

To work with Winterfell, we implemented the field trait from Lambdaworks to the native fields of Winterfell. In other words, we are running our STARK prover with Winterfell fields.

Since Miden works with mini-Goldilocks, the auxiliary trace and the random challenges drawn from the verifier belong to a field extension. One easy way to deal with this is by having all the elements belong to the extension field, which would add overhead to the elements of the main trace (since they live in the smaller base field).

To solve this issue, we split the trace in two, with one part belonging to the main trace and using the small field and the extension belonging to the larger field.

Moreover, we added some useful generalizations. Since, a lot of times, elements from the extension field are multiplied by elements belonging to the base field, the operation can be improved. This is similar to what we do, for example, in the complex numbers when we multiply it by a real. If we want to compute $2\times (1 + i)$, we distribute and do two multiplications instead of doing a naive multiplication with the formula $(2 + 0i) \times (1 + i)$).

To handle this case, we implemented the [subfield logic](https://github.com/lambdaclass/lambdaworks/pull/709). This allows us to define the operations between field elements and exceptional cases for when a subfield element operates with its parent field element. And since it's just a matter of picking the correct operation in compilation time, there is no overhead. All this extra logic adds no overhead to the fields, as it can be measured in our benchmarks.

Along with the changes in the fields, we also introduced changes to the [FFT so that it works over extension fields](https://github.com/lambdaclass/lambdaworks/pull/711). Now, the interpolation of the auxiliary trace and computation of the composition polynomial has to work over larger fields.

## Winterfell adapter

The Winterfell Adapter transforms a Winterfell AIR (algebraic intermediate representation) into a Lambdaworks AIR.

Internally, it creates a new implementation of the Air trait, using all the configurations from Winterfell. One detail is that the evaluation of constraints is delegated here to the implementation in Winterfell to avoid a redefinition that would take longer for someone who already has the Air defined in Winterfell.

To see it working, we can check the following link, which contains an example of how to generate proof for the [Fibonacci AIR](https://github.com/lambdaclass/lambdaworks/tree/main/winterfell_adapter). Let's check it.

### Code and Examples

Let's see how the Winterfell adapter is used with a simple Air.

#### Fibonacci Air

Suppose you want to run Lambdaworks prover with a `WinterfellFibonacciAIR.`
    
    use winterfell::Air;
    
    struct WinterfellFibonacciAIR {
        /// ...
    }
    
    impl Air for WinterfellFibonacciAIR {
        /// ...
    }
    

##### Step 1: Convert your Winterfell trace table

Use the Lambdaworks `AirAdapter` to convert your Winterfell trace:
    
    let trace = &AirAdapter::convert_winterfell_trace_table(winterfell_trace)
    

##### Step 2: Convert your public inputs

Create the `AirAdapterPublicInputs` by supplying your `winterfell_public_inputs` and the additional parameters required by the Lambdaworks prover:
    
    let pub_inputs = AirAdapterPublicInputs {
        winterfell_public_inputs: AdapterFieldElement(trace.columns()[1][7]),
        transition_degrees: vec![1, 1],    /// The degrees of each transition
        transition_exemptions: vec![1, 1], /// The steps at the end where the transitions do not apply.
        transition_offsets: vec![0, 1],    /// The size of the frame. This is probably [0, 1] for every Winterfell AIR.
        composition_poly_degree_bound: 8,  /// A bound over the composition degree polynomial is used for choosing the number of parts for H(x).
        trace_info: TraceInfo::new(2, 8),  /// Your winterfell trace info.
    };
    

Note that you might have to also convert your field elements to `AdapterFieldElement,` as in this case.

##### Step 3: Make the proof
    
    let proof = Prover::prove::<AirAdapter<FibonacciAIR, TraceTable<_>>>(
        &trace,
        &pub_inputs, /// Public inputs
        &proof_options,
        StoneProverTranscript::new(&[]),
    );
    

`TraceTable` is the Winterfell type that represents your trace table. You can see the `examples` folder inside this crate to check more examples.

### Miden Air

Let's see how it is used with an actual Miden AIR and program.

First, we must compile and run the code to generate a trace. This is done in the same manner as Miden does it.

The whole code is a bit long, but it starts like this:
    
    let fibonacci_number = 16;
            let program = format!(
                "begin
                    repeat.{}
                        swap dup.1 add
                    end
                end",
                fibonacci_number - 1
            );
    let program = Assembler::default().compile(program).unwrap();
    ... 
    // Some more code goes in the middle until we generate the trace
    
    let winter_trace = processor::execute(
        &program,
        stack_inputs.clone(),
        DefaultHost::default(),
        *ProvingOptions::default().execution_options(),)
    

After generating the trace from Miden, the real work for the prover starts. But the code is not that different from the Fibonacci case; it just has a more complex AIR, but the user is abstracted from that.

To generate the proof, we run the following code:
    
    let pub_inputs = AirAdapterPublicInputs {
        winterfell_public_inputs: pub_inputs,
        transition_exemptions: vec![2; 182],
        transition_offsets: vec![0, 1],
        trace_info: winter_trace.get_info(),
        metadata: winter_trace.clone().into(),
    };
    
    let trace =
        MidenVMQuadFeltAir::convert_winterfell_trace_table(winter_trace.main_segment().clone());
    
    let proof = Prover::<MidenVMQuadFeltAir>::prove(
        &trace,
        &pub_inputs,
        &lambda_proof_options,
        QuadFeltTranscript::new(&[]),
    )
    .unwrap();
    

Finally, to verify it, it is enough to call the verify function with the proof and the public inputs:
    
    Verifier::<MidenVMQuadFeltAir>::verify(
                &proof,
                &pub_inputs,
                &lambda_proof_options,
                QuadFeltTranscript::new(&[]),
            )
    

### Benchmarks

To run the Fibonacci Miden benchmark run:
    
    cargo bench
    

To run it with parallelization, run:
    
    cargo bench --features stark-platinum-prover/parallel,winter-prover/concurrent
    

Several PRs added support for extension fields for the prover and verifier ([716](https://github.com/lambdaclass/lambdaworks/pull/716), [717](https://github.com/lambdaclass/lambdaworks/pull/717) and [724](https://github.com/lambdaclass/lambdaworks/pull/724)). These allow us to represent the trace in the base field (which has faster operations and less memory use) and have a different frame for the auxiliary trace over the extension. There were some modifications in the constraint calculations, such as being able to use different fields.

There is also a [Miden adapter](https://github.com/lambdaclass/lambdaworks/blob/main/winterfell_adapter/src/examples/miden_vm.rs) containing some example tests, such as Fibonacci and readme example.

## Adding periodic columns

Winterfell also uses periodic columns, so we had to add them and test their use in this [PR](https://github.com/lambdaclass/lambdaworks/pull/685/files). These have uses for hash function calculations or supporting constants that we need.

## Conclusions

Lambdaworks has been growing over the last year. We have added several proof systems and commitment schemes to give users an easy-to-use library to experiment with and build applications. We have also been working to make the provers compatible with our libraries, giving the users a drop-in replacement. We decided to work towards compatibility with Winterfell/Miden VM since we like many design choices and the work done to generalize AIRs in [AIRscript](https://github.com/0xPolygonMiden/air-script). We will continue improving the performance of our provers and supporting new proof systems as part of our roadmap.
