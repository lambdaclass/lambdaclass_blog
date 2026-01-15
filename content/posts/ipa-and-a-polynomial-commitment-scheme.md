+++
title = "Inner Product Argument (IPA) and a Polynomial Commitment Scheme"
date = 2023-08-25
slug = "ipa-and-a-polynomial-commitment-scheme"

[extra]
math = true
feature_image = "/images/2025/12/Robert_Arch_of_Titus.jpg"
authors = ["LambdaClass"]
+++

In this blogpost, we'll take a closer look at the Inner Product Argument. We'll start by understanding the basics of this technique and then shift our focus to its variant within the Halo2 proving system. Specifically, we'll explore how Halo2 ingeniously employs the Inner Product Argument as a polynomial commitment scheme.

Let's first fix some notation that will be used throughout the text.

## Notation

The symbol $\mathbb{F}$ always denotes a prime field of order $p$. Given two vectors $A=(a_1,\dots,a_n)$ and $B=(b_1,\dots,b_n)$ of elements of $\mathbb{F}$ of the same length, the inner product between $A$ and $B$ is the element $a_1b_1 + \cdots + a_nb_n \in \mathbb{F}$. It is denoted by $\langle A, B\rangle$.

The symbol $\mathbb{G}$ denotes a commutative group of order $p$. We always use additive notation. If $A=(a_1,\dots,a_n)$ is a vector of elements of $\mathbb{F}$ and $G=(G_1, \dots, G_n)$ is a sequence of elements of $\mathbb{G}$, then $\langle A, G\rangle$ denotes the element $a_1G_1 + \cdots + a_nG_n \in\mathbb{G}$.

# The inner product argument

To understand what this is all about, let's go straight to its description. This is a sort of commitment scheme and there will be a prover and a verifier. The argument has two parts.

**Commit** : The prover can commit to a pair of vectors $(A, B)$, where $A \in \mathbb{F}^n$ and $B \in \mathbb{F}^n$ by producing an object that we denote by $P$. This process does not unveil $A$ or $B$, but it is binding. Meaning that any other vectors would produce another commitment with high probability. Usually, the prover sends $P$ to the verifier.

**Open** : Assume the verifier already holds a commitment $P$. The open protocol is an interactive protocol in which the prover sends a value $c\in\mathbb{F}$ and convinces the verifier that

        * $P$ is a valid commitment of two vectors $A$ and $B$, both of length $n$.
        * The value $c$ is the inner product of $A$ and $B$.

### Ok, but why?

This scheme itself might not seem particularly valuable, as $A$ and $B$ can be anything. However, its significance lies in its role as a building block for other proving systems. Within these contexts, additional checks are applied to enforce specific structures upon $A$, $B$, and $c$, all dependent on public parameters. Instead of sending $P$, the prover sends other commitments that make possible the structure checks on $A$ and $B$. From those commitments, the verifier can efficiently reconstruct $P$. This approach imbues the vectors with certain contextual meanings regarding the statement being proven. The requirement that their inner product equals a predetermined value functions as evidence of the prover's knowledge regarding this fact.

The version we'll describe next was introduced in the [Bulletproofs paper](https://eprint.iacr.org/2017/1066). To gain further insight into its application within a zero-knowledge proof of arithmetic circuits, refer to Section 5 of that paper.

### Setup

Both the Commit and Open protocols depend on a few precomputed values. The needed ingredients are:

        * A commutative group $\mathbb{G}$ with $p$ elements. We'll use additive notation.
        * Two sequences of elements $G=(G_1,\dots, G_n)$ and $H=(H_1,\dots, H_n)$ of elements of $\mathbb{G}$. We may refer to these as _bases_.

Here $n$ is the length of the vectors to be committed. We will always assume it is a power of two. If this is not the case, vectors can be padded with zeroes until the next power of two.

### Commit

Given vectors $A = (a_1,\dots, a_n)$ and $B=(b_1,\dots, b_n)$, the commitment of the pair $(A, B)$ is:

