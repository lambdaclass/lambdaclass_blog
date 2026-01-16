title = "A Sharper Look at FRI"
date = 2026-01-16
description = "A review recent developments in the analysis of cryptographic security of one of the biggest pieces of the ZK engine: the FRI protocol implementing interactive oracle proofs of proximity, IOPPs."

[taxonomies]
tags = ["cryptography", "zero knowledge proofs", ""]

[extra]
authors = ["Manuel Puebla"]
feature_image = "/images/2026/Hans_Holbein_the_Younger_-_The_Ambassadors_-_Google_Art_Project.jpg"
math = true
+++

# A sharper look at FRI

In this article we will review recent developments in the analysis of cryptographic security of one of the biggest pieces of the ZK engine: the FRI protocol implementing interactive oracle proofs of proximity, IOPPs. A newly uploaded article by Eli Ben-Sasson, Dan Carmon, Swastik Kopparty and Shubhangi Saraf alongside Ulrich Habock (BCHKS25), revisits the foundational 2020 paper "Proximity Gaps for Reed Solomon Code" (BCIKS20) where the soundness of the RS-IOPP was established based on the Correlated Agreement Theorem. By a detailed and sharper use of linear algebra in the process under the list decoding regime, they obtained enhanced security performance bounds for the standard FRI. Here we will conceptually revise the protocol and give an outline of how their breakthrough was achieved.

The acquainted reader may skip directly to section 4, while newcomers are encouraged to read the first sections to get familiar with notations and concepts involved.

## 1. Basic Reed-Solomon landscape

Let us begin with an overview of one the basics of code-based cryptography: an interactive instance of information exchange between a Prover (P) and a Verifier (V) - where P wants to convince V that he has executed a certain task or possesses certain information. Usually, the information P claims to possess is in a fact the result of a computation, in the form of a low degree polynomial f, say $\deg(f) < k$ with coefficients in a suitable finite field $\mathbb{F}_q$ of $q$ elements.

A completely naive approach would be for the prover to send the list of coefficients of the polynomial he claims to possess, or by the Fundamental Theorem of Algebra, a list of $\deg(f)+1 \leq k$ evaluations of his polynomial. It is clear that such an idea is cryptographically insecure, since any leak in the communication channel would surrender the information to any attacker in plain sight.

One of the ideas to circumvent the exposure of $f$ is to actually evaluate $f$ at many more points $\mathcal{D}$ with $n = |\mathcal{D}| >> k$ in the base field $\mathbb{F}_q$, so that now what the Prover and Verifier exchange are much longer lists of evaluations:

The effect that this has is that any attacker will be faced to the challenge of distinguishing between lists of numbers corresponding to evaluations of low degree polynomials, and lists that do not come from evaluating such polynomials.

> **Reed-Solomon Code:** This is the very basic idea of a Reed-Solomon code $RS[q,n,k]$: length $n$ vectors consisting exactly of the evaluation of polynomials of degree bounded by $k$ over a domain $\mathcal{D} \subset \mathbb{F}_q$.

As a subset of the ambient vector space $\mathbb{F}_q^n$, the Reed-Solomon code is a vector subspace since the evaluation of polynomials is a linear operation, and as such it is a prime example of a *linear code*. This means that the coordinate-wise addition of codewords is again a codeword, and pointwise multiplication of codewords by elements of the field is again a codeword. Not all codes are linear.

For a general code $\mathcal{C}$ defined over a finite field $\mathbb{F}_q$ with block length $n$, for any two codewords $\mathbf{u}, \mathbf{v} \in \mathbb{F}_q^n$, "absolute" Hamming distance $d(\mathbf{u}, \mathbf{v})$ is defined as the number of positions where the corresponding symbols differ:

$$d(\mathbf{u}, \mathbf{v}) = \left| \{ i \in \{1, \dots, n\} : u_i \neq v_i \} \right|$$

and typically one works with a fractional version of $d$ which takes in account the blocklength:

$$\Delta(\mathbf{u}, \mathbf{v}) = \frac{d(\mathbf{u}, \mathbf{v})}{n}$$

This allows the **interpretation of the distance as the fraction of entries in which two codewords differ**. Finally we recall the notion of the rate of a code of dimension $k$ and blocklength $n$ as the ratio:

$$\rho = \frac{k}{n}$$

This number can be interpreted in a few ways, namely as a measure of **information content:** $\rho$% of the transmitted symbols carry the actual information of the message. The **redundancy** is the remaining $(1-\rho)$% of the message, and is the resource consumed to provide error correction capabilities (more on this soon). A lower rate implies higher redundancy and theoretically higher resilience to noise, at the cost of throughput.

