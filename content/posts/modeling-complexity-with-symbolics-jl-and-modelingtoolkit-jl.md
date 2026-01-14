+++
title = "Modeling complexity with Symbolics.jl and ModelingToolkit.jl"
date = 2021-03-18
slug = "modeling-complexity-with-symbolics-jl-and-modelingtoolkit-jl"
description = "An interview with Chris Rackauckas"

[extra]
feature_image = "/content/images/2025/12/Screenshot-2025-12-17-at-10.40.17---AM.png"
authors = ["LambdaClass"]

[taxonomies]
tags = ["Julia", "Programming", "Simulation", "Symbolic Programming", "Data Science"]
+++

#### An interview with Chris Rackauckas

![](/content/images/max/2000/1-sHzrVkhNvHxdiJ2IBmfVPA.png)

As we often mentioned on Not a Monad Tutorial, the world is complex, and we increasingly understand where our tools fall short when trying to model this complexity.

We’ve previously interviewed Chris Rackauckas on [SciML](https://notamonadtutorial.com/scientific-machine-learning-with-julia-the-sciml-ecosystem-b22802951c8a); this time he joins us to answer questions regarding new developments in the area of symbolic computation with Julia, its relation to numerical computing, causal vs acausal approaches, how these matters are represented in Symbolics.jl and ModelingToolkit.jl, and how these packages relate to the existing simulation tooling landscape.

These packages compose easily and thus allow modelling larger, more complex systems by reusing parts, as well as helping community efforts. Having these interoperable packages is key to building a modern simulation software stack which can address the aforementioned needs of complex modelling.

* * *

#### What is Symbolics.jl? What are the motivations behind the creation of the system?

[Symbolics.jl](https://github.com/JuliaSymbolics/Symbolics.jl) is a Computer Algebra System (CAS) in the Julia programming language developed by the [JuliaSymbolics Organization](https://juliasymbolics.org/). Think symbolic computation: write down equations and ask the computer to come up with symbolic solutions. It’s a modern CAS, meaning it’s built on a widely used modern programming language (Julia), making use of modern tooling like pervasive parallelism, new algorithms like E-Graphs, integration with machine learning, and more.

#### What is ModelingToolkit.jl? What are the needs it addresses?

[ModelingToolkit.jl](https://github.com/SciML/ModelingToolkit.jl) is an equation-based acausal modeling system. It’s similar to systems like Modelica which allow for composing models to quickly generate realistic simulations. This lets you take pre-built models created by other scientists and build complete systems. For example, you can take a high fidelity model of an air conditioning, then make a model of a building, and stick the air conditioning into the building and ask what kind of energy efficiency you get. Then change the building to start designing what’s most efficient.

#### How does acausal modeling relate to tools like Simulink?

Simulink is a causal modeling tool. You have to know “what causes what” in order to develop the simulation. This can be difficult in our complex world: the heat of the building is read by the thermostat which turns the AC on which then changes the heat of the building. Feedbacks and “algebraic loops” cause issues in causal modeling systems: users have to break the loops or change the model. For this reason [experts consider causal modeling as not suitable for complex simulations](https://arxiv.org/abs/1909.00484) as they do not compose well. This is the reason acausal tools like Modelica have seen a lot of adoption. Even MATLAB has an acausal tool now, SimScape. Given the advancements in these techniques, I see the next generation of engineers all using acausal tools, with ModelingToolkit.jl being one of the only fully-featured free and open-source acausal systems.

#### Why is symbolic computation needed at all? What are the advantages compared to numerical computation? When is one preferred to the other?

Are you sure you know enough mathematics to have written the mathematical model in the most numerically-stable form? Even if you know all of the tricks that you’re supposed to do, do you want to do it all by hand? I see the main use of symbolic computation in symbolic-numerics, i.e. using symbolic techniques to improve the models which are then used in numerical methods. For example, in a recent blog post titled [Generalizing Automatic Differentiation to Automatic Sparsity, Uncertainty, Stability, and Parallelism](https://www.stochasticlifestyle.com/generalizing-automatic-differentiation-to-automatic-sparsity-uncertainty-stability-and-parallelism/), I describe how a two-dimensional pendulum simulation without the small angle approximation requires a differential-algebraic equation. The intuitive model of “position moves by velocity, velocity moves by acceleration, and length is constant” is actually an unstable description of the full pendulum. You have to differentiate the “length is constant” equation twice, then substitute other relationships, and then you arrive at an “index-1” DAE which is easier to numerically solve. Even if you know enough of these details to do it, you don’t want to handle that! Symbolic-numeric computation is how we will get to a future where that is all automated.

#### Wolfram Mathematica and SymPy in Python are some of the most popular choices when dealing with symbolic manipulation nowadays. What are the advantages Symbolics.jl offers in comparison to them?

Symbolics.jl is being built from the ground up for speed, being built from the ground up with parallelism, and last but not least, it’s being built up from a community of tools. There is so much good stuff out there that I think it would be unreasonable to silo one’s organization off and do everything from scratch. Julia has many great initiatives like [OSCAR.jl](https://www.computeralgebra.de/sfb/) which are building fast implementations of the mathematical guts. We are using the fact that Julia is a high performance language to both develop high level interfaces and ensure that all of these tools can be used with minimal overhead, mental and computational. So while you might know nothing about Galois fields, there might be a fancy algorithm underneath the hood when you call factorize(x² + 2x + 1) that does it efficiently and scales to large systems.

#### How is ModelingToolkit.jl related to Symbolics.jl? What role does Julia’s composability play in the relationship between the two packages?

Acausal modeling requires symbolic transformations of equations. In that pendulum example, “differentiate the equation twice and substitute”, what kind of tool provides features like differentiation and high performance equation rewriting (i.e. substitution)? A CAS! So ModelingToolkit.jl let’s someone say “this is an ODE”, where it’s equations are described by Symbolics.jl expressions. There are then functions that do things like “transform this to index-1 form” and “analytically discover which equations are redundant and delete them”, and those transformations are written using the tools of Symbolics.jl. This means that as the CAS grows more powerful, so will ModelingToolkit.jl and its environment.

#### How does ModelingToolkit.jl compare to other modeling frameworks such as Modelica and Simulink? How easily would a person with some background on these frameworks adapt to ModelingToolkit.jl?

ModelingToolkit.jl’s focus at this point has mainly been on flexibility and speed. In terms of flexibility, ModelingToolkit.jl is the only one which has a hackable compiler that allows composing transformations. All of the symbolic enhancements that are allowed in the Modelica and Simulink compilers are those that are built-in. While it sounds like that’s all that most users need, what that really does is stifle innovation. There are people working in these fields that need a common framework to build off of. Many of these researchers are now in Julia. So for example, could we add an analysis pass that automatically tells you whether you can distinguish between parameters with the data you have? Yes, anyone could extend the ModelingToolkit.jl system with a pass that does that, [and we’re already talking with authors of Julia libraries about doing this](https://github.com/alexeyovchinnikov/SIAN-Julia). There is so much going on in this space that it’s hard to express, but expect tons of unique transformations to be allowed on your models. “Make a model that doesn’t solve in other systems solve here” is not just a dream.

And then there’s speed. We haven’t done complete and comprehensive benchmarking against all of the systems yet, but we have seen [some good performance against some Modelica compilers](https://arxiv.org/abs/2103.05244), indicating we’re doing really well. One NASA user of ModelingToolkit.jl said [a 15 minute Simulink simulation took 50ms in ModelingToolkit.jl](https://youtu.be/tQpqsmwlfY0). A user mentioned at the [AAS/AIAA Space Flight Mechanics meeting that every case against a Fortran package with a MATLAB interface, they saw at least an order of magnitude acceleration by moving to ModelingToolkit.jl](https://youtu.be/FMVOUvWNlLE). In a very early version of ModelingToolkit.jl, we did a demo with Pfizer where we [demonstrated a 175x acceleration over their original C-based simulations](https://juliacomputing.com/case-studies/pfizer/). Part of all of this is just due to the solvers, [which benchmark really well in a cross-language way](https://benchmarks.sciml.ai/html/MultiLanguage/wrapper_packages.html). Another good chunk is due to the feature sets of the solvers, and ModelingToolkit.jl automatically enabling some of the best choices of combinations. This is explored a bit in a talk at JuliaCon 2020 titled [Auto-Optimization and Parallelism in DifferentialEquations.jl](https://www.youtube.com/watch?v=UNkXNZZ3hSw), which was the video that announced the release of ModelingToolkit.jl as a new front end to the solvers for further improving speed.

That said, we have focused so far on the details. We want the biggest hardest models with the users who have the most demands. These other tools have put a lot more time into user interface, specifically graphical user interfaces (GUIs). Modelica and Simulink has a lot of tooling for drag-and-drop model building. Also, they have libraries of premade libraries. But, this will change very soon. Keep your eyes peeled for some announcements.

#### What are the main challenges to solve in order to build such a high level modeling library?

You want to make the modeling language be expressive enough so that every detail you can mathematically specialize on and optimize for is there, but you want to make it easy for users to actually use. Striking that balance is difficult. ModelingToolkit.jl has around 4 years in various prototype forms going through and breaking designs until we found one that could actually solve the problem to the level we hoped.

#### How is Julia code generated from symbolic expressions?

The symbolic expressions use the same exact pieces under different symantics. For example, square roots in the model are `sqrt` in Symbolics.jl and `sqrt` in Julia. This means all we have to do is take the symbolic expression and write it into a Julia function, and invoke the compiler. Invoking compilation on the fly as part of a symbolic language is an interesting challenge though, something that a tool like SymPy skips but which reduces speed by orders of magnitude. The specific details of this are pretty esoteric so I will spare you, but to make this all work we created a new hook into the Julia compiler called [RuntimeGeneratedFunctions](https://github.com/SciML/RuntimeGeneratedFunctions.jl) which allow for staged compilation that composes with garbage collection, making generated code safe.

#### What are the mechanisms that allow easy model composition with ModelingToolkit.jl?

It’s the acasual modeling. You can develop pieces in isolation and just declare relationships between the components. For example, build a model of a power generator, and a model of a computer chip. Now you want to connect these two completely different models? Physically, a wire would connect them and then Kirchoff’s laws would have to hold, i.e. the voltages would have to be equal at the connection points and the currents would sum to zero. So in ModelingToolkit.jl that’s what you’d do: you’d say “current from generator + current to chip = 0” and “voltage at generator = voltage at chip” and bingo you’re there. Now this might produce some redundant variables and equations, but it’s okay: the symbolic preprocessing system eliminates all of this and simplifies down to the most efficient problem to simulate. Then at the end, you can ask “give me the timeseries of the voltage at the chip” and it will give you it, regardless if it was actually in the simulation of not, because it has the information to reconstruct these values.

ModelingToolkit.jl goes one step further. There are `connect` statements which let you define a common behavior. For example, a `Pin` in an electrical circuit always has a voltage and a current, and those laws from above are how “connections” physically work. So at this higher level you can say “connect the pin of the generator to the pin of the circuit”, and it generates all of the physical relationships associated with that statement. There are many prebuilt systems which are coming very soon (likely to be completed before these responses are public!), so heat flow, enthalpy relationships, etc. are all simple `connect` statements. The connection mechanism is extendable too, so if you have a common meaning in say pharmacological models which differs, you can create a new variable type and make connections automatically enforce the laws you want. Connect the heart to the kidney means blood flow is conserved but oxygen is not. This makes it easy to specialize the systems to each of the specific scientific domains.

#### What are the advantages of symbolic preprocessing of models?

From the previous statement, note that simple modeling requires the ability to build things in isolation, and then just say “a=b”. Numerically simulating with “a=b” is rather difficult though, numerical methods really want to not solve equations exactly. But if the current at one side is 10^(-8) higher than the other, you lose conservation of current, and you can have the power of the system steadily rising until it spirals out of control and the simulation crashes. This is actually a very common behavior in causal modeling systems. But if you eliminate the variable “b” and replace it with “a” in every place where it shows up, and then if the user asks for “b” you give them “a”, now you’ve symbolically enforced equality and you will never have a numerical issue due to that effect. So not only does it make the set of equations you have to solve smaller (making the solving process faster), but it also makes the numerical solving a lot more stable and more likely to succeed.

#### Who are ModelingToolkit.jl and Symbolics.jl aimed to? Beyond academia, do you consider people in the industry might find them useful?

Symbolics.jl is more academically focused. People doing symbolic computer algebra are everywhere, but I tend to see more in academia. Physicists, computational biologists, etc. Because Symbolics.jl allows for translating back and forth between Julia code and symbolic code automatically, we’re seeing computer scientists even adopt it as a nice and easy way to analyze code.

ModelingToolkit.jl on the other hand is more focused towards engineers and modelers. Mechanical engineers, robotics experts, building designers, synthetic biologists. These people are found commonly in both academia and industry. We’re getting a lot of praise from industry users of ModelingToolkit.jl already, so it’s likely to find a nice foothold there.

#### How many people are involved in the projects? What are their backgrounds?

There are far too many involved, so I’m just going to give a shoutout to the top few. Yingbo Ma is a super star, still an undergrad but a major contributor to both SciML (the differential equation solvers and ModelingToolkit.jl) and JuliaSymbolics. Shashi Gowda is a PhD student at MIT who has been driving a lot of the internals of JuliaSymbolics. Then there have been many contributions by NASA folks, high schoolers, professors in math departments and biology departments, pandemic researchers, etc. It’s still very early on in the project but the community around it is already great.

#### What are the next steps for each project?

We’re going to have a major announcement very soon, so stay tuned.
