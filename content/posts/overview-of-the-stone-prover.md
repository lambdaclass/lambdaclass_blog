+++
title = "An overview of the Stone Cairo STARK Prover"
date = 2023-09-28
slug = "overview-of-the-stone-prover"

[extra]
math = true
feature_image = "/images/2025/12/Napoleon-Ge--rome.jpg"
authors = ["LambdaClass"]
+++

## Introduction

About one month ago, Starkware open-sourced its Stone Prover, which is currently in production in Starknet. It is a library that allows one to produce proofs of computational integrity using STARKs (Scalable Transparent Arguments of Knowledge).

The codebase has around 100k lines of code, written mainly in C++. It has the following main components:

        * AIR: contains the constraints of the algebraic intermediate representation of CAIRO.
        * Channel (transcript in STARK Platinum): contains the interactions between the prover and verifier and gives methods to sample random challenges.
        * Composition polynomial. The constraints of the AIR are enforced over the trace polynomials and randomly combined into a single polynomial.
        * Commitment schemes: contains the methods to (cryptographically) commit to a series of polynomial evaluations.
        * FRI, Fast Reed Solomon interactive oracle proofs of proximity: performs the low-degree testing that allows one to prove that a function is close to a low-degree polynomial.

At Lambdaclass, we are working on our Cairo prover, STARK Platinum (written in Rust), being compatible with the Stone Prover so that anyone can use the Rust version to generate valid proofs for different applications built on top of Starknet. We hope that the performance and usability of our prover helps the community to adopt it.

