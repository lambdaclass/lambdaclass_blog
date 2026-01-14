+++
title = "Everything you wanted to know about periodic constraints in STARKs but nobody told you"
date = 2023-02-24
slug = "periodic-constraints-and-recursion-in-zk-starks"

[extra]
feature_image = "/images/2025/12/Rudolf_Ritter_von_Alt_001.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["zero knowledge proofs"]
+++

As you might have already guessed we are studying all the literature and code available to become one of big players in the industry. We want to thank [Eli Ben-Sasson](https://twitter.com/EliBenSasson) and [Starkware](https://twitter.com/StarkWareLtd) for the amazing work they've been doing in the space and for helping us to learn all this. We also want to thank [Max Gillett](https://twitter.com/maxgillett) for the time he has invested in talking with us about all these things. They have been amazing with us and we hope we can continue learning a lot from them.

**Introduction**

[ZK-STARKs](https://eprint.iacr.org/2018/046.pdf) (zero-knowledge scalable, transparent, post-quantum arguments of knowledge) are cryptographic tools that allow one party to prove the integrity of a computation. For example, a party can show that he computed the first 1000 elements of a Fibonacci sequence correctly, ran a given machine learning algorithm, or correctly processed 5000 Ethereum transactions. Moreover, checking the resulting proof is much faster than performing the naïve re-execution of the computation by a verifier (the verification time scales logarithmically in the calculation size). Given their properties, they have attracted interest in many areas; among them, they can solve the scalability problems that decentralized ledgers suffer from.

There are many interesting resources to learn the basics of STARKs, such as Starkware's [STARK 101](https://starkware.co/stark-101/), [Anatomy of a STARK](https://aszepieniec.github.io/stark-anatomy/overview), [Ministark](https://github.com/andrewmilson/ministark), as well as Starkware's blog on arithmetization ([parts I](https://medium.com/starkware/arithmetization-i-15c046390862) and [II](https://medium.com/starkware/arithmetization-ii-403c3b3f4355)). In this post, we will focus on how constraints are enforced and how to deal with them when applied periodically. Soon we will be posting a more in-depth version of STARKs.

The starting point for STARKs is arithmetization. We generate the execution trace of the program, obtaining a table showing how each register evolves according to the instructions being executed. The values of the execution table are related by constraints (usually low-degree polynomials). We will focus, in particular, on transition constraints and how to check that the values of the trace satisfy them.

**Transition constraints**

A transition constraint dictates the relations between different states of a computation. Suppose we have one register, which contains the elements of a Fibonacci sequence,

$a_0=a_1=1$

$a_{n+2}=a_{n+1}+a_n$

The last equation gives the transition constraint for the Fibonacci sequence; the others handle the boundary constraints for the problem, and it is easier to deal with them. To make our discussion easier, suppose that we performed $2^m$ steps of the Fibonacci sequence for some $m \geq 1$. We get, by rewriting the constraints and analyzing each index,

$a_2-a_1-a_0=0$

$a_3-a_2-a_1=0$

$a_4-a_3-a_2=0$

and so on. We can convert the trace elements into polynomials by interpolating over a suitable domain. To make things easier, we choose the $n$-th roots of unity, which enables us to perform interpolation via the fast Fourier transform. The roots are spanned by one element (a generator, $g$): by taking its powers, we get all the $n$-th roots of unity, $\left\\{1,g,g^2,g^3,...,g^{n-1}\right\\}$.Let us call $t(x)$ the polynomial interpolating the trace, that is, the polynomial taking the following values:

$t(1)=a_0$

$t(g)=a_1$

$t(g^2)=a_2$

$\vdots$

$t(g^{n-1})=a_{n-1}$

We can express the constraints as

$t(g^2)-t(g)-t(1)=0$

$t(g^3)-t(g^2)-t(g)=0$

$t(g^4)-t(g^3)-t(g^2)=0$

In a generic way,

$t(g^2x)-t(gx)-t(x)=0$

The way we can check that the constraints are enforced is by verifying that the polynomial $p(x)=t(g^2x)-t(gx)-t(x)$ is divisible by $(x-x_0)$, where $x_0$ is the point where we enforce the constraint. Another way to see this is that the resulting function

$$Q(x)=\frac{p(x)}{x-x_0} $$

is a polynomial. Instead of showing that $Q(x)$ is a polynomial, the STARK IOP proves that it is close to a low-degree polynomial.

In the case of the Fibonacci sequence, the constraint is valid for $x_0 \in \left\\{1,g,g^2,...g^{n-3} \right\\}$. Given that it is divisible by each factor, it is divisible by the product of all of them,

$Z_D(x)=\prod_{0}^{n-3} (x-g^k)$

The problem we face with this polynomial is that, to compute it, we need to perform a linear amount of multiplications, that is, as many multiplications as factors there are. Fortunately, the roots of unity have the following property:

$s(x)=\prod_{i=0}^{n-1} (x-g^k)=x^n-1$

So, instead of performing a linear amount of operations, we can calculate $Z_D(x)$ from $s(x)$ by taking out the missing factors:

$$Z_D(x)=\frac{ s(x)}{\prod_j (x-g^j)}=\frac{x^n-1}{(x-g^{n-1})(x-g^{n-2})} $$

The advantage of STARKs is that if a constraint is repeated many times, we can express that concisely. The only change goes in the vanishing polynomial $Z_D(x)$, which adds factors.

**Constraints repeating after $m$ steps**

In a case such as Fibonacci's, the constraint involves almost all points in the domain, so calculating the vanishing polynomial, $Z_D(x)$, is straightforward. But what happens when a constraint is applied only at certain points? For example, in EthStark, some transition constraints are applied only after $m$ steps. 

To fix ideas, suppose that we have a transition constraint of the form 

$f(x,gx,...g^d x)=0$

Our Fibonacci sequence fits this form. We will now consider that it applies every four steps; that is, the constraint is enforced at $x_0 \in \left\\{1, g^4, g^8, g^{12},...\right\\}$

The vanishing polynomial looks like

$Z_D(x)=\prod_k (x-g^{4k})$

If $g$ is a generator of the $n$-th roots of unity, $g^4$ is a generator of the $n/4$-th roots of unity, $\omega=g^4$. So, we can rewrite the former as

$Z_D(x)=\prod_k (x-\omega^k)$

But since the product is over all $n/4$-th roots of unity,$Z_D(x)=x^{n/4}-1$. If the constraint is applied every 32 steps, as in EthStark, the vanishing polynomial is simply$Z_D(x)=x^{n/32}-1$. If we skip some steps, we need to take those out. For example, suppose we have two constraints 

$f_1(x,g x)=0$

$f_2(x, g x)=0$. 

Constraint 2 is enforced every four steps, and constraint 1 is enforced every two (but not where constraint 2 is valid). To make it clear, constraint 2 is valid at $x_0 \in \left\\{1,g^4,g^8,g^{12},...\right\\}$ and constraint 1 is valid at $\left\\{g^2, g^6, g^{10},... \right\\}$. The vanishing polynomial for constraint 2 is

$Z_{D,2}(x)=\prod (x-g^{4k})$

and we have already found the solution, $Z_{D,2}(x)=(x^{n/4}-1)$. For constraint 1, we have 

$Z_{D,1} =\prod_{i \neq 0 \pmod{2} } (x-g^{2i})$

The $i \neq 0 \pmod{2}$ is just a way to say that the product only considers odd values of $i$ (so multiples of 4 are ruled out). We can apply the same trick as before: 

$$Z_{D,1}=\frac{ \prod (x-g^{2i})}{\prod (x-g^{4k})}$$

This may seem weird, but we know precisely how to calculate each of them:

$$Z_{D,1}(x)=\frac{x^{n/2}-1}{x^{n/4}-1} $$

From here, we can remove some points where the constraint is not enforced. For example, if it is not valid at $x_0=6$,

$$Z_{D,1}(x)=\frac{x^{n/2}-1}{(x^{n/4}-1)(x-g^6)} $$

If we added a constraint $f_3(x,gx)$ that is enforced on steps $\left\\{32,64,92,... \right\\}$, we would have 3 vanishing polynomials,

$$Z_{D,3}=\frac{x^{n/32}-1}{x-1} $$

$$Z_{D,2}=\frac{(x^{n/4}-1)(x-1)}{x^{n/32}-1} $$

$$Z_{D,1}(x)=\frac{x^{n/2}-1}{x^{n/4}-1} $$

So, by taking advantage of the properties of the roots of unity, we can enforce constraints that are applied periodically.

**Summary**

STARKs are a powerful tool that allows us to prove the integrity of a computation. To that end, STARKs start with the execution trace of a program and interpolate each column using polynomials. To see that the trace is valid, we need to check that all the constraints given by the computation are enforced. These constraints can be composed with the trace polynomials; if the constraints hold at step $T$, the resulting polynomial $P(x)$ should be divisible by $(x-g^{T-1})$ or, equivalently, there is a polynomial $Q(x)$ such that $P(x)=Q(x)(x-g^{T-1})$. If a constraint is applied multiple times, we can use the following facts to express them concisely:

        * The polynomial $P(x)$ is divisible by the product of factors of the form $x-x_0$.
        * We can easily shift the constraints thanks to the structure of the multiplicative subgroups.
        * The product of all elements in the multiplicative subgroups yield $x^n-1$, where $n$ is the subgroup's order (number of elements).

This results in advantages in terms of performance and ease of understanding.

Finally, we will post a beginner's version of STARKs soon, so stay tuned!
