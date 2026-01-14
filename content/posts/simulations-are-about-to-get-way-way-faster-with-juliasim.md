+++
title = "Simulations are about to get way, way faster with JuliaSim"
date = 2021-09-02
slug = "simulations-are-about-to-get-way-way-faster-with-juliasim"
description = "JuliaSim is a cloud-based simulation platform built on top of the Julia open source stack, including SciML and ModelingToolkit"

[extra]
feature_image = "/images/2025/12/Screenshot-2025-12-17-at-10.37.29---AM.png"
authors = ["LambdaClass"]

[taxonomies]
tags = ["Julia", "Simulation", "Scientific Computing", "Clojure", "Sciml", "JuliaSim", "Actor Model"]
+++

Today we're excited to bring you a first glance at the result of a major multi-year project by the Julia Computing team.

JuliaSim is a cloud-based simulation platform built on top of the Julia open source stack, including SciML and ModelingToolkit, which we explored in depth [here](/scientific-machine-learning-with-julia-the-sciml-ecosystem/) and [here](/modeling-complexity-with-symbolics-jl-and-modelingtoolkit-jl/), respectively. These were just the base of JuliaSim, which aims to change the way the industry does modeling and simulation with powerful acceleration and integration within a complete ecosystem.

[JuliaSim](https://juliacomputing.com/products/juliasim/)'s first beta will be released in a few months. We interviewed Chris Rackauckas to learn more about the project.

* * *

#### What is JuliaSim? How does it compare to alternatives like Modelica/Dymola?

JuliaSim is a cloud-based platform for accelerated modeling and simulation. Unlike tools like Dymola, it integrates with a large open source community, the Julia programming language and the SciML ecosystem, to enhance its environment with offerings like easy parallelism, automated generation of ML surrogate models, and much more. In [a recent talk at JuliaCon 2021](https://www.youtube.com/watch?v=lNbU5jNp67s) I highlight this community integration as one of its core aspects that gives JuliaSim a competitive advantage in terms of features and performance, since it allows us to contribute to and benefit from the work of many scientists and engineers from across the world.

While JuliaSim has acausal modeling as one of its core features, unlike Modelica-based tools that is just one of its domains. Accelerated simulation of PDEs with neural networks, integrating stochastic simulation into workflows, specific simulation environments for pharmacology and circuit modeling, and much more are all part of the JuliaSim product. We see the future as a place where composability will be necessary to achieve the next level of simulations.

#### Can it integrate with the FMI? Will we be able to use models written in, e.g. Modelica, inside JuliaSim?

Yes, JuliaSim at its release will offer features for integrating with the FMI standard, allowing for FMI imports and FMI exports. This will allow for example the ability to build surrogates of models from Modelica or Simulink platforms, and allow for generating binaries that can integrate back into these platforms.

#### A key aspect of Modelica is its standard library, which includes many of the most common components for modeling. Will there be a similar thing in JuliaSim?

With JuliaSim we are building a standard library which includes similar domains to the Modelica Standard Library, but also includes many other domains related to the customers we have been working with. For example, with JuliaSim one will be able to easily search a database of hundreds of physiological and systems biological models for accelerating workflows in biomedical simulation and drug development. We plan to continually improve this model library and mold it to the needs of our customers.

#### What are surrogate models? What makes them important, especially beyond academic applications?

Surrogate models are an amortization of compute cost to improve simulation workflows. It gives you a way to say "do 100 simulations now, and all of my future simulations are 100x faster". When you mix this with cloud resources you can get a major workflow update: pay for a bit of cloud compute to spawn a bunch of simulations in parallel, but now every time you click the simulate button you do not have to wait 30 minutes to check the result.

When I was in graduate school I noticed that there is a very nonlinear effect of code speed on productivity which I captured in a [blog post](https://www.stochasticlifestyle.com/the-nonlinear-effect-of-code-speed-on-productivity). If you have to wait 30 minutes for a result, that means that instead you'll start it before lunch or before a 1 hour meeting, so the true "time to see simulation results" gets amplified further. 2 hour simulations are something you will start in the morning and check at night. Thus a surrogate changing a long simulation to something that you can analyze in real-time is invaluable to decreasing labor costs because of how simulation time effects the day-to-day life of an engineer.

While in an academic sense we focus on issues like "training the surrogate costs 100 simulations, but we needed 10,000 simulations for to optimize the building design and thus we saved in the end", I do not think this calculus is really the major change that surrogates will bring. Even if it takes 100 simulations to train a surrogate that you use 10 times, if you integrate this will cloud compute to do those all in parallel, then to the user you only have to sit through what is effectively 2 simulations. If that's a two hour simulation time, you've now changed a workflow that takes a full day to something that you set to train in the morning and then after lunch you can interactively fiddle with parameters until your controls are correct. And then any time you revisit in the future, it's ready to be fiddled with again. When you view surrogates in this light, I think you can see why we believe this will be a gamechanger for the everyday engineer.

#### One of the main innovations brought by JuliaSim is the generation of fast and accurate surrogate models that can speedup simulations as much as 500x, even in the presence of stiff models. How is this achieved? What's a CTESN?

A continuous-time echo state network (CTESN) is an implicitly trained machine learning framework for capturing the dynamics of stiff models. These are models with phase transitions, fast transient behavior, and are well-known to be numerically difficult. Across many domains we have shown the CTESN training procedure to be robust due to how it incorporates implicit features of stable differential equation solvers. All that we need to generate it is a chunk of simulations done beforehand, and what results is this really fast object that will predict the simulation behavior at new parameters.

#### How easy is it to compose surrogate models with normal ones in JuliaSim? What are the advantages of this approach?

The CTESN represents the surrogate of a differential equation model as a differential equation model. Because of this representation, it's not different from the other physical components. As long as you train it to cover the right states and observables, it will slot right into where you had the larger model before.

#### Paramount to surrogatization is the ability to check the accuracy of the surrogate model and its performance against the original one. How does JuliaSim tackle this? Are these metrics appropriately exposed to the user?

JuliaSim generates diagnostics of the surrogate training process to signal to the user important features like the projected maximum error over the timeseries over the user-defined parameter space. A lot of this is done through quasi-random sampling right now, though we are investigating more complex techniques to more quickly achieve good estimates.

#### Does JuliaSim run on top of [JuliaHub](https://juliahub.com/lp/) or are they separate things? Is the pricing model expected to be the same?

JuliaSim is JuliaHub-based platform. JuliaSim users receive a subscription to a set of proprietary packages, such as the standard library and the surrogatization tools, which grants access to their use on JuliaHub. The pricing model of JuliaSim is simply the subscription and pay-for-compute, so users only pay for what they use but have access to the full suite.

#### Will there be a GUI for modeling or will we mostly have to write all the Julia code explicitly?

There will be many GUIs! The first GUI that we are building is more pharmaceutical modeling focused given our early customer base and connections with Pumas-AI. This allows for quickly building chemical reaction network and systems pharmacology models, and representing models in a visual form for presentations and reporting. It also will serve as the basis for visual programming of compartmental models in pharmacokinetics. We also will have a GUI at launch which simplifies the FMU surrogatization process, allowing non-Julia users to quickly accelerate their FMUs by entering in parameter information and clicking "surrogatize". We have other GUIs planned for the near future as well, such as GUIs for block diagrams and acausal modeling, along with 3D visualization tools.

#### JuliaSim is launching pretty soon; what can we expect from this first version? What features are next?

JuliaSim's first beta will be launching fairly soon. I wouldn't call it the first version quite yet, though the beta will already be usable as we have been working with a group of customers to showcase the performance advantage for their specific applications. The first release will be a mix of GUIs, cloud parallel surrogatization, and standard libraries. And for the future we are aiming for a lot more. The full vision of JuliaSim is expressed in [the JuliaCon 2021 video](https://www.youtube.com/watch?v=lNbU5jNp67s) so refer to that for more details.