An important concept in coding theory is the concept of a list around a word w: for $w \in \mathbb{F}_q^n$ and $\delta > 0$ it is the set

$$List[w, \mathcal{C}, \delta]$$

and this is comprised of the codewords belonging to the code $\mathcal{C}$ that have distance at most $\delta$ from the word $w$. An associated question is given $w$ to decide, in terms of $\delta$, how many elements a list has. For sufficiently small $\delta$, the list around $w$ has at most one element and in this sense we will say that $w$ can be "corrected" to the corresponding $u \in \mathcal{C}$; that is the usual information-theoretic view of goodness of the code. We will say that in those circumstances we're within the "unique decoding regime". For Reed-Solomon codes, this bound for $\delta$ can be given in terms of the rate of the code and this regime is characterized with

$$\delta < \frac{1-\rho}{2}$$

However this will sometimes be too much of a restriction at the time of implementing efficient and fast code-based algorithms and **we will be willing to admit a list of candidate codewords sufficiently close to the received word $w$, instead of a single codeword.** At these times, we will we working in the "list decoding regime" and **it is crucial for lists $\mathcal{L}$ around $w$ not to have too many elements.** For that matter, there is a bound on $\delta$, usually called the Johnson bound that says that the number of elements in a list $\mathcal{L}$ is polynomially bounded. The Johnson bound is valid for any code, and is obtained by combinatorial and geometric arguments.

> **Johnson Bound for Reed-Solomon Codes:** Specifically for Reed-Solomon codes, it can be given in terms of the rate and the list decoding regime is characterized as
>
> $$\delta < 1 - \sqrt{\rho} = J$$
>
> and a standard upper bound for the list size $\mathcal{L}$ is:
>
> $$\mathcal{L} \le \frac{1 - \delta}{(1 - \delta)^2 - \rho}$$

Sometimes, this list size is expressed in terms of the distance between the operating proximity parameter $\delta$ and the actual Johnson bound; typically this is called the "safety gap" $\eta$. Naturally $\eta = J - \delta = 1 - \sqrt{\rho} - \delta$ and then

$$\delta = (1 - \sqrt{\rho}) - \eta \quad \implies \quad 1 - \delta = \sqrt{\rho} + \eta$$

This translates as

$$\mathcal{L} \le \frac{\sqrt{\rho} + \eta}{2\eta\sqrt{\rho} + \eta^2} \approx \frac{\sqrt{\rho}}{2\eta\sqrt{\rho}} = \frac{1}{2\eta}$$

The dependency $\mathcal{L} = O(1/\eta)$ often cited in FRI literature is simply the asymptotic behavior of the exact discriminant bound $\frac{1-\delta}{(1-\delta)^2 - \rho}$ as the proximity parameter approaches the Johnson bound.

## 2. What is an IOPP

Going back at the problem of the Prover (P) and Verifier (V) exchanging information, let's see how to set up that stage. Actually, it would be nice to start by spelling out what IOPP actually stands for: Interactive Oracle Proofs of Proximity. We'll contextualize each of these titles in this itemized section:

- Obviously, **Interactive** stands for the notion of prover and verifier interact with each other exchanging information.

- Now comes the sketchy part: in these contexts, the Verifier ($V$) lacks the computational resources to read the entire Prover's ($P$) message; it is restricted to open or look up a limited number of times a small portion of the data produced by the prover. Technically, the Verifier has what is called **Oracle** access: $P$ commits to a function $f: D \to \mathbb{F}$ and $V$ accesses $f$ essentially as a black box oracle. $V$ selects an index $x \in D$, and the oracle responds with $f(x)$.

  In practice, this is achieved via *Merkle Trees*. The commitment is the Merkle Root. An oracle query response consists of the value $f(x)$ and the Merkle authentication path.

- The use of **Proofs of Proximity** rather than strict membership is both a fundamental theoretical necessity in succinct proofs and practical limitation because **to verify strict membership (that a vector is *exactly* a codeword), the verifier must read the entire input and this requires linear time $\Omega(n)$.** In order to break free from this limitation, the idea is not to test for word-membership to the code, but rather that a word is **$\delta$-close** to the code. Within the FRI protocol, this property can be checked with high probability using only a logarithmic number of queries.

Let us emphasize these facts again:

> **Key Insight:** In order to make an IOPP protocol feasible in practice, we relax the condition of membership $f \in \mathcal{C}$ to a condition of proximity $\Delta(f, \mathcal{C}) < \delta$ by allowing a positive distance $\delta > 0$: this allows sublinear number of queries (sublinear in the blocklength $n$) since now the Verifier does not have to read the whole message - and at the same time, for security reasons, but we do not allow a $\delta$ way too big: if a malicious Prover (P) wants get away with a false statement $f$ we want to make those chances as slim as possible. For that reason we demand $\delta$ to be bounded by a meaningful constant, say, the Johnson bound.

