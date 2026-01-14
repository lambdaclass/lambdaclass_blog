+++
title = "SymJAX: symbolic CPU/GPU/TPU programming"
date = 2020-09-18
slug = "symjax-symbolic-cpu-gpu-tpu-programming"
description = "A symbolic programming version of JAX"

[extra]
feature_image = "/content/images/2025/12/Screenshot-2025-12-19-at-12.10.16---PM.png"
authors = ["LambdaClass"]

[taxonomies]
tags = ["Symjax", "Jax", "Theano", "Symbolic", "Programming"]
+++

#### A symbolic programming version of JAX

![](/content/images/max/2000/1-U2wpT5qoWqSOwrgYtgLJ3w.png)SymJAX's really cool logo

As we try to have a deeper undestanding of the world we live in, we tend to add more and more complex relationships in the models we use to describe it, so we need to borrow a hand from computers to run them.

Complex relationships often are represented in form of graphs and many learning algorithms require differentiation of some kind.

We also don’t want to lose mathematical interpretability, so having a symbolic programming framework that allows us to represent these complex models in a familiar way, provided with a Theano-like user experience, would be a very interesting tool to have in our pocket.

This is what SymJax has come to offer us. To know more about this, we interviewed [Randall Balestriero](https://github.com/RandallBalestriero) the creator and sole contributor of the project so far.

#### What is SymJAX?

[SymJAX](https://github.com/RandallBalestriero/SymJAX) is a [NetworkX](https://networkx.github.io/) powered symbolic programming version of [JAX](https://github.com/google/jax) providing a [Theano](https://github.com/Theano/Theano)-like user experience. In addition of simplifying graph input/output, variable updates and providing graph utilities such as loading and saving, [SymJAX](https://github.com/RandallBalestriero/SymJAX) features machine learning and deep learning utilities similar to [Lasagne](https://github.com/Lasagne/Lasagne) and [Tensorflow1](https://www.tensorflow.org/).

**Illustrative example: Adam optimizer of a dummy loss**
    
    
    import symjax
    import symjax.tensor as T
    
    
    from symjax.nn.optimizers import Adam
    
    
    # we create a persistent variable to be optimized
    
    
    z = T.Variable(3.0, dtype=”float32", trainable=True)
    
    
    # the optimization is about minimizing the following loss
    
    
    loss = T.power(z — 1, 2, name='loss')
    
    
    # this loss is just a node in the graph, nothing is computed yet
    
    
    print(loss) # Op(name=loss, fn=power, shape=(), dtype=float32, scope=/)
    
    
    # we minimize it with Adam, we can omit to assign it to a variable since the
    
    
    # internal updates are automatically collected, 0.1 is the learning rate
    
    
    Adam(loss, 0.1)
    
    
    # we create the function (XLA compiled graph) and define what are the inputs
    
    
    # (here none), the outputs and the persistent variable updates (from Adam)
    
    
    train = symjax.function(outputs=[loss, z], updates=symjax.get_updates())
    
    
    # for illustrative purposes, we perform 200 steps and reset the graph after 100 steps
    
    
    for i in range(200):
    
    
      if (i + 1) % 100 == 0:
    
    
      # we can use any identifier to select what to reset, ('*' is the default)
    
    
      # if we want to only reset the variables create by Adam
    
    
      # (the moving averages etc) one would use (for example)
    
    
      # symjax.reset_variables(/AdamOptimizer*')
    
    
      # in our case let reset all variables
    
    
      symjax.reset_variables()
    
    
      # the output of this function is the current loss and value of z, and when called it also
    
    
      # internally perform the given updates computed from Adam
    
    
      train()

For additional examples please see: <https://symjax.readthedocs.io/en/latest/auto_examples/>

#### The SymJAX documentation reads: “The number of libraries topping Jax/Tensorflow/Torch is large and growing by the day. What SymJAX offers as opposed to most is an all-in-one library with diverse functionalities”. What’s the main issue with having to use multiple libraries and how does creating a single library solve it?

There is absolutely nothing wrong with having complementary libraries that can be interconnected. In my opinion the current limitation of the mentioned libraries is the absence of inter-compatibility making it difficult to use features from one with another. This is different than say numpy and scipy who both complement each other seamlessly. In SymJAX, the JAX backend allows for any JAX library to be directly imported into SymJAX (as were C/CUDA code easily imported into Theano). Second, [Tensorflow is increasingly leveraging a JAX backend](https://www.tensorflow.org/probability/api_docs/python/tfp/experimental/substrates/jax), this development will also allow to easily import those Tensorflow utilities into SymJAX. People interested in using a standard JAX/Tensorflow library while benefiting from SymJAX utilities can do so easily. The other way around, any computational graph designed in SymJAX with SymJAX utilities can also be translated back into pure JAX, allowing JAX libraries to benefit from SymJAX. The target end result being that each library newly developed tool would directly benefit all cross-library users.

#### The documentation states that one of the goals of SymJAX is to optimize processes. How does the library enable that optimization? How does it compare to other technologies?

There are really two levels of (computational) optimization in SymJAX. First, SymJAX allows to define a computational graph which can be viewed as a computational roadmap based on inputs and operations producing some desired outputs (possibly involving some persistent graph variable updates). This user-defined computational roadmap is obtained without performing any actual computation yet. It is then compiled with XLA producing a sequence of computation kernels generated specifically for the given graph. This step allows to potentially merge multiple low-level operations into a single kernel and demonstrated performances gains for example [in Tensorflow](https://www.tensorflow.org/xla/). This step alone provides SymJAX with similar performances to Jax and XLA-Tensorflow, ceteris paribus.

The second and most important feature of SymJAX is its graph canonicalization. This feature is the same as the one that was employed in the [now-discontinued Theano library](http://www.deeplearning.net/software/theano/). Graph canonicalization allows generic graph optimization such as replacing the following subgraph:
    
    
    log( exp(x) * exp(4 + x) )

by the much simpler, yet equivalent subgraph:
    
    
    2 * x + 4'

This type of graph simplification can be done on much more complex parts of the graphs such as replacing the sum of two Gaussian distributions by a single Gaussian with different mean and covariance; hence greatly reducing the computational burden of random sampling. This reduced graph is then XLA compiled further optimizing low-level operations. This feature allows for much broader optimization than present in XLA and in most current libraries as it requires _a priori_ knowledge of the computational graph.

#### Does SymJAX support all state-of-art neural network architectures?

SymJAX provides out-of-the-box some basic neural network layers implementations. The number of implemented layers increases at each release but can surely not follow the exponentially growing number of neural network flavours being designed by the deep learning community. However, the core of SymJAX provides all the standard operations featuring almost all numpy and scipy functions among many more. This allows anyone to implement their own layers and neural networks (as well as losses or any other bit of a deep learning pipelines) ensuring that any needed architecture can be implemented on-the-go.

#### What were the biggest challenges in allowing a broad hardware support (GPUs, TPUs)?

One of the crucial benefit of leveraging JAX as the backend XLA interface is the ability to benefit from their latest hardware support. There was thus nothing additional needed in SymJAX to enable such broad support.

#### Is there support for dynamic computation graphs à la Pytorch? If not, are there any plans for it?

The computational graph in itself can be evaluated without XLA compilation allowing one to define a graph, evaluate it, and keep building it while evaluating it again (similar to session.run from Tensorflow 1). This would not give optimal performances but can be useful in some cases and would allow very general dynamic computation graphs. For best performances however the graph needs to be compiled effectively freezing its structure. However, we do allow for one dynamic aspect to persist after compilation: dynamic leading axis length (such as variable batch size). This allows, if needed, to have a compiled graph with the possibility to feed shape varying inputs. For now this is only possible on the leading axis but more general dynamic computation graphs will be considered in the future by allowing only the parts of the graph that will not vary dynamically to be compiled separately allowing for high-performance "hybrid" graphs to be evaluated.

#### SymJAX pays homage to Theano in many aspects. What’s different from Theano and why not improve Theano to bring it up to date instead of creating a new library from scratch?

The minimalist version of SymJAX and Theano both make the user define a graph, compile it and then evaluate it. However, SymJAX offers various user-friendly features that greatly simplify its use as opposed to Theano such as

  * much simpler graph construction and monitoring with explicit shape and dtype of each node
  * lazy (non compiled) partial graph evaluation (a la session.run or pytorch)
  * the concept of scopes (a la Tensorflow) and node/variable/placeholder fetching based on their names and scopes
  * utilities to save, load and reset variables and graphs
  * various graph analysis tools from networkX that can be used to study the computational graph and provide in-depth structural analysis
  * side utilities to allow deep learning pipelines to be built

The option of updating Theano was considered but would have forced to not only implement the above features (requiring some important changes in the Theano design) but would also force us to consistently keep working on the XLA interface/compilation and on the support for the latest hardwares including not only new GPU releases but also novel hardwares like TPUs. By instead building upon Jax XLA interface, we directly benefit from the latest XLA support allowing us to focus instead on additional features and graph related utilities.

#### Theano is powerful but in terms of popularity it lost the battle to the more high-level TensorFlow. What is the user you have in mind for SymJAX? How is it better than the other options?

As per the above points, I believe that Theano lost attraction due to its lack of user-friendly features making it too tedious to build a working pipeline as opposed to Tensorflow (or PyTorch) which allowed for a more flexible set-up thanks to features like automatically gathering trainable variables to be differentiated, automatically resetting all the graph variables without keeping track of them explicitly and so on. In addition Theano suffered from a very slow compilation step and often difficult GPU-support installation.

However, none denies the benefits of Theano in term of its graph simplification abilities and its design. By combining the best of both libraries and incorporating additional JAX abilities, you obtain SymJAX which I believe will attract users from any background. In fact, one of the main effort in SymJAX is to make the symbolic programming paradigm extremely user-friendly allowing anyone to employ it with minimum burden while enjoying all the induced benefits.

#### How many people are behind this project? Are you looking for contributors?

I have been the sole contributor of this project up until recently when a geophysicist colleague stepped in. There has also been a rising interest from the PyMC developer team to see how fit would be SymJAX to replace the Theano backend they employed. This ongoing discussion also allowed for additional contributions to SymJAX. All contributions are welcome and anyone interested in getting involved more actively with this project should feel free to contact me!

#### What is SymJAX’s current status and plans for the near future? How close is the project to its first stable release?

SymJAX has been unstable in its early months as many graph libraries were tested and various new features required drastic changes in the entire pipeline. We now are at a much more stable point where only a few remaining features are being tested and replaced (for example the graph visualization tool, the online data saving and visualization, and the graph canonicalization). But those changes are very localized in the library and do not break any other part of the library when changed. In its current state, SymJAX can already be used actively. In addition, the main remaining task is around documentation, and providing a rich Gallery of examples detailing all the functionalities of SymJAX. Once those changes are done, the first stable release will be published; a rough estimate would put us a few weeks away from it.

#### For our readers who might want to know more, what papers, articles and courses do you recommend doing to learn about symbolic programming and deep learning?

For a jump-start in deep learning, the Deep Learning book (<https://www.deeplearningbook.org/>) is complete and offers all the tricks of the trade for practitioners. For more in-depth understanding of deep networks there are way too many articles to cite so I will only refer to a few iconic ones in two topics that I particularly enjoy:

Orbits, Groups, Invariants and Manifolds

  * <http://yann.lecun.com/exdb/publis/pdf/simard-98.pdf> (Transformation Invariance in Pattern Recognition, Tangent Distance and Tangent Propagation)
  * <https://arxiv.org/pdf/1602.07576.pdf> (Group Equivariant Convolutional Networks)
  * <https://arxiv.org/pdf/1203.1513.pdf> (Invariant Scattering Convolution Networks)
  * <https://ai.stanford.edu/~ang/papers/nips09-MeasuringInvariancesDeepNetworks.pdf> (Measuring Invariances in Deep Networks)

Deep Generative Networks

  * <https://arxiv.org/pdf/1701.00160.pdf> (NIPS 2016 Tutorial:Generative Adversarial Networks)
  * <https://pure.uva.nl/ws/files/17891313/Thesis.pdf> (Variational inference & deep learning)
  * <https://blog.evjang.com/2018/01/nf1.html> (Normalizing Flows Tutorial)
