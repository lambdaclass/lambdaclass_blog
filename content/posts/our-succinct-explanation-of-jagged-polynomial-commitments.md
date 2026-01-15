+++
title = "Our Succinct explanation of jagged polynomial commitments"
date = 2025-06-06
slug = "our-succinct-explanation-of-jagged-polynomial-commitments"

[extra]
feature_image = "/images/2025/12/La_ronda_de_noche-_por_Rembrandt_van_Rijn.jpg"
authors = ["LambdaClass"]
+++

## Introduction

Few weeks ago, Succinct release their paper [Jagged Polynomial Commitments](https://github.com/succinctlabs/hypercube-verifier/blob/main/jagged-polynomial-commitments.pdf) and their verifier using the techniques described there, allowing them to prove Ethereum blocks in around 12 seconds, showing that real-time proving of the chain is possible. While this represents [the average case and energy consumption is still high](https://x.com/VitalikButerin/status/1925050155922862526), it is a major step towards scaling Ethereum using ZK. The paper makes heavy use of multilinear polynomials and the sumcheck protocol, so we recommend you read our post on [sumcheck](/have-you-checked-your-sums/), [GKR](/gkr-protocol-a-step-by-step-example/) and [Basefold](/gkr-protocol-a-step-by-step-example/) if you are unfamiliar with them. For more background on sparse commitments and its uses, see [twist and shout](https://eprint.iacr.org/2025/105.pdf) and [Lasso](https://eprint.iacr.org/2023/1216.pdf). For more background on read-once branching programs and their use in evaluating multilinear extensions, see [here](https://eprint.iacr.org/2018/861.pdf).

## Jagged functions

Typical arithmetization schemes consist of several tables (for example, one for the CPU, one for the ALU, another for memory, etc) and a set of algebraic constraints that have to be enforced over the table. Each column of the tables is encoded using univariate or multivariate polynomials and the prover then commits to these encodings (using a polynomial commitment scheme, PCS). In both cases, we require that the length of the columns is a power of 2, since this enables efficient encoding, either via the fast Fourier transform (FFT) or the multilinear Lagrange basis polynomials. This imposes several constraints:

        1. All columns in a table must have the same length
        2. We need to pad the columns to ensure their length is equal to a power of 2.

This results in a lot of overhead, since we need to pad all columns to the same length and store a large number of dummy entries in the tables (for example, zero values). We would like to use some sparse representation of the data, that is, just storing all the non-dummy values. Moreover, we would like to compress everything into a single column to commit to just one encoding. This is precisely one of the main points of the paper, which finds a way to obtain a dense representation of the tables, without all the padding (note that we will need the column to have a length equal to a power of 2, and some padding might be necessary).

We will explain the idea behind the dense representation using one table, but the idea can be extended to several tables, adding one additional variable keeping track of the number of table and the number of columns each table has. Suppose we have a table which has 32 columns ($32 = 2^5$). For each column, we keep the length $l_k$ of each column, consisting of the non-dummy entries. For example, $l_0 = 2^{20}$, $l_1 = 2^{18} + 15$, $l_2 = 2^{16} + 1475$, and so on and so forth. The prover can construct a vector whose entries are the added lengths of the columns, $t$. So, $t_0 = l_0$, $t_1 = l_0 + l_1$, $t_2 = l_0 + l_1 + l_2$. In summary,  
$t_0 = l_0$  
$t_{k + 1} = t_k + l_{k + 1}$  
Note that, since the $l_k$ are all positive, the vector $t$ has non-decreasing entries. We can merge all the columns into a single one, by stacking them one below the other. Given an index $j$ for the vector of stacked columns, we can find where the original element was. First, we look for the smallest $k$, such that $j < t_k$. This $k$ gives the column where the element belongs. Then, we can compute the row by doing $i = j - t_{k - 1}$ (if $k = 0$, then $i = j$). This yields a one-to-one correspondence between the original table and the stacked columns (we will call this, the dense representation form now on). The dense representation has a length equal to $2^m$, where $m = \lceil \log_2 \max{t} \rceil$. Given the procedure to find the row and column, we can define two functions,  
$\mathrm{col}(j) = \min_k \{t_k > j \}$  
$\mathrm{row}(j) = j - t_{k - 1}$  
Using the letter $q$ to denote the multilinear encoding of the dense representation, we see that each entry corresponds to the non-dummy part of the multilinear extension of the whole table, $p$.  
$p(\mathrm{row}(j), \mathrm{col}(j)) = q(j)$.

This saves a lot of space to represent the whole table, at the expense of having the prover send the vector $t$. We can then show that if we want to evaluate $p(z_r , z_c)$ this is equivalent to,  
$p(z_r , z_c) = \sum p(x , y) \mathrm{eq} (x , z_r) \mathrm{eq} (y , z_c) = \sum q(i) \mathrm{eq}(\mathrm{row}(i) , z_r) \mathrm{eq}(\mathrm{col}(i) , z_c)$  
since any zero entry of $p(x,y)$ does not contribute to the sum.

## Why does this work with multilinear polynomials?

Multivariate polynomials use the sumcheck protocol to reduce statements to the evaluation of the polynomial at a random point. For example, we can use the sumcheck protocol to show that the multivariate polynomial $g$ evaluates to zero over the hypercube using the zero-check,  
$$\sum \mathrm{eq}(r,x) g(x) = 0$$  
and, by interacting with the prover, the verifier is left to perform one evaluation at $z$ for $\mathrm{eq} (r,z) g(z)$, plus some simple checks involving univariate polynomials. Using a PCS, the prover can give the verifier access to $g$ and query for the evaluation at $z$ using the evaluation protocol of the PCS.

In the case of univariate polynomials, we show that $g(x)$ has zeros over a domain $D$ by quotienting with the zerofier/vanishing polynomial over $D$, $Z_D (x)$. In general, if $D$ has a nice structure (for example, $D$ consists of the n-th roots of unity), the vanishing polynomial can be evaluated very efficiently (in our example, $Z_D (x) = x^n - 1$. In the case of sparse polynomials, the representation of $Z_D (x)$ may be complicated and thus not efficiently computable.

Thus, multilinear polynomials do not require computing quotients and you can work a priori on more general fields (FFTs, on the other hand, need smooth domains where $|F| - 1 = 2^n c$, where $n$ is typically at least $24$).

## How to handle a large number of columns

The paper offers two optimizations to deal with a large number of columns:

        1. Fancy jagged: if all the columns in a table have the same height, we reduce the amount of information we need to pass to compute $t$.
        2. Commit to the column heights. The prover can include the column heights (prepending them to the table) in the table and commit to them.

## Jagged PCS

Another core part of the paper consists in developing a PCS for sparse/jagged polynomials. Remember that, from the discussion above,  
$p(z_r , z_c) = \sum p(x , y) \mathrm{eq} (x , z_r) \mathrm{eq} (y , z_c) = \sum q(i) \mathrm{eq}(\mathrm{row}(i) , z_r) \mathrm{eq}(\mathrm{col}(i) , z_c)$  
We can find the multilinear extension of a function $f_t$ given by  
$f_t (x) = \mathrm{eq}(\mathrm{row}(x) , z_r) \mathrm{eq}(\mathrm{col}(x) , z_c)$  
Using the sumcheck protocol for products of multilinears, it suffices for the verifier to show that $v = q(\alpha) f_t (\alpha)$, which in turn amounts to $q(\alpha) = \beta_1$ and $f_t (\alpha) = \beta_2$. The key point lies in that $f_t$ can be efficiently evaluated by the verifier. This is proven in claim 3.2.1.

To show that the function can be computed efficiently, the paper introduces a function $g(w,x,y,z)$ which satisfies that $g(w,x,y,z) = 1$ if and only if $x < z$ and $x = w + y$. This function can be directly related to $f_t$ and $g$ can be computed efficiently using a width 4 branching program:  
$f_t (z_r , z_c , i) = \sum_y \mathrm{eq} (z_r , y) g(z_c , y , t_{y - 1} , t_y )$

The proof relies on the uniqueness of the multilinear extension, so it suffices to check the equality for $z_r , z_c , i$ as binary strings. If $g(z_r , i , t_{ y - 1} , t_y ) = 1$, then $i < t_y$ and $i = z_r + t_{ y - 1}$. Since $z_r \geq 0$, it follows that $t_{y - 1} \leq i < t_y$ and $z_r = i - t_{y - 1}$. Since we have that $\mathrm{col}_t (i) = z_c$ and $\mathrm{row}_t (i) = z_r$, it follows that $f_t (z_r , z_c , i) = 1$. Similarly, if $f_t (z_r , z_c , i) = 1$, then the variables $w, x, y , z$ automatically satisfy the conditions for $g(w,x,y,z) = 1$.

From the above, we see that we can compute $f_t$ by calculating $2^k$ evaluations of $g$. By claim 3.2.2, a width-4 read-once branching program can compute efficiently $g$, by inspecting each bit of $w, x, y, z$ in a streaming fashion. The conditions $i < t_y$ and $z_r = i - t_{ y - 1}$ for non-vanishing $g$ can be inspected by looking at 4 bits at a time and keeping track of two additional variables.

The paper then discusses how to produce symbolic evaluations using a read-once matrix branching program, which we will need for batch-proving multiple evaluations. The program is defined by a sequence of matrices $M = {M_j^\sigma }$ where $\sigma \in { 0,1 }^b$ and $j = 1, 2, ... , n$ and a sink vector $u$. Given an input $x \in {0 , 1 }^n$, the output of the program is the first component of the vector given by $(\prod M_j^{ x_j }) u$, that is $e_1^t (\prod M_j^{ x_j }) u$, where $e_{1j} = \delta_{1j}$ (one if and only if $j = 1$, zero otherwise).

If the matrices are boolean matrices (having as entries either $0$ or $1$), matrix multiplication involves only additions (the paper calls matrices multiplication friendly if computing their product involves a linear number of additions and no multiplications).

When the sink vector $u$ is not given, the evaluation can be done in symbolic form, and, when the vector is finally given, get the final value of the matrix branching program. The idea is that we can get a vector $\mathrm{res}$ such that $\mathrm{res} . u = f_{M,u} (z)$, where $f$ is the multilinear extension of the matrix branching program given by $M$ and $u$. The vector $\mathrm{res}$ is given by  
$$\mathrm{res} = e_1^t \prod_j \left( \sum_\sigma \mathrm{eq} (z_j , \sigma) M_j^\sigma \right)$$

## Batch-proving of multiple evaluations

The problem we face is that the verifier should compute $k$ evaluations, which can be prohibitely costly. However, by interacting with the prover, we can boil everything down to just one evaluation. This follows a standard technique, where the verifier selects random weights $\alpha_0, \alpha_1, ... \alpha_{ k - 1}$ and the prover performs a random linear combination. More precisely, suppose that we want to prove that  
$h (z_0 ) = v_0$  
$h (z_1 ) = v_1$  
$\vdots$  
$h (z_{ k - 1} ) = v_{ k - 1}$  
The prover then does the following linear combination with $\alpha_j$,  
$\sum_j \alpha_j h( z_j ) = \sum_j \alpha_j v_j$  
The prover wants to convince the verifier that $h( z_j ) = v_j$ holds for every $j$, so $v_j$ is sent to the verifier. The verifier can compute the sum on the right-hand side on his own, $\sum \alpha_j v_j$.

The left-hand side can be calculated efficiently by the prover. First, note that  
$h( z_j ) = \sum h (b) \mathrm{eq} (b , z_j) = \sum h_k \mathrm{eq} (b , z_j)$  
where $k = \sum_j b_j 2^j$ with $b = b_0 b_1 b_2 ... b_{ k - 1}$. In other words, the evaluation $h (z_j)$ can be computed as the inner product between the vector h, such that $h_k = h(b)$, and the vector of Lagrange basis polynomials $\mathrm{eq}(b , z_j)$. Since the inner product is (bi)linear, we can write the linear combination as  
$\sum \alpha_j h( z_j ) = \sum h(b) \left(\sum \alpha_j \mathrm{eq} (b , z_j) \right)$  
The prover and verifier can run the sumcheck protocol on $\left(h(b) \sum \alpha_j \mathrm{eq} (b , z_j) \right)$ and at the end the verifier has to compute $h(\rho ) \sum \alpha_j \mathrm{eq} (\rho , z_j)$ at the random point $\rho$, which in practice would be an oracle query for $h$ plus computing the linear combination $\sum \alpha_j \mathrm{eq} (\rho , z_j)$. Some optimizations used in the sumcheck protocol are presented in [improvements on zerocheck](https://eprint.iacr.org/2024/108.pdf).

## Where does all this fit in and future work

The jagged approach allows us to commit to the non-zero part of tables and save a lot of work, both in terms of memory requirements as well as commitment times. If we combine this idea with [M3 arithmetization](https://www.binius.xyz/basics/arithmetization/m3), where we do not need to commit to polynomials that can be computed via certain operations from trace polynomials (virtual polynomials), we see a massive reduction in the amount of work we have to do. This, in turn, could drive proving time, proving cost and memory footprint down, allowing us to prove bigger Ethereum and L2 blocks, effectively scaling it to bring more users and power more usecases.