## 3. How FRI works

FRI stands for Fast Reed-Solomon Interactive Proof of Proximity, a shortened version of RS-IOPP. It is actually an IOPP protocol adjusted for Reed Solomon codes. It basically consists of two distinct phases: the COMMIT phase and the Verify phase. Most of the optimization and prover's work comes in during the COMMIT phase, while the Verifier's bulk of work happens during the Verify phase. We proceed to briefly discuss each of these phases.

### 3.1 The COMMIT phase

In this phase, the Prover wants to prove that he possesses a codeword in $\mathcal{C}_0 = RS[q,n,k]$ where the evaluation domain $\mathcal{D}_0$ is agreed beforehand. Conceptually, after the $i$-th round of interaction with the Verifier the Prover produces a codeword $f_i$ belonging to a smaller Reed Solomon code $C_i$. This results in a sequence of codewords $f_1, f_2, \ldots f_r$ belonging to an adequate sequence of Reed-Solomon codes $C_i = RS[q, n_i, k_i]$ such that if $n = n_0$ and $k = k_0$ then for $0 \leq i \leq r$:

- the evaluation domains are nested: $\mathcal{D}_{i+1} \subset \mathcal{D}_i$ and their sizes are uniformly related: this means that we have a relation of the form $n_i = a \cdot n_{i+1}$ where the constant $a$ is known as the *folding constant*. Typically, $a = 2, 4$ or $8$. In this exposition we'll stick to the case $a = 2$ for simplicity.
- the rate of the code remains unchanged at each step: $\frac{k_i}{n_i} = \rho$.

> **Note:** The FRI protocol is usually instantiated for fields of characteristic $> 2$, and blocksize $n_0$ being a power of $2$ such that $\mathcal{D}_0$ is indeed the collection of $n_0$-th roots of unity. Also, the dimension of the code is chosen to be a power of two so that the rate can be interpreted in terms of bits.

A brief description of the COMMIT phase goes as follows:

1. **Initialization:** An honest Prover $P$ commits to the initial codeword $f_0$ (via a Merkle Root).

2. **Interaction Loop ($i = 0$ to $r-1$):**
   - The verifier $V$ sends a random challenge $\alpha_i \in \mathbb{F}$.
   - The $P$ now proceeds to construct a new word in a "smaller" Reed-Solomon code $\mathcal{C}_{i+1}$ over the new domain $D_{i+1} = \{x^2 : x \in D_i\}$ which is a subset of the previous domain and contains half the points. The rationale behind this is that for a polynomial $f_i$ with $\deg(f_i) < k_i$ one can write $f_i$ as the sum of a polynomial containing all the even powers and a polynomial containing all the odd powers. This amounts to the guaranteed existence of two polynomials $g_i$ and $h$ both having degree $< \frac{k}{2}$ such that

     $$f_i(X) = g_i(X^2) + X h(X^2)$$

     One of the good things about this decomposition, is that both $g_i$ and $h$ evaluated at $x^2$ are linearly related to $f$ evaluated at $x$ and $-x$:

     $$g_i(x^2) = \frac{f(x) + f(-x)}{2} \quad \text{and} \quad h(x^2) = \frac{f(x) - f(-x)}{2x}$$

     and so the Prover is now able to define a new Reed-Solomon codeword for $z \in D_{i+1}$ by

     $$f_{i+1}(z) = g_i(z) + \alpha_i h_i(z)$$

     belonging to $C_{i+1} = RS[q, \frac{n_i}{2}, \frac{k_i}{2}]$. $P$ computes and commits to this new word and sends the new Merkle root to V.

3. **Termination:** The process stops when the degree is small (e.g., constant). $P$ sends the final value directly.

The reader acquainted with the classical Fast Fourier Transform algorithm will find these last few lines very familiar.

### 3.2 The VERIFY phase

We're now ready to describe the VERIFY phase of the protocol: $V$ verifies that the committed functions satisfy the recurrence relation defined by the challenges $\alpha_i$.

1. **Sampling:** $V$ samples a random point $z$ from the initial domain $D_0$.

2. **Consistency Check:** For each layer $i$:
   - $V$ queries the oracle for $f_i(z)$ and $f_i(-z)$ (symmetric points in domain $D_i$).
   - $V$ queries the oracle for $f_{i+1}(z^2)$ in the next domain $D_{i+1}$.
   - $V$ verifies the collinearity equation:
     $$f_{i+1}(z^2) \stackrel{?}{=} g_i(z^2) + \alpha_i \cdot h_i(z^2)$$
     where $g_i$ and $h_i$ are derived from the even and odd coefficients of $f_i$.