In this post, we will analyze some of the components of the Stone Prover and explain how they work and their implementation. For an introduction to STARKs, see our [previous posts](/diving-deep-fri/) or the [STARK Platinum docs](https://github.com/lambdaclass/lambdaworks/tree/main/docs/src/starks).

## Domains

Every implemented field $\mathbb{F}$ has a generator $\omega$ of the unit groups $\mathbb{F}^\times$. They can be obtained by calling the class method `Generator` of `PrimeFieldElement`. The generator for the `Stark252Field` is $\omega = 3$ ([here](https://github.com/starkware-libs/stone-prover/blob/3d5bb8bd991b7809a6d379c123c902667bac600f/src/starkware/algebra/fields/prime_field_element.h#L138-L140) and [here](https://github.com/starkware-libs/stone-prover/blob/3d5bb8bd991b7809a6d379c123c902667bac600f/src/starkware/algebra/fields/big_prime_constants.h#L61)).

The class representing a domain is [`ListOfCosets`](https://github.com/starkware-libs/stone-prover/blob/3d5bb8bd991b7809a6d379c123c902667bac600f/src/starkware/algebra/domains/list_of_cosets.h#L34). The method `TraceGenerator` returns a primitive root of unity $g$ of the order of the trace length $2^n$ that generates a domain $D$. It is computed as $g = \omega^{ ( p - 1 ) / 2^n }$. The LDE is then represented as a list of cosets ${h^i w D: i = 0, \dots , k - 1 }$ all of the same size as $D$, such that their union is the actual LDE domain:

$$D_{\text{LDE}} = w D , \cup , h w D , \cup , h^2 w D , \cup , \cdots , \cup , h^{k-1} w D,$$  
where $h = w^{( p - 1 ) / 2^{ n + k }}$.

## Transcript

The stone prover uses a `NonInteractiveProverChannel` class to handle its interactions with the transcript. There are two basic operations:

        * `SendBytes`: the prover appends bytes to the transcript.
        * `ReceiveBytes`: the prover receives bytes from the transcript.

These operations are building blocks for more complex operations, such as sampling a `FieldElement` or a number. Several hash functions can be used to interact with the transcript (e.g., Keccak, Pedersen).

These operations are mainly implemented in the `HashChain` class, with other classes just delegating to it. It has the following attributes:

        * `self.counter`: counts how many blocks of $K$ bytes have been consumed.
        * `self.hash`: holds the current state of the hash function.
        * `self.spare_bytes`: when a user asks for $T$ bytes where $T$ is not multiple of $K$, it stores them to use them later on.

Here, $K$ is the number of bytes needed to store the output of the chosen hash functions (e.g., 32 bytes for Keccack256).

### Appending to the transcript

When bytes $X$ are appended to the transcript, the current digest $D$ is obtained and interpreted as a BigInt. Then, a seed increment is added to it. The concatenation of this new seed and $X$ is the latest state of the hash function.

Pseudocode:
    
    def append(new_bytes, seed_increment):
        digest = self.hash.digest()
        new_seed = digest + self.seed_increment
        self.hash = Hash(new_seed || bytes)
    

Here, `||` is the concatenation operator.

### Sampling from the transcript

Pseudocode:
    
    def sample_block():
        counter_bytes = | 24 bytes of 0x00 | counter as u64 | # This depends on the "block" size, the hash size.
        self.counter++
        return Hash(self.hash.digest() || counter).digest()
    
    
    
    def sample(number_bytes):
        for chunk32 in split(number_bytes, 32):
            result = result + sample_block()
        return result
    

This is a simplified version of the code. Here, the hash size is assumed to be 32 bytes (256 bits). Also, this pseudocode does not handle the case where a programmer asks for a number of bytes that's not a multiple of the hash size.

### Transcript initialization (Strong Fiat-Shamir)

The main prover and verifier executables initialize the transcript using a Fiat-Shamir strategy. This means that the hash function is updated using the public parameters.

There are two implementations of this: the Fibonacci AIR and the Cairo AIR (`CpuAir`).

        * [Fibonacci](https://github.com/starkware-libs/stone-prover/blob/3d5bb8bd991b7809a6d379c123c902667bac600f/src/starkware/statement/fibonacci/fibonacci_statement.inl#L40-L52): the transcript is initialized with `claimed_index_in_64_bit_big_endian || claimed_value_in_montgomery_form`
        * [Cairo](https://github.com/starkware-libs/stone-prover/blob/3d5bb8bd991b7809a6d379c123c902667bac600f/src/starkware/statement/cpu/cpu_air_statement.cc#L99): the transcript is initialized with the `n_steps`, `rc_min`, `rc_max`, and the public memory. The layout is described [here](https://github.com/starkware-libs/stone-prover/blob/3d5bb8bd991b7809a6d379c123c902667bac600f/src/starkware/statement/cpu/cpu_air_statement.cc#L127-L135).

### Logging interactions

The flag `-generate_annotations` can be enabled when the main prover is executed. This logs the interactions between the prover and the verifier and can help debug and address compatibility issues. The annotations are added to the output JSON file of the proof.

![](/images/external/r15g0-BAn.png)

### Hash functions

By default, the `keccak256` hash function is used.

This is the list of supported options:
    
    using HashTypes = InvokedTypes<
        Blake2s256, Keccak256, Pedersen, MaskedHash<Keccak256, 20, true>,
        MaskedHash<Blake2s256, 20, true>, MaskedHash<Blake2s256, 20, false>,
        MaskedHash<Keccak256, 20, false>>;
    

## Composition polynomial

[Here](https://gist.github.com/schouhy/64fd2fca56e6776d16eb8df3437a0816) is an example of how to instantiate a composition polynomial and compute evaluations of it. It can be run like the Fibonacci example.

### Relevant classes

        * [`CompositionPolynomial`](https://github.com/starkware-libs/stone-prover/blob/3d5bb8bd991b7809a6d379c123c902667bac600f/src/starkware/composition_polynomial/composition_polynomial.h#L55): Abstract class defining interface. It has only two child classes 
          * [`CompositionPolynomialImpl`](https://github.com/starkware-libs/stone-prover/blob/3d5bb8bd991b7809a6d379c123c902667bac600f/src/starkware/composition_polynomial/composition_polynomial.h#L81): Concrete implementation of the above. It does NOT follow the pimpl pattern. It's just a child class.
          * `CompositionPolynomialMock`: Used for testing.
        * [`CompositionOracleProver`](https://github.com/starkware-libs/stone-prover/blob/3d5bb8bd991b7809a6d379c123c902667bac600f/src/starkware/stark/composition_oracle.h#L44): A wrapper around a `CompositionPolynomial` that also knows the polynomial interpolating the trace (called `traces`), the domains of interpolation, and the transcript.

### Notes

Despite the name, the class `CompositionPolynomialImpl` is not responsible for the actual computation of the composition polynomial. It does not handle the logic of collecting all individual evaluations of the constraints and gluing them together to form the composition poly. It handles parallelization and formats all inputs to pass them to `Air::ConstraintsEval`. This is the method where constraints are both evaluated **and** aggregated to obtain the evaluation of the composition polynomial. So, every implementation of `Air` is responsible for the correct aggregation step of all the constraint evaluations.

Two things stand out:

        * There is no degree adjustment. This is seen in the [Fibonacci Air](https://github.com/starkware-libs/stone-prover/blob/3d5bb8bd991b7809a6d379c123c902667bac600f/src/starkware/air/fibonacci/fibonacci_air0.inl#L83-L164) and the [Cairo Air](https://github.com/starkware-libs/stone-prover/blob/3d5bb8bd991b7809a6d379c123c902667bac600f/src/starkware/air/cpu/board/cpu_air_definition0.inl#L302-L309).
        * The coefficients used to aggregate all terms [are all powers of a single challenge](https://github.com/starkware-libs/stone-prover/blob/3d5bb8bd991b7809a6d379c123c902667bac600f/src/starkware/stark/stark.cc#L44-L58).

### Evaluation

For computing the composition polynomial evaluations, the prover calls [`CompositionOracleProver::EvalComposition(n_tasks)`](https://github.com/starkware-libs/stone-prover/blob/3d5bb8bd991b7809a6d379c123c902667bac600f/src/starkware/stark/stark.cc#L327C49-L327C49). This will return the set of evaluations of the composition polynomial in the $d$ cosets, where $d$ is chosen as the minimum integer such that the degree bound of the composition polynomial is less than $2^n d$ (see the Domains section for details about domains and cosets). The oracle then uses its pointers to the trace polynomials to evaluate them at the LDE domain (or use cached computations from the previous commitment phase). The oracle then passes this to `CompositionPolynomial::EvalOnCosetBitReversedOutput()` along with coset offsets and other domain relevant data. This method launches multiple tasks that call `Air::ConstraintEval` to compute a single evaluation at a point of the LDE. This is the method where the computation is ultimately done.

### Breaking the composition polynomial

The composition polynomial $H$ is always broken into $d = \deg(H) / 2^n$ parts, where $2^n$ is the trace length,

$$H = H_0 ( X^d ) + X H_1 ( X^d ) + \cdots + X^{ d - 1 } H_{ d - 1 }( X^d ).$$

To do so, after computing the evaluation of $H$, one way to calculate each $H_i$ would be to interpolate $H$ and then split its coefficients on a monomial basis. [The approach](https://github.com/starkware-libs/stone-prover/blob/3d5bb8bd991b7809a6d379c123c902667bac600f/src/starkware/composition_polynomial/breaker.cc#L64-L66) in the Stone prover is an optimization of this. Instead of running a full IFFT to interpolate $H$, they do only $\log(d)$ steps of IFFT, resulting in the evaluations of each $H_i$ if $d$ is a power of two.

## DEEP composition polynomial

One strange design choice is reusing the AIR and composition polynomial machinery to build the **DEEP** composition polynomial. The deep composition polynomial is seen as a composition polynomial of a particular AIR, called `BoundaryAIR` (see [here](https://github.com/starkware-libs/stone-prover/blob/3d5bb8bd991b7809a6d379c123c902667bac600f/src/starkware/stark/stark.cc#L349-L370) and [here](https://github.com/starkware-libs/stone-prover/blob/3d5bb8bd991b7809a6d379c123c902667bac600f/src/starkware/air/boundary/boundary_air.h#L34)). It has nothing to do with boundary constraints. It is only used for building the DEEP composition poly. It is the same class, independently of whether the FibonacciAIR, CpuAir or any other AIR is being used to arithmetize the program being proven. The deep composition polynomial is called [`oods_composition_oracle`](https://github.com/starkware-libs/stone-prover/blob/3d5bb8bd991b7809a6d379c123c902667bac600f/src/starkware/stark/stark.cc#L450) in the main [`ProveStark`](https://github.com/starkware-libs/stone-prover/blob/3d5bb8bd991b7809a6d379c123c902667bac600f/src/starkware/stark/stark.cc#L383) method.

A side effect of this is cluttering the annotations. It looks like the verifier chooses two times the challenge used for building the composition polynomial:
    
    ...
    V->P: /STARK/Out Of Domain Sampling: Constraint polynomial random element
    ...
    V->P: /STARK/Out Of Domain Sampling: Constraint polynomial random element
    

The first time refers to the challenge of the composition polynomial. The second time refers to the challenge to build the DEEP composition polynomial.

## Commitment Scheme

        * [Here's](https://gist.github.com/ajgara/c9ef34a8b2af614db026dc56c929509b) an example Python code.

The commitment algorithm is simple at its core, but many classes interact with each other to produce a commitment. Also, there are settings and other factors that can change the way the commitment is made. For example, the trace evaluated at the LDE may not fit into RAM due to its size, changing the commitment strategy. Let's first analyze the core algorithm, assuming the LDE fits in RAM and no special settings are used.

The strategy here is to build a Merkle tree. To produce this Merkle tree, we need to know how to make the leaves of the tree and how to merge two nodes into a node for the next layer.

Suppose we want to commit the following trace:

Evaluations of column 1 on LDE | Evaluations of column 2 on LDE  
---|---  
$t_0 ( wh^0 g^0 )$ | $t_1 ( wh^0 g^0 )$  
$t_0 ( wh^0 g^1 )$ | $t_1 ( wh^0 g^1 )$  
$t_0 ( wh^0 g^2 )$ | $t_1 ( wh^0 g^2 )$  
$t_0 ( wh^0 g^3 )$ | $t_1 ( wh^0 g^3 )$  
$t_0 ( wh^1 g^0 )$ | $t_1 ( wh^1 g^0 )$  
$t_0 ( wh^1 g^1 )$ | $t_1 ( wh^1 g^1 )$  
$t_0 ( wh^1 g^2 )$ | $t_1 ( wh^1 g^2 )$  
$t_0 ( wh^1 g^3 )$ | $t_1 ( wh^1 g^3 )$  
  
We refer to the Domains section for domain details and cosets. The whole LDE domain is shifted by $w$, the powers of $h$ denote in which coset the value sits, and the powers of $g$ denote the index inside that coset. Before committing the trace, the stone prover permutes the order of the rows.

First, the cosets are permutated following [bit reverse order](https://en.wikipedia.org/wiki/Bit-reversal_permutation). For example, if we had:
    
    | coset 1 | coset 2 | coset 3 | coset 4 |
    

Applying the bit reverse permutation:
    
    | coset 1 | coset 3 | coset 2 | coset 4 |
    

Then, the bit reverse order is applied again but inside each coset separately. The final permuted trace would look like this:

Evaluations of column 1 on LDE | Evaluations of column 2 on LDE  
---|---  
$t_0 (wh^0 g^0 )$ | $t_1 (wh^0 g^0 )$  
$t_0 (wh^0 g^2 )$ | $t_1 (wh^0 g^2 )$  
$t_0 (wh^0 g^1 )$ | $t_1 (wh^0 g^1 )$  
$t_0 (wh^0 g^3 )$ | $t_1 (wh^0 g^3 )$  
$t_0 (wh^1 g^0 )$ | $t_1 (wh^1 g^0 )$  
$t_0 (wh^1 g^2 )$ | $t_1 (wh^1 g^2 )$  
$t_0 (wh^1 g^1 )$ | $t_1 (wh^1 g^1 )$  
$t_0 (wh^1 g^3 )$ | $t_1 (wh^1 g^3 )$  
  
In this case, we only have two cosets, so applying the bit reverse order does nothing, and the two cosets stay in the same place. Then, the elements inside each coset are reordered. Now that we have the correct order, we can start building the leaves of the Merkle tree.

Each leave will correspond to one row. This is because each time the prover opens $t_i(z)$, it will open all of the other columns $t_j(z)$ at the same value $z$, so it makes sense to store them at the same leaf and using the same authentication path for them.

If each column has $|LDE|$ rows, we'll have $|LDE|$ leaves, each with its hash. The $i$-th leaf is the hash that results from hashing the concatenation of all the columns at the $i$-th row. So, for example, the first leaf in this case is $H( t_0 (w h^0 g^0 ) || t_1 ( w h^0 g^0 ))$.

Note that the stone prover stores its field elements in Montgomery form to enhance the performance of its operations. When using the bytes of a field element to hash them, the field element stays in the Montgomery form (it is not translated to standard format). Also, the limbs representing the field element are stored from least significant at position 0 to most significant at the end.

Now that we have the leaves, our first layer of the tree, we can build the next layer by merging nodes. To do this, the Stone Prover connects two consecutive nodes by concatenating their hashes and obtaining the hash of the new parent. Repeating this operation halves the number of nodes at each step until the Merkle tree is complete.

For a simple example, check out the [python code](https://gist.github.com/ajgara/c9ef34a8b2af614db026dc56c929509b).

Check out the Fibonacci [example](https://gist.github.com/schouhy/216f5de449481701d36ab99df86bc081#file-fibonacci_stone_prover-cc-L136-L144) to see how to instantiate the classes relevant to commitments.

### TableProver

The `TableProver` abstract class and its implementation `TableProverImpl` are high-level interfaces for dealing with commitments and decommitments of 2-dimensional arrays of field elements. It consists mainly of a commitment scheme but also has a pointer to a ProverChannel to send and receive elements from the verifier.

There is a [TableProverFactory](https://github.com/starkware-libs/stone-prover/blob/3d5bb8bd991b7809a6d379c123c902667bac600f/src/starkware/commitment_scheme/table_prover.h#L102-L109) and a [utils function](https://github.com/starkware-libs/stone-prover/blob/3d5bb8bd991b7809a6d379c123c902667bac600f/src/starkware/stark/utils.inl#L26-L30) to instantiate it. There's also a helper used in [tests](https://github.com/starkware-libs/stone-prover/blob/3d5bb8bd991b7809a6d379c123c902667bac600f/src/starkware/stark/stark_test.cc#L64-L72).

The `TableProverImpl` has a [`Commit`](https://github.com/starkware-libs/stone-prover/blob/3d5bb8bd991b7809a6d379c123c902667bac600f/src/starkware/commitment_scheme/table_prover_impl.cc#L117) method that in turn calls the `Commit` method of its `commitment_scheme_` member, which is a pointer to a `CommitmentSchemeProver`.

### CommitmentSchemeProver

[This class](https://github.com/starkware-libs/stone-prover/blob/3d5bb8bd991b7809a6d379c123c902667bac600f/src/starkware/commitment_scheme/commitment_scheme.h#L67) implements the logic of the commitment scheme.

There is a commitment scheme [builder](https://github.com/starkware-libs/stone-prover/blob/3d5bb8bd991b7809a6d379c123c902667bac600f/src/starkware/commitment_scheme/commitment_scheme_builder.inl#L177-L195) that calls another method [here](https://github.com/starkware-libs/stone-prover/blob/3d5bb8bd991b7809a6d379c123c902667bac600f/src/starkware/commitment_scheme/commitment_scheme_builder.inl#L56-L70) that constructs a `CommitmentSchemeProver` by [alternately calling](https://github.com/starkware-libs/stone-prover/blob/3d5bb8bd991b7809a6d379c123c902667bac600f/src/starkware/commitment_scheme/commitment_scheme_builder.inl#L106-L124) `PackagingCommitmentSchemeProver` and `CachingCommitmentSchemeProver`.

#### Segments

There are several details to consider when dealing with traces or LDEs that are so large they do not fit into RAM.

Evaluations of a polynomial over the LDE are split into segments. Each segment contains a continuous subset of the rows. One Merkle tree is built for each part. Then, another Merkle tree is built on top of that, where the leaves are the roots of the Merkle trees of each segment.

Two comments help a bit in understanding [here](https://github.com/starkware-libs/stone-prover/blob/3d5bb8bd991b7809a6d379c123c902667bac600f/src/starkware/commitment_scheme/commitment_scheme.h#L47-L55) and [here](https://github.com/starkware-libs/stone-prover/blob/3d5bb8bd991b7809a6d379c123c902667bac600f/src/starkware/commitment_scheme/commitment_scheme_builder.inl#L63-L65)

### CachingCommitmentSchemeProver

The prover may want to store the entire MerkleTree once it's committed so that when openings are performed, there's no need to recalculate them. However, if this is too memory-consuming, the prover might choose not to store it and recalculate it later on. The [CachingCommitmentSchemeProver](https://github.com/starkware-libs/stone-prover/blob/3d5bb8bd991b7809a6d379c123c902667bac600f/src/starkware/commitment_scheme/caching_commitment_scheme.h#L31-L40) implements this logic.

### PackagingCommitmentSchemeProver

It has an inner commitment scheme, which separates things into packages and passes them to the internal commitment scheme.

## FRI

The FRI part is responsible for generating the FRILayers, generating the query points, and producing the proof. The proof consists of several elements from the Merkle trees from every layer, plus inclusion proofs (authentication paths).

The [Frifolder](https://github.com/starkware-libs/stone-prover/blob/main/src/starkware/fri/fri_folder.h) takes two evaluations from the previous layer and computes an evaluation of the current layer using the `FriFolderBase` class. The FRI protocol allows one to commit to a certain subgroup of layers (for example, every second layer). There is the possibility of varying the number of layers one commits to, but this makes the logic more complicated. The recommendation is to commit every third layer in this [issue](https://github.com/starkware-libs/stone-prover/issues/4). However, the FRI step vector makes it harder for a new user to work with the prover and we don't believe it particulary offers an advantage in performance.

The protocol distinguishes between data and integrity queries; if an evaluation is part of the integrity queries, it is not supplied as part of the proof. This is because the integrity query can be deduced from elements from the previous layers. We don't need to check the value directly; if we correctly computed the value, the inclusion proof should pass. More concretely, if the prover sends the values corresponding to $p_k ( x_i )$ and $p_k ( - x_i )$, the verifier can compute $p_{ k + 1 }( x_i^2 )$. This value is needed to check the inclusion proof in the Merkle tree; if we use a wrong value, the validation should fail (unless there is a collision for the hash function).

The protocol finishes when the size of a layer is smaller than a threshold value; the prover supplies the polynomial representing those evaluations by performing an interpolation over those values. This optimization reduces the proof length, as we avoid sending several values from many Merkle trees and their authentication paths.

The protocol is optimized for proof size since it avoids sending unnecessary information from the integrity queries, the pairs of values are grouped in the same branch in the Merkle tree, and the protocol finishes before reaching degree zero.

## Conclusions

In this post, we covered different components of the Stone prover, how they work, and some of their consequences in proof size. Starkware has done a great job developing the prover and open-sourcing it. There a few parts that still need an improvement but that is always the case with software.

We are currently working towards achieving compatibility between Stone and STARK Platinum. To reach this goal, we need to adapt different parts so that the challenges we generate are the same and the proof we get (from sampling the queries) and its serialization and deserialization are precisely the same. We will continue explaining how the Stone Prover works and the optimizations we are adding to STARK Platinum to enhance its performance while maintaining compatibility.
