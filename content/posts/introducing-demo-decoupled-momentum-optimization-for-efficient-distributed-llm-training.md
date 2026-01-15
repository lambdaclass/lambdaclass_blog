+++
title = "Introducing DeMo: Decoupled Momentum Optimization for efficient distributed LLM training"
date = 2024-12-06
slug = "introducing-demo-decoupled-momentum-optimization-for-efficient-distributed-llm-training"

[extra]
math = true
feature_image = "/images/2025/12/Horace_Vernet_-1789-1863-_-_Arabs_Travelling_in_the_Desert_-_P584_-_The_Wallace_Collection.jpg"
authors = ["LambdaClass"]
+++

## TL;DR

Training Large Language Models (LLM) with billions of parameters is computationally intensive and involves large communication in specialized data centers. [Nous Research](https://nousresearch.com/) released DeMo, showing how to reduce these communication costs by orders of magnitude, decreasing costs and enabling training with poorer connections and less expensive hardware. This post introduces basic concepts and discusses [the paper](https://arxiv.org/pdf/2411.19870).

## Introduction

The problem of machine learning consists of finding a function (or mapping) from a set of inputs, $X$, to a set of outputs, $Y$. This relationship can be quite complex, and we want to approximate it by having information on samples $(x , y)$. For example, we could be interested in the response of the length of a hanging spring to adding weight; to that end, we would measure the weight we are adding, $w$, and record the variation in length, $\Delta x$. Another example could be correlating the energy expenditure by a person based on information such as heart rate, weight, height, and amount of skeletal muscle mass. We could also want to train an agent to recognize an image. While the underlying relationships and objectives could be very different, they can be treated by some families of mathematical methods. Before diving into specifics of large language models (LLM) and artificial intelligence (AI), let us focus on simpler problems, such as measuring the spring's elongation with weight or the current circulating in a wire due to the application of a given voltage.

In the case of the spring, we get some weights (for example, 25 g, 50 g, 100 g, 200 g). We measure the resulting elongation once the movement of the spring finishes, say 1, 2, 4 and 8 cm. Using empirical knowledge from Physics, as long as we are in an elastic regime, [Hooke's law](https://en.wikipedia.org/wiki/Hooke%27s_law) holds: the weight (applied force) is proportional to the elongation, $k \Delta x = w$, where $k$ is the stiffness of the spring. The relationship is not always like this because if we add too much weight, the spring is deformed significantly and loses its behavior. The problem we want to solve is, therefore,

Find $k$ such that $k \Delta x_i = w_i$ for $i = 0, 1, 2, ... n$. This is a system of linear equations, and should there be no measurement errors and this relationship be the true mapping, then $k = w_i / \Delta x_i$.

Some problems we face are:

        1. The relation/mapping we are using may be an approximation of the true relationship.
        2. There are errors associated with the measurements (we can assume for the time being that these errors are random and not introduced systematically by the observer).
        3. We don't have lots of measurements $(\Delta x , w)$.

This makes things quite harder. To start with, the system of equations $k \Delta x_j = w_j$ could no longer have a valid solution. For example, we could have $(1 , 25)$ and $(2.01 , 49.9)$, which translates to:  
$k. 1 = 25$  
$k. 2.01 = 49.9$  
The first equation yields $k = 25$, while the second gives $k = 24.82$. This system of equations has no solution, but we could still be interested in estimating $k$ from the information available (the two values are not too far apart, so maybe we can do something). We could define a new function that measures the difference between the observed output $w_j$ and the predicted output $\Delta x_j$. We call this function the [loss function](https://en.wikipedia.org/wiki/Loss_function). For example,  
$L(k) = (k \Delta x_0 - w_0 )^2 + (k \Delta x_1 - w_1 )^2 = (\hat{w}_0 - w_0 )^2 + (\hat{w}_1 - w_1 )^2$

The function measures the quadratic error between the weight predicted by Hooke's law and our measurements. Our objective is to find $k$ such that the loss function is minimal,  
$\min_{k \in K} L(k)$

Calculus tells us that the function (assuming it is "nice") attains an extremal value if the derivative with respect to $k$ is zero,  
$dL/dk = 0$

Using the chain rule for derivatives,  
$dL/dk = 2(k \Delta x_0 - w_0 )\Delta x_0 + 2(k \Delta x_1 - w_1 ) \Delta x_1 = 0$

This equation is linear, and we can solve it directly. Let us complicate the problem a little bit, assuming

        1. We have several parameters, $k_0, k_1 , ... , k_m$
        2. That the equations to find the parameters are non-linear.

The procedure can be generalized using multivariate calculus if we have several parameters. We ask for the partial derivatives with respect to each parameter to be zero:  
$\partial L / \partial k_0 = 0$  
$\partial L / \partial k_1 = 0$  
$\partial L / \partial k_2 = 0$  
$\vdots$  
$\partial L / \partial k_m = 0$

The vector containing all these partial derivatives is the gradient of $L$. We have a system of several equations with as many variables to solve.

What happens when the equations above are not easy to solve? We have two facts:

        1. The gradient should be zero at the minimum.
        2. The gradient's direction gives the direction of the greatest increase in a function (so following the opposite direction should give the steepest descent).

This is the working principle of the steepest descent search. Starting for a set of parameters $k^0$, we recursively set  
$k^{n + 1} = k^n - \gamma \nabla L$  
where $\gamma$ is a parameter (called the learning rate). High values of $\gamma$ generate instability and convergence issues, whereas low values of $\gamma$ mean we move slowly toward the minimum.

We now face some further questions which we did not address before:

        1. A function can have several (local) minima, so how can we ensure that we find the true (global) minimum?
        2. Is there a way we can adapt the learning rate $\gamma$ so that we can achieve convergence faster?
        3. What happens if the number of observations $(x_i , y_i )$ is very large and the loss function has a complicated or expensive to evaluate expression?

We will first address the third question and then try to solve the others. We have an expression of the form:  
$L (k) = \sum_j E_j (x_j, y_j , k)$  
For example, $E_j = ( f(x_j , k) - y_j )^2$ could be the quadratic error for each observation, and $f$ is the function giving the relationship between input and output. Computing the whole gradient involves the (partial) derivative of each $E_j (x_j , y_j )$ and summing over all values of $j$, making the evaluation of the gradient expensive. We could try to reduce the number of terms just by choosing one observation and approximate the true gradient by this value:  
$\nabla L \approx \nabla E_j$  
This reduces the computational burden at the expense of accuracy. We could also try to estimate the gradient using a subset of the observations or mini-batch. This is the idea of the stochastic gradient descent.

Since we are dealing with approximations, the learning rate may need to be readjusted and decreased at a specific rate, making it $\gamma^n$.

We can improve the method by introducing momentum, which keeps track of previous gradients when updating it for the next iteration. Basically,  
$\Delta k^n = \alpha \Delta k^{n - 1} - \gamma (\nabla L)^n$  
$k^{n + 1} = k^n + \Delta k^n$  
We can see that if $\alpha = 0$, we recover the original gradient descent. If $\alpha$ is different from zero, we accumulate the previous gradients and, considering the directions given by earlier steps. This will ensure that if we were going in a given direction for some time, we will continue going that way, avoiding sudden changes in direction.

Since gradients can have components with very different values, we can adjust learning rates for each variable, as in the case of the [Adam optimizer](https://arxiv.org/pdf/1412.6980).

The problem with local minima can be solved by means of this momentum method (which would prevent us from being trapped in shallow minima), trying different starting points and also [annealing methods](https://en.wikipedia.org/wiki/Simulated_annealing).

We can create or approximate more complex behaviors by using neural networks. Given the input variables $x_1, ... x_m$, we can form a linear combination, using weights $w_{j0}$ and apply an activation function $f$, obtaining new values $z_{11}, ... z_{1m}$ as follows:  
$a_{1j} = \sum_l w_{jl} x_l + w_{j0}$  
$z_{1j} = f(\sum_l w_{jl} x_l + w_{j0})$  
We can add a new layer, using the output above, by performing linear combinations and applying an activation function  
$z_{2j} = f(\sum_l w_{jl}^{(2)} z_{1l} + w_{j0}^{(2)})$  
We can similarly add other layers until we get the output of the neural network,  
$z_{3j} = f(\sum_l w_{jl}^{(3)} z_{2l} + w_{j0}^{(3)})$

Gradients can be computed efficiently using backpropagation. We will start again with our loss function as a sum of terms, each corresponding to one sample,  
$L (k) = \sum_j E_j (x_j, y_j , k)$  
We will focus on computing the derivative of one $E_j$ with respect to each of the parameters,  
$$\frac{\partial E_j}{ \partial w_{ji} } = \frac{\partial E_j}{\partial a_j} \frac{\partial a_j }{\partial w_{ij}}$$

The second partial derivative on the right-hand side is straightforward since $a_j$ is a linear combination of $w_{ij}$,  
$$\frac{\partial a_j }{\partial w_{ij}} = z_i$$  
For the other derivative, we will just call it  
$$\frac{\partial E_j}{\partial a_j} = \delta_j$$  
so that  
$$\frac{\partial E_j}{ \partial w_{ji} } = z_i \delta_j$$

The derivatives for each layer can be computed by evaluating $\delta_j$ and using the formula provided. For the hidden layers,  
$$\delta_j = \sum_m \frac{\partial E_j}{\partial a_m} \frac{\partial a_m}{\partial a_k}$$  
We can finally arrive at the backpropagation formula for $\delta_j$,  
$\delta_j = f^\prime (a_j ) \sum_m w_{mj} \delta_m$

The basic procedure to evaluate the derivatives would be to first compute the $a_j$ for all the layers and the output, evaluate $\delta_j$ for the output, and use the last formula using backpropagation to obtain each $\delta_j$ for each inner layer.

Many Large Language Models (LLM) are based on neural networks. They have shown good performance in different fields, such as translation and conversational AI. These can be in the order of trillions of parameters. Therefore, in order to attain reasonable training times, we need accelerators, such as GPU and TPU. We often encounter heterogeneity in GPU clusters, and interconnects are partitioned into high-bandwidth islands in each machine and low-bandwidth across machines, limiting training speeds and suboptimal hardware utilization. This also affects memory planning, and frequent memory defragmentations significantly slow training. This also translates into capital and operational costs.

Strategies such as Distributed Data Parallelism and Fully Sharded Data Parallelism have the accelerators split the weights and synchronize the gradients, with communication volumes proportional to the size of the model (For example, [training a GPT-J-6B with 10B tokens on 4 machines would require 915 TB of data transferred!](https://proceedings.mlr.press/v202/wang23t/wang23t.pdf). [LlaMa pre-training with 7 billion parameters uses over 58 GB of memory to store parameters, activations, and gradients](https://arxiv.org/pdf/2403.03507)). This makes gradient synchronization require expensive high-speed interconnects, forcing all devices to be in the same physical space. Reducing communication costs by over an order of magnitude could not only reduce costs or training times, but also allow for the use of more distributed hardware.

Some techniques used to reduce memory footprint and communication costs are:

        * [Sparsification and compression](https://proceedings.mlr.press/v202/wang23t/wang23t.pdf)
        * [Low-rank projection of gradients](https://arxiv.org/pdf/2403.03507)
        * [Federated averaging](https://proceedings.mlr.press/v54/mcmahan17a/mcmahan17a.pdf)

In this blog post, we will discuss [DeMo](https://arxiv.org/pdf/2411.19870), recently released by [Nous Research](https://nousresearch.com/), which provides significant savings in communication and memory use, allowing to train LLMs with poorer connections and less powerful hardware.

## Nous Research

Nous Research is dedicated to researching human-centric language models and simulators, focusing on areas including model architecture, data synthesis, fine-tuning, and reasoning, all aimed at aligning AI systems with real-world user experiences. Four months ago, they released a preliminary report on [DisTro](https://github.com/NousResearch/DisTrO/blob/main/A_Preliminary_Report_on_DisTrO.pdf), a family of architecture-agnostic and network-agnostic optimizers, significantly reducing the communication costs by several orders of magnitude, which enables efficient distributed training of AI.

## Working hypothesis

The paper shows that gradients for very large LLM exhibit both redundancy and high compressibility. This is the core insight enabling DeMo. It is based on the following three observations:

        1. The fast-moving components of momentum exhibit high spatial auto-correlation with a small number of principal components.
        2. Fast-moving momentum components show low temporal variance and should be used to update the parameters immediately. The slow-moving components exhibit high temporal variance and benefit from temporal smoothing.
        3. Slow-moving momentum components are crucial for long-term convergence and should be preserved rather than filtered out.

Using these conjectures, the authors modify the SGD method with momentum to decouple momentum between the different accelerators. After updating the momentum, the fast components $q$ of momentum are extracted using a discrete cosine transform (DCT), and these components are shared with minimal communication.

## How does DeMo work?

The starting point is the Stochastic Gradient Descent (SGD) with momentum algorithm. Instead of computing the overall gradient, we will compute local gradients and use them to update the (decoupled) momentum. Then, we will extract the $k$ fastest components for each momentum and subtract them from the decoupled momentum. Finally, we will communicate and synchronize all the fast components and update the parameters using this synchronized gradient. This is the algorithm as described in the [paper](https://arxiv.org/pdf/2411.19870):  
![Screenshot 2024-12-04 at 2.35.32 PM](/images/external/SJeEXz07ye.png)

The extraction of the fast components is critical for the algorithm's performance. While the Kosambi–Karhunen–Loève Transform provides a way to achieve the decorrelation, separation, and extraction of the main components, the DCT offers an excellent approximation under the hypothesis provided above. The advantages of DCT lie in its efficient computation and high degree of parallelization. Besides, it is computed on a fixed orthogonal basis, which allows us to decode a DCT-encoded signal efficiently without additional information.

We can work with each momentum tensor as a d-dimensional autocorrelated signal, chunk them, and apply the DCT to each, extracting the highest $k$ values and their frequencies. This creates two tensors, one containing the frequencies (using an index) and the other keeping the amplitude (using a floating point number). In the DCT, the frequencies are given by $2\pi i/N$, so giving $i$ suffices to specify the frequency, so we would get pairs $(i, A)$ indicating the frequency and amplitude of the fastest components. We can then perform the inverse DCT with these tensors to recover the values of the components, $q_t$, and remove these values from the momentum (fourth step of the algorithm).

After gathering all the fastest local components, we are ready to synchronize them. The first step is to average the amplitudes over repeated frequencies (if the frequency given by the index 11, corresponding to $2\pi 11/N$, is repeated in the fastest components of a local gradient). In the second step, we perform the inverse DCT to recover the values of the fastest components of the global gradient, $Q_t$. The advantage is that if we choose the parameters appropriately, the number of fastest components we have to share is significantly smaller than the gradient.

The experimental results show that DeMo can reduce communication costs by at least one order of magnitude compared to AdamW, without noticeable changes in convergence.

## Summary

This post introduced basic concepts related to machine learning and LLM, explaining the objectives, strategies, and challenges that arise when training very large models. The need to split parameters and computation among several accelerators introduces the need for specialized connections, having all devices in the same physical place. Using empirical observations from training LLMs, Nous Research proposed DeMo, leveraging the DCT to extract the fastest components and reduce the amount of data the accelerators have to share. The experimental results show a reduction of at least an order of magnitude with respect to AdamW (depending on the choice of parameters, it can be higher), allowing for the use of networks with poorer bandwidth and heterogeneous hardware to train LLMs, reducing both capital and operational costs.
