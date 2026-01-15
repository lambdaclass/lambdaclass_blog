+++
title = "ZPrize: eyes on the prize"
date = 2023-01-23
slug = "eyes-on-the-prize"

[extra]
math = true
feature_image = "/images/2025/12/Angelica_Kauffmann_-_Virgil_reading_the_---Aeneid---_to_Augustus_and_Octavia_-Hermitage-.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["zero knowledge proofs"]
+++

# Introduction

This post contains a summary of different approaches to optimize multiscalar multiplication with CUDA, as presented for [ZPrize](https://www.zprize.io/blog/announcing-zprize-results). This is an important calculation in certain [proving systems](/the-hunting-of-the-zk-snark/) (zk-SNARKs), where it is necessary to add lots of points over an [elliptic curve](/multiscalar-multiplication-strategies-and-challenges/). These large sums can be broken down into smaller ones, each of which can be calculated in parallel by a processor, making the use of CUDA ideal to speed it up considerably. A short introduction to CUDA can be found [here](/cuda-from-scratch/). The results of the ZPrize are promising, leading to more than 2x speed up; and the good news does not stop there, since each solution introduces different tricks and strategies. Below you will find an overview of some solutions and the links to each repo.

## Table of Contents

        * Goal
        * Pippenger's algorithm
        * Base algorithm
        * Speakspeak's submission
        * 6block's submission
        * Mike Voronov and Alex Kolganov's submission
        * MatterLabs's submission
        * Yrrid's submission

## Goal

Given $n\in\mathbb{N}$, elliptic curve points $P_1, \dots, P_n$ and scalars $k_1, \dots, k_n$ in a finite field, compute $$P=\sum_{i=1}^nk_iP_i$$

where the summation is understood in terms of ordinary [elliptic curve addition](/what-every-developer-needs-to-know-about-elliptic-curves/).

The number of points is related to the number of constraints needed to represent the computation (which can be larger than 100,000,000). This calculation appears, for example, when we want to compute the commitment of a polynomial \\( a_0+a_1x+a_2x^2+...a_dx^d \\) using the Kate-Zaverucha-Goldberg (KZG) commitment scheme.

## Pippenger algorithm

Let $\lambda$ be the number of bits needed to store the scalars, and let $s$ be an integer between $1$ and $\lambda$. Denote by $\lceil \lambda/s \rceil$ the ceiling of $\lambda/s$, that is the least integer number greater than or equal to $\lambda/s$.

Write each scalar $k_i$ in base $2^s$  
$$k_i = \sum_{j=0}^{\lceil \lambda/s \rceil-1}m_{i,j}(2^{s})^j,$$  
where $0 \leq m_{i,j} < 2^s$. Then

$$\sum_{i=1}^n k_iP_i = \sum_{i=1}^n\sum_{j}m_{i,j}2^{sj}P_i = \sum_{j=0}^{\lceil \lambda/s \rceil-1}2^{sj}(\sum_{i=1}^n m_{i,j}P_i).$$

Let us rewrite the inner sum differently. For each $1 \leq m < 2^s$ we can group all the terms of the inner sum that have $m_{i,j}=m$ and write

$$\sum_{i=1}^nm_{i,j}P_i = \sum_{m=1}^{2^s-1}m(\sum_{i:,m_{i,j}=m}P_i)$$

For the elements $m$ such that there is no $i$ with $m_{i,j}=m$ we interpret the sum $\sum_{i:, m_{i,j}=m}P_i$ as $0.$ This last step is called _bucketing_.

Putting it all together we obtain:  
$$\sum_{i=1}^nk_iP_i = \sum_{j=0}^{\lceil \lambda/s \rceil - 1}2^{sj}\sum_{m=1}^{2^s-1}m\sum_{i:, m_{i,j}=m}P_i \tag{1}$$  
Pippenger's algorithm consists of computing the sums above starting from the innermost sum:

(1) For each $j$ and $m$ compute $B_{j,m} := \sum_{i:,m_{i,j}=m}P_i$.

(2) For each $j$ compute $G_j := \sum mB_{j,m}$ as follows. For all $1 \leq m < 2^s$ compute all the partial sums in descending order of the indices  
$$S_{j,m} = B_{j,2^{s-1}} + \cdots + B_{j,m}.$$  
Then compute the sum of the partial sums $S_{j,1} + \cdots + S_{j,2^s-1}$. This is equal to the sum $G_j$ we want.

(3) Compute

$$\sum_{j=0}^{\lceil \lambda/s \rceil-1}2^{sj}G_j.$$

In pseudocode (extracted from [this paper](https://eprint.iacr.org/2022/1321.pdf)):

![](/images/external/vXGaugg.png)

## Base algorithm

The implementation is in `algorithms/src/msm/variable_base/`. It is specific to the BLS12-377 curve. For this curve, we have $\lambda=253$.

Aleo uses Pippenger's algorithm with $s=1$. Equation $(1)$ reduces to  
$$\sum_{i=1}^nk_iP_i = \sum_{j=0}^{\lambda - 1}2^{j}\sum_{i:, 1=m_{i,j}}P_i,$$  
where $m_{i,j}$ are defined as before, but in this particular case $m_{i,j}$ coincides with the $j$-th bit of $k_i$.  
Step 1 of Pippenger's algorithm is trivial for this particular choice of $s$ and we get $G_j = B_{j,1}.$

#### Parallelization strategy

CUDA parallelization is only used to modify step 2 as follows.

(2) The goal is to compute $G_{j} = \sum_{i:, 1=m_{i,j}}P_i$ for all $j$. For that, the following steps are performed.

(2.a) First, compute

$$G_{j, a} = \sum_{\substack{i:, 1=m_{i,j},\ 128a\leq i < 128(a+1)}}P_i$$

for all $0 \leq a < \lceil n/128 \rceil$ and all $j$ in parallel. That is done using $\lambda * \lceil n/128 \rceil$ threads.

(2.b) Then for each $j$ compute $G_{j}$ by adding $G_{j,a}$ for all $a$. Each $j$ gets its thread and so this step requires $\lambda$ steps. Each thread adds $\lceil n/128\rceil$ elliptic curve points.

Once all the $G_j$ are computed the rest of the Pippenger algorithm is executed in the CPU as in the previous section.

## [Speakspeak](https://github.com/z-prize/2022-entries/tree/main/open-division/prize1-msm/prize1a-msm-gpu/speakspeak)

The article is "cuZK: Accelerating Zero-Knowledge Proof with A Faster Parallel Multi-Scalar Multiplication Algorithm on GPUs" and can be found [here](https://eprint.iacr.org/2022/1321.pdf). There are differences between what the paper describes and the actual implementation in the ZPrize submission.

#### Parallelization strategy described in the paper

The strategy here is to change steps 1 and 2 of Pippenger's algorithm to leverage GPU parallelization.

We use the notation introduced in the **Pippenger's algorithm** section. Let $t$ be the number of threads to be used.

(1) compute $B_{j,m}$ as follows. For each $1 \leq j < \lceil \lambda / s \rceil$:

(1.a) compute $m_{i,j}$ in parallel for all $i$ using all $t$ threads.

(1.b) For each $0\leq l < t$ compute

$$B_{j,m,l} := \sum_{\substack{i \text{ such that} \ ,m_{i,j}=m \ i \equiv l \text{ mod } t}}P_i$$

Use all $t$ threads for it.

(1.c) Let $M^{(j)}$ be the matrix with elliptic curve point entries such that $M_{m, l}^{(j)} = B_{j,m,l}$. This is a sparse matrix. Compute $B_{j,m} = M^{(j)}\cdot 1_t$, where $1_t$ is the vector of length $t$ with all entries equal to $1$. This can be done using existing parallel algorithms for sparse matrix-vector multiplications. Use all $t$ threads for it.

(2) Compute all $G_j$ as follows. For all $0\leq j < \lceil \lambda / s \rceil$ do the following in parallel using $t' := t/\lceil \lambda / s \rceil$ threads for each one.

(2.a) For a given $j$, to compute $G_j = \sum mB_{j,m}$, split the sum in $t'$ even chunks and compute each one separately in its thread. That is, if we denote $\sigma=(2^s-1)/t'$, for each $0 \leq \xi < \sigma$ compute

$$\sum_{m=\xi\sigma}^{(\xi+1)\sigma-1}mB_{j,m}.$$

This can be done in the same way with the partial sum trick as in step 2 of Pippenger. There is an additional step needed in this case because the sequence of coefficient in the sum above is $\xi\sigma, \xi\sigma+1, \dots,$ instead of $1, 2, 3,\dots$. But that is easily fixed by adding $(\xi\sigma-1)$ times the largest partial sum.

(2.b) Add all the chunks of the previous step. The result is $G_j$.

Finally compute step 3 as in Pippenger.

In pseudocode:

![](/images/external/meWCE2d.png)![](/images/external/TdZi4gO.png)

### Parallelization strategy from the implementation

The parallelization strategy in the actual code of the submission is quite simpler. There is no optimization with sparse matrix multiplications. However, there are several interesting things to note.

        * Only the curve BLS12-377 is supported.
        * The window size $s$ is chosen to be $21$. Since $\lambda = 253 = 12 * 21 + 1$, there are 13 windows, one of which has only binary scalars. This last window is treated differently from the other 12 windows. This is an odd choice given that $253 = 11 * 23$
        * All the memory to store the inputs, the results, and all the partial results in between is allocated at the beginning. This needs quite a lot of memory. About 3.2GB of GPU RAM is only needed to store the scalars of all windows in the case of $2^{26}$ base points.
        * For the most part (first 12 windows) kernels are launched with grids of blocks of $12$ columns and $M$ rows, where $M$ varies according to the task. Blocks on the other hand are one dimensional of size 32 and therefore warps and blocks coincide. Each column then handles computations relative to a specific window.
        * There is intensive use of the `cub` [library](https://nvlabs.github.io/cub/index.html#sec1) for [sorting](https://nvlabs.github.io/cub/structcub_1_1_device_radix_sort.html), computing [run lengths](https://nvlabs.github.io/cub/structcub_1_1_device_run_length_encode.html), computing [cumulative sums](https://nvlabs.github.io/cub/structcub_1_1_device_scan.html) and [filtering](https://nvlabs.github.io/cub/structcub_1_1_device_select.html) lists.
        * Most of the code is actually inside the `sppark/msm` directory. The original `sppark/msm` code has been modified.

The repository includes a walkthrough of the main parts of the code. Here is a summary.

Let $n=2^{26}$ be the number of base points and let $N$ be $2 * Cores / (12 * 32)$, where $Cores$ is the number of cores of the GPU. Kernels will be usually launched with grids of 12 x $N$ blocks of 32 threads. The factor $2$ in $N$ makes sense at least at a step where a binary reduction algorithm is used to add up all points of an array of size $12 * N *32$.

For step (1) of Pippenger.

(1.a) To compute $m_{i,j}$ for all $i,j$, a kernel with $N$ x $12$ blocks of $32$ threads are launched. All the scalars are partitioned and each thread is in charge of computing the $m_{i, j}$ for all $j$ for the coefficients $k_i$ in its partition. Partitions are of size ~ $n/(32*N)$.

(1.b) Sequentially for each window $j$, the set of scalars $m_{i,j}$ is sorted using `cub::DeviceRadixSort::SortPairs`. Let us denote $m_{i, j}'$ the $i$-th scalar of window $j$ after sorting.

(1.c) Sequentially for each window $j$, the number of occurrences of each scalar $1 \leq m < 2^s$ in the window is computed using `cub::DeviceRunLengthEncode::Encode` on the previously sorted scalars $m_{i,j}'$.

(1.d) For technical reasons needed in the next step, the cumulative sum of the number of occurrences is computed using `cub::DeviceScan::InclusiveSum`.

(1.e) A kernel is launched to compute the buckets. The kernel gets a grid of size $N$ x $12$ blocks of $32$ threads. Column $j$ of the total $12$ columns handles the buckets of a window $j$. The range of indexes $1$ to $n$ is divided evenly into subranges and each thread handles the buckets corresponding to the unique scalars $m_{i,j}'$ with $i$ in its range. Ranges are slightly expanded and contracted for threads to get non-overlapping sets of scalars.

This concludes the computation of the buckets $B_{j, m}$ for all $0\leq j < 12$ and $1 \leq m < 2^s$

For step (2) of Pippenger.

(2.a) A kernel is launched on a grid of $N$ x $12$ blocks of $32$ threads. Each thread computes an even chunk of the sum $G_j = \sum mB_{j,m}$ just as described in the paper. As before, each column of the grid handles a different window.

(2.b) For each window $j$, its chunks are added up using a binary reduction algorithm. This effectively computes all $G_j$ for $0 \leq j <12$.

Then step (3) of Pippenger is performed in the CPU.

## [6block submission](https://github.com/z-prize/2022-entries/tree/main/open-division/prize1-msm/prize1a-msm-gpu/6block)

The main contribution of this solution is a different approach to steps (1) and (2). If we forget about GPU parallelization for a moment, both steps are performed in a single step as follows.

(1') For each window $j$, first sort all scalars $m_{i, j}$. Denote by $m_{i ,j}'$ and $P_{i}'$ the sorted list of scalars and points respectively. For each $i$ from $n$ to $1$, where $n$ is the number of base points, compute

$$\begin{aligned} t_{i-1} &:= t_{i} + P_{i}' \\\ s_{i-1} &:= (m_{i, j}' - m_{i-1, j}')t_i + s_i\end{aligned}$$

with $t_n = P_n'$ and $s_n = \mathcal O$. Then $G_j$ is equal to $m_{0,j}'t_0 + s_0$. The rest of the approach is the same as in Pippenger.

### Parallelization strategy.

Let $n$ be the number of base points $2^{26}$. The window size used is $21$. The $253$ bits are grouped in $11$ windows of size $21$ and an additional window of size $22$.

(1'.a) A kernel is launched on a one-dimensional grid of one-dimensional blocks of at most 128 threads. The exact size of the blocks is computed using the CUDA occupancy calculation function `cudaOccupancyMaxPotentialBlockSize`. The total number of threads equals the number of points. Each thread is then in charge of computing all the $m_{i, j}$ for a single scalar $k_i$.

The following steps are performed sequentially for each window $j$.

(1'.b) Having fixed $j$, the list $(m_{i, j})_{i=1}^n$ is sorted _._ The `cub` function `cub::DeviceRadixSort::SortPairs` is used for this. This function sorts key-value pairs. In this case, the pairs sorted are $(m_{i,j}, i)$, to keep track of which base point corresponds to which scalar in the sorted list. Let us denote by $m_{i, j}^\prime$ and $P_i^\prime$ the sorted list of scalars and points respectively.

(1'.c) Then a kernel is launched on a one-dimensional grid of one-dimensional blocks of at most 128 threads. Again the exact size of the blocks is computed using `cudaOccupancyMaxPotentialBlockSize`. The range $1$ to $n$ is split evenly and each thread is in charge of computing the sum $\sum m_{i, j}'P_i'$ for $i$ in its range. This is done by computing $s_0$ and $t_0$ as described above. This produces a certain number of partial results (one for each thread) that we denote here by $B_{k, j}$. The sum of all these elements for all $k$ equals $G_j$.

(1'.d) The results $B_{k, j}$ for all $k$ are copied to the CPU and added sequentially to get $G_j$. Then, this is doubled $21$ times to get $2^{21}G_j$ (except for the last window where $2^{22}G_{12}$ is computed). While this happens in the CPU, steps (1'.b) and (1'.c) are handled in the GPU for the subsequent window.

Once all windows have been handled, the final sum is performed in the CPU.

A few interesting things to note about this solution.

        * The code is very clear. It uses OOP and many c++11 features and standard libraries.
        * A naive implementation of the kernel launched in step (1'c) could severely suffer from warp divergence. This is because there is a lot of branching in the construction of $t_i$ and $s_i$. For example, if one $m_{i, j}'$ is equal to $m_{i-1,j}'$ then nothing has to be done to compute $s_i$. To overcome this issue, each thread fills up a buffer of max size $10$ with the non-zero differences $m_{i, j} - $m_{i-1, j}$ it encounters. All the elliptic curve operations are postponed until one of the threads in the warp fills out its buffer. At this point, all the threads in the warp flush their pending elliptic curve operations. To do this the warp vote function `__any_sync` is used (see [here](https://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html#warp-vote-functions)).

## [Mike Voronov and Alex Kolganov](https://github.com/z-prize/2022-entries/tree/main/open-division/prize1-msm/prize1a-msm-gpu/mikevoronov)

Mainly, this submission improves over the baseline using signed scalars to reduce the number of buckets in step (1) of Pippenger (more details below). Although it also claims to use a careful tiling of threads to compute the partial sums in step (2) in Pippenger's algorithm in parallel, there is little documentation about it.

The main contribution is in step (1). This solution uses a window size $s=23$.

(1.a) To compute $m_{i, j}$ a one-dimensional grid of one-dimensional blocks of size $256$ is launched. The total number of threads equals the number of base points, which is $2^{26}$. Each thread is in charge of computing the subscalars $m_{i, j}$ for a single $k_i$. Since the window size is $2^{23}$, all the subscalars $m_{i, j}$ satisfy $0 \leq m_{i, j} < 2^{23}$. If a subscalar is $m_{i, j}$ turns out to be bigger than $2^{22}$, then $2^{23}$ is substracted from it reducing it to the range $-2^{22} \leq m_{i, j} < 0$ and $2^{23}$ is carried over to the next window. The sign of the negative subscalar is transferred to the base point, given that it is cheap to negate elliptic curve points. As a consequence, they end up with subscalars in the range $0 \leq m_{i, j} < 2^{22}$ and possibly an additional window in case the last window needs to carry scalars.

Windows are then separated into two groups: The windows with odd and even indexes. Windows are handled in an asynchronous way and it is possible to handle more than two, the `config.numAsync` variable manages stream count. But for A40, two streams are enough to utilize all compute resources. The only exception is the last window which is treated separately in the CPU since it is the overflow window of the previous step and it is therefore much smaller. Each group gets its stream of threads and traverses its windows sequentially to compute the buckets and the final window sum $G_j$ as follows.

(1.b) For each window $j$, it sorts the subscalars $m_{i, j}$ and precomputes the starting and ending indexes of the occurrences of each subscalar in the sorted list, along with the number of occurrences of each one. This is done using the `thrust::sort_by_key` and `thrust::inclusive_scan` functions from the `thrust` library. It then launches a kernel with a one-dimensional grid of one-dimensional blocks of size $32$ to compute the buckets using the above pre-computed information.

(2.a) All windows are computed in parallel in different streams (two streams were used, but it is possible to use more, depending on GPU memory).  
(2.b) The buckets are then sorted, such that the buckets with the most points are run first. This allows the GPU warps to run convergent workloads and minimizes the tail effect. This solution writes custom algorithms to achieve this.

Then step (3) of Pippenger is performed in the CPU.

Other things to note from this solution.

        * The use of the `thrust` library.
        * It always uses one-dimensional grids of one-dimensional blocks of sizes either $256$ or $32$.
        * Two streams are used to even and odd windows in step (1.b) in parallel. This is because two streams are enough to utilize all computational resources.
        * It looks like it was developed and run on a memory-constrained GPU card. In step (1.b) each group reuses the allocated arrays to store the buckets. It also reuses allocated arrays for different unrelated intermediate steps in the computation of the sorted lists of subscalars and the indexes associated with the first and last occurrences of each one.

Tested ideas that didn't work. From the README of the submission:

        * NAF - signed scalars are better because NAF reduces the number of buckets 2/3 times, but signed scalars in 2 times
        * NAF + signed scalars - the main drawback of this variant is that a count of sums on the 2nd step twice more
        * Karatsuba multiplication + Barrett reduction - turned out that the CIOS baseline Montgomery is better
        * Affine summation + the Montgomery trick - turned out to be slower than the baseline summation

## [MatterLabs](https://github.com/z-prize/2022-entries/tree/main/open-division/prize1-msm/prize1a-msm-gpu/matter-labs)

This solution precomputes $2^{69j}P_i$ for each input point (this is different from what is stated in the documentation), $P_i$, and $j=0, 1, 2, 3$. These are all points in the EC. We can rewrite the first sum in this way:

$$ \sum_{i=1}^n \sum_{j=0}^3 k_{ij}2^{69j} P_i$$

where each $k_{ij}<2^{69}$.

Since each $2^{69j}P_i$ belongs to the EC and is already computed we can rewrite the sum as $\sum_{m=1}^{3n}k_m P_m$ (for other $k$s and other $P$s) where each $k_{m}<2^{69}$. This allows us to split each $k_m$ into three 23-bit windows for Pippenger's algorithm.

The `Arkworks` library is used to represent finite fields, elliptic curves, and big integers in the tests. However, for the MSM algorithm itself, these structures are implemented by the authors. They used optimized versions of the operations to run them on the GPU when running device code.

A new library is developed called `Bellman-CUDA`. It's used to make operations on finite fields, sort (using `CUB` utilities), run length-encoding (using `CUB` as well), etc. taking advantage of the GPU. The goal of this is probably to replace in the future the calls to `CUB` with more efficient algorithms.

The windows are processed in smaller parts. The first chunk of all the windows is processed first, then the second chunk of all windows, etc. This allows processing while other scalar parts are still in asynchronous transfer from the host to the device memory.

For each window chunk, a tuple index for each bucket is generated in parallel: $(i, j)$ where $i$ is the coefficient for the bucket and $j$ is the EC point in that bucket. These are sorted (in parallel) according to the first component so that we have the EC points that are to be summed up in each bucket. They are then length-encoded and sorted (in parallel as well) according to the number of points that the bucket has. In this way, the buckets that have more points will be processed first to enable efficient usage of the GPU hardware. After that, a list of offsets is generated (using the parallel algorithm to compute exclusive sums implemented by `CUB`) to know where each bucket starts and ends. For example:

$$  
\begin{align}  
2P_1+5P_2+4P_3+1P_4+2P_5 \rightarrow (2,1), (5,2), (4,3), (1,4), (2,5) \\\  
\rightarrow [(1, 4), (2, 1), (2, 5), (4, 3), (5, 2)], [1, 2, 4, 5], [1, 2, 1, 1] \\\  
\rightarrow [4, 1, 5, 3, 2], [0, 1, 3, 4, 5], [1, 2, 4, 5], [1, 2, 1, 1]  
\end{align}  
$$

The buckets are then aggregated in parallel.

The FF and EC routines have been optimized:

        * Based on Montgomery's multiplication
        * Minimized correction steps in the FF operations
        * Use of XYZZ representation for the EC point accumulators
        * Use of fast squaring

### Streams and memory management

The following streams are created:

        * `stream`
        * `stream_copy_scalars`
        * `stream_copy_bases`
        * `stream_copy_finished`
        * `stream_sort_a`
        * `stream_sort_b`

The first one is the mainstream. Kernels such as `initialize_buckets`, `compute_bucket_indexes`, `run_length_encode`, `exclusive_sum`, and `sort_pairs` are run in that stream.

`stream_copy_scalars` waits for `event_scalars_free`.  
`stream_copy_scalars` handles the async copying of scalars and enqueues `event_scalars_loaded`.

`stream_copy_bases` waits for `event_scalars_loaded` and `event_bases_free`. This stream also handles the async copying of bases and queues `event_bases_loaded`.

`stream` waits for `event_scalars_loaded`, handles the kernel `compute_bucket_indexes`, and queues `event_scalars_free`.

`stream` handles the sorting of the indexes and the asynchronous allocation of memory for the indexes and run lengths, as well as the `exclusive_sum` kernel and the allocation of memory for the offsets.

`stream` enqueues `event_sort_inputs_ready`. `stream_sort_a` and `stream_sort_b` wait on that event to handle the sorting of the pairs on the GPU.

`stream_sort_a` enqueues `event_sort_a` and `stream_sort_b` enqueues `event_sort_b`. `stream` waits on that event and also on `event_bases_loaded` before handling the kernel that aggregates the buckets. `stream` enqueues the (async) freeing of memory for the bases.

On the last loop of window chunk processing, `stream_copy_finished` waits for `event_scalars_loaded` and `event_bases_loaded`.

Memory es freed and the streams (except `stream` that handles the bucket reduction and window splitting kernels) are destroyed.

### Bucket aggregation algorithm

This algorithm is used after having every bucket computed, and is the basis for a parallelization strategy to aggregate buckets. It is an alternative to the classic sum of partial sums trick in Pippenger's. In what follows we assume every bucket has already been computed and the remaining problem is to add up all the points in every window.

### Notation

Let us fix some notation. Let $W=(B_0, \dots, B_{2^{b}-1})$ be a tuple of $2^b$ elliptic curve points. Let us call such a tuple a **$b$-bit window**. To every window $W$ we associate an elliptic curve point $P_W$ defined as

$$P_W := B_1 + 2B_2 + \cdots + (2^{b}-1)B_{2^{b}-1}$$

We call a tuple of $m$ such windows $C = (W_0, \dots, W_{m-1})$ of the same length $2^{b}$ a **window configuration**. We say that the window configuration has shape $(m, b)$. Every window configuration has an associated elliptic curve point defined by

$$P_C := P_{W_0} + 2^{b}P_{W_1} + 2^{2b}P_{W_2} + \cdots + 2^{(m-1)b}P_{W_{m-1}}$$

In the context of MSM, each $B_i$ is a bucket and $P_C$ is the desired final result.

### Reduction process

Let us assume every bucket has already been computed and let $C$ be the corresponding window configuration. MatterLabs' solution implements an algorithm to obtain $P_C$ by iteratively reducing a window configuration $C_i$ of shape $(m, b)$ to another window configuration $C_{i+1}$ of shape $(2m, \lceil b/2 \rceil)$. At every step, the point $P_{C_{i}}$ is not necessarily equal to $P_{C_{i+1}}$, but it can be obtained from $C_{i+1}$ by shifting some scalars. See below for the details. The process starts with a configuration $C$ of shape $(3, 23)$ and ends with a configuration $D$ of shape $(96, 1)$. At this point, $P_C$ is computed from $D$.

### Window splitting

The reduction consists of splitting every window of a configuration. Let us describe this splitting process for a single $b$-bit window $W$. We construct from it two new $\lceil b/2\rceil$-bit windows $\hat W_0$ and $\hat W_1$ such that

$$P_W = P_{\hat W_0} + 2^{\lceil b/2 \rceil}P_{\hat W_1}.$$

The idea behind this construction is the following. Every component of $W$ is of the form $B_r$, where $0\leq r < 2^b$. We can write $r = a + b2^{k}$ where $0\leq a,b < 2^k$. Then $B_r$ is put into two new buckets, namely the $a$-th component of window $\hat W_0$ and the $b$-th component of window $\hat W_1$.

#### Case $b$ even:

Write $b=2k$. Let $W$ be a $b$-bit window. Define the new $k$-bit windows $\hat W_0$ and $\hat W_{1}$ as follows.

Denote the components of $W$ by $(B_{0}, \dots, B_{2^b-1})$. Then

$$  
\begin{aligned}  
\hat W_{0} &:= (\sum_{i=0}^{2^{k}-1}B_{i2^k}, \sum_{i=0}^{2^{k}-1}B_{i2^k+1},\dots,\sum_{i=0}^{2^{k}-1}B_{i2^k+2^{k}-1}), \\\  
\hat W_{1} &:= (\sum_{i=0}^{2^{k}-1}B_{i}, \sum_{i=0}^{2^{k}-1}B_{i + 2^k},\dots,\sum_{i=0}^{2^{k}-1}B_{i + (2^{k}-1)2^{k}})  
\end{aligned}  
$$

#### Case $b$ odd:

Let us write $b = 2k-1$. This case is similar to the above. As before, let $W$ be a $b$-bit window. The definition of $\hat W_0$ and $\hat W_1$ follows the same logic as before.  
But there is a catch. If $r$ is such that $0\leq r < 2^b$ and we write $r= a + b2^k$ with $0\leq a,b < 2^k$, then $b$ is necessarily at most $2^{k-1}$. And so the second half of the coordinates of $\hat W_{1}$ will be empty. This is because none of the buckets $B_r$ of $W_n$ will be assigned to those coordinates. And so we obtain

$$  
\begin{aligned}  
\hat W_{0} &:= (\sum_{i=0}^{2^{k-1}-1}B_{i2^k}, \sum_{i=0}^{2^{k-1}-1}B_{i2^k+1},\dots,\sum_{i=0}^{2^{k-1}-1}B_{i2^k+2^{k}-1}), \\\  
\hat W_{1} &:= (\sum_{i=0}^{2^{k}-1}B_{i}, \sum_{i=0}^{2^{k}-1}B_{i + 2^k},\dots,\sum_{i=0}^{2^{k}-1}B_{i + (2^{k-1}-1)2^{k}}, \mathcal O,\dots, \mathcal O).  
\end{aligned}  
$$

In the above definition, there are $2^{k-1}$ coordinates with entry $\mathcal O$, the point at infinity.

### Reduction of window configurations and coefficient shifts

Performing the above process on every window of a configuration $C$ we obtain a new configuration $D$ of the desired shape. We will not always have $P_C = P_D$.

Let $C=(W_0, W_1, \dots, W_n)$ be a window configuration of shape $(m, b)$. For every window $W_n$, let $\hat W_{2n}$ and $\hat W_{2n+1}$ the two $\lceil b/2 \rceil$-bit windows obtained from splitting $W_n$. Let $D=(\hat W_0, \hat W_1, \dots, \hat W_{2m-1})$. This is a window configuration of shape $(2m, \lceil b/2 \rceil)$.

If $b$ is even, then it is easy to see that $P_C = P_D$.

If $b$ is odd, then $P_C$ is, in general, different from $P_D$. For example, the first 2 terms of $P_C$ are $W_0 + 2^bW_1$. On the other hand, the first four terms of $P_D$ are $\hat W_0 + 2^k\hat W_1 + 2^{2k}\hat W_2 + 2^{3k}\hat W_3$. This is equal to $W_0 + 2^{2k} W_1 = W_0 + 2^{b+1}W_1$. And so the coefficient of $W_1$ in $P_D$ has an extra factor of $2$.

Nevertheless, $P_C$ is equal to

$$P_{\hat W_0} + 2^{k-f_1}P_{\hat W_1} + 2^{2k-f_2}P_{\hat W_2} + \cdots + 2^{(2m-1)k-f_{2m-1}}P_{\hat W_{2m-1}},$$  
where $f_i = \lfloor i/2\rfloor$. We call these the coefficient shifts.

In general, we can define $f_i$ to be $0$ for all $i$ if $b$ is even and $f_i = \lfloor i/2 \rfloor$ for all $i$ if $b$ is odd.

### Algorithm

We start with a window configuration $C_0$ of shape $(m, b) = (3, 23)$. Inductively for every $i$ perform the reduction step on $C_i$ to obtain a new window configuration $C_{i+1}$ and also accumulate the coefficient shifts. After $4$ steps we obtain $C_5$ of shape $(96, 1)$ and the accumulated coefficient shifts $f_i$.

From $C_5$ and and the $f_i$ we can compute $P_{C_0}$.

### Parallelization strategy

When splitting a window configuration of shape $(m, b)$ into one of shape $(2m, k)$, where $k=\lceil b/2\rceil$, each new bucket is a sum of $2^k$ elements (or $2^{k-1}$ in some cases when $b$ is odd). To compute these, the following kernels are launched.

        1. First a kernel with $2m2^{k+l}$ threads for some $l \leq \lfloor b/2 \rfloor$ is launched. The $2^k$ terms of the sum of each new bucket are split into $2^{l}$ even groups. Each thread then computes the sum of the terms in a group. These partial sums are computed sequentially.
        2. A second kernel with $2m2^{k}$ threads is launched. Each thread is in charge of a bucket. It uses a binary reduction algorithm to compute it by adding the $2^l$ partial sums obtained by the previous kernel.

## [Yrrid](https://github.com/z-prize/2022-entries/tree/main/open-division/prize1-msm/prize1a-msm-gpu/yrrid)

This solution precomputes $2^{2\cdot23j}P_i$ for each input point, $P_i$ and $j=1,...,6$. These are all points in the EC. We can rewrite the first sum in this way:

$$ \sum_{i=1}^n \sum_{j=0}^5 k_{ij}2^{2\cdot23j} P_i$$

where each $k_{ij}<2^{2\cdot23}$.

Since each $2^{46j}P_i$ belongs to the EC and is already computed we can rewrite the sum as $\sum_{m=1}^{6n}k_m P_m$ (for other $k$s and other $P$s) where each $k_{m}<2^{46}$. This allows us to  
split each $k_m$ into two 23-bit windows for Pippenger's algorithm.

Another optimization the algorithm uses is the following: the window value has a sign bit and a 22-bit scalar value. If the scalar is large, we can negate the point and change the scalar to $s'=m - s$ where $m$ is the order of the field. The new scalar, $s'$, will have a high bit clear. This works since $s' (-P_i) = (m - s) (-P_i) = -s -P_i = s P_i$.

The buckets are then sorted, such that the buckets with the most points are run first. This allows the GPU warps to run convergent workloads and minimizes the tail effect. This solution writes custom algorithms to achieve bucket sorting instead of using the CUB libraries.

The bucket sums are computed in parallel (assigning a thread to each bucket) using the XYZZ EC representation. The operations for this curve representation can be found [here](https://hyperelliptic.org/EFD/g1p/auto-shortw-xyzz.html#addition-add-2008-s).

The FF and EC routines have been optimized:

        * Based on Montgomery's multiplication
        * Minimize correction steps in the FF operations
        * Use an XYZZ representation for the EC point accumulators
        * Use fast squaring

## Summary

Multiscalar multiplication (MSM) is one of the key operations in many proving systems, such as Marlin or Plonk with Kate polynomial commitment schemes. Owing to the nature of the operation, we can leverage GPUs to reduce its calculation time. The ZPrize competition sought to improve the current baseline of 5.86 seconds for an MSM with \\( 2^{26} \\) points for the BLS12-377 curve. There were 6 different proposals, each with its unique features, based on Pippenger's algorithm: optimizing window size, precomputation of some points (trading memory for speed), different coordinate systems for elliptic curve addition, endomorphisms, parallel reduction algorithms, point negation, non-adjacent form for integers, better finite field arithmetic. The best solutions achieved 2.52 seconds (2.3x speedup), but we think there is still more room for further optimization. Will we get below 1 second? Maybe you have the answer...