This description leads to the central question of the article: how safe is this gadget?

## 4. An improved soundness analysis of FRI as an IOPP instantiation

Here is where the novelty of the recent work BCHKS25 improves the soundness analysis of the FRI protocol done in BCIKS20. In the foundational article Proximity Gaps for Reed-Solomon codes, the authors proved a fundamental result (coined the Correlated Agreement Theorem) from which the soundness of the FRI protocol is proved. In their most recent paper, a detailed analysis of a linear algebra fact is used to obtain tighter bounds describing the soundness of the protocols, enabling now implementations in a wider setting. Before diving into the mathematics involved, we need to define the concept of $\delta$-soundness, from which the security of the protocol can be established and fine-tuned.

> **Soundness Definition:** In order to define what it means for an IOPP to have a soundness with parameters $(\delta, \epsilon)$ we will simply take the simplest route first: the probability of the Verifier accepting a forged proof $f^*$ should be as small as possible. In terms of distance to a code, let us re-phrase the previous sentence as: the probability of the Verifier accepting a word $f^*$ which is $\delta$-far should be less than $\epsilon$.

Mathematically, let $\mathcal{C} \subseteq \mathbb{F}_q^n$ be a Reed-Solomon code. Let $P^*$ be any (potentially malicious) prover strategy that outputs an oracle function $f^*: D \to \mathbb{F}$.

**Definition:** The FRI protocol is said to have **soundness error $\epsilon$ for proximity parameter $\delta$** if the following implication holds:

$$\text{If } \min_{c \in \mathcal{C}} \Delta(f^*, c) > \delta \quad \implies \quad \Pr\left[ V^{f^*} \text{ accepts} \right] \le \epsilon$$

Where $\Delta(\cdot, \cdot)$ denotes the relative Hamming distance.

From the definition of $(\delta, \epsilon)$ soundness of the IOPP, one can define the security level $\lambda$ (in bits) of the Protocol. It relates to the soundness error $\epsilon$ of the protocol, defined as the probability that a Verifier accepts a proof for an invalid statement (i.e., a codeword that is $\delta$-far from the code).

$$\epsilon \le 2^{-\lambda} \iff \lambda = -\log_2(\epsilon)$$

Now the nature of the soundness error can be also characterized in a colloquial manner: the acceptance of a forged codeword could be the result of two combined effects

1. a dishonest Prover being lucky proposing a forged codeword $f^*$ which is $\delta$ far from the code and gets closer to the code at each folding step: this will be typically named "folding error" or "commit error" since it happens during the COMMIT phase, $\epsilon_{commit}$

2. a Verifier being unlucky and spot checking at places where a forged codeword $f^*$ actually coincides with a valid codeword: this error usually goes by the name of "query error", $\epsilon_{query}$.

The total soundness error is composed of errors from the two main phases:

$$\epsilon_{\text{total}} \le \epsilon_{\text{commit}} + \epsilon_{\text{query}}$$

Particularly, the commit error is of relevance because it talks about a structural feature of the whole FRI gadget: we need to know that a dishonest Prover has very little chance of getting away with a forged proof - in terms of vicinity, the chances for a forged word becoming closer to the code at each folding step must be negligible. And here is where the celebrated Correlated Agreement comes in: it states that **whenever a folding of two words is sufficiently close to a Reed-Solomon code, it must be because the words being folded have themselves a very high agreement with valid Reed-Solomon words, this is, they are close to Reed Solomon code themselves to begin with.** This rules out the possibility of "fabricating valid words from invalid ones".

## 5. What changed?

In the classic analysis presented in BCIKS20, the soundness error is derived using a union bound over the $r$ rounds of folding and the expression obtained by the authors was roughly:

$$\epsilon_{\text{classic}} \approx \underbrace{\frac{n^2}{q}}_{\text{Commit Error}} + \underbrace{(1 - \delta)^l}_{\text{Query Error}}$$

where $l$ was the number of queries, $n$ the block size and $q$ the number of elements in the field. The immediate implications where that in order to achieve, say $\lambda = 100$ bits of security, one required $\frac{n^2}{q} < 2^{-100}$. This forced $q \approx n^2 \cdot 2^{100}$, prohibiting the use of small fields (like 64-bit fields) for large $n$. Also, the bits of security from the query phase scale linearly with $l$:

$$\lambda_{\text{query}} \approx l \cdot \log_2\left(\frac{1}{1-\delta}\right)$$

In their recent article, Ben-Sasson et al revisited the original proof and gave a refined use of a linear algebra argument present in the application of the Guruswami-Sudan decoder and achieved tighter and better bounds for this error. The refined error bound is approximately:

$$\epsilon_{\text{modern}} \approx \underbrace{\frac{n}{q}}_{\text{Commit Error (Linear)}} + \underbrace{C \cdot (1 - \delta)^l}_{\text{Query Error}}$$

(Where $C$ is a small constant related to the list size, often close to 1 in practice). The key improvements can be directly seen from their estimate: the improvement from $|S| \approx n^2$ to $|S| \approx n$ fundamentally changes the requirements for the field size $q$ in the Commit Phase soundness error $\epsilon = |S|/q$.

- **In BCIKS20:** To get $\epsilon < 2^{-40}$ with $n = 2^{20}$, one required $q \approx n^2 \cdot 2^{40} = 2^{80}$. This ruled out efficient 64-bit fields (like Goldilocks).
- **In BCHKS25:** With $|S| \approx n$, to get $\epsilon < 2^{-40}$, one requires $q \approx n \cdot 2^{40} = 2^{60}$. This allows the use of small, hardware-friendly fields (e.g., 64-bit fields) while maintaining rigorous provable security.

### The origin of the $n^2/q$ error term in classic FRI analysis and how it got shaved

This section is aimed for the mathy reader familiar with the technical folklore of polynomials and its use in coding theory. The derivation of the bound for the commit phase error can be understood once we are clear in the role of some sets and consistent with the notation.

Conceptually speaking, the bound for the commit phase can be interpreted by looking at the event of the Prover going lucky by folding two codewords which are $\delta$-far from the code with an unfortunate bad choice of $\alpha \in \mathbb{F}_q$ by the Verifier (V), and obtaining a codeword which is closer to the code. Concretely, let $u_0, u_1: \mathcal{D} \to \mathbb{F}$ be the functions committed by the Prover. Let $\mathcal{C}$ be the target Reed-Solomon code. The set $S$ is defined as:

$$S = \{ z \in \mathbb{F}_q : \Delta(u_0 + z \cdot u_1, \mathcal{C}) \le \delta \}$$

In words, $S$ contains every field element $z$ such that the linear combination $u_0 + z u_1$ falls within the proximity radius $\delta$ of the code, even if $u_0$ and $u_1$ themselves are far from $\mathcal{C}$. At the level of the FRI Protocol, the size of $S$ directly dictates the soundness error of the Commit Phase, since assuming uniformly random choices of challenges at the Verifier's end,

$$\text{Probability of Commit Error} = \Pr_{\alpha \leftarrow \mathbb{F}_q}[\alpha \in S] = \frac{|S|}{q}$$

Of course, to ensure security we must prove that $|S|$ is as small as possible when compared to the field size $q$. In the seminal paper BCIKS20, the authors obtain a very important and celebrated result, the Correlated Agreement Theorem (or CAT for short) which involves the size of this set $S$ of "bad folds" and is *almost* a proof of the soundness of FRI.

**Theorem (Correlated Agreement on lines):** Let $u_0, u_1: \mathcal{D} \to \mathbb{F}_q$, $m \geq 3$ and define $\delta_0(\rho, m) = J - \frac{\sqrt{\rho}}{2m}$. Set $\delta \leq \delta_0$. If

$$|S| > \frac{(1 + \frac{1}{2m})^7 m^7}{3\rho^{3/2}} n^2$$

then there exist two Reed Solomon codewords $v_0, v_1 \in \mathcal{C}$ such that they jointly coincide with $u_0, u_1$ in a set of size at least $(1-\delta)n$:

$$|\{x \in \mathcal{D}: (u_0(x), u_1(x)) = (v_0(x), v_1(x))\}| > (1-\delta)n$$

At this point, the reader is rightly puzzled since off the bat we're contested with very funny expressions depending oddly on some new constants. The thing is that the bound on $S$, its shape and qualitative meaning are derived from the *method of proof* of the CA theorem, namely the use of a very important piece of machinery from coding theory called the Guruswami-Sudan decoder. Before commenting on this powerful algorithm, let's brush up the statement of the CAT in terms more sensible to the FRI protocol. By setting $\eta > 0$ the distance from $\delta$ to the Johnson bound $J = 1 - \sqrt{\rho}$ and $m = O(\frac{\sqrt{\rho}}{\eta})$, the previous theorem allows us to have the following *working version* of CAT:

> **Theorem (Working Version):** Let $u_0, u_1: \mathcal{D} \to \mathbb{F}_q$, $\delta, \eta > 0$ and suppose $\eta \leq \frac{\sqrt{\rho}}{20}$. Define $\delta_0(\rho, \eta) = J - \eta$ and set $\delta < \delta_0$. If
>
> $$|S| > \frac{\rho^2}{(2\eta)^7} \frac{n^2}{q}$$
>
> then there exist two Reed Solomon codewords $v_0, v_1 \in \mathcal{C}$ such that they jointly coincide with $u_0, u_1$ in a set of size at least $(1-\delta)n$:
>
> $$|\{x \in \mathcal{D}: (u_0(x), u_1(x)) = (v_0(x), v_1(x))\}| > (1-\delta)n$$

Now this is a little bit easier for the eyes. And now how does this actually help us prove the soundness of FRI? What this theorem says is that whenever the set of bad folds is "big enough", then the words being folded were close to the RS code themselves. This implies that a malicious prover does not have high chance of cheating: his "bad folding set" will be of limited size and so the expression

$$\frac{\rho^2}{(2\eta)^7} \frac{n^2}{q}$$

serves as an upper bound for $\epsilon_{commit}$.

So how do we make sense of why do we see a quadratic term $n^2$ in this expression? Let's dive into the mechanics of method of proof of this result, the application of the Guruswami-Sudan Decoder.

> **Guruswami-Sudan Decoder:** Briefly speaking, the Guruswami-Sudan decoder is an algorithm that takes as inputs: a word in the form of list of pairs $(x_i, y_i) \in \mathbb{F}^2$ for $1 \leq i \leq n$, a "multiplicity parameter" $m$, and an integer $D_X = D_X(m)$. Then proceeds in two phases:
>
> 1. **Interpolation Phase:** The algorithm finds a polynomial $Q(X,Y) \in \mathbb{F}[X,Y]$ such that has zeros of order at $m$ at each $(x_i, y_i)$, this is, a polynomial $Q$ that satisfies
>
>    $$Q(x_i, y_i) = 0 \quad \text{and} \quad \nabla_X^{m_X} \nabla_Y^{m_Y} Q(x_i, y_i) = 0$$
>
>    for all non negative integers $m_X, m_Y$ such that $m_X + m_Y < m$. Here, the symbol $\nabla_X^{m_X}$ stands for "take the derivative of $Q$ respect to the variable $X$ exactly $m_X$ times", and by that, we mean the Hasse derivative at $(x_i, y_i)$. The choice of $m$ is made to ensure that this equations form a compatible system of linear equations for the coefficients of $Q$ producing a non trivial polynomial. This typically happens when the number of unknowns is greater than the number of equations.
>
> 2. **Factorization Phase:** The algorithm finds factors of $Q(X,Y)$ of the form $R(X,Y) = Y - P(X)$
>
>    The vanishing of $Q$ implies then that each factor produces a word $P$ interpolating "sufficiently many" of the points inputs $(x_i, y_i)$. The number of such factors is bounded above by $D_Y = \deg_Y(Q)$, the total $Y$ degree of $Q$.
>
> In terms of list decoding Reed Solomon words, the GS decoder produces all the words that are close enough to the received points.

The idea in BCIKS is that since the GS decoder works for any field, the authors now instantiate the algorithm with $\mathbb{F}_q(Z)$ as basefield, and interpret a folded word $u_0(X) + Z u_1(X)$ as a Reed Solomon word in this extended setting. By appropriately choosing $m$ and $D_X$ the GS decoder produces an interpolating polynomial

$$Q(X,Y) \in \mathbb{F}_q(Z)[X,Y]$$

The coefficients of this polynomial are a priori, elements of the field $\mathbb{F}_q(Z)$, this means that the coefficients are quotients of polynomials: rational functions of $Z$. So, here comes the first feat of fine tuning:

> **Key Observation:** By carefully looking at the rank of the interpolation matrix and an application of Cramer's rule to non singular minor of the coefficient matrix, a non trivial solution to the interpolation problem can be found such that its coefficients are actually polynomials in $Z$, and their degree can be tracked.

Now, we can suppose that the coefficients of $Q$ are simply polynomials in $Z$ and so we can consider

$$Q(X,Y,Z) \in \mathbb{F}_q[X,Y,Z]$$

It is in terms of the weighted degree of this polynomial that the bound for $S$ is expressed. Concretely, the authors prove that the following inequalities hold:

- $\deg_X(Q) < D_X = (m + \frac{1}{2})\sqrt{\rho} n$
- $\deg_Y(Q) < \frac{D_X}{k} = \frac{(m + \frac{1}{2})}{\sqrt{\rho}}$
- $\deg_{YZ}(Q) \leq \frac{(m + \frac{1}{2})^3}{6\sqrt{\rho}} n$

where $D_{YZ}$ is the $(0,1,1)$ weighted degree of $Q$. This measures the degree in $Z$ *after* substituting $Y$ for a polynomial of degree 1 in $Z$. This is a crucial quantity to look after, since it controls the vanishing of $Q$.

