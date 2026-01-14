+++
title = "Summary on rStar-Math: showing how smaller LLMs can outperform bigger ones with deep thinking"
date = 2025-01-28
slug = "summary-on-rstar-math-showing-how-smaller-llms-can-outperform-bigger-ones-with-deep-thinking"

[extra]
feature_image = "/content/images/2025/12/Saint_Jerome_Writing-Caravaggio_-1605-6-.jpg"
authors = ["LambdaClass"]
+++

**TL;DR** : this post addresses the [paper introducing rStar-Math](https://arxiv.org/pdf/2501.04519) and the techniques for smaller language models to outperform more complex large language models on math-related tasks. You can check the [code here](https://github.com/zhentingqi/rStar). rStar-Math significantly improved the math reasoning abilities of SLMs. For instance, on the MATH benchmark, it enhanced Qwen2.5-Math-7B's performance from 58.8% to 90.0% and Phi3-mini-3.8B's from 41.4% to 86.4%, surpassing OpenAI's o1-preview model. Additionally, on the USA Math Olympiad (AIME), rStar-Math solved an average of 53.3% of problems, ranking among the top 20% of high school math students.

## Introduction

Large Language Models (LLMs) are advanced artificial intelligence systems designed to understand, generate, and manipulate human language. They are trained on extensive datasets comprising billions of words, enabling them to perform a wide range of language-related tasks.

**Key Characteristics of LLMs:**

        * **Scale:** LLMs contain many parameters ranging from millions to billions, allowing them to capture intricate patterns and nuances in language.
        * **Training Data:** These models are trained on diverse and extensive text corpora, including books, articles, websites, and other textual sources, providing them with a broad understanding of language usage across different contexts.
        * **Capabilities:** LLMs can perform various tasks such as text generation, translation, summarization, question-answering, and more, often with human-like proficiency.

**Underlying Architecture:**

Most LLMs are built upon the [Transformer architecture](https://arxiv.org/pdf/1706.03762), introduced in 2017. This architecture uses self-attention to process and generate language efficiently, enabling models to consider the context of words in a sentence and capture long-range dependencies. One great advantage of transformers is that learning transfer can be very effective. Thus, we can train a model using large amounts of data and then train it in some other tasks using fine-tuning. An LLM that can be adapted to solve multiple different tasks is known as a foundational model. To process data, it must be first transformed into a sequence of tokens.

Most state-of-the-art LLM use the decoder part of the transformer, stacked several times (for example, 24, 48, 72, 100, etc). Each decoder contains the following elements:

        * **Masked self-attention** : A multi-head attention sub-layer with a causal mask to ensure tokens cannot attend to future positions (we will explain these terms soon).
        * **Feed-forward network** : A position-wise two-layer MLP with a nonlinearity.
        * **Residual Connections** and **Layer Normalization** around each sub-layer.

A minimal schematic for decoder layer $m$ is:  
$\mathbf{H_{ att }}^m = \mathrm{MHA}( \mathbf{H}^{m - 1 })$

$\mathbf{H_{addnorm}}^m = \mathrm{Layer Normalization}(\mathbf{H}^{m - 1} + \mathbf{H_{att}}^m)$

$\mathbf{H_{ffn}}^m = \mathrm{FFN} (\mathbf{H_{addnorm}}^m)$

$\mathbf{H}^m = \mathrm{Layer Normalization}( \mathbf{H_{addnorm }}^m + \mathbf{H_{ffn}}^m)$  
MHA denotes the multi-head attention function, LayerNormalization is the normalization function, and FFN is the feed-forward neural network.

The attention works by relating three elements: keys, queries, and values, which come from suitable transformations of the layer inputs. These transformations are linear, and the elements of the matrices should be learned by the model:  
$\mathbf{Q} = \mathbf{H}^{m - 1} W_Q$  
$\mathbf{K} = \mathbf{H}^{m - 1} W_K$  
$\mathbf{V} = \mathbf{H}^{m - 1} W_V$

The attention mechanism compares the keys and queries to find the best value match. One way to find a correlation between two vectors is via the cosine of the angle formed by queries and keys,  
$$\cos (\theta) = \frac{\mathbf{Q^t} \mathbf{K}}{\lVert\mathbf{Q} \rVert \lVert \mathbf{K} \rVert}$$  
The scalar product between two vectors shows how correlated they are. In LLMs, we use the softmax function, which ensures that the activations will be positive and, at most 1:  
$$a_{nm} = \frac{\exp(x_n^t x_m )}{\sum \exp(x_n^t x_l )}$$

There are two necessary adjustments to attention: scaling and causality. The first one is needed to rescale the arguments of the softmax function and avoid getting vanishingly small gradients. Causality ensures that a token cannot attend to future tokens so that the model can only use current or previous tokens, enabling autoregressive generation. Thus,  
$\mathbf{H}_{att,s} = \mathrm{attention}(\mathbf{Q}, \mathbf{K}, \mathbf{V}) = \mathrm{softmax}\left( \frac{\mathbf{Q} \mathbf{K}^t}{\sqrt{d_k}} + \mathbf{M} \right) \mathbf{V}$  
where $\mathbf{M}$ is the mask, which makes all the positions where a token should not attend future tokens equal to $- \infty$ (so that when we apply the softmax function, those elements are equal to zero). $d_k$ is the length of the key vector.

The multi-head attention function has $h$ different heads (each with its key, query, and value matrices). It concatenates the results of each head (basically gluing them one after the other) and applies a matrix $\mathbf{W}^o$,  
$head_i = \mathrm{attention}(\mathbf{H}^{m - 1} \mathbf{Q}^i , \mathbf{H}^{m - 1} \mathbf{K}^i , \mathbf{H}^{m - 1} \mathbf{V}^i )$  
$H_{att} = \mathrm{concatenate} \left( head_1 , head_2 , \dots head_h \right) \mathbf{W}^o$

After attention and normalization, each token’s representation goes through a **position-wise** [MLP](https://en.wikipedia.org/wiki/Multilayer_perceptron) (applied identically to each sequence position, hence “position-wise”):

$$  
\mathbf{z} = \mathbf{h} , W_1 + \mathbf{b}_1,  
\quad  
\mathbf{z}' = \sigma(\mathbf{z}),  
\quad  
\mathbf{h}' = \mathbf{z}' , W_2 + \mathbf{b}_2,  
$$  
where:

        * $\mathbf{h} \in \mathbb{R}^{d}$ is a single token’s representation from the attention sub-layer.
        * $W_1 \in \mathbb{R}^{d \times d_{\text{ff}}}$, $W_2 \in \mathbb{R}^{d_{\text{ff}} \times d}$.
        * $\sigma$ is typically a **GELU** (Gaussian error linear unit) or **ReLU** ([rectified linear unit](https://en.wikipedia.org/wiki/Rectifier_\(neural_networks\))) nonlinearity (activation function).
        * This is done for each position independently, so in matrix form:  
$$\text{FFN}(\mathbf{H}) ;=; \max\bigl(0,,\mathbf{H},W_1 + \mathbf{b}_1\bigr),W_2 + \mathbf{b}_2.$$

Before reading text or images, they have to be transformed into tokens. Let the input be a sequence of tokens:  
$(x_1, x_2, \dots, x_T),$  
where each $x_i$ is an integer index into a vocabulary. We map each $x_i$ to a **d** -dimensional embedding vector:  
$\mathbf{E}(x_i) \in \mathbb{R}^d.$  
Thus, the input sequence is transformed into an embedding matrix:  
$\mathbf{X} ;=;  
\bigl[  
\mathbf{E}(x_1);, \mathbf{E}(x_2);, \ldots; ,\mathbf{E}(x_T)  
\bigr]  
;\in; \mathbb{R}^{T \times d}.$

A decoder-only Transformer must still encode the notion of sequence position. Common methods include:

        * **Learned positional embeddings** : A trainable $\mathbf{P}(i) \in \mathbb{R}^d$ for each position $i$.
        * **Sinusoidal (original Transformer)** :  
$$  
\begin{aligned}  
\text{PE}(i,,2k) &= \sin\Bigl(\tfrac{i}{10000^{2k/d}}\Bigr),\quad  
\text{PE}(i,,2k+1) = \cos\Bigl(\tfrac{i}{10000^{2k/d}}\Bigr).  
\end{aligned}  
$$
        * **Rotary Positional Embeddings (RoPE)** : A rotation in the query/key space (commonly used in GPT-NeoX, LLaMa, etc.).

Either way, the next step is typically:  
$\mathbf{H}^{(0)} = \mathbf{X} ;+; \mathbf{P},$  
where $\mathbf{P}$ indicates the positional information (shape $\mathbb{R}^{T \times d}$, same as $\mathbf{X}$).

**Applications:**

        * **Natural Language Processing (NLP):** LLMs enhance various NLP tasks, including sentiment analysis, entity recognition, and language translation.
        * **Content Creation:** They assist in generating articles, reports, and even creative writing, aiding authors and content creators.
        * **Customer Service:** LLMs power chatbots and virtual assistants, providing human-like interactions in customer support scenarios.

**Challenges and Considerations:**

Despite their impressive capabilities, LLMs face challenges such as:

        * **Resource Intensity:** Training and deploying LLMs require substantial computational resources, making them accessible primarily to large organizations.
        * **Ethical Concerns:** Issues like the generation of biased or inappropriate content and the potential for misuse necessitate careful consideration and responsible deployment.
        * **Interpretability:** Understanding the decision-making process of LLMs can be complex, raising concerns about transparency and trustworthiness.

In general, one would expect that the quality of the responses and LLM capabilities should be higher, given a greater set of parameters. The problem with this approach is that models become prohibitively expensive to train and fine-tune and cannot be run locally by users. The paper shows how a smaller LLM can outperform more powerful LLMs by using deep thinking and using the following concepts and ideas:

        * **Code-Augmented Chain-of-Thought (CoT) Data Synthesis** : This method generates step-by-step verified reasoning trajectories by performing extensive Monte Carlo Tree Search (MCTS) rollouts. These trajectories are used to train the policy smaller language model (SLM), ensuring it learns accurate and logical reasoning steps.
        * **Process Reward Model Training** : Instead of naïve step-level score annotation, the authors develop a more effective process preference model (PPM). This model evaluates the quality of reasoning steps, guiding the policy SLM to produce better solutions.
        * **Self-Evolution Framework** : The policy SLM and PPM are built from scratch and iteratively evolved through multiple rounds. In each round, millions of synthesized solutions for a large set of math problems are generated, progressively enhancing the reasoning capabilities of the models.

It is important to note that while an LLM can provide a correct answer for a given problem, the reasoning may be flawed or contain invalid steps. Thus, it is essential that the model can learn how to avoid invalid steps along the way. rStar decouples reasoning into a generation-discrimination process. The following section will discuss the techniques used to train and improve the LLM.

## Techniques

rStar's process involves generating alternative steps and reasoning about them. The main techniques are:

        * **Monte Carlo Tree Search** (MCTS): [MCTS](https://en.wikipedia.org/wiki/Monte_Carlo_tree_search) is used during test-time to explore multiple reasoning paths. The policy SLM generates potential steps, and the PPM evaluates them, guiding the search towards the most promising solutions. MTCS is used because it breaks down problems into single-step generation tasks, yielding step-level training data for the LLM. Besides, this approach is simpler than Best-of-N or self-consistency, which requires generating full solutions at once.
        * **Code-Augmented Data Synthesis** : By incorporating code execution into the data synthesis process, the system ensures the generated reasoning steps are verifiable and correct, providing high-quality training data for the policy SLM.
        * **Process Preference Modeling (PPM)** : The PPM assesses the quality of intermediate reasoning steps, allowing the system to prefer more logical and accurate paths during the MCTS exploration.
        * **Self-Evolution Strategy** : Through iterative training rounds, both the policy SLM and PPM are refined. Each round uses the outputs from the previous iteration to improve performance, enabling the models to develop advanced reasoning capabilities over time.

MCTS is a decision-making algorithm used in complex domains such as board games (Go, Chess, Shogi), combinatorial optimization, and various planning problems. The key idea of MCTS is to incrementally build a search tree by running many simulated “playouts” (or rollouts) from a given state and using the simulation results to guide which parts of the tree should be explored more deeply. The four steps for MCTS are:

        * **Selection** : Starting at the root node (the current game state), select child nodes down the tree according to a selection policy that balances exploration (trying less-visited moves) and exploitation (focusing on moves that appear promising). The Upper Confidence Bound for Trees (UCT) is a standard selection policy.
        * **Expansion** : When you reach a node that is not a terminal state and has unvisited child states (moves), expand one (or more) of those child nodes in the tree.
        * **Simulation (Rollout)** : From the expanded node, simulate a random (or semi-random) sequence of moves until reaching a terminal state (i.e., game over or a pre-defined depth for non-terminal states). The outcome of this simulation (win/lose/draw or another reward measure) is recorded.
        * **Backpropagation** : Propagate the simulation’s result back up through the visited nodes in the tree, updating statistics (e.g., total reward, visit counts). This information is used to inform the next selection step.

In this case, the LLM first generates the MCTS with a set of human reasoning actions to build higher quality reasoning trajectories such as:

        * **Propose a one-step thought**.
        * **Complete reasoning thought**.
        * **Propose subquestions and answer**.
        * **Re-answer the subquestion**.
        * **Rephrase the question**.

These are typical actions that we as humans do to solve complex tasks. We rephrase or find related questions that can help us shed new light on the problem.

A second LLM verifies each trajectory proposed by the first one and assesses their validity. If there is an agreement between both, the trajectories can be considered mutually consistent and valid with high likelihood. This resembles working with peers and checking each other's answers. Since each step contains Python code, only those nodes with successful code execution are kept. These high-quality trajectories will be used as part of the training set.

The authors introduce a method to provide step-by-step verified trajectories with per-step Q-value annotations. They use four rounds of self-evolution: the first two are terminal-guided MCTS (since the PPM still has not been trained), while the next two rely on the trained PPM. Starting from the tree's root (the original query), the LLM generates different alternative steps and annotates each with a Q-value. The process proceeds until the LLM reaches a solution corresponding to a tree leaf, $s_d$. Each $s_d$ contains a sequence of steps linking it to the root, corresponding to a single trajectory. Initially, all Q-values are set to $0$. We generate each new level of the tree until we get to the first leaf (terminal node) and reward it according to whether it got to the correct answer. Then, this score is backpropagated to all the steps in the trajectory, according to $Q(s_k ) = Q(s_k ) + Q(s_d )$. As we get more valid trajectories going through a node, the higher its $Q$ value. Finally, the LLM takes $n$ high-quality of these trajectories to use as training data.

Upper Confidence Bound for Trees (UCT) balances exploration and exploitation. For a node $k$, its UCT value is computed as  
$$UCT(k) = \frac{W_k }{N_k} + c \sqrt{\frac{\ln (N_p )}{\ln (N_k )}}$$

where $W_k$ is the total reward of node $k$, $N_k$ is the number of times node $k$ has been visited, $N_p$ is the number of times the parent node of $k$ has been visited and $c$ is a constant. A higher value of $c$ favors exploration. The first term focuses on the reward of the node (exploitation), while the second one encourages exploration by penalizing nodes with high visit counts relative to its parent. The reward will first be given from the terminal and later by the PPM. The authors introduce a novel training method based on positive-negative preference pairs.

Since SLM have weaker capabilities, the authors used four rounds of MCTS deep thinking to generate progressively higher quality data and extend the training set with more challenging problems:

        * **Round 1** : Bootstrapping an initial strong policy model, SML-r1. This uses terminal annotated Q-values and performs 8 MCTS rollouts for efficiency. The data obtained is used to train PPM-r1.
        * **Round 2** : Training a reliable PPM PPM-r2. Using PPM-r1, the authors conduct lots of MCTS with 16 rollouts per problem.
        * **Round 3** : PPM-augmented MCTS for improved data quality. Using PPM-r2, the model tackles more complex problems and generates additional data to train PPM-r3.
        * **Round 4** : Solving more challenging problems. For unsolved problems, the authors increase the number of rollouts to 64 or 128 and produce different MCTS with various initial seeds. This step boosts the success rate of the math model.

## Results

After four rounds of self-evolution, rStar-Math significantly improved the math reasoning abilities of SLMs. For instance, on the MATH benchmark, it enhanced Qwen2.5-Math-7B's performance from 58.8% to 90.0% and Phi3-mini-3.8B's from 41.4% to 86.4%, surpassing OpenAI's o1-preview model. Additionally, on the USA Math Olympiad (AIME), rStar-Math solved an average of 53.3% of problems, ranking among the top 20% of high school math students. The following graphs compare the performance of rStar-math in different benchmarks with other LLMs based on the number of rollouts.

![image](https://hackmd.io/_uploads/SyLxqMdP1x.png)

## Summary

LLMs have shown great capabilities in understanding human language, image generation, and developing agents to perform various tasks. While their performance and accuracy have increased, this has been at the cost of a larger number of parameters, increasing training and inference costs and making it impossible for users to run them locally or fine-tune them to perform a particular task. Another important point is that LLMs can hallucinate, providing invalid answers or giving the right answer with flawed reasoning. This work explores how to use deep thinking with smaller LLM to improve performance, which could enable users to run the model locally or even fine-tune it. Using Monte Carlo Tree Search, scoring strategies based on Go engines, and code-augmented data, rStar-math achieves performance similar to that of much larger LLMs. In summary, rStar-Math demonstrates that with innovative training and reasoning strategies, small language models can achieve state-of-the-art performance in mathematical reasoning tasks, rivaling or surpassing larger models.
