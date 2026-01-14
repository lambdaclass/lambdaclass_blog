+++
title = "SNARKs on binary fields: Binius - Part 2"
date = 2024-01-05
slug = "binius-part-2"

[extra]
feature_image = "/content/images/2025/12/Hubert_Robert_-_L-E--cole_de_chirurgie_en_construction_-cropped-.jpg"
authors = ["LambdaClass"]
+++

## Introduction

This post is a continuation of our discussion on [Binius](https://gitlab.com/UlvetannaOSS/binius), a new proof system that works over binary fields. Before continuing, see the [first part](/snarks-on-binary-fields-binius/) if you are unfamiliar with some of the concepts or [our post](/binius-moving-zk-forward/) on why we think this proof system can help move the industry forward.

In this part, we will focus on the concatenated codes (which will allow us to extend the polynomial commitment scheme for small fields) and the different protocols to check statements over multivariate polynomials.

## Concatenated Codes

In our previous post, we covered the polynomial commitment scheme for small fields. To develop the general commitment scheme, we first need to introduce the packing scheme and concatenated codes. Remember that in this setting we are working with a tower of fields, $\tau_0 \subset \tau_1 \subset \dots \subset \tau_t$. We work with a $[n_0 , k_0 , d_0]$ linear outer code with a $[n_i , k_i , d_i]$ linear inner code. The outer code works over $\tau_{i + k}$, while the inner code works over $\tau_i$.

The whole construction depends on packing several elements from a field, and interpreting them as elements from an extension field. We can view $2^k$ elements from $\tau_i$ as a single element from $\tau_{i + k}$ (we can view it as a $\tau_i$ vector space, as we can see the complex numbers as a two dimensional vector space over the real numbers).

The concatenated code's encoding procedure works as follows:

        1. Pack the initial message over $\tau_i$ into elements of $\tau_{i+k}$. For example, we have four bit variables from $\tau_0$, $0, 1, 1, 1$ and we can group then as an element $0111$ from $\tau_2$.
        2. Encode the packed message using the outer code. For example, we can use Reed-Solomon encoding.
        3. Unpack each symbol in the codeword into a message over $\tau_i$.
        4. Encode using the inner code and concatenate the elements. This encoding may be the trivial one, that is, applying the identity code.

One problem we face is that we have to use the extension code. We have an interplay between different fields: the field representing the coefficients of the polynomial, the field for the alphabet of the code, the intermediate field and the extension field which we use for cryptographic security (here, $\tau_t$). To work with the extension code, we define a structure containing elements from $\tau_i$ in a rectangular array (of $2^{\tau - i} \times 2^k$ elements). Each row contains $2^k$ elements, which can be interpreted as a $\tau_{i + k}$ element. Analogously, the $2^{\tau - i}$ elements in a column can be interpreted as a single element in $\tau_t$. The structure has a dual view: as a vector space over $\tau_t$ of dimension $2^k$ (viewing the columns) or as a vector space over $\tau_{i + k}$ of dimension $2^{t - i}$. Multiplication of the array by an element from $\tau_i$ is interpreted as multiplication elementwise. If we want to multiply by an element over $\tau_t$, we take each column (which is a single element from $\tau_t$) and perform the multiplication of each column by the element. In an analogous way, we can multiply by an element in $\tau_{i + k}$ by multiplying each row.

The block level encoding-based polynomial commitment scheme's procedure is:

        1. Commit($p$): Arrange the coefficients of the polynomial into an $m_0 \times m_1$ matrix, with entries in $\tau_i$. Group the elements taking chunks of $2^\kappa$ and interpret them as elements in $\tau_{i + k}$ and apply the extended encoding row-wise, obtaining a matrix of size $m_0 \times n$ with elements over $\tau_\tau$. Build a Merkle tree from the columns and output the root as commitment.
        2. Prove($p$,$s$): The prover arranges the coefficients into an $m_0 \times m_1$ matrix $t$ with entries in $\tau_i$. He computes and sends in the clear $t^\prime = \otimes_{ i = l_1 }^\ell (1 - r_i , r_i ) . T$ to the verifier. The verifier samples $\rho$ indexes $j_0 , j_1 , ... j_{\rho - 1}$. The prover sends the columns of the encoded matrix $U$ with their accompanying Merkle paths.
        3. Verify($\pi , r , s$): The verifier checks that $t^\prime \otimes_{ i = 0}^{l_1} .(1 - r_i , r_i ) = s$. Then, the verifier interprets $t^\prime$ as chunks of size $2^k$ and applies the extended code, unpacking all the elements to get $u^\prime$. The verifier checks that all the columns supplied are included in the Merkle tree, and checks that $\otimes_{ i = l_1 }^\ell ( 1 - r_i , r_i ).u$.

The size of the proof can be calculated from $t^\prime$ ($m_1$ elements from $\tau_t$), the columns (consisting of $\rho m_0$ elements from $\tau_{i + k}$) plus the authentication paths for the $\rho$ columns. Assuming a digest size of $256$ bits, we have $2^\tau m_1 + 2^{i + k} \rho m_0 + 2^8 \rho \log_2 {n}$ bits.

## Protocols

Binius contains a list of key polynomial predicates, based on those proposed by [HyperPlonk](https://eprint.iacr.org/2022/1355.pdf):

        1. Query
        2. Sum
        3. Zero
        4. Product
        5. Multiset
        6. Permutation
        7. LookUp

Almost all of the protocols boil down to a sumcheck. For the basics of the sumcheck protocol, see our [previous post](/have-you-checked-your-sums/) or [Thaler's book](https://people.cs.georgetown.edu/jthaler/ProofsArgsAndZK.pdf).

The zerocheck protocol is useful, for example, to prove that the gate constraints are enforced in HyperPlonk. In that protocol, we have a multilinear polynomial $M$ (which encodes the trace) and selector multilinear polynomials $S_1$, $S_2$, $S_3$, such that, for every point in ${0, 1 }^n$, we have  
$0 = S_1 (M_0 + M_1 ) + S_2 M_0 M_1 + S_3 G(M_0 ,M_1 ) - M_2 + I$  
where $M_0 (x) = M(0,0,x)$, $M_1 (x) = M(0,1,x)$, and $M_2 (x) = M(1,0,x)$.

How can we prove that the multivariate polynomial, $P = S_1 (M_0 + M_1 ) + S_2 M_0 M_1 + S_3 G(M_0 ,M_1 ) - M_2 + I$ is equal to zero for every value in ${0, 1 }^n$ ? We let the verifier supply a random point $r_{zc}$ from $\mathbb{F}^n$ and build the multivariate polynomial  
$P^\prime (x) = eq(r_{zc} , x) P(x)$  
with $eq(x,y) = \prod ( x_i y_i + (1 - x_i ) (1 - y_i ))$ and we run the sumcheck protocol for $P^\prime (x)$, using as sum value $0$. The verifier will only need to do one evaluation of $P^\prime (x)$ at $x = r_{s}$.

The use of the sumcheck with $P^\prime (x)$ involves multivariate polynomials which are not multilinear; this means that the prover has to send at each round a polynomial of at most degree $d$. HyperPlonk has an optimization for this case: the prover sends a commitment to a univariate polynomial of degree at most $d$ and provides an evaluation at a single point (instead of at least 3 points).

Since most of the protocols end up in a sumcheck, we can batch the polynomials using a random linear combination and reduce all the checks to a single sumcheck. [Binius's repo](https://gitlab.com/UlvetannaOSS/binius/-/tree/main?ref_type=heads) contains the implementation of the zero, sum and evaluation checks.

Binius proposes the use of Plonkish arithmetization; the main difference with HyperPlonk lies in the fact that the trace contains elements belonging to different subfields. Therefore, the gate constraints will express relations over different subfields. An execution is valid if

        1. All gate constraints hold.
        2. All global copy constraints are satisfied.
        3. Every witness variable lies inside its prescribed subfield.

The first two conditions hold for any of the variants of Plonk; the last one is introduced because we work with extension towers.

## Conclusions

In this post, we covered how the commitment scheme developed in the first part is extended to work with packed fields. We can view arrays of field elements in a dual way, packing the elements column or row-wise. The paper later presents some key protocols to prove predicates over polynomials, such as evaluation, sum and product check; these boil down to doing several sumchecks, which can be batched conveniently. These, together with some arithmetization scheme (such as Plonkish) can be used to yield a SNARK. Tha main difference between HyperPlonk and Binius lies in the fact that the trace elements in Binius may belong to different subfields. However, this does not add a new check. Rather, this could replace what could be additional checks in HyperPlonk. These subfield checks are guaranteed by the security property of the small-field polynomial commitment scheme.
