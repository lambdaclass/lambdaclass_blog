+++
title = "If it compiles, it is correct (almost): an introduction to Lean 4 for ZK systems and Engineering"
date = 2026-01-29
description = "At LambdaClass, we explore Lean 4 as a formal verification tool for zero-knowledge proof systems. As the ZK ecosystem matures, correctness becomes paramount: a single bug in a zkVM or proof system can compromise the security of billions of dollars in assets."

[taxonomies]
tags = ["lean", "zero knowledge proofs", "formal verification"]

[extra]
authors = ["LambdaClass"]
feature_image = "/images/2026/Rene_Antoine_Houasse_-_Minerva_and_the_Triumph_of_Jupiter-_1706.jpg"
math = true
+++

## Introduction

At LambdaClass, we've been exploring Lean 4 as a tool for formal verification in zero-knowledge proof systems and in formalizing the [kernel of Concrete](https://federicocarrone.com/series/concrete/the-concrete-programming-language-systems-programming-for-formal-reasoning/). As the ZK ecosystem matures, the stakes for correctness have never been higher: a single bug in a zkVM or proof system can compromise the security of billions of dollars in assets. We've seen this play out repeatedly, such as subtle arithmetic errors, off-by-one mistakes in constraint systems, edge cases that evade thousands of test vectors. Audits help, but audits are human; they miss things. Tests tell you what didn't fail; proofs tell you what can't fail. 

This work is part of a broader effort at LambdaClass to bring formal methods into production systems. We're also developing Concrete, a systems programming language whose kernel is being formalized in Lean 4, designed from the ground up so that every design choice must answer the question: can a machine reason about this? The same rigor we apply to Concrete's type system applies to how we think about ZK infrastructure: correctness should be proven, not hoped for.

Why formal verification, and why now? Theorem provers have been around for decades, with systems like Coq and Isabelle producing landmark results like CompCert, seL4, and foundational mathematics formalization. But the gap between proving theorems and shipping production code remained wide. Lean 4 narrows that gap significantly: it's both a proof assistant and a modern programming language that compiles to efficient C. You can write your specification, prove it correct, and extract deployable code, all in the same system.