$$P := \sum_{i=1}^n a_i G_i + \sum_{i=1}^n b_i H_i.$$

### Open

The Open protocol has $\log_2(n)$ rounds. Let's start with the easiest example.

#### Case $n=2$.

In this case $A = (a_1, a_2)$ and $B = (b_1, b_2)$.

The protocol starts with the verifier choosing a random element $U$ in $\mathbb{G}$ and sending it to the prover.

The prover computes the following elements and sends them to the verifier

        * $L := a_1G_2 + b_2H_1 + a_1b_2U$ and
        * $R := a_2G_1 + b_1H_2 + a_2b_1U$.

The verifier chooses a random non-zero value $x\in\mathbb{F}$ and sends it to the prover, who uses it to compute the following elements:

        * $a' := a_1 x + a_2 x^{-1}$
        * $b' := b_1 x^{-1} + b_2 x$

The prover sends $a'$ and $b'$ to the verifier. Finally, the verifier checks that:

$$  
\begin{equation}  
x^2 L + P + c U + x^{-2} R = x^{-1} a' G_1 + xa' G_2 + x b' H_1 + x^{-1} b' H_2 + a'b'U  
\end{equation}  
$$

The verifier accepts if and only if the above equality holds.

#### Completeness idea

To see why this equality holds, one can expand both sides and check that they have the same terms. Let's examine for example the first term on the right-hand side:

$$  
\begin{aligned}  
x^{-1} a' G_1 &= x^{-1} (a_1 x + a_2 x^{-1}) G_1 \\\  
&= (a_1 + a_2 x^{-2}) G_1 \\\  
&= \color{blue}{a_1 G_1} + \color{red}{x^{-2} a_2 G_1}  
\end{aligned}  
$$

Notice how this matches part of $P = \color{blue}{a_1G_1} + a_2G_2 + b_1H_1 + b_2H_2$. The other term appears in $x^{-2}R = \color{red}{x^{-2}a_2G_1} + x^{-2} b_1 H_2 + x^{-2}a_2b_1U$. The rest of the terms behave similarly.

#### Soundness idea

In the Bulletproofs paper, the authors prove that, under the discrete log assumption, if the prover could successfully respond with $a',b'$ for at least $4$ different values of $x$, then two vectors $A$ and $B$ can be extracted from them such that $\langle A, B\rangle = c$ and $P$ is the commitment of the pair $(A, B)$.  
So if such $A$ and $B$ don't exist, there are at most $3$ values of $x$ for which the prover knows $a'$ and $b'$ that make the verifier's check pass. But the chances that the verifier happens to choose a random $x$ that's one of those $3$ options, is negligible.

#### General case for $n = 2^k$

It is an iterative application of a process in that in each step the prover takes two vectors $A$ and $B$ of size $2^k$ and produces two more vectors $A'$ and $B'$ each of size $2^{k-1}$. In the subsequent step $A'$ and $B'$ take the role of $A$ and $B$ and repeat until $k=0$. In each intermediate step, the bases $G$ and $H$ are updated to halve their length too.  
In the first iteration, $A$ and $B$ are the original vectors and the final step is exactly the base case already described for $n=2$. At the end, $A'$ and $B'$ would be of length $1$, so they are just elements of $\mathbb{F}$. They are the elements we denoted by $a'$ and $b'$ above.

Concretely, the first step is as follows.

Let $n = 2^k$ and suppose $k>1$. Otherwise, we follow the case $n=2$ described above.  
Write $A = (a_1,\dots, a_{2^k})$ and define the lower and higher parts of $A$ as $A_{lo} := (a_1,\dots,a_{2^{k-1}})$ and $A_{hi} := (a_{2^{k-1}+1}, \dots, a_{2^k})$. The same for $B$, $B_{lo}$ and $B_{hi}$, $G_{lo}$, $G_{hi}$, $H_{lo}$, $H_{hi}$.

