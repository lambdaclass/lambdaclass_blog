+++
title = "Verified Code Optimization in Lean 4: How Equality Saturation Generates Proven-Correct C Code with Truth Research ZK"
date = 2026-02-16
slug = "verified-code-optimization-in-lean-4"
description = "Verified Code Optimization in Lean 4: How Equality Saturation Generates Proven-Correct C Code with Truth Research ZK"

[extra]
feature_image = "/images/2026/An_Experiment_on_a_Bird_in_an_Air_Pump_by_Joseph_Wright_of_Derby-_1768.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["Lean", "Zero Knowledge"]
+++

# Verified Code Optimization in Lean 4: How Equality Saturation Generates Proven-Correct C Code with Truth Research ZK

Our experiments with Lean and formal verification continue to bear fruit. 
To further our knowhow and experience, we set out to see if we could apply Lean's strengths to a more advanced topic: compiler optimizations.

Traditional verified compilers focus on semantic preservation of already-written C code, limiting their ability to perform radical algorithmic optimizations. 
On the other hand, domain-specific code generators produce extremely efficient code but lack formal correctness guarantees integrated into the proof assistant. 
In our exploration of the Lean programming language, we started building an optimization engine that combines both traditions: the system compiles algebraic theorems from Mathlib into rewrite rules that feed a purely functional equality saturation engine, and emits C code with SIMD intrinsics accompanied by formal traceability annotations.

The result is Truth Research ZK, a verified optimizer that transforms mathematical specifications written in Lean 4 into optimized C and Rust code with formal correctness guarantees. 
Every applied transformation has a corresponding Lean proof, and where the emitted code can be audited against the formally verified logic. 

In this article we'll discuss the architecture and pipelining of [Truth Research ZK](https://github.com/lambdaclass/truth_research_zk), a first stab at Automatic Formal Optimization.

## 1. An algebraic DSL lifted to type theory

### What is a DSL and why we need one

A DSL (*Domain-Specific Language*) is a programming language designed for a specific domain or context, in contrast to a general-purpose language like Rust or C. A DSL does not need to handle threads, I/O, or memory management — it only needs to precisely express the operations of its domain. In exchange for this restriction, it gains a property: the compiler can reason exhaustively about programs written in it, because the space of possible programs is bounded and structured.

In Truth Research ZK, the DSL is a Lean 4 inductive type called `MatExpr`; primarily because this exploration began with the possibility of applying the ideas of Formal Verification to optimizing Lean specifications of programs involving matrices, linear algebra and eventually, elements of the FRI protocol. `MatExpr` is then the intermediate representation on which the entire system operates: rewrite rules are applied on it and it is then translated to C code. A program in this DSL does not describe *how* to compute say, a transform or perform vector addition — it describes *what* transform it is, as an algebraic formula. The optimizer is responsible for deriving the *how*.

For readers familiar with `enum`s in Rust, a Lean inductive type is conceptually similar: it defines a closed type with a finite set of *variants* (called **constructors**). The difference is that in Lean, constructors can be **indexed by values** — the matrix dimensions are part of the type, not runtime data. For instance, Truth Research ZK's DSL defines `MatExpr α m n`: a matrix expression over a coefficient type `α`, with `m` rows and `n` columns. Some of the constructors implemented are

```lean
inductive MatExpr (α : Type) : Nat → Nat → Type where
  | identity (n : Nat) : MatExpr α n n             -- I_n
  | dft (n : Nat) : MatExpr α n n                  -- Symbolic DFT
  | ntt (n p : Nat) : MatExpr α n n                -- NTT over Z_p
  | twiddle (n k : Nat) : MatExpr α n n            -- Twiddle factors
  | perm : Perm n → MatExpr α n n                  -- Permutation
  | kron : MatExpr α m₁ n₁ → MatExpr α m₂ n₂      -- A ⊗ B
         → MatExpr α (m₁ * m₂) (n₁ * n₂)
  | compose : MatExpr α m k → MatExpr α k n        -- A · B
            → MatExpr α m n
  | add : MatExpr α m n → MatExpr α m n            -- A + B
        → MatExpr α m n
  -- ... and others
```