> **In this language, the hypothesis on the lower bound of the set of "bad folds" becomes**
>
> $$|S| > 2 D_X D_Y^3 D_{YZ}$$
>
> **We will devote the rest of this article to make sense of this inequality, and crucially, how it is used.**

We will begin by exploiting the interpolation with multiplicity which is granted by the GS algorithm: whenever $z \in S$ we know that there's a polynomial $P_z(X)$ with coefficients in $\mathbb{F}_q$ with $\deg_X(P_z) < k$ such that $Y - P_z(X)$ is a factor of $Q(X, Y, z)$. This means, that $Q(X, P_z(X), z) = 0$ and whenever $Q$ factors as $Q = A \cdot B$, then

$$A(X, P_z(X), z) = 0 \quad \text{or} \quad B(X, P_z(X), z) = 0$$

since $\mathbb{F}_q$ is a field. This allows us to concentrate on irreducible factors $\Psi \in \mathbb{F}_q[X,Y,Z]$ of $Q$; supposing

$$Q(X,Y,Z) = C(X,Z) \prod_i \Psi_i(X,Y,Z)$$

where each factor $\Psi$ is irreducible with $\deg_Y(\Psi_i) \geq 1$ and for simplicity we also assume they are *separable* in the $Y$ variable. Now for each $z \in S$ we must have some factor $\Psi_i$ vanishing, and since $\deg_Y(Q) = D_Y$, there are at most $D_Y$ such factors. This implies that there must be one factor that "absorbs" at least $\frac{|S|}{D_Y}$ such points. Let $\Psi$ be such a factor.

Now the next step is finding "a good $x_0$" - this is, a good starting point in the domain $\mathcal{D}$ to characterize such a polynomial $P_z(X)$. In order to do so, it is proven that there exists a $x_0 \in \mathbb{F}_q$ such that $\Psi(x_0, Y, Z)$ is again separable in $Y$. For such a point now the dependency on $X$ disappears and the "good factor" now can be expressed as

$$\Psi(x_0, Y, Z) = C \psi(Z) \prod_j H_{\psi,j}(Y,Z)$$

so the vanishing of $\Psi$ is translated as the vanishing of one of its factors $H$ when evaluated at $(P_z(x_0), z)$. So we will be interested in the set

$$S_{x_0, \Psi, H} = \{z \in S: \Psi \text{ vanishes at } (X, P_z(X), z) \text{ and } H(P_z(x_0), z) = 0\}$$

> **Conceptually, this is exactly the set of $z$ such that the Implicit Function Theorem, in a finite field setting, applies. In the algebraic literature, this goes by the folk name of "Hensel lifting". For these values of $z$, a solution $P_z(X)$ in the form of a power series with coefficients in $\mathbb{F}_q(Z)$ and powers of $(X - x_0)$ exists.**

Notice that the separability of $\Psi(x_0, Y, Z)$ is typically the non vanishing of the $Y$-derivative. Since we are interested in polynomial solutions, some of these points in $S_{x_0, \Psi, H}$ won't work: the ones that are poles of the coefficients of the series. So, in order to guarantee this local existence of $P_z(x_0)$, we need to show that the set

$$S' = S_{x_0, \Psi, H} - \{z \in S: \text{ are poles of the coefficients present in the power series}\}$$

**is "big enough"**.

The biggest source of complications come from the set of poles - and this is so because there is no guarantee that the $H_{\psi,j}$ factor of $\Psi$ is monic: this is what produces the denominators in the coefficients of the formal power series solution around $x_0$. Dealing with this involves the theory of weight and descending to the theory of algebraic function fields (a fascinating subject a little bit afar from the aims of this review).

Cutting to the chase, the hypothesis in the Correlated Agreement Theorem

$$|S| > 2 D_X D_Y^3 D_{YZ}$$

enables to firstly find an important lower bound for the $z$ leading to a formal power series solution:

$$|S_{x_0, \Psi, H}| \geq \frac{|S|}{D_Y} > 2 D_Y^2 D_X D_{YZ}$$

The authors also obtain an upper bound for the number of poles can be obtained by the use of **an analogue of the Schwarz-Zippel lemma (Lemma A.1 in their appendix), which is used crucially three times in their proof.** First, to obtain an upper bound for the set of poles reading $D_Y^2 D_{YZ}$

and in turn this produces a lower bound for the number of elements in $S'$:

$$|S'| > |S_{x_0, \Psi, H}| - D_Y^2 D_{YZ} > 2 D_X D_Y^2 D_{YZ} - D_Y^2 D_{YZ} = D_Y^2 D_{YZ}(2D_X - 1)$$