The protocol starts also with the verifier choosing a random element $U$ in $\mathbb{G}$ and sending it to the prover. This only happens at the very first round. The same element $U$ is then used throughout all rounds.

The prover computes the following vectors and sends them to the verifier

        * $L := \langle A_{lo}, G_{hi} \rangle + \langle B_{hi}, H_{lo} \rangle + \langle A_{lo}, B_{hi}\rangle U$, and
        * $R := \langle A_{hi}, G_{lo} \rangle + \langle B_{lo}, H_{hi} \rangle + \langle A_{hi}, B_{lo}\rangle U$.

The verifier chooses a random non-zero value $x\in\mathbb{F}$ and sends it to the prover.

At this point, the next step starts. The prover computes

        * $A' := x A_{lo} + x^{-1} A_{hi}$,
        * $B' := x^{-1} B_{lo} + x B_{hi}$.

These will take the roles of $A$ and $B$. The bases are updated similarly to $A$ and $B$. Meaning, in the next step, instead of $G$ and $H$, the following bases are used:

        * $G' := x^{-1} G_{lo} + x G_{hi}$.
        * $H' := x H_{lo} + x^{-1} H_{hi}$.

Finally, the verifier accepts if and only if the check at the last step ($n$=2) succeeds.

# Polynomial commitment scheme

