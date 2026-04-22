+++
title = "The hitchhiker's guide to reading Lean 4 theorems"
date = 2026-03-17
slug = "th-hitchhikers-guide-to-reading-lean-4-theorems"
description = "Claude can generate Lean code all day long, but eventually you have to read the code and more importantly, the theorems verifying the software's correctness properties. Learn how to read Lean theorems in this short guide."

[extra]
feature_image = "/images/2026/Domenico-Fetti_Archimedes_1620.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["Lean", "Formal Methods"]
+++

# The hitchhiker's guide to reading Lean 4 theorems

You already know more about mathematical proofs than you think. If you have ever written a function with a type signature, you have written something structurally identical to a formal proof. This fact stems from a deep theoretical result called the **Curry-Howard correspondence**, and is the foundation on which proof assistants like Lean 4 are built.

Consider this TypeScript function:

```typescript
function compose<A, B, C>(f: (b: B) => C, g: (a: A) => B): (a: A) => C {
  return (a) => f(g(a));
}
```

Now consider this Lean 4 theorem:

```lean
theorem imply_transitivity {P Q R : Prop} (hpq : P → Q) (hqr : Q → R) : P → R :=
  fun hp => hqr (hpq hp)
```

These are the same thing. The TypeScript function says "given `f: B → C` and `g: A → B`, I can produce `A → C`." The Lean theorem says "given a proof that P implies Q and a proof that Q implies R, I can produce a proof that P implies R." The implementation is identical: compose the two functions. A type is a proposition, and a program of that type is a proof of that proposition. When Lean's compiler accepts your code, it has verified your proof — not by running tests or checking examples, but by verifying that the program you wrote actually has the type you claimed.

This post teaches you to read Lean 4 proofs the way you would read someone else's code: by understanding the vocabulary, the structure, and the intent behind each step. All examples are drawn from real verified projects, such as [AMO-Lean](https://github.com/lambdaclass/amo-lean), a formally verified optimizer for cryptographic primitives, and [OptiSat](https://github.com/lambdaclass/optisat), a verified e-graph equality saturation engine. No prior Lean or formal math background is required. If you can read Python or TypeScript, you can learn to read Lean proofs.

## The Rosetta Stone

Before diving into syntax, it helps to establish the translation between mathematical and programming concepts. Every idea in formal mathematics has a direct programming analogue.

A **theorem** is a function with a type signature. Its **hypotheses** are function parameters, and its **conclusion** is the return type. The **proof** is the function body — the implementation. A **lemma** is a helper function. `∀` (for all) is a generic type parameter. The arrow `→` means both "implies" and "function from A to B." Conjunction `∧` is a tuple. Disjunction `∨` is a tagged union. Existence `∃` is a dependent pair. Equality `=` is structural equality. And QED — the moment the kernel accepts the proof — is the moment the type checker says "this compiles."

In programming, you trust the compiler to reject ill-typed programs. In Lean, you trust the **kernel**, a minimal, well-audited core, to reject invalid proofs. The kernel is the only thing you need to trust. Everything else — tactics, automation, Mathlib's 500,000+ lines of code — could be buggy, and the kernel would still catch any invalid proof that those tools generated. This is called the **de Bruijn criterion**: [the verifier is independent of the proof generator](https://lawrencecpaulson.github.io/2022/01/05/LCF.html). Think of it as trusting the CPU and the OS kernel, but not application code. In Lean, the trust boundary is even tighter.

## Anatomy of a Theorem

Let's dissect real theorems from the ground up, starting as simply as possible and building toward the complexity you will encounter in verified codebases.

The simplest theorem you can write in Lean looks like this:

```lean
theorem one_plus_one : 1 + 1 = 2 := rfl
```

