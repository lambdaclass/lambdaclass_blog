+++
title = "Efficient attention explained: the math behind linear-time transformers"
date = 2025-10-13
slug = "efficient-attention-explained-the-math-behind-linear-time-transformers"

[extra]
math = true
feature_image = "/images/2025/12/the-astronomer.jpg"
authors = ["LambdaClass"]
+++

## Introduction

One of the key components of the Transformer architecture is the Attention layer, which is in charge of making every word (or more generally, every _token_) learn the context given by every other in a sequence, and was introduced in the seminal paper [Attention is all you need](https://arxiv.org/abs/1706.03762). In this post, we will explore this equation and a specific approach that manages to improve its complexity to be linear with a few mathematical tricks, following the work of [Shein et al. (2021)](https://arxiv.org/pdf/1812.01243).

## How the original implementation of Attention works

There's a lot of information about the original Attention (also known as dot product Attention) implementation out there so we'll do just a quick recap of it. It all comes down to a bunch of matrix multiplications with a normalization function. The exact mathematical formulation is

$$  
Attention(Q,K,V) = softmax(\frac{{QK^T}}{\sqrt{d_k}})V   
$$

where,

        * $Q \in \mathbb{R}^{N\times d_q}$, are the projections of the input sequence over the query space
        * $K \in \mathbb{R}^{N\times d_k}$ are the projections of the input sequence over the key space
        * $V \in \mathbb{R}^{N\times d_v}$ are the projections of the input sequence over the value space
        * $N$ is the sequence (or _context_) length, i.e., the maximum size of the input
        * $d_{q}, d_{k}$ and $d_{v}$ are the dimensions of each of the projection spaces

Both the $Q$ and $K$ matrices must have the same embedding dimension, so we can assume $d_k = d_q$ and without loss of generality we can consider $d_{q} = d_{k} = d_{v} = d$ for simplicity.

The softmax function works by mapping each element of an arbitrary, real numbers array into the range $(0, 1)$ - this is how it looks for a given input element:

![Im 1](/images/external/softmax.png?raw=true)

The $\sqrt{d_k}$ scaling factor is present to prevent the softmax function from saturating – as $d_k$ becomes larger, the dot products in $QK^T$ grows larger in magnitude, pushing the softmax function into regions where it is essentially flat and thus has extremely small gradients. While using backpropagation for training, this may turn into stability issues, slow training or even leaving some parameters entirely frozen for the whole training process.

We use the softmax function to go from attention scores (the results of the matrix multiplication of $QK^T$) to attention weights that will be multiplied by the $V$ matrix. The attention weights can be interpreted as how much each token affects the other ones in the sequence. If the attention weight between a pair of tokens is high, then we say that one _attends_ to the other.  
As an example, from basic english grammar, we know that in the sentence

> _Do androids dream of electric sheep?_

the word _**sheep**_ attends more to _**electric**_ than to the word _**do**._

## Deep dive into Attention complexity

One of the major drawbacks of the Attention mechanism is the way in which computational resources scale with respect to the sequence length $N$. In the definition of the Attention function we can see the similarity calculation between the vectors in $Q$ and $K$, given by $QK^T$. From basic matrix multiplication we know that,

$$  
(\mathbb{R}^{N\times d} \times \mathbb{R}^{d\times N}) \rightarrow \mathbb{R}^{N\times N}  
$$

which means that we end up having to store a $N \times N$ matrix and hence have $O(N^2)$ memory complexity. On the other hand, this matrix multiplication needs a total of $O(d_{k}N^2)$ operations, so we can clearly see that resource demands scale quite quickly as the sequence length gets larger.

In essence, the original attention architecture is really limited by the sequence length we can use, making it infeasible for situations where bigger contexts are needed. There has been a lot of effort on trying to optimize the original Attention mechanism and we will focus on one that really stands out due to the simplicity of its approach, taking into account some of their trade-offs.

## Efficient Attention

Since the scaling issues come from having to compute and store the $N \times N$ matrix as an intermediate value in the computation, if we could somehow apply softmax piecemeal we could have simpler intermediate values. If we apply softmax to the rows of $Q$, and to the columns of $K$ separately and _then_ do the product, we can avoid storing the entire matrix. Since we are no longer performing a dot product in this approximation, we also do not need the scaling factor $\sqrt{d_k}$.

Thus, efficient Attention, as proposed by [Shen et al. (2021)](https://arxiv.org/pdf/1812.01243), is given by:

$$  
E(Q,K,V) = softmax_{row}(Q)softmax_{col}(K)^T V  
$$

where now we make the distinction between $softmax_{row}$ and $softmax_{col}$, where we apply the softmax function in the rows and the columns of the matrices, respectively. In general, when there is no specification, the $softmax_{row}$ version is assumed.

The trick boils down to getting rid of applying the softmax function over the result of $QK^T$ – kind of like distributing the softmax function into $Q$ and $K$, with the caveat that this is not really a mathematical property of the softmax function but an approximation. This way, we can arrange the order of the matrix multiplications in this expression to our advantage, making the resulting computation much more efficient.

If we first compute $softmax_{col}(K)^TV$, we have to store an $d \times d$ matrix, which means a $O(d^2)$ memory complexity, and requiring $O(Nd^2) \approx O(N)$ calculations with $d≪N$. This attention implementation is sometimes referred as _Linear Attention_ due to the dependency with $N$_._

The efficiency gains make themselves obvious considering that $d < N$ in any practical case, and the difference grows as we make context lengths bigger and bigger.

To reiterate, the mathematical expression for this new Attention mechanism works as an _approximation_ since the two softmax operations applied over $Q$ and $K$ are not equivalent to the single softmax over $QK^T$. The core property that both variants share, and what makes the approximation reasonable is the fact that the sum over the rows of $softmax_{row}(QK^T)$ and $softmax_{row}(Q)softmax_{col}(K)^T$ both equal 1.

The approximation is good enough for some applications where the context length $N$ can be large. An example of this is the Computer Vision field, where input tokens may represent pixels of an image. Other examples include audio and genomics, where input lengths can reach millions.

## Interpretability of Efficient Attention

When trying to make sense of what this change means in the LLM context, we can think of the standard attention mechanism as the process of all elements in our query matrix asking all elements in the key matrix what they should pay attention to. It's an iterative process to get the correlation between one word (the query element) and the rest of the words in the same sentence (the key elements). We're essentially doing:

$$  
s_{ij} = Q_iK_j^T  
$$

for all _j_ in the input sequence. Each of these $s_i$ (the full set of scores for position _i_) is called an _attention map_ , so we create $N$ of such attention maps (one for each of our $N$ input positions).

The Efficient Attention mechanism creates attention maps that do not follow positional information about our queries and instead reference a more general aspect of the whole input. Instead of each query having its own attention map checking correlation with every other element, we create **global attention maps** with information that captures general semantic themes.

These maps are derived from the keys $K$, but they no longer depend on a specific positions. They are denoted $k_j^T$ and when multiplied by the elements in our value matrix we get $d_{k}$ vectors denoted as $g_i$. Each query then uses coefficients to mix these global themes rather than attending to individual positions.

Let’s see a practical toy example with some random numbers to see the difference clearly:

Suppose we have the sentence **"With great power comes great responsibility"** with **N = 6** tokens and **$d_{k} = 4$** (so we'll generate 4 global attention maps).

In **Dot Product Attention** , each of the 6 tokens creates its own attention map over all 6 positions:

**Token 3 ("power")** creates an attention map $s_3$:

$$  
s_3 = [0.08, 0.45, 0.15, 0.20, 0.05, 0.07]  
$$

This tells "power" to attend strongly to position 2 ("great") and moderately to position 4 ("comes"). We got the output:

$$  
output_3=0.08⋅V_1+0.45⋅V_2+0.15⋅V_3+0.20⋅V_4+0.05⋅V_5+0.07⋅V_6  
$$

**Token 4 ("comes")** creates its own separate attention map $s_4$:

$$  
s_4 = [0.05, 0.12, 0.38, 0.10, 0.08, 0.27]  
$$

This tells "comes" to attend strongly to positions 3 ("power") and 6 ("responsibility"). We get the output:

$$  
output_4=0.05⋅V_1+0.12⋅V_2+0.38⋅V_3+0.10⋅V_4+0.08⋅V_5+0.27⋅V_6  
$$

Similarly, all 6 tokens each create their own attention map. **Total: 6 attention maps, each of size 6.**

In **Efficient Attention** , instead of position-specific attention maps, we can create, for example, **4 global semantic attention maps** that capture themes across the entire sentence. In a language context, an example of these global maps for this input sentence could be something like:

        1. Modifier theme: The model encodes the fact that _great_ qualifies both _power_ and _responsibility_. 
           * _“great” → “power”_
           * _“great” → “responsibility”_
        2. Cause-consequence theme: This encodes the overall causal/propositional structure 
           * “power” → “responsibility”
           * “with … power” → “comes … responsibility”
        3. Predicate theme: Maps tokens to the main predicate. This reduces the need for the model to discover the verb as the organizing node — the map enforces it. 
           * All words point toward the main verb _“comes”_
        4. Parallelism - Analogy theme: Highlights symmetry between paired concepts 
           * _“power” ↔ “responsibility”_
           * Both are treated as abstract nouns of similar importance

**$k_1^T$ (Modifier theme)** : $[0.10, 0.85, 0.15, 0.10, 0.85, 0.20]$ → creates $g_1$

**$k_2^T$ (Cause-consequence theme)** : $[0.05, 0.10, 0.90, 0.05, 0.10, 0.88]$ → creates $g_2$

**$k_3^T$ (Predicate theme)** : $[0.20, 0.05, 0.10, 0.95, 0.05, 0.10]$ → creates $g_3$

**$k_4^T$ (Parallelism-Analogy theme)** : $[0.90, 0.15, 0.20, 0.15, 0.10, 0.10]$ → creates $g_4$

Each $g_i$ is a weighted sum of all value vectors $V_{j}$ using the corresponding global map weights.

Each token mixes these 4 global themes:

**Token 3 ("power")** with $q_3=[0.30,0.20,0.10,0.40]$

$$  
output_3=0.30⋅g_1+0.20⋅g_2+0.10⋅g_3+0.40⋅g_4  
$$

**Token 4 ("comes")** with $q_4=[0.10,0.25,0.40,0.25]$

$$  
output_4=0.10⋅g_1+0.25⋅g_2+0.40⋅g_3+0.25⋅g_4  
$$

Here, there are only four global maps shared by all tokens, and each token selects which themes it should attend to, rather than attending to each of the other words in the sentence. The number and composition of themes and how they are picked are just part of this example.

## Lost in the Big Picture

While Efficient Attention offers significant computational advantages, it comes with an important trade-off: it loses the ability to sharply focus on specific positions and instead focuses on coarse global features. Let's demonstrate this limitation with a practical example.

In this example, we'll compare the attention scores produced by $softmax(\frac{{QK^T}}{\sqrt{d_k}})$ vs $softmax({{Q}}) ⋅ softmax({{K}})^T$. Although Efficient Attention actually computes $softmax({{K}})^T ⋅ V$ first to achieve its efficiency gains, the final attention distribution remains the same. Examining the scores directly helps us visualize and understand what's happening to the attention pattern.

Recall from linear algebra that the dot product of two vectors relates to their similarity:

$$  
a⋅b=∣a∣.∣b∣cos⁡(θ_{ab})  
$$

When vectors are closely aligned, their dot product is large.

In the example below, we have one query vector and four key vectors. Notice that the third key is identical to our query, so we should expect it to receive most of the attention:

$q = [2, 1, 3]$

$k_1 = [1, 0, 1]$, $k_2 = [0, 1, 0]$, $k_3 = [2, 1, 3]$, $k_{4} = [1, 1, 0]$

For the standard Dot-product Attention case,

$$  
AttnWeight_1= softmax(\frac{q.k_1}{\sqrt{3}}) = 0.005  
$$

$$  
AttnWeight_2 = softmax(\frac{q.k_2}{\sqrt{3}}) = 0.001  
$$

$$  
AttnWeight_3 = softmax(\frac{q.k_3}{\sqrt{3}}) = 0.992  
$$

$$  
AttnWeight_4 = softmax(\frac{q.k_4}{\sqrt{3}}) = 0.002  
$$

As we expected, position 3 got almost all the attention.

We now repeat the same calculations for the Efficient Attention case. For simplicity in the calculations here, we will use the matrix formulation where $K$ is the matrix created by setting the vectors $k_i$ as rows.

$$  
softmax(q).softmax_{col}(K)^T = [0.1309, 0.0713, 0.6962, 0.1017]  
$$

The trade-off is clear: by applying softmax before computing similarities, Efficient Attention smooths out the attention distribution. Instead of sharply focusing on the most relevant position (3), it distributes attention more uniformly across all positions. This flattening effect is why the mechanism is sometimes described as capturing broad semantic themes rather than precise positional relationships.  
This limitation explains why state-of-the-art language models still prefer standard attention despite its quadratic cost; the ability to attend precisely to specific tokens is crucial for many language understanding tasks. However, although Efficient Attention is not commonly used in LLMs, it remains highly valuable for AI models in other domains. In applications such as computer vision, where inputs represent pixels in images, the model can still perform well with this type of attention mechanism, making the substantial efficiency gains well worth the trade-off.

## Code implementation and benchmarks

To have a rough idea of the improvements over computational resources with efficient attention, we will run comparisons for some values of $N$and how each of the Attention implementations scales as it increases.

We'll see how easy it is to implement these functions using PyTorch and also to use them as a layer in a LLM.
    
    import torch
    
    def dot_product_attention(Q, K, V):
        attn_scores = torch.matmul(Q, K.T)                 # N x N
        attn_weights = torch.softmax(attn_scores, dim=-1)  # N x N
        return torch.matmul(attn_weights, V)               # N x d
       
    def efficient_attention(Q, K, V):
        Q_smr = torch.softmax(Q, dim=-1)                   # N x d
        K_smc = torch.softmax(K, dim=-2)                   # N x d
        KV = torch.matmul(K_smc.T, V)                      # d x d
        return torch.matmul(Q_smr, KV) 
    

Below you can see a comparison of the execution times for different values of the sequence length $N$, for both Attention implementations.

For reference, these benchmarks were run on a machine with the following specs:

        * **GPU:** NVIDIA RTX A4000 (16 GB)
        * **OS:** Ubuntu 22.04 LTS (Kernel 5.15.0-157)
        * **CPU:** 8 × Intel(R) Xeon(R) Gold 5315Y @ 3.20 GHz

![Im 2](/images/external/execution_time.png?raw=true)

Similarly, below is the comparison for the memory resources

![Im 3](/images/external/memory_usage.png?raw=true)

As one can see, at the beginning, the memory and performance are similar for both (although better for the linear attention implementation), but for larger sequence lengths, both the time and memory requirements of the original implementation grow exponentially (plots are in log-log scale, so a greater slope means greater exponent), whilst the Efficient Attention implementation doesn’t.

You can see the [code used for the benchmarks](https://github.com/lambdaclass/linear_attention_blog/blob/main/notebook/benchmark.ipynb).

The same repository also includes a [full Transformer implementation](https://github.com/lambdaclass/linear_attention_blog/blob/main/transformer.py) following the GPT architecture, with a configuration option to switch between **Efficient Attention** and the **original Dot Product Attention** , providing a broader view of how everything fits together.

## Conclusion

Efficient Attention has been shown to be much more memory and performance efficient than the usual Dot Product Attention, allowing for much larger contexts to be processed due to its linear dependency with it. So why aren’t they more widely adopted? State-of-the-art models will rather pay the high costs of training to have that small edge over the competition.

Nevertheless, efficient attention implementations remain important in domains such as video generation or genomics, where context sizes can inherently become very large.

In this blog post, we’ve presented the original and simplest implementation of linearized attention; however, this is an ever-evolving field, and new and improved implementations have emerged, such as CosFormer, LinFormer, and Mamba. Some modern architectures also take a hybrid approach, mixing standard and efficient attention heads to balance accuracy and stability.

* * *

## References

        * [Efficient Attention paper](https://arxiv.org/pdf/1812.01243)
        * <https://github.com/lucidrains/linear-attention-transformer>
        * <https://www.youtube.com/watch?v=LgsiwDRnXls>
        * <https://cmsflash.github.io/ai/2019/12/02/efficient-attention.html>