There is a polynomial commitment scheme inspired by the IPA protocol. This is used in the [Halo2](https://zcash.github.io/halo2/index.html) proving system.

A polynomial commitment scheme has two parts:

        * **Commit** : given a polynomial $p$, the prover produces an object that's unique to $p$. We denote it here by $[p]$ and is called the _commitment_ of $p$. The prover usually sends $[p]$ to the verifier. The object $[p]$ is a sort of hash of $p$.
        * **Open** : This is an interactive protocol between the prover and the verifier. The verifier only holds the commitment $[p]$ of some polynomial and sends a value $z$ to the prover at which he wants to know the value $p(z)$. The prover responds with a value $c$ and then they engage in the _Open_ protocol. As a result of it, the verifier gets convinced that the polynomial that corresponds to the commitment $[p]$ evaluates to $c$ at $z$.

The idea to build a polynomial commitment scheme out of IPA is primarily based on two observations.

        * A polynomial $p = \sum_{i=0}^{n-1} a_i X^i$ is uniquely determined by the vector of its coefficients $A = (a_0, \dots, a_{n-1})$.
        * The evaluation of $p$ at an element $z$ is precisely the inner product between the vector $A$ of coefficients of $p$ and the vector $B$ of power of $z$. More precisely, if $p = \sum_{i=0}^{n-1} a_i X^i$, then

$$ p(z) = \langle A, B\rangle,$$  
where $A = (a_0, \dots, a_n)$ and $B = (1, z, z^2, \dots, z^n)$.

As we'll see shortly, the commitment of the polynomial $p$ is very similar to the commitment $P$ of $(A, B)$ in IPA. The open protocol is very similar too. And it proves that a value $c$ is actually $c = \langle A, B\rangle$, which is $p(z)$ by the way $B$ is defined.  
A major difference with IPA is that, in this case, the vector $B$ is always known to the verifier. So the terms that correspond to $B$ in the commitment are unnecessary. This makes the sequence $H_1,\dots, H_n$ unnecessary too. Instead of completely removing those terms, a random value is added by the prover, but with another purpose. It is called the _blinding factor_ and it's there to add zero knowledge to the protocols.

### Setup

As with IPA, there is a setup phase where the needed ingredients are produced:

        * A commutative group $\mathbb{G}$ with $p$ elements. As before, we'll use additive notation.
        * A sequences of elements $G_0,\dots, G_{n-1} \in \mathbb{G}$ and a single element $H\in\mathbb{G}$.

### Commit

Given a polynomial $p = \sum_{i=0}^{n-1} a_i X^i$, to produce the commitment $[p]$ of it, the prover chooses a random value $r\in\mathbb{F}$ and computes

$$[p] := a_0G_0 + \cdots + a_{n-1}G_{n-1} + rH.$$

The value $r$ is called the _blinding factor_. The prover always keeps track of which values $r$ were used for each of the produced commitments $[p]$. This is because he'll need them later on for the Open protocol. Formally, what we described is a commitment to the pair $(p, r)$ and we should write it as $[(p,r)]$. But to ease notation we drop the explicit mention to the blinding factor $r$.

### Open

Recall we are assuming here that the verifier already holds a commitment $[p]$ to a polynomial $p$, known to the prover. The prover also knows the value $r$ he used to produce the commitment $[p]$. Also, the verifier has already sent an element $z$ in $\mathbb{F}$ at which he wants to know the value of $p(z)$. The prover responded with a purpoted value $c$. What follows is the Open protocol in which they engage to convince the verifier that $c = p(z)$.

#### Case $n=2$

Let's begin with the base case. As with IPA, this will be the base case to which all the other cases reduce to.

When $n=2$, the polynomial $p$ is of degree at most $1$, that is, $p=a_0 + a_1 X$. Let $A=(a_0, a_1)$ and $B=(1, z)$. Define $b_0 = 1$ and $b_1=z$.

The interaction starts with the verifier choosing a random element $U$ in $\mathbb{G}$ and sending it to the prover.

The prover chooses random values $s, s' \in \mathbb{F}$ and responds the verifier with the following elements

        * $L := a_0G_1 + sH + a_0b_1U$ and
        * $R := a_1G_0 + s'H + a_1b_0U$.

The verifier chooses a random non-zero value $x\in\mathbb{F}$ and sends it to the prover, who uses it to compute the following elements.

        * $a' := a_0 x + a_1 x^{-1}$
        * $b' := b_0 x^{-1} + b_1 x$

The prover sends $a'$ and $b'$ to the verifier along with the element $r' := sx^2 + r + s'x^{ - 2}$. Finally, the verifier checks that:

$$  
\begin{equation}  
x^2 L + [p] + x^{-2} R + c U = x^{-1} a' G_0 + xa' G_1 + r' H + a'b'U  
\end{equation}  
$$

The verifier accepts if and only if the above equality holds.

#### General case $n=2^k$

The idea is the same as in IPA. It is a recursive argument.

Let $n = 2^k$ and suppose $k>1$. If $k=1$, we follow the case $n=2$ described above.  
Write $p = \sum_{i=0}^{n-1}a_iX^i$. As before, define $A = (a_0,\dots, a_{2^k-1})$ and $B=(1, z, \dots, z^{n-1})$. Let the lower and higher parts of $A$ be the first and second halves of it. The same for the rest of the vectors involved.

The protocol starts also with the verifier choosing a random element $U$ in $\mathbb{G}$ and sending it to the prover.

The prover chooses random elements $s, s'$ in $\mathbb{F}$. He computes the following vectors and sends them to the verifier

        * $L := \langle A_{lo}, G_{hi} \rangle + sH + \langle A_{lo}, B_{hi}\rangle U$, and
        * $R := \langle A_{hi}, G_{lo} \rangle + s'H + \langle A_{hi}, B_{lo}\rangle U$.

The verifier chooses a random non-zero value $x\in\mathbb{F}$ and sends it to the prover.

At this point, the next step starts. The prover computes

        * $A' := x A_{lo} + x^{-1} A_{hi}$,
        * $B' := x^{-1} B_{lo} + x B_{hi}$.

These will take the roles of $A$ and $B$. The following basis is used in the next round instead of $G$:

        * $G' := x^{-1} G_{lo} + x G_{hi}$.

The verifier accepts if and only if the check at the last step ($n$=2) succeeds.

# To be continued

In a follow-up blogpost we'll discuss the complexity of these protocols and we'll see how they can be optimized and used in recursive arguments of knowledge.