One of the things to note regarding the characteristics of Lean 4 is that **dimensions are part of the type:** `compose` only accepts matrices where the inner dimension $k$ matches — $A_{m \times k} \cdot B_{k \times n}$. Lean rejects a composition with incompatible dimensions at compile time. This is impossible to express in a Rust `enum` without resorting to `PhantomData` and complex trait bounds.

### Optimizations as factorizations in matrix algebra

To understand the DSL of choice, one must first learn about [SPIRAL](https://www.spiral.net/), a well-established and long-standing project from Carnegie Mellon University that tackles a specific problem: generating highly optimized code for linear transforms (FFT, NTT, DCT, WHT) without writing implementations by hand. The core idea is that all these transforms can be represented as special products of structured sparse matrices, and that optimizations — reordering operations, vectorizing, improving cache locality — are equivalent to applying algebraic identities on those matrices. **SPIRAL's insight is that an FFT of size $N$ is not an algorithm: it is a factorization through the Kronecker product,** an arcane idea that endured time and now finds a place in modern applications. If $A$ is $m \times m$ and $B$ is $n \times n$, then $A \otimes B$ is an $(mn) \times (mn)$ matrix that applies $A$ to "blocks" and $B$ within each block. The Cooley-Tukey identity makes this explicit:

$$DFT_{mn} = (DFT_m \otimes I_n) \cdot T_n^{mn} \cdot (I_m \otimes DFT_n) \cdot L_n^{mn}$$

This expresses: to compute a DFT of size $m \times n$, apply a stride permutation ($L$), then $m$ copies of $DFT_n$ applied to contiguous blocks ($I_m \otimes DFT_n$), then multiply by twiddle factors ($T$), then $n$ copies of $DFT_m$ applied across strided groups ($DFT_m \otimes I_n$).

Each factor is a sparse matrix with exploitable structure. In terms of code and computers, $I_m \otimes A_n$ is a `for` loop of $m$ iterations applying $A$ to contiguous segments of size $n$; alternatively $A_m \otimes I_n$ is the same operation but with interleaved (*strided*) data. The operator $L_n^{mn}$ (stride permutation) models memory reorderings. Concretely, it maps index $i$ to $(i \bmod m) \cdot n + \lfloor i / m \rfloor$, which is the transpose of an $m \times n$ matrix stored in row-major order.

Since we are looking for a prospective Formal Optimizer capable of certifying FRI code, SPIRAL became a natural and attractive candidate and adopted some of its principles:

1. **Representation**: transforms are matrix formulas, not imperative code.
2. **Optimization by algebraic rewriting**: optimizing means applying identities (Cooley-Tukey, stride factorization, Kronecker distribution).
3. **Lowering pipeline**: the algebraic formula is lowered to a Σ-SPL intermediate representation with explicit loops, and from there to C with SIMD.

One of the contributions of Truth Research ZK can be explained by a problem it overcomes: in SPIRAL the algebraic identities are axioms *hardcoded* in the compiler (written in GAP/OCaml). If an identity has an error, the compiler silently generates incorrect code. But for our Formal Optimizer, **each identity is a theorem verified by the Lean 4 kernel** and as we've discussed, logic errors are caught at compile time.

At the time of writing this article, there is one exception: the tensor product of permutations requires a computationally verifiable axiom (`applyIndex_tensor_eq`) due to a limitation of the Lean 4 kernel with the *splitter* for indexed inductive types. The axiom states that `applyIndex (tensor p q) i` computes the same result as an auxiliary function `applyTensorDirect` — both definitions are algorithmically identical, but Lean cannot automatically generate the equation for pattern matching over the indexed type `Perm n`. The axiom is exhaustively validated by `#eval` for all concrete sizes used in the system.

## 2. So, how do you optimize formally?

### The basic objects: e-graphs

Formal Optimization is achieved by adopting a technique called Equality Saturation applied to e-graphs. In order to understand what all this means, one must first understand the problem we want to solve.

Consider an optimizer with two rules: $a \times 1 \to a$ and $a \times (b + c) \to a \times b + a \times c$. Given the expression $x \times (1 + y)$, a conventional rewriter must choose which rule to apply first. If it applies distribution, it gets $x \times 1 + x \times y$, and can then simplify to $x + x \times y$. But if another rule directly simplified $1 + y$, the decision to distribute first might have been suboptimal. The problem is that conventional rewriting is **destructive**: applying a rule discards the original expression. The result depends on the application order, and finding the optimal order is in general an exponential search problem. 

E-Graphs offer a better solution by *simultaneously* representing all equivalent forms of an expression. It is a data structure that stores a set of expressions grouped into **equivalence classes**: if two expressions have been proven equal, they belong to the same class.

Concretely, an E-Graph has two components:

1. **E-Nodes**: represent operations. An e-node for $a + b$ stores the operator `+` and references to the *classes* of $a$ and $b$ (not to concrete nodes). This is key: since children point to classes, not to specific expressions, a single e-node for `+` implicitly represents the sum of *any* pair of representatives of those classes.

2. **E-Classes**: sets of e-nodes that have been proven equivalent. When a rewrite rule establishes that $e_1 = e_2$, the e-nodes of $e_1$ and $e_2$ are merged into the same class.

**Equality saturation** is then the process of applying *all* rewrite rules exhaustively until none produces new equivalences or a limit is exceeded. The result is not an optimal expression — it is an E-Graph containing *all* discovered equivalent expressions; we shall call it a "Saturated E-Graph". Concretely, this runs through a pure function (`Saturate.lean`):

```lean
def saturate (g : EGraph) (rules : List RewriteRule)
    (config : SaturationConfig) : SaturationResult
```

The E-Graph goes in, the saturated E-Graph comes out. Each iteration applies all rules over all classes, instantiates the right-hand sides that match, merges the corresponding classes, and restored invariants. The process terminates when a fixed point is reached or a configurable limit on nodes/iterations is exceeded.

A subsequent **extraction** phase selects the best one according to a pre-selected cost model. 

This is a broad strokes description of the idea behind our implementation of formal optimization: there are obvious aspects related to the limitations of Lean and C that must be taken into account.

Lean understands math but does not understand **memory**. The standard reference implementation of E-Graphs is [`egg`](https://egraphs-good.github.io/), written in Rust. `egg` uses `Vec<T>` with indices as implicit pointers, leveraging Rust's controlled mutability for efficient merge operations. However, implementing the same structure in Lean 4 — a pure functional language — presents distinct design challenges. Lean guarantees referential purity: there is no observable mutation, no pointers, no aliasing. This is what enables the Lean kernel to verify proofs, but it also means that cyclic or densely linked data structures must be designed carefully to avoid excessive pressure on memory management. 

In order to do this, Truth Research ZK avoids recursive inductive structures (trees, linked lists of nodes) that would be the idiomatic choice in Lean. Instead, it uses an architecture of **flat hash tables with integer indices** — conceptually closer to an ECS (*Entity-Component-System*) than to a functional graph: now nodes are flat data: they encode operations and the type of its children, containing no recursive substructures. E-nodes now comprise equivalent expressions, enabling $O(1)$ equivalence checks by integer identifier comparison. These equivalence classes are managed via a union-find. Lean 4 internally implements a *reference counting* mechanism: when an `Array` has a single owner (refcount = 1), operations like `set!` mutate in-place without copying. This provides performance comparable to the mutable case for the union-find usage pattern, where the array is modified sequentially within a function.

This architecture avoids cycles in the heap and maintains the referential purity required by the Lean kernel. The matrix E-Graph (`EGraph/Vector.lean`) extends this same design with `MatENodeOp` nodes that include Kronecker products, permutations, twiddle factors, and transposition operations as first-class variants.

Of course, there are rules that threaten to grow the E-Graph indefinitely. Commutativity ($a + b \to b + a$) applied once produces a new expression; applied again, it regenerates the original; and so on in an infinite cycle. Truth Research ZK implements two strategies in `Optimize.lean`:

1. **Directed rules**: Each `OptRule` has a classification (`.reducing`, `.structural`, `.expanding`) and a `costDelta` that estimates whether the rule reduces or increases the expression's cost. Only *reducing* rules are in the safe set by default.
2. **Canonical ordering**: For commutative operations, a deterministic structural hashing (`exprHash`) imposes a preferred ordering on operands: if `hash(a) > hash(b)`, only `a + b` is stored, never `b + a`. This eliminates the need for a bidirectional commutativity rule. The tradeoff is explicit: theoretical completeness is sacrificed (the E-Graph will not explore *all* possible commuted forms) in exchange for guaranteed termination. In practice, for the signal processing optimizations we target, this tradeoff is acceptable.


## 3. The role of metaprogramming

In most compilers, optimizations ($x \times 0 \to 0$, factorization, distribution) are implicit assumptions in the compiler's code. If a rule is incorrect, the compiler silently produces wrong code. There is no mechanism within the compiler to *prove* that the transformation preserves program meaning. In Truth Research ZK, every rewrite rule has a corresponding Lean theorem proving preservation of denotational semantics. And the mechanism that connects those theorems to the optimizer — the one that converts formal proofs into executable rules — is the metaprogramming monad `MetaM` which gives access to the metavariable context, i.e. the set of metavariables that are currently declared and the values assigned to them.

### Structure of a verified rule

As defined in `VerifiedRules.lean`, a rule consists of:

1. A syntactic pattern (LHS → RHS).
2. A formal theorem of semantic equality:
   $$\forall \, \texttt{env}, \; \texttt{eval}(\texttt{env}, \texttt{LHS}) = \texttt{eval}(\texttt{env}, \texttt{RHS})$$

For example, distributivity:

```lean
theorem distrib_left_correct (env : VarId → Int) (a b c : Expr Int) :
    eval env (.mul a (.add b c)) = 
    eval env (.add (.mul a b) (.mul a c)) := by 
  simp only [eval]
  ring
```

The structure of this proof is representative. The `eval` function is the **denotational semantics** of the DSL: it translates a syntactic expression (`Expr Int`) to its semantic value (`Int`) given a variable environment. The `simp only [eval]` unfolds the recursive definition of `eval`, reducing both sides to pure arithmetic expressions over integers. The `ring` tactic — provided by Mathlib — closes the goal automatically because the resulting equality is a ring identity.

The simpler proofs (identities involving 0 and 1) use Mathlib lemmas directly; ring properties (distributivity, associativity) are closed with `ring`. Power proofs require induction over lists. Truth Research ZK does not reimplement arithmetic: it *imports* existing Mathlib lemmas and uses them as the foundation of correctness.

### MetaM: what it is and what it enables

The ability to **automatically convert theorems into rewrite rules** is the component that distinguishes Truth Research ZK from a conventional optimizer that merely *has* proofs. To understand why this matters, consider the alternative: without metaprogramming, each optimizer rule is written by hand twice: once as `Pattern → Pattern` for the E-Graph, and once as a theorem for the correctness proof. If the two definitions diverge — if the pattern says `a * (b + c) → a*b + a*c` but the theorem proves something else — the system is inconsistent without anyone noticing. This is exactly the kind of subtle error that formal verification should prevent.

As mentioned, `MetaM` is Lean 4's metaprogramming monad, a concept that encapsulates a computation pattern; in this case, `MetaM` encapsulates computations that have access to *Lean's compiler internal state*. Concretely, a function operating in `MetaM` can:

- **Query the environment**: Access all definitions, theorems, and axioms loaded in the current context. This includes all of Mathlib. The function `getConstInfo name` returns the complete declaration of any constant by its name — its type, its body, its universe levels.

- **Inspect the internal representation of expressions**: In Lean, everything — types, terms, proofs — is represented as values of type `Lean.Expr`. An expression like `a + b = b + a` is internally an application of `@Eq` to a type, with subexpressions that are applications of `@HAdd.hAdd` with type arguments and typeclass instances. `MetaM` allows navigating this structure, decomposing it, and reconstructing it.

- **Open quantifiers**: A theorem like `∀ (a b : α), a + b = b + a` in its internal representation is a chain of `Lean.Expr.forallE`. The function `forallTelescope` opens all quantifiers simultaneously, creating fresh free variables for each one and exposing the equality body. This allows inspecting the LHS and RHS of the conclusion without having to manually parse the chain of `forallE`.

- **Resolve metavariables**: `instantiateMVars` substitutes pending metavariables (unknowns) in an expression with their assignments. This is necessary because Lean's elaborator may leave metavariables unresolved during incremental elaboration.

### Application

The module `Meta/CompileRules.lean` defines a monad transformer `ConvertM := StateT ConvertState MetaM` that combines MetaM with its own state for variable tracking. The complete pipeline for converting a theorem into a rewrite rule is:

1. **Obtain the theorem's type**: we first retrieve the declaration: the type of a theorem *is* its statement — for example, the type of `distrib_left_correct` is `∀ env a b c, eval env (.mul a (.add b c)) = eval env (.add (.mul a b) (.mul a c))`.

2. **Open the quantifiers**: `forallTelescope type fun args body` opens all the `∀`s and exposes `body`, which is an equality `Eq lhs rhs`.

3. **Extract LHS and RHS**: `extractEqualityFromExpr` uses `e.eq?` — a MetaM helper that recognizes the structure `@Eq.{u} α lhs rhs` — to obtain both sides of the equality.

4. **Convert to Pattern**:  the program recursively traverses the `Lean.Expr` of the LHS (and the RHS), recognizing applications of known functions.

5. **Emit the rule**: The result is a `RewriteRule` with name, LHS pattern, and RHS pattern, ready to be consumed by the E-Graph.

All of this is invoked with the `#compile_rules` command:

```lean
#compile_rules [distrib_left_correct, mul_one_right_correct, add_zero_left_correct]
```

The command iterates over the names, executes the pipeline for each one, and emits the compiled rules with a diagnostic log. If a theorem does not have the expected form (is not an equality, or uses unsupported operators), it emits a warning instead of failing silently.

### Advantages

To reiterate, one of the advantage of this approach is **structural consistency**: the rules that the E-Graph applies are mechanically extracted from the same theorems that prove their correctness. There is no possibility of divergence between "what the optimizer believes is correct" and "what is formally proven." If someone modifies a theorem in Mathlib or in the project, `#compile_rules` automatically extracts the new version.

Furthermore, **MetaM opens the door to generating rewrite rules from equality theorems in Mathlib without manual intervention.** The current `#compile_rules` pipeline supports the scalar DSL operators (addition, multiplication, exponentiation over `Expr Int`); extending it to the matrix-level DSL operators — Kronecker products, permutations, diagonal scalings — is work in progress. Within the scalar domain, any Mathlib identity that takes the form of an equality between expressions built from these operators is a potential optimization rule for the E-Graph.

### Rewriter correctness

The central correctness theorem (`Correctness.lean`) is structured in layers:

1. `applyFirst_sound`: if all rules in a list preserve semantics, applying the first one that matches also preserves semantics.
2. `rewriteBottomUp_sound`: bottom-up rewriting preserves semantics (by structural induction on the expression).
3. `rewriteToFixpoint_sound`: iteration to fixed point preserves semantics (by induction on fuel).
4. `simplify_sound`: the main simplification function preserves semantics, composing the previous lemmas with `algebraicRules_sound`.

This result is formally proven for the scalar rewriter. For the E-Graph engine, correctness reduces to the correctness of individual rules: since every rule applied during saturation has an independent proof, and the `merge` operation only adds equivalences without destroying nodes, the extracted result preserves the semantics of the input. The full formalization of this compositional argument for the E-Graph is work in progress.

As a practical safeguard, the code includes an audit function that verifies at compile time that each optimizer rule has a corresponding theorem. A `#guard` directive fails the build if the count of verified rules does not match the expected value, ensuring that no rule is accidentally added to the optimizer without a proof.

## 4. Code generation, cost model, and proof anchors

### From algebra to silicon

At this point, the E-Graph operates on `MatExpr`, which is a good language for algebraic reasoning but says nothing about memory layout, loop structure, or hardware. The generated C code, on the other hand, must describe exactly which memory addresses to read and write, in what order, and with what instructions. Something must bridge this gap — and the bridge cannot be informal, because this is precisely where subtle bugs hide. A Kronecker product $I_m \otimes A_n$ looks simple as algebra, but its implementation requires deciding between block-contiguous and strided access patterns, each with different cache behavior.

Code generation follows SPIRAL's three-stage design, each stage trading abstraction for executability:

1. **MatExpr → Σ-SPL** (`Sigma/Basic.lean`): Matrix formulas are lowered to the Sigma-SPL intermediate representation, which explicitly models memory access patterns. A Kronecker product $I_n \otimes A_m$ transforms into a loop: $\Sigma_{i=0}^{n-1} (S_{i,m} \cdot A \cdot G_{i,m})$, where $G$ is a *gather* (read with stride) and $S$ is a *scatter* (write with stride). A composition $A \cdot B$ becomes a sequential evaluation with a temporary buffer. This stage is where algebra meets memory.

2. **Σ-SPL → expanded Σ-SPL** (`Sigma/Expand.lean`): Symbolic kernels are expanded to elementary scalar operations. A DFT$_2$ becomes `y0 = x0 + x1, y1 = x0 - x1`. A Poseidon S-box $x^5$ becomes `t = x*x; t = t*t; y = t*x` — three multiplications via a square chain. The output is straight-line code in SSA form.

3. **Σ-SPL → C** (`Sigma/CodeGen.lean`, `Sigma/SIMD.lean`): The final code is emitted as scalar C or with SIMD intrinsics. Loops in Σ-SPL become `for` loops; temporary buffers become local arrays; gather/scatter patterns become indexed memory accesses. Vectorization follows SPIRAL's principle: $A \otimes I_\nu$ (where $\nu$ is the SIMD width) vectorizes trivially — each scalar operation becomes a SIMD operation.

The lowering from MatExpr to Σ-SPL has a formal correctness theorem (`lowering_algebraic_correct` in `AlgebraicSemantics.lean`), which states that running the lowered code produces the same result as evaluating the original matrix expression directly. This theorem is proven for 18 of 19 MatExpr constructors; the remaining case (the Kronecker product) requires a proof of the adjustBlock/adjustStride memory access patterns that is still in progress.

### Cost model and extraction

Once the E-Graph is saturated, the system contains a superposition of equivalent implementations. The original expression and all expressions discovered by rewrite rules coexist in the graph. Extracting the "best" requires a criterion: that is the cost model.

The `MatCostModel` is a parameterizable SIMD-aware structure (in our case, costs are assigned to each operation performed in a NTT implementation, but this part is completely customizable for different perspectives, appraisals and applications). As examples,

1. **Symbolic operations cost zero.** A `dft 1024` node generates no code by itself — it will be expanded in later pipeline stages. Assigning it zero cost in the E-Graph means the extractor will never prefer a premature expansion over the factored representation. This preserves the $O(\log N)$ structure that SPIRAL needs.

2. **Costs scaled by SIMD width.** The cost of twiddle factors and element-wise operations (`elemwise`) is divided by `simdWidth`. This reflects that an AVX2 vector multiplication processes 4 elements at the cost of one instruction. The consequence: when changing `simdWidth` from 4 to 8, the extractor automatically prefers factorizations with greater internal parallelism.

3. **Scalar fallback penalty.** The `scalarPenalty := 1000` is an explicit anti-pattern: if the E-Graph contains a variant requiring scalar expansion (without vectorization), the extractor avoids it at all costs. This steers the search without needing negative rules.

Now the extraction algorithm is a bottom-up iterative analysis (`computeCosts`): for each e-class, the cost of each node is evaluated as `localCost + Σ childCosts`, and the minimum-cost node is recorded. The process iterates until convergence or a maximum of 100 iterations, necessary because dependencies between classes can be circular.

This design has a property worth making explicit: **the cost model is the only unverified component that affects result quality.** The rewrite rules are formally proven — any expression extracted from the E-Graph is semantically correct. But the *optimality* of the generated code depends entirely on the costs reflecting hardware reality. An incorrect cost model produces correct but slow code.

### Proof Anchors

Truth Research ZK introduces the concept of *Proof Anchors* in the generated code.

The emitted C code includes structured annotations documenting the preconditions, postconditions, and invariants of each block:

```c
// PROOF_ANCHOR: fri_fold_parametric
// Preconditions:
//   - n > 0
//   - even, odd, out are non-null
//   - out does not alias even or odd (required for restrict)
// Postconditions:
//   - forall i in [0, n): out[i] == even[i] + alpha * odd[i]
//   - output array is fully initialized
```

These annotations create a traceability chain connecting the algebraic transformations verified in Lean to specific blocks of emitted code. They are not executable assertions nor end-to-end formal verification of the binary — they are structured documentation designed to facilitate human auditing and future integration with static verification tools.

The difference from an ad-hoc comment is that Proof Anchors are generated *systematically* by the codegen pipeline (controlled by the `includeProofAnchors` flag in the code generation configuration) and follow a parseable format, enabling external tools to extract them and cross-reference them against the Lean project's theorems.

A verified binary is useless if it is not auditable. Proof Anchors are Truth Research ZK's mechanism for making the distance between the formal proof and the executed code auditable.

## 5. Current status and where we at in the circle of trust

Truth Research ZK's architecture — a typed DSL, an E-Graph with verified rules, a parameterizable cost model, and a codegen pipeline with traceability — is not specific to the matrix domain. 
The components are separable, and the pattern that Truth Research ZK instantiates is general:

1. Define a DSL as a Lean inductive type (with denotational semantics).
2. Write rewrite rules as semantic preservation theorems.
3. Compile those rules to an E-Graph via MetaM.
4. Saturate, extract with a cost model, and emit code.

To apply this to a different domain, it suffices to replace `MatExpr` with another DSL and write the corresponding rules. 
The E-Graph, union-find, hashconsing, saturation, and extraction are generic — they assume nothing about the domain except that nodes have children and a cost.

This architecture is promising and we look forward to maturing it and expanding its application.
The most direct candidates are domains where known algebraic identities exist and where the "best" implementation depends on context (hardware, input size, required precision). 

Verified compilation is not a single problem — it is a chain of trust gaps, and different projects focus on different links in the chain. 

For instance, [**Peregrine**](https://peregrine-project.github.io/) provides a unified, verified middle-end for code *extraction* from proof assistants. Given a program already written and proven correct in Agda, Lean, or Rocq, Peregrine compiles it to an executable language (CakeML, C, Rust, OCaml) through a verified intermediate representation called λ□ (lambda box). Its concern is *faithful preservation*: ensuring that type and proof erasure do not alter the program's semantics.

**CertiCoq** is a verified compiler from Gallina — Coq's specification language — to Clight, a subset of C compilable by CompCert. Its pipeline applies standard compiler optimizations (inlining, closure conversion, dead code elimination) with machine-checked correctness proofs. Combined with CompCert, it yields a fully verified chain from Coq to assembly.

Both Peregrine and CertiCoq take a *program* and compile it faithfully. Truth Research ZK takes a *specification* and derives a program.
Given the algebraic formula $DFT_N$, Truth Research ZK discovers the Cooley-Tukey butterfly decomposition via equality saturation and lowers it to C with SIMD intrinsics — a qualitative transformation that neither Peregrine nor CertiCoq attempt, because it is not their job. Conversely, Truth Research ZK does not verify the C compiler or the extraction mechanism: it verifies the algebraic transformations that produce the C source.

These tools are composable. Truth Research ZK generates intentionally simple C (~300 lines, no dynamic allocation in the hot path, no function pointers, no recursion) — exactly the subset that CompCert handles well. In principle, a fully verified chain is possible: Truth Research ZK guarantees that the algebraic optimizations preserve the semantics of the mathematical specification; CompCert guarantees that the C compiler preserves the semantics of the generated source code. Together, they would close the trust gap from mathematical specification to verified binary.

| Project | Input | Transformation | Output |
|---------|-------|---------------|--------|
| **Peregrine** | Programs in Agda/Lean/Rocq         | Verified extraction (faithful)              | CakeML, C, Rust, OCaml |
| **CertiCoq**  | Programs in Gallina (Coq)          | Verified compilation (standard passes)      | Clight → assembly via CompCert |
| **Truth Research ZK**  | Algebraic specifications (MatExpr) | Verified optimization (equality saturation) | C with SIMD |

It is important to be explicit about what is formally verified and what is not: Truth Research ZK still and has a long way to go.

| Component | Status |
|---|---|
| Individual rewrite rules (E-Graph)      | 19/20 formally verified (0 sorry in module) |
| Scalar rewriter correctness             | Formally proven (`simplify_sound`, composing `rewriteToFixpoint_sound` with `algebraicRules_sound`) |
| E-Graph compositional correctness       | Valid informal argument; formalization in progress |
| Permutations (stride, bit-reversal)     | Formally verified (with 1 documented axiom for tensor product of permutations) |
| MatExpr → Σ-SPL lowering                | Formally proven for 18/19 constructors (`lowering_algebraic_correct`); Kronecker product case in progress |
| NTT algorithm (Cooley-Tukey = DFT spec) | Formally proven (`ct_recursive_eq_spec`, `ntt_intt_recursive_roundtrip`) |
| Lazy butterfly (Harvey optimization)    | Formally proven (`lazy_butterfly_simulates_standard`) |
| Generated C code vs. Lean specification | Validated by 2850+ tests (64/64 Plonky3 bit-exact, 120 pathological vectors, UBSan clean) |
| Proof Anchors                           | Traceability for auditing; not end-to-end mechanical verification |

Truth Research ZK does not claim or aim to be an end-to-end verified compiler at CompCert's level. 
The two tools close different gaps in the trust chain: CompCert guarantees that a C compiler preserves the semantics of source code when producing machine code; 
Truth Research ZK guarantees that the algebraic transformations producing the C source code preserve the semantics of the mathematical specification, and in principle they are composable.

What Truth Research ZK offers is an optimizer where the algebraic transformations — the part most prone to subtle errors — are formally verified, with explicit traceability down to the emitted code. 
Its architecture is portable: the pattern of typed DSL + verified rules + E-Graph + cost model does not assume matrix structure. 
Recent advances in optimal extraction (OOPSLA 2024), learned cost models (ASPLOS 2025), and E-Graphs for automated theorem proving (POPL 2026) suggest that the techniques described here converge with active research lines in compilers, formal verification, and machine learning.

Source code is available at [https://github.com/lambdaclass/truth_research_zk](https://github.com/lambdaclass/truth_research_zk).

## References

- Willsey et al., [*egg: Fast and Extensible Equality Saturation*, POPL 2021](https://dl.acm.org/doi/10.1145/3434304)
- Franchetti et al., [*SPIRAL: Code Generation for DSP Transforms*, Proceedings of the IEEE, 2005](https://ieeexplore.ieee.org/document/1386651)
- Zhang et al., [*egglog: Better Together: Unifying Datalog and Equality Saturation*, PLDI 2023](https://dl.acm.org/doi/10.1145/3591239)
- Goharshady et al., [*Fast and Optimal Extraction for Sparse Equality Graphs*, OOPSLA 2024](https://dl.acm.org/doi/10.1145/3689801)
- Cai et al., [*SmoothE: Differentiable E-Graph Extraction*, ASPLOS 2025](https://dl.acm.org/doi/10.1145/3669940.3707262)
- Yang et al., [*TENSAT: Equality Saturation for Tensor Graph Superoptimization*, MLSys 2021](https://arxiv.org/abs/2101.01332)
- Rossel et al., [*Towards Pen-and-Paper-Style Equational Reasoning in ITPs by Equality Saturation*, POPL 2026](https://goens.org/publications/rossel-popl-26/lean-egg.pdf)
- Wang et al., [*SPORES: Sum-Product Optimization via Relational Equality Saturation*, VLDB 2020](https://arxiv.org/abs/2002.07951)
- Panchekha et al., [*Herbie: Automatically Improving Floating Point Accuracy*, PLDI 2015](https://dl.acm.org/doi/10.1145/2737924.2737959)
- Singher & Itzhaky, [*Easter Egg: Equality Reasoning Based on E-Graphs with Multiple Assumptions*, FMCAD 2024](https://ieeexplore.ieee.org/abstract/document/10918355)
- Suciu et al., [*Semantic Foundations of Equality Saturation*, ICDT 2025](https://arxiv.org/abs/2501.02413)
- Yang et al., [*LeanDojo: Theorem Proving with Retrieval-Augmented Language Models*, NeurIPS 2023](https://arxiv.org/abs/2306.15626)
- Koehler et al., [*Guided Equality Saturation*, POPL 2024](https://dl.acm.org/doi/10.1145/3632900)
- Harvey, [*Faster arithmetic for number-theoretic transforms*, Journal of Symbolic Computation, 2014](https://www.sciencedirect.com/science/article/pii/S0747717113001181)