Read it as a programmer: `theorem` declares a named, typed value, like `const` in JavaScript. `one_plus_one` is the name. `: 1 + 1 = 2` is the declaration signature, And `:= rfl` is the proof, where [`rfl`](https://lean-lang.org/doc/reference/latest/Tactic-Proofs/Tactic-Reference/#rfl) stands for the tactic "reflexivity", which is a command to the prover indicating that both sides compute to the same value. The kernel evaluates `1 + 1` to `2`, evaluates `2` to `2`, confirms they are identical, and accepts the proof. No runtime check occurs. The truth is established at compile time.

Things get more interesting when hypotheses appear:

```lean
theorem add_pos (a b : Nat) (ha : a > 0) (hb : b > 0) : a + b > 0 := by
  omega
```

Here `a b : Nat` are two natural number parameters — like `function add_pos(a: number, b: number)`. Then `(ha : a > 0)` is a *proof* that `a` is positive: a precondition, a contract. The naming convention is consistent across Lean codebases: `h` for "hypothesis," followed by the variable it refers to, so `ha` is a hypothesis about `a`, `hb` about `b`. Numbered variants like `h₁` and `h₂` are common when several hypotheses concern the same variable. You will also see `ih` for "inductive hypothesis," `hne` for non-equality, `hlt` for less-than, and `this` for the most recent unnamed result. The conclusion `: a + b > 0` is what must be true given the preconditions, and `omega` is a *tactic* — an automated solver for linear arithmetic — that constructs the proof term automatically.

The curly braces introduce **implicit arguments**, Lean's version of generics:

```lean
theorem list_append_nil {α : Type} (l : List α) : l ++ [] = l := by
  simp
```

The `{α : Type}` tells Lean to infer `α` from context. You never write `list_append_nil Nat [1, 2, 3]` — just `list_append_nil [1, 2, 3]`, and Lean figures out that `α = Nat`. This is exactly how TypeScript's `function appendNil<T>(l: T[]): T[]` works: the type parameter is inferred, not specified.

Real-world theorems combine all these elements. Here is a theorem from AMO-Lean's NTT verification:

```lean
theorem sum_of_powers_zero {ω : F} {n : ℕ} (hn : n > 1)
    (hω : IsPrimitiveRoot ω n) :
    (Finset.range n).sum (fun i => ω ^ i) = 0
```

Don't panic at the density. Decode it piece by piece: `{ω : F}` is an implicit element of some field `F` (a generic `T` with arithmetic). `{n : ℕ}` is an implicit natural number. `(hn : n > 1)` requires `n` to be at least 2. `(hω : IsPrimitiveRoot ω n)` requires `ω` to be a primitive nth root of unity — a structured mathematical property asserting `ω^n = 1` and `ω^k ≠ 1` for `0 < k < n`. And the conclusion says the sum `ω^0 + ω^1 + ... + ω^(n-1)` vanishes. In programming terms, this is a generic function parameterized over a field type, taking two proofs as input, and returning a proof that the power sum is zero. This is a foundational result for the Number Theoretic Transform, the crypto-friendly cousin of FFT.

## The Proof State: your debugger

When you write `by` in Lean, you enter **tactic mode** — an interactive environment that feels remarkably like a debugger session. There is a **goal**: the thing you need to prove, like a failing assertion. There are **hypotheses**: facts you already know, like variables in scope. Each **tactic** is a command that transforms the goal, bringing you one step closer to closing it.

The `⊢` symbol (called "turnstile") separates what you know from what you need to prove. Everything above `⊢` is in scope; below it is your obligation. Here is a proof with the state annotated at each step:

```lean
theorem add_comm_manual (a b : Nat) : a + b = b + a := by
  -- STATE: a : Nat, b : Nat ⊢ a + b = b + a
  induction a with
  | zero =>
    -- STATE: b : Nat ⊢ 0 + b = b + 0
    simp
  | succ n ih =>
    -- STATE: ih : n + b = b + n ⊢ n + 1 + b = b + (n + 1)
    rw [Nat.succ_add, Nat.add_succ, ih]
```

The structure mirrors recursive programming. `induction a` creates two subgoals — the base case (`a = 0`) and the inductive step (`a = n + 1`) — where you get `ih`, the inductive hypothesis, for free. In the base case the [simp tactic](https://leanprover-community.github.io/extras/simp.html) that 'simplifies' terms by rewriting them, invoking a database of facts.  The second branch is  the 'recursive call', wherein `ih` is inductive hypothesis. Given the hypothesis we can rewrite (`rw`) the terms to satisfy the goal. The kernel guarantees termination because `n < n + 1`. If you have ever written a recursive function with a base case and a step that reduces the problem, you have done induction.

## The Tactic Vocabulary

[Tactics](https://lean-lang.org/theorem_proving_in_lean4/Tactics/#Theorem-Proving-in-Lean-4--Tactics) are commands for constructing proofs, and each one has a clear programming analogue. Lean comes with a very convenient selection of tactics, and new ones can be developed specializing in mathematical subdomains. You can see the tactic reference [here](https://lean-lang.org/doc/reference/latest/Tactic-Proofs/Tactic-Reference/).

**[`intro`](https://lean-lang.org/doc/reference/latest/Tactic-Proofs/Tactic-Reference/#intro)** is naming function parameters. When the goal is `P → Q → R`, writing `intro hp hq` moves `P` and `Q` into the hypothesis context as `hp : P` and `hq : Q`, leaving `R` as the new goal. It is the formal version of writing `function(hp, hq) { ... }`.

**[`exact`](https://lean-lang.org/doc/reference/latest/Tactic-Proofs/Tactic-Reference/#exact)** is `return`. It closes a goal by providing a term that has exactly the right type. `exact h` says "the proof is exactly `h`," just as `return h` says "the answer is exactly `h`."

**[`apply`](https://lean-lang.org/doc/reference/latest/Tactic-Proofs/Tactic-Reference/#apply)** is partial function application. If you have `hpq : P → Q` and your goal is `Q`, then `apply hpq` reduces the goal to `P`. It says "I know how to get a `Q` from a `P`, so now just give me a `P`." This is calling a function and letting the type checker figure out what arguments are still needed.

**[`rw`](https://lean-lang.org/doc/reference/latest/Tactic-Proofs/Tactic-Reference/#rw)** is find-and-replace. Given an equation `h : a = b`, the tactic `rw [h]` replaces all occurrences of `a` with `b` in the goal. You can rewrite backwards with `rw [← h]` (replaces `b` with `a`) and rewrite in specific hypotheses with `rw [h] at h2`. It is regex substitution for mathematical expressions, except the kernel guarantees it preserves truth.

**[`simp`](https://lean-lang.org/doc/reference/latest/Tactic-Proofs/Tactic-Reference/#simp)** draws from a database of hundreds of simplification lemmas and applies them until the goal is in normal form. `simp only [rule1, rule2]` restricts it to specific rules. Think of it as `eslint --fix` for mathematical expressions — it knows, for instance, that `l ++ [] = l`, that `0 + n = n`, and thousands of similar facts. When you see `simp` in a proof, the author is saying "this follows from standard simplification rules."

**[`omega`](https://lean-lang.org/doc/reference/latest/Tactic-Proofs/Tactic-Reference/#omega)** is for solving linear arithmetic problems over N or Z. It decides any system of linear inequalities over `Nat` or `Int`, handling `+`, `-`, multiplication by constants, `≤`, `<`, `=`, `≠`, and logical combinations. When a proof ends with `omega`, the statement is a routine arithmetic fact. Think of it as Z3 for the integer fragment.

**[`cases`](https://lean-lang.org/doc/reference/latest/Tactic-Proofs/Tactic-Reference/#cases)**  is `switch`. It destructs a value and creates one subgoal per constructor. For `Nat`, that means `zero` and `succ m`. For `Bool`, `true` and `false`. For a custom enum, each variant. When you see `cases x with | variant1 => ... | variant2 => ...`, read it as a match expression that must handle every possibility.

**[`have`](https://lean-lang.org/doc/reference/latest/Tactic-Proofs/The-Tactic-Language/#have)** is a local `let` binding. Writing `have h3 : T := proof` introduces a new fact `h3` of type `T` into the context, proved by `proof`. It is exactly a local variable declaration: you prove something intermediate, name it, and use it later. It is the "extract local variable" refactoring, applied to proofs.

**[`constructor`](https://lean-lang.org/doc/reference/latest/Tactic-Proofs/Tactic-Reference/#constructor)** builds structs. For `∧` (logical AND), it splits the goal into two subgoals — prove each conjunct. For `∃` (exists), it asks you to provide a witness. For `↔` (if and only if), it splits into the forward and backward directions. The `⟨...⟩` angle brackets are Lean's anonymous constructor notation, equivalent to tuple or struct literals.

Two more deserve mention. **[`split`](https://lean-lang.org/doc/reference/latest/Tactic-Proofs/Tactic-Reference/#split)** handles `if/then/else` expressions in the goal by creating one subgoal per branch. And the **`<;>` combinator** applies the same tactic to all pending goals — it is `.forEach()` for proof obligations.

That is the core vocabulary. A dozen tactics cover the vast majority of proofs you will encounter. Let's see them in action.

## Walking Through Real Proofs

### When the Definition Does All the Work

From AMO-Lean's NTT butterfly implementation:

```lean
def butterfly_fst (a b twiddle : F) : F := a + twiddle * b
def butterfly_snd (a b twiddle : F) : F := a - twiddle * b

theorem butterfly_fst_eq (a b twiddle : F) :
    butterfly_fst a b twiddle = a + twiddle * b := rfl
```

The theorem says "`butterfly_fst a b twiddle` equals `a + twiddle * b`," and the proof is `rfl`. Why? Because `butterfly_fst` is *defined* as `a + twiddle * b`. When Lean evaluates both sides, they are identical. The proof is literally "look at the definition."

This pattern reveals a design principle: **when a proof is `rfl`, the definitions are doing the intellectual work.** The best Lean code makes interesting properties fall out definitionally. If you find yourself writing long proofs for simple properties, it often means the definitions need rethinking.

### Induction Mirroring Function Structure

From AMO-Lean's [list](https://github.com/lambdaclass/amo_lean/blob/main/AmoLean/NTT/ListUtils.lean#L24) utilities:

```lean
def evens : List α → List α
  | [] => []
  | [x] => [x]
  | x :: _ :: xs => x :: evens xs

theorem evens_length (l : List α) :
    (evens l).length = (l.length + 1) / 2 := by
  induction l using evens.induct with
  | case1 => simp [evens]
  | case2 x => simp [evens]
  | case3 x y xs ih =>
    simp only [evens, List.length_cons]
    rw [ih]
    omega
```

The function `evens` extracts even-indexed elements from a list: `[a,b,c,d,e]` becomes `[a,c,e]`. It has three pattern-matching cases — empty, singleton, and two-or-more elements. The proof has *exactly the same three cases*, because `induction l using evens.induct` generates the induction principle from the function's own pattern matching.

The base cases (`case1` and `case2`) are dispatched by `simp [evens]` — unfold the definition, simplify, done. The interesting case is `case3`: for a list `x :: y :: xs`, we have the inductive hypothesis `ih : (evens xs).length = (xs.length + 1) / 2`. The proof unfolds `evens` and `List.length_cons` with `simp only`, substitutes `ih` with `rw`, and finishes the resulting arithmetic with `omega`.

The takeaway: **proof structure mirrors function structure.** Three cases in the function, three cases in the proof. The inductive hypothesis is the recursive call. `omega` handles the arithmetic bookkeeping that would be tedious by hand. If you can read the function, you can read the proof.

### Forward and Backward: Biconditional Proofs

From OptiSat's [utility](https://github.com/lambdaclass/optisat_lean/blob/main/LambdaSat/Util/NatOpt.lean) library:

```lean
theorem le_min_iff (a b c : Nat) : c ≤ Nat.min a b ↔ c ≤ a ∧ c ≤ b := by
  constructor
  · intro h
    exact ⟨Nat.le_trans h (min_le_left a b),
           Nat.le_trans h (min_le_right a b)⟩
  · intro ⟨ha, hb⟩
    simp only [Nat.min_def]
    split <;> omega
```

The goal is `↔` (if and only if), so `constructor` splits it into two directions — like implementing both `serialize` and `deserialize`. The forward direction assumes `h : c ≤ Nat.min a b` and builds the conjunction using `⟨..., ...⟩` — Lean's tuple literal. Each component chains two inequalities via `Nat.le_trans`: from `c ≤ min a b` and `min a b ≤ a`, we get `c ≤ a`. The backward direction destructures the conjunction into `ha` and `hb`, unfolds `min` to its `if a ≤ b then a else b` definition, then `split <;> omega` splits on the `if` and solves both branches with the arithmetic solver.

### Composing Guarantees: The Soundness Sandwich

From OptiSat's [rewrite rule verification](https://github.com/lambdaclass/optisat_lean/blob/main/LambdaSat/SoundRule.lean#L104):

```lean
theorem sound_rule_preserves_consistency
    (g : EGraph Op) (rule : SoundRewriteRule Op Expr Val)
    (lhsId rhsId : EClassId)
    (env : Nat → Val) (v : EClassId → Val)
    (hv : ConsistentValuation g env v)
    (hwf : WellFormed g.unionFind)
    (h1 : lhsId < g.unionFind.parent.size)
    (h2 : rhsId < g.unionFind.parent.size)
    (vars : Nat → Expr)
    (h_lhs : v (root g.unionFind lhsId) = rule.eval (rule.lhsExpr vars) env)
    (h_rhs : v (root g.unionFind rhsId) = rule.eval (rule.rhsExpr vars) env) :
    ConsistentValuation (g.merge lhsId rhsId) env v :=
  merge_consistent g lhsId rhsId env v hv hwf h1 h2
    (by rw [h_lhs, h_rhs, rule.soundness env vars])
```

This theorem has eleven parameters. Don't let the size intimidate you — they decompose logically into four groups. The *setup* (four params): an e-graph, a rewrite rule, and two class IDs. The *semantics* (two params): an environment and a valuation that assigns values to e-classes. The *preconditions* (five params): the valuation is consistent, the union-find is well-formed, both IDs are valid, and the LHS and RHS of the rule match the valuation. And the *conclusion*: after merging the two classes, the valuation is *still* consistent.

The entire proof is a single function call — `merge_consistent` — with one "glue" argument: `by rw [h_lhs, h_rhs, rule.soundness env vars]`, which says "rewrite using the two matching hypotheses, then apply the rule's own soundness guarantee to show both sides are equal."

**Big theorems are not necessarily hard to prove — they are hard to state.** The eleven parameters capture every precondition precisely. The proof itself is function composition: delegate to an existing lemma and provide the connecting argument. This is the **soundness sandwich** pattern: state preconditions precisely, compose existing guarantees, let the types do the work.

### Algebra on Autopilot: The Geometric Series

From AMO-Lean's roots of unity:

```lean
theorem geom_sum_finset (r : F) (n : ℕ) :
    (1 - r) * (Finset.range n).sum (fun i => r ^ i) = 1 - r ^ n := by
  induction n with
  | zero => simp
  | succ n ih =>
    rw [Finset.sum_range_succ, mul_add, ih]
    ring
```

The statement is the closed form of the geometric series: `(1 - r) * (1 + r + r² + ... + r^(n-1)) = 1 - r^n`. The base case is trivial — when `n = 0`, both sides are zero, and `simp` handles it. The inductive step is three rewrites followed by `ring`. `Finset.sum_range_succ` splits off the last term. `mul_add` distributes the multiplication. `ih` substitutes the inductive hypothesis. And then `ring` — the computer algebra system tactic — finishes the remaining polynomial identity.

The human's job here is to set up the structure: choose induction, apply the right rewrites to expose the algebraic shape. The machine's job is to verify the algebra. This division of labor is typical of good Lean proofs: **humans provide strategy; tactics provide computation.**

## Advanced Patterns

Beyond the basic vocabulary, a few structural patterns recur across real codebases.

**The roundtrip pattern** proves that two operations are inverses — the formal version of `deserialize(serialize(x)) = x`. From [AMO-Lean](https://github.com/lambdaclass/amo_lean/blob/main/AmoLean/NTT/ListUtils.lean#L90):

```lean
theorem interleave_evens_odds (l : List α) :
    interleave (evens l) (odds l) = l := by
  induction l using evens.induct with
  | case1 => simp [evens, odds, interleave]
  | case2 x => simp [evens, odds, interleave]
  | case3 x y xs ih =>
    simp only [evens, odds, interleave]
    rw [ih]
```

Split a list into even-indexed and odd-indexed elements, interleave them back, and you get the original list. 

**The fuel pattern** handles recursive functions that might not terminate. Instead of proving termination directly, you add a `fuel : Nat` parameter that decreases on each recursive call. If fuel runs out, the function returns `none`. The correctness theorem then says "if the function returned `some result` (meaning it finished within the fuel budget), then `result` is correct." From OptiSat:

```lean
theorem extractF_correct (g : EGraph Op) ... :
    ∀ (fuel : Nat) (classId : EClassId) (expr : Expr),
      extractF g classId fuel = some expr →
      EvalExpr.evalExpr expr env = v (root g.unionFind classId) := by
  intro fuel
  induction fuel with
  | zero => intro classId expr h; simp [extractF] at h
  | succ n ih => ...
```

This is pragmatic engineering: you avoid the hardest part — termination proofs for complex recursive functions — while still getting useful correctness guarantees. Many real-world verified systems use this pattern. Ideally one avoids such tricks but if termination proves difficult to prove for other reasons it can provide a way.

**The case split + embedded lemma pattern** combines `cases`, `have`, and `omega` to handle subproblems locally. From AMO-Lean:

```lean
theorem evens_length_pow2 (l : List α) (k : Nat) (hk : k ≥ 1)
    (hl : l.length = 2^k) :
    (evens l).length = 2^(k-1) := by
  rw [evens_length, hl]
  have h2k : 2^k = 2 * 2^(k-1) := by
    cases k with
    | zero => omega
    | succ n => simp [Nat.pow_succ, Nat.mul_comm]
  omega
```

The `have h2k` introduces a local lemma — a fact proved on the spot and used immediately, like a local helper function. The `| zero => omega` case is interesting: `k = 0` contradicts `hk : k ≥ 1`, so `omega` detects the contradiction and closes the goal. In programming terms, this branch is unreachable, and the compiler proves it. Don't try to do everything in one shot. Use `have` to prove intermediate facts, name them clearly, and compose.

## What Happens When You Compile a Lean File

Understanding what `lake build` actually does clarifies why Lean proofs carry the weight they do. 

First, **elaboration**: Lean's frontend converts your high-level code — tactics, implicit arguments, coercions — into a low-level **proof term**, a pure lambda calculus expression.

Second, **kernel type-checking**: the kernel, a separate minimal program, independently verifies that the proof term has the declared type. The kernel does not trust tactics, `simp` lemma databases, or any automation. It only trusts basic type theory rules. If `simp` had a bug that generated an invalid proof term, the kernel would reject it.

Third, **compilation to native code**: for `def`s and `#eval`, Lean compiles to native machine code via a C intermediate. Theorems are erased — they have no runtime cost. They exist only at compile time, as type-checking obligations.

The important point is that the first two phases are independent. The tactics in phase one are just *programs that generate proof terms*. They could be buggy. But the kernel in phase two would catch any invalid output. The kernel guarantees three things: **logical consistency** (the theorem follows from the axioms), **well-typedness** (no type errors), and **universality** (the theorem holds for all values satisfying the hypotheses, not just tested examples).

What the kernel does *not* guarantee is equally important: it does not check that the theorem is useful, that the hypotheses are satisfiable, or that the definitions capture the intended semantics. You could formally prove that your sort function returns a list of the same length — but that specification says nothing about the output being sorted. Lean verifies *what you stated*, not *what you meant*. That gap is where human judgment remains irreplaceable.

## A Method for Reading Unfamiliar Proofs

When you encounter a Lean proof you have never seen before, resist the urge to read it top-to-bottom. Start with the statement, not the proof. The statement tells you *what* is true; the proof tells you *why*. Read the *what* first.

Identify the implicit parameters in curly braces — they set the mathematical context. Identify the explicit hypotheses — these are the preconditions. Identify the conclusion after the final colon — this is the guarantee. Translate the statement to plain English and ask yourself: "Is this plausible? Is this interesting?"

Next, glance at the first tactic to classify the proof strategy. If it opens with `rfl`, the theorem is true by definition. If it starts with `simp` or `omega`, the proof is automated — the machine handles it. `intro` signals an assume-and-show argument. `induction` means a recursive argument. `cases` means case analysis. `constructor` means building the goal piece by piece. `apply` means delegating to another theorem. Most proofs fall cleanly into one of these categories.

Then, if you care about the *why*, track the proof state through each tactic. What goals exist? What changed? Why does this step bring us closer? Most proofs have one creative insight — the "hard step" — and the rest is bookkeeping. Look for which `rw` or `have` introduces the crucial equation, which `apply` invokes the non-obvious lemma, or where the inductive hypothesis gets used. Once you find the hard step, you understand the proof.

Reading Lean proofs is a skill, like reading assembly or navigating a foreign codebase. The first time is slow. The tenth time, you start seeing patterns. By the hundredth theorem, you read proofs as fluently as code.

The payoff is real and somewhat hard to transmit until you go through it. Just as the borrow-checker in Rust takes some getting used to, learning to trust what Lean provides and accept the cost tradeoff requires some initial effort. 
When AMO-Lean proves that its NTT implementation preserves algebraic properties, or when OptiSat proves that every e-graph rewrite preserves semantics, these are not tests that happened to pass. They are **permanent, universal guarantees** checked by a minimal trusted kernel. No edge case was missed. No regression can break them. The proof *is* the documentation, and it is machine-checked.

The next time you see a Lean theorem, try this: ignore the proof, read the statement, and ask yourself — "what would it take to test this?" The answer is oftern "infinitely many tests." That is what the proof replaces: infinite testing, compressed into a finite program that the kernel can verify.

Proofs are programs, and programs are proofs. You have been writing proofs your entire career. Now you know how to read them.

---

*All code examples in this article compile with Lean 4 and are drawn from [AMO-Lean](https://github.com/lambdaclass/amo-lean) and [OptiSat](https://github.com/lambdaclass/optisat), open-source formally verified optimization projects.*