> **Secondly, this lower bound is exactly what the Schwarz-Zippel lemma demands to guarantee polynomial solutions of degree at most $k$ in $X$; then again it is used to guarantee (together with the Fundamental Theorem of Algebra) that the degree in $Z$ of the solution is at most 1** and so
>
> $$P(X,Z) = V_0(X) + Z V_1(X)$$

produces the promised Reed-Solomon words $v_0$ and $v_1$ and this concludes the path set in BCIKS.

In the recent BCHKS25, two improvements are made: first of all, a tighter linear algebra argument is carried on at the Cramer Rule level producing an interpolating polynomial $Q$ with a smaller $D_{YZ}$:

$$D_{YZ} \leq \frac{1}{3}(m + \frac{1}{2})^2 \frac{n}{k}$$

- now the choice of $m$ is bound to be $m \geq 3$ and still allows some optimization. Second, in carrying out the very same analysis of BCIKS20, a closer look at the set $S_{x_0, \Psi, H}$ a smaller lower bound for $S$ while keeping the use of the Schwarz-Zippel lemma for algebraic function fields. What happens is that in the original paper, **lower bounds on this set are established in terms of the weighted degree bounds of $Q$, while the set is defined in terms of a factor of $Q$.**

Before continuing, lets set:

- $D_Y^{\Psi_i} = \deg_Y(\Psi_i)$
- $D_Y^{H_{i,j}} \equiv D_Y^{H_{\psi_i,j}} = \deg_Y(H_{\psi_i,j})$
- $D_Z^{\Psi_i} = \deg_{YZ}(\Psi_i) - \deg_Z(C_i)$ - the weighted $(1,1)$ degree of the part of $\Psi_i$ that does not include the pure $Z$ factor.

since we're going to use these quantities to bound the size of the sets $S_{x_0, \Psi_i, H_{ij}}$. Now the authors prove that there exists a pair of factors $\Psi_i, H_{ij}$ such that

1. $|S_{x_0, \Psi_i, H_{ij}}| \geq 2 D_X D_Y^{\Psi_i} D_Y^{H_{ij}} D_Z^{\Psi_i}$
2. $|S_{x_0, \Psi_i, H_{ij}}| > D_Y^{\Psi_i} D_Y^{H_{ij}} D_Z^{\Psi_i} + \delta n + 1$

both hold simultaneously; if these inequalities fail to hold for all possible pairs, then the fact that the sets $S_{x_0, \Psi_i, H_{ij}}$ form a partition of $S$ implies that by summing over all possible factors we achieve

$$|S| \leq 2 D_X D_Y^2 D_{YZ} + (\delta n + 1) D_Y$$

This last inequality is obtained by formally summing and using the additivity of degrees when factoring a polynomial (this is what makes the funny degree notation above disappear and lets the degrees of $Q$ finally pop up); details are present in section 3 of BCHKS25.

> **What this result is saying is that whenever $|S| > 2 D_X D_Y^2 D_{YZ} + (\delta n + 1) D_Y$ a polynomial of adequate degrees in $X$ and $Z$ can be found from Hensel Lifting producing the promised Reed-Solomon words that appear in the conclusion of the Correlated Agreement.**

The last part of this analysis amounts to taking a look at the bound for $S$ employing the improved weighted degree bounds for $Q$; by losing the linear part in $D_Y$ we obtain

$$|S| > 2 D_X D_Y^2 D_{YZ} > 2(m + \frac{1}{2})\sqrt{nk} \cdot \left((m + \frac{1}{2})\frac{n}{k}\right)^2 \cdot \frac{1}{3}(m + \frac{1}{2})\frac{n}{k}$$

and since the rate of the code is defined as $\rho = \frac{k}{n}$, we obtain

$$|S| > \frac{2}{3}(m + \frac{1}{2})^5 \sqrt{nk} \frac{n}{k} \frac{n}{k} = \frac{2}{3} \frac{(m + \frac{1}{2})^5}{\rho^{3/2}} \cdot n$$

which is pretty much the promised improvement against the former known bound

$$|S| > \frac{(m + \frac{1}{2})^7}{3\rho^{3/2}} \cdot n^2$$

To finally land on our feet, what this discussion has been about: if for sufficiently many $z$ the words $u_0(X) + z u_1(X)$ are $\delta$ close to the code, then an Implicit Function argument produces Reed-Solomon codewords $v_0(X), v_1(X)$ which are $\delta$-close to the original words (where all this runs on the choice of $\delta$ and the parameters of the Reed-Solomon code). So the chances for a malicious prover to cheat the verifier, are indeed slim, namely linear in the size of the evaluation domain $\mathcal{D}$.