The timing is right: [Lean 4](https://lean-lang.org/) reached its stable release in 2023, and [Mathlib](https://leanprover-community.github.io/mathlib4_docs/), one of the largest formalized mathematics libraries—completed its port to Lean 4 in 2024. The [Ethereum Foundation has funded initiatives](https://blog.ethereum.org/2024/04/01/zk-grants-round) to formally verify zkVMs, recognizing that the complexity of these systems demands machine-checked proofs, not just tests and audits.

This article is our attempt to share what we've learned with the curious and newcomers. We'll cover the theoretical foundations that make Lean 4 powerful (the Curry-Howard isomorphism), show why this matters for writing correct software, and conclude with a practical example: formally verifying an addition constraint that's common in ZK systems.

## Lean 4: from Sets to Types

So, what is Lean 4? Like a many-faceted jewel, the answer is different dependending on how you view (and hold) it. Lean 4 can be described as simultaneously being two things; the first is a functional, expressive programming language that is capable of efficient compilation, and can be explored as such as a first approximation. While this is of course true, the real reason we’re interested in Lean is that there is more to it. Lean is also an Interactive Theorem Prover, a system that allows for the formal verification of mathematical reasoning correctness.

At its core, Lean fuses two theoretical fields: **Type Theory** and **Lambda Calculus**.

Some of you with a background in Computer Science may already be acquainted with those terms, but briefly speaking, for the general audience, we can characterize Type Theory as providing the language’s type system: unlike Set Theory (where objects can be inhomogeneous conglomerates prone to paradoxes if care is not taken), Type Theory offers a more robust and “typed” foundation for mathematics.

To be more concrete, there is some vagueness in naive set theory, defining sets as “collections of objects” and moreover, there are no limitations to the nature of their members: a set A may consist of a real number, a triangle, and a complete list of last names of the presidents of the USA, say. Lean 4 adopts Type Theory and the notion of Type as central, which prevents the behaviour of usual sets. This rigidity, far from being an expressive limitation, turns out to be of great importance and a source of a great feature.

> The central concept in Lean is the **Typing Judgment**, commonly denoted
as `t : T`, which means “term `t` is of type `T`”.

Also, Lambda Calculus provides the theory regarding computation and functional programming (think of Haskell, for instance). Routinely, as a
programming language it behaves and offers the usual set of tools that any coder uses on a daily basis; just to quickly mention surfacing features, constants are defined by specifying their name, type, and value. For example

> `def name : Type := term`

Lean allows for type inference, expression evaluation (`#eval`), and type checking (`#check`). Furthermore, to build complex structures, Lean uses **constructors** that have direct parallels in languages like C++, for instance `Prod A B` represents the Cartesian product $A \times B$:

> `(5, true)` is a term of type `Prod Int Bool`.

and so on. At this point in time, there are several sources to check Lean 4’s syntax and typical grammar online, the reader is encouraged to look for those references to play around as we go along.

## Functions are first-class citizens

There is something interesting to be said about *functions* in Lean. While in most languages (Python, C++), a function is an abstraction over a sequence of CPU instructions, in Lean 4 (and Dependent Type Theory), **a function is a first-class citizen**. For example, if you have a function $f$ that takes an integer and returns a boolean, its **type** is $\mathbb{Z} \to \text{Bool}$, this is in Lean’s jargon simply
$$
f : \mathbb{Z} \to \text{Bool}
$$

There are many advantages to treating functions as first-class objects:

1.  **Uniformity:** Everything is a term of a type. `5` is of type `Nat`. `sum` is of type `Nat -> Nat -> Nat`. `Pythagorean_Theorem` is of type `Prop`, a meaningful statement that admit proof. The compiler uses this mechanism to verify your code, logic, and mathematics.

2.  **Currying (Partial Application):** In Lean, "multi-argument" functions do not strictly exist.

    - A function summing two numbers `Int -> Int -> Int` is actually a function that takes **one** number and *returns another function* waiting for the second number.

    - This allows creating new functions by “fixing” arguments without extra code.

    - Again, this aids the mechanism that can mechanically reason about the code. 

3.  **Dependent Types (The Crown Jewel):**

    - There are many type systems out there, some more formal than others, and some more powerful than others. Among the most expressive are the members of the dependent type systems, and among those, the system underpinning Lean's type system is the most powerful.

    - The return type of a function can **depend on the value** of the
      input argument.

    - *Example:* A function `zero_vector (n : Nat)` returns a vector of size `n`. The *type* of the result (`Vector F n`) changes according to the value of `n`. This is impossible in standard Java or Rust.

The real potential behind this language is that it is founded on a
crucial idea resulting from the convergence between Mathematical Logic
and the Theory of Computation: **the Curry-Howard Isomorphism Theorem.**

While working on combinatory logic (between 1930 and 1950) Haskell Curry observed a peculiar pattern: the types of the most basic functions in computation (combinators) had exactly the same algebraic structure as the axioms of implicational logic (i.e. the classic “if A then B”). He intuited that computation and logical deduction were two sides of the same coin.

Later, in the 1960’s, William Howard formalized this intuition demonstrating that the process of **simplifying a logical proof** (cut
elimination in natural deduction) is isomorphic to the process of
**executing a program** (beta reduction in lambda calculus).  

The **Curry-Howard Theorem (or Isomorphism)** establishes that logical systems and computational systems are structurally identical. This allows mathematical proofs to be treated not as static text, but as executable algorithms.

> **Propositions as Types:** A mathematical statement `P` is a Type.  
> **Proofs as Programs:** A proof of `P` is simply a Term (program) of
> type `P`.

If the program compiles (type checks), the proof is valid.

## The Curry-Howard Isomorphism and its consequences

The application of the Curry-Howard isomorphism furnishes a bridge between Propositional Logic and Type theory. For reference, a brief conceptual table looks like

| **Propositional Logic** | **Type Theory (Lean)** | **Concept** |
|:---|:---|:---|
| Proposition ($P$) | `P : Prop` | A type in the logical universe. |
| Proof ($h$) | `h : P` | A term of type `P`. |
| Implication ($P \to Q$) | `P -> Q` | **Function**: Takes a proof of `P`, returns one of `Q`. |
| Conjunction ($P \land Q$) | `P `$\times$` Q` (Prod) | **Product**: A pair with a proof of `P` and one of `Q`. |
| Disjunction ($P \lor Q$) | `P `$\oplus$` Q` (Sum) | **Sum**: A proof of `P` *or* a proof of `Q`. |
| True ($\top$) | `Unit` / `True` | **Unit**: Type with a single value `()`. Trivial. |
| False ($\bot$) | `Empty` / `False` | **Void**: Type with no values. Impossible to construct. |
| Negation ($\neg P$) | `P -> False` | Function deriving a contradiction from `P`. |

This is striking at first but one of the great features of Lean is that it allows a *greater* equivalence: we can move from “static” logic to dynamic logic (i.e. Predicate Logic). This is the most powerful conceptual transition when learning Lean and is done by exploiting the fact that **predicates can be modeled as functions!**

In predicate logic, a statement like “`x` is even” is neither true nor false until we know the value of `x`. In Lean, this is modeled as a function that **takes data and returns a Proposition**. When standard mathematics says “`P(x)` is a predicate over a set `A`”, Lean writes a function taking inputs of Type A and returning a logical proposition Prop: “`P : A -> Prop`”.

## An elementary example

This example defines the property of “being divisible by 2” using the modulo operation.

```
-- PREDICATE DEFINITION
-- --------------------

/--
  We define a function called `is_divisible_by_two`.
  
  Syntax breakdown:
  1. `def`: Keyword to define data or functions.
  2. `(n : Nat)`: The input argument. We expect a natural number.
  3. `: Prop`: The RETURN TYPE. 
     It does not return `true` or `false` (computation), 
     it returns a logical statement.
  4. `:=`: Separates the signature from the implementation.
  5. `n % 2 = 0`: The body. It is an equation asserting the remainder is zero.
-/
def is_divisible_by_two (n : Nat) : Prop :=
  n % 2 = 0

-- USAGE OF THE PREDICATE
-- ----------------------

-- Here we evaluate the predicate with the number 4.
-- Lean reduces this to the proposition "0 = 0".
#check is_divisible_by_two 4 
-- Console result: is_divisible_by_two 4 : Prop

-- Here we evaluate with 5.
-- Lean reduces this to the proposition "1 = 0".
-- Note: The proposition is syntactically valid (it is of type Prop), 
-- even though it is mathematically false.
#check is_divisible_by_two 5
```

Note that `Nat -> Prop` reads: “Give me a natural number, and I will return a logical question about that number.”

Also, the distinction between **Validity and Truth:** defining the predicate does not state whether it is true or false for a given number. It only defines *what the statement means*. `is_divisible_by_two 5` is a valid object of type `Prop`; it is simply one for which we cannot construct a proof.

## Universal quantifiers

What does it mean to prove “For all `x`, `P(x)` is true”? It means that if you give me **any** concrete value `x`, I can return a proof of `P(x)`. But this is EXACTLY a function!

Now let us state and prove something involving a universal quantifier; will use the predicate `P(x) : x < x + 1`. In Lean, the "for all" ($\forall$) behaves like a function that accepts **any** value from the domain. Here we will use `theorem` instead of `def` because our intention is to prove a truth, not just define a structure.

## A second example

```
import Mathlib.Data.Nat.Basic -- Import basic natural number properties

-- DEFINITION AND PROOF OF A UNIVERSAL THEOREM
-- -------------------------------------------

/--
  Theorem: For every natural number x, x is strictly less than x + 1.

  Syntax breakdown:
  1. `theorem`: Indicates we are creating a term of a proposition (a proof).
  2. `x_less_than_succ`: The name we give to our theorem.
  3. `: forall (x : Nat), x < x + 1`: The PROPOSITION we want to prove.
     Reads: "For any x of type Nat, it holds that x < x + 1".
  4. `:=`: The proof begins.
-/
theorem x_less_than_succ : forall (x : Nat), x < x + 1 := by
  -- We enter "Tactic Mode" with the keyword `by`.
  -- This allows us to construct the proof (the function) step-by-step.
  
  -- STEP 1: INTRODUCTION (intro)
  -- The goal is to prove something "for all x".
  -- The `intro` tactic takes that generic `x` and puts it in our context.
  -- It is equivalent to saying on paper: "Let x be any natural number..."
  intro x
  
  -- Current State (Infoview):
  -- x : Nat  (We have an arbitrary x)
  -- |- x < x + 1 (Our goal is to prove this for that specific x)

  -- STEP 2: APPLYING AN AXIOM (exact / apply)
  -- We search the Lean library for a theorem that states exactly this.
  -- There is one called `Nat.lt_succ_self` which proves `forall n, n < succ n`.
  -- We pass our `x` to that function.
  exact Nat.lt_succ_self x
```

We can highlight that `intro x`: is the direct translation from logic to programming. To construct a function that works for *all* inputs, we first declare a variable representing that input.

## Constructivism

This extension to Predicate Logic however is not a copy of the usual *day-to-day* Predicate Logic. There is an important (philosophical and important) difference: Lean is constructive by default. What do we mean by this?

Proving something like “$\exists x, P(x)$” in constructive Lean requires *calculating* the `x` and presenting it. It is not enough to prove that “it is impossible for it not to exist.”. Also, the Law of the Excluded Middle: $P \lor \neg P$ is **not an axiom** in Lean’s constructive logic.

The fact that LEM is not an axiom should not be perceived alarmingly. After all, code is still subject to the boundaries of Computer Science: in computing, we do not always know if a program terminates or not (Halting Problem), so we cannot assert $P \lor \neg P$ *universally*. To calm some spirits down, Lean allows invoking classical logic (`open Classical`) if the mathematician desires, accepting non-constructive axioms but losing direct “computability” of proofs.

## Why does all this matter?

From a coder’s perspective, one question surely lingers from the beginning in the vicinity of “what does mathematics have to do with this?”.

**Let’s start by saying that beyond theory, Lean 4 solves endemic problems in the development of complex systems.** In industrial languages like Rust or C++, the compiler prevents memory management errors (segfaults, data races). However, it is blind to the mathematical “truth” of the program. **Lean raises the bar: it converts logical errors into compilation errors.**

For example, picture a classical rookie (and not so rookie) mistake: the case of the “wrap-around bug” (i.e. an index out of bounds). Imagine implementing a constraint on an execution trace of a STARK.

- **In Rust:** An engineer writes a loop `for i in 0..N` checking `trace[i+1] == trace[i] + 1`. In the last iteration, `i+1` overflows or accesses invalid memory. Rust might throw a *panic* at runtime, or worse, read garbage and accept a false proof.

- **In Lean:** We use dependent types like `Fin n` (numbers strictly less than `n`).

  - If you try to access `trace[i+1]` without first proving that `i < n-1`, Lean **will not compile**.

  - The compiler throws a type error: *"You have not proven that `i+1` is a valid index."*

  - This forces the engineer to handle constraints properly during design, not during debugging.

So adopting Lean introduces a layered development architecture distinguishing compilation and execution errors starkly and providesb **an improved workflow.** Lean’s role is to guarantee that the *specification* is correct and consistent before writing a single line of low-level code.

## Certified Code Extraction

Lean 4 is not just a verifier; it is an efficient programming language capable of compiling to C. This enables something called **Certified Code Extraction**: a the process by which Lean takes your mathematical definitions (functions, structures) and **compiles them into efficient C code**, eliminating all the "logical overhead" (the proofs) that is not necessary for execution.

Since writing the specification in Lean and then rewriting it by hand in C introduces the risk of human error, you can write critical functions (like Merkle Path verification or polynomial evaluation) in Lean, formally prove their correctness, **and then ask Lean to automatically generate the corresponding Code.** As a result, you obtain a binary that runs with the speed of C, but with the mathematical guarantee that it is a faithful representation of the logic verified in Lean. This feature is arguably what turns Lean 4 into a “game changer” for the industry, separating it from academic predecessors like Coq or Isabelle.

In order to understand how this works, we look at a fundamental distinction Lean makes when compiling: **Data (`Type`):** Numbers, Lists, Vectors, Matrices, etc. are *necessary to run the program*, while **Proofs (`Prop`):** Theorems, lemmas, type guarantees (e.g., `i < n`), etc. *are only necessary to convince the compiler*, but they are useless at runtime.

But what sense do we make out of a “compiled mathematical proof”? Well, this is a deep question. Below we give a brief list of the practical utility of the binary resulting from **Code Extraction**, separated by these two distinct viewpoints.

From the perspective of a software developer, the resulting binary (say,
`libfri_verifier.so` or `fri_verifier.exe`) is a **production artifact**. This is useful for

1.  **Deployment:** this binary is what you upload to the server, the
    blockchain node, or the IoT device. You may replace your old
    `verifier.rs` library (hand-written and potentially buggy) with this
    binary. The advantage is that now you possess an executable that
    runs at native speed (C/C++) but will **never** suffer from a buffer
    overflow or accept a false proof.

2.  **Integration:** the extracted Lean code usually exposes a C API;
    you use **FFI (Foreign Function Interface)** to call functions
    within the Lean binary. As an example, think of “My web server
    (Rust) handles JSON and networking, but when the critical moment
    arrives to verify the cryptographic proof, it passes the bytes to
    the Lean binary.” You delegate critical security to the verified
    compone price in speed. If you wrote it in C, you would pay a price in
    security risk. You use the Lean binary when you need the raw speed
    of the metal (C) but cannot afford a single memory or logical error.

The binary is then interpreted as an **Armored Static/Dynamic Library**. It serves to execute critical business logic in production without fear of it crashing or being exploited.

From the perspective of a mathematician, the binary produced is a “Witness Calculator”: the **computational realization** of an existence theorem. For instance, the uses of this binary are typically

1.  **To “Materialize” Existence:** you proved the theorem:
    $\forall x, \exists y, P(x, y)$ (“For every input `x`, there
    exists a solution `y`”). While the theorem is abstract, the binary
    is concrete. The mathematician uses the binary to **find** that
    `y` in the real world - say you feed the binary the number
    $x = 2^{64} + 13$. The binary executes the algorithm implicit in
    your proof and spits out the number $y = 1948...$. You have
    converted an abstract truth into concrete data.

2.  **For Certified Computation:** Sometimes you want to calculate
    something difficult (e.g., the `n`-th prime number, or a ZK
    execution trace). Now the binary works as a “Black Box of Truth”: if
    you used a Python script and got a result, you might doubt if you
    implemented the algorithm correctly. By using the Lean binary, you
    have the mathematical guarantee that the number on the screen **is**
    the correct one according to the axiomatic definition. There is no
    margin for logical error.

From a mathematical perspective, the binary is an **Executable Instance** of your proof. It serves to calculate concrete values (witnesses) that satisfy your theorems, bringing mathematical objects from the world of ideas onto the hard drive.

> It is the same file, but one views it as a **confirmation of theory**,
and the other as a **production tool**.

## Performance

Lean 4 uses a reference counting strategy called [Perceus](https://www.microsoft.com/en-us/research/publication/perceus-garbage-free-reference-counting-with-reuse/) with aggressive reuse and uniqueness optimizations. When the compiler detects that a data structure is uniquely owned (reference count of 1) and you're about to create a similar structure, Lean can reuse the memory in place rather than allocating new memory and copying.

This makes purely functional code competitive with imperative implementations in many cases—functional algorithms for Merkle trees or polynomial manipulation can achieve performance closer to hand-written
C++ than you might expect from a high-level functional language.

## Practical Example: Verifying Addition Constraints

Let's put theory into practice with an example directly relevant to ZK systems. In STARKs and other proof systems, we often need to verify that arithmetic operations on 32-bit integers are correct. Since we work with field elements (like the BabyBear field with prime $p = 2^{31} - 2^{27} + 1$), we decompose 32-bit integers into smaller "limbs" and use carry bits to track overflow.

## The Setup

Consider adding two 32-bit integers `lhs` and `rhs` to get `res`. Each is decomposed into two 16-bit limbs:

$$
\text{lhs} = \text{lhs}_0 + \text{lhs}_1 \cdot 2^{16}
$$
$$
\text{rhs} = \text{rhs}_0 + \text{rhs}_1 \cdot 2^{16}
$$
$$
\text{res} = \text{res}_0 + \text{res}_1 \cdot 2^{16}
$$

The constraint equations that ZK circuits enforce are:

$$
\text{lhs}_0 + \text{rhs}_0 = \text{res}_0 + \text{carry}_0 \cdot 2^{16}
$$
$$
\text{lhs}_1 + \text{rhs}_1 + \text{carry}_0 = \text{res}_1 + \text{carry}_1 \cdot 2^{16}
$$

where $\text{carry}_0$ and $\text{carry}_1$ are bits (0 or 1).

**The theorem we want to prove:** If these constraints are satisfied and the carries are bits, then $\text{res} \equiv \text{lhs} + \text{rhs} \pmod{2^{32}}$.

**Important caveat:** This theorem establishes the modular arithmetic identity given the constraint equations hold. In a real ZK circuit, you'd also need separate range constraints ensuring each limb is in $[0, 2^{16})$. Those range checks are typically enforced by lookup arguments or decomposition constraints in the circuit—we're proving the algebraic relationship here.

## The Lean 4 Proof

```
import Mathlib.Data.ZMod.Basic
import Mathlib.Tactic
-- Define constants for readability
def LIMB_BASE : Nat := 65536      -- 2^16
def MOD_32 : Nat := 4294967296    -- 2^32
/--
  THEOREM: Addition Constraint Correctness
  If the limb constraint equations hold and carries are bits,
  then res ≡ lhs + rhs (mod 2^32).
  Note: This proves the algebraic identity. Range constraints
  (ensuring limbs are < 2^16) are handled separately in circuits.
-/
theorem add_constraint_mod32
  (lhs0 lhs1 rhs0 rhs1 res0 res1 carry0 carry1 : Nat)
  -- Limb constraint equations
  (h_low : lhs0 + rhs0 = res0 + carry0 * LIMB_BASE)
  (h_high : lhs1 + rhs1 + carry0 = res1 + carry1 * LIMB_BASE)
  -- Carry bit constraints
  (h_c0_bit : carry0 ≤ 1)
  (h_c1_bit : carry1 ≤ 1)
  : (res0 + res1 * LIMB_BASE) % MOD_32 =
    (lhs0 + lhs1 * LIMB_BASE + rhs0 + rhs1 * LIMB_BASE) % MOD_32 := by
  -- Unfold constants so omega can work with concrete numbers
  unfold LIMB_BASE MOD_32
  unfold LIMB_BASE at h_low h_high
  -- From the constraints we derive:
  --   res + carry1 * 2^32 = lhs + rhs
  -- The omega tactic handles the linear arithmetic automatically
  omega
```

## Understanding the Proof

Let's break down what's happening:

1. **Unfold Definitions:** We expand `LIMB_BASE` and `MOD_32` to their
   concrete values (65536 and 4294967296) so the `omega` tactic can
   reason about them.

2. **Algebraic Manipulation:** We multiply the high-limb equation by
   $2^{16}$ and combine it with the low-limb equation. This gives us
   the relationship between the full 32-bit values.

3. **Core Identity:** The key insight is that after combining the
   constraints:
   $$
   \text{res} + \text{carry}_1 \cdot 2^{32} = \text{lhs} + \text{rhs}
   $$

4. **Modular Reduction:** Since $\text{carry_1} \cdot 2^{32} \equiv 0 \pmod{2^{32}}$,
   we get $\text{res} \equiv \text{lhs} + \text{rhs} \pmod{2^{32}}$.

The `omega` tactic handles the linear arithmetic automatically, making the proof remarkably concise while remaining rigorous.

## Concrete Examples

We can also verify specific cases:

```
-- Verify 100 + 200 = 300 (no carries)
example : (300 + 0 * 65536) % 4294967296 =
          (100 + 0 * 65536 + 200 + 0 * 65536) % 4294967296 := by
  native_decide
-- Verify 65535 + 1 = 65536 (carry from low limb)
-- 65536 = 0 + 1 * 65536
example : (0 + 1 * 65536) % 4294967296 =
          (65535 + 0 * 65536 + 1 + 0 * 65536) % 4294967296 := by
  native_decide
-- Verify 2^32 - 1 + 1 ≡ 0 (mod 2^32) (full overflow)
example : (0 + 0 * 65536) % 4294967296 =
          (65535 + 65535 * 65536 + 1 + 0 * 65536) % 4294967296 := by
  native_decide
```

This is exactly the kind of constraint verification that appears in zkVMs. By proving it in Lean 4, we have machine-checked assurance that our constraint logic is correct—not just for test cases, but for all possible inputs.

## Conclusion

We've covered a lot of ground in this article:

- **The Curry-Howard Isomorphism** reveals that proofs and programs are
  fundamentally the same thing. Types are propositions, and terms
  (programs) are proofs.

- **Type Safety as Logic Safety:** Lean's type system catches not just
  runtime errors but logical errors. If your code compiles, your proof
  is valid.

- **Certified Code Extraction:** Lean 4 isn't just a theorem prover—it
  compiles to efficient C code, letting you deploy formally verified
  software in production.

- **Practical ZK Verification:** We demonstrated how Lean 4 can verify
  the correctness of arithmetic constraints used in zero-knowledge
  proof systems.

At LambdaClass, we see formal verification as an essential tool for the ZK ecosystem. As proof systems grow more complex, the gap between "code works" and "code that is provably correct" becomes increasingly important. Lean 4 helps us bridge that gap.

## Getting Started with Lean 4

If you want to try the examples in this post:

1. **Install elan** (Lean's toolchain manager):
   ```bash
   curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh
   ```

2. **Set up VS Code** with the [lean4 extension](https://marketplace.visualstudio.com/items?itemName=leanprover.lean4)
   for interactive proving with real-time feedback.

3. **Create a project** with Mathlib:
   ```bash
   lake new my_project math
   cd my_project
   lake update && lake build
   ```

4. **Write your proofs** in `.lean` files. The VS Code extension shows
   goal states as you write, and `lake build` verifies everything compiles.

## Resources for Learning More

- [Lean 4 Manual](https://lean-lang.org/lean4/doc/) — Official documentation
- [Mathematics in Lean](https://leanprover-community.github.io/mathematics_in_lean/) — Tutorial for mathematical formalization
- [Mathlib Documentation](https://leanprover-community.github.io/mathlib4_docs/) — The comprehensive math library
- [Functional Programming in Lean](https://lean-lang.org/functional_programming_in_lean/) — For the programming perspective
- [Theorem Proving in Lean 4](https://lean-lang.org/theorem_proving_in_lean4/) — Deep dive into proof tactics