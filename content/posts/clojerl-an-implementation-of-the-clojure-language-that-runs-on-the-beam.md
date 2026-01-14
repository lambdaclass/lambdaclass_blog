+++
title = "BEAM all the things! ClojErl, an implementation of Clojure on the Erlang Virtual Machine"
date = 2021-07-15
slug = "clojerl-an-implementation-of-the-clojure-language-that-runs-on-the-beam"
description = "An interview with its creator, Juan Facorro."

[extra]
feature_image = "/content/images/2025/12/Screenshot-2025-12-17-at-10.39.00---AM.png"
authors = ["LambdaClass"]

[taxonomies]
tags = ["Clojure", "Erlang", "Elixir", "Beam", "ClojErl"]
+++

#### **An interview with its creator, Juan Facorro.**

* * *

Our blog has had a long standing interest in novel uses of the BEAM, or Erlang virtual machine, as shown by the many articles we have published on that topic: we talked to Eric Merritt about [languages that run on BEAM](/eric-merritt-erlang-and-distributed-systems-expert-gives-his-views-on-beam-languages-hindley/) from a high-level overview, and went deep on [Gleam](/an-interview-with-the-creator-of-gleam-an-ml-like-language-for-the-erlang-vm-with-a-compiler/) (an ML-like language for the Erlang VM with a compiler written in Rust), [MLFE](/d-day-invasion-with-mlfe-ml-landing-in-the-erlang-world/) (which is short for ML-Flavored Erlang), [Efene](/efene-an-erlang-vm-language-that-embraces-the-python-zen/) (an alternative syntax for Erlang), [using Elixir for videogame backends](/gaming-with-elixir-discovering-new-lands-in-the-beam-realm/), and [Lasp](/lasp-a-little-further-down-the-erlang-rabbithole/) (“a suite of libraries aimed at providing a comprehensive programming system for planetary scale Elixir and Erlang applications”).

We also published a guide to learn [Clojure](/how-to-earn-your-clojure-white-belt/) and an [interview](/a-pythonist-finds-a-new-home-at-clojure-land/) that might persuade you to get into it if you haven't already.

So our readers will understand it was inevitable for us to be interested in Juan Facorro's project, [ClojErl](https://github.com/clojerl/clojerl). And of course, we interviewed him about it. We hope you enjoy it as much as we did.

* * *

#### **Tell us a little about ClojErl, what is it? How did it come about?**

ClojErl is an implementation of the [Clojure](https://clojure.org/) language that runs on the [BEAM](https://en.wikipedia.org/wiki/BEAM_\(Erlang_virtual_machine\)) (the Erlang Virtual Machine).

The project started as a learning and exploratory exercise on language implementation. The idea was born out of the combination of my desire to use Clojure at work, and me starting a new job at [Inaka](https://inaka.github.io/) where I learned to use Erlang (and the BEAM) to build systems.

I found that the concurrency model of the BEAM made sense to me, because it provided a framework and some guarantees that made it simple for me to think about concurrency. This has not been the case for me with other concurrency models.

The BEAM was built to solve a practical problem (i.e. high availability communication switches) and solving for concurrency was a big part of the solution, which also included immutable data structures. These two concepts, concurrency and immutability, are also at the core of Clojure’s design principles, so it seemed like a good idea to try to bring this language to the BEAM.

I'm not sure if I thought about it at the time, but the abstractions on which Clojure is built make using the language a pleasure. The example that I always use is the fact that you can use the **count** core function with almost any data structure (it only needs to implement the **ICounted** protocol). Even though it is possible to define a function like this in Erlang, I think the resulting code would not be idiomatic Erlang and it would be hard both to maintain and to extend to new types. This is not the case with Clojure.

#### **What advantages does the actor model bring over clojure's concurrency model?**

I don't think there are absolute advantages of one model over the other.

Because of the way systems are built on the BEAM and the tools it provides (i.e. lightweight processes, monitors and links), it is very suitable for building resilient systems that (when designed right) can recover from failure. This can arguably be done with any language and platform (e.g. Akka on the JVM), but I think it is simpler and easier to do when using the BEAM.

Other things are harder and end up being more complex when using Erlang, but I have wondered if this is something that is more related to the size of the community and the problems it is solving, than the language itself. The amount of Elixir libraries that have been written to do almost anything would suggest that this is very likely the case.

#### **When would ClojErl be a better choice than regular JVM clojure?**

I would say that whenever you need to build a system that is resilient, degrades gracefully and can recover from failures, and you don't want to spend time on building the mechanism to achieve this from scratch. Using ClojErl will provide a battle-tested platform where all these things are already included in the VM's design and how systems are built on it.

This assumes that you don't need a very purpose-specific library that exists only in Java, or a Clojure library that is a lot of work to port from Clojure(Script) into ClojErl.

It also assumes that there is a library (either in Erlang or maybe other BEAM language) for every one of your needs, which unfortunately is sometimes not the case.

#### **How much impact does losing Java interop have on the language in everyday use?**

There is no impact as far as I can tell, although I'm biased :).

Anything that would necessitate Java interop is either replaced with Erlang interop or an implementation of the set of protocols through which Clojure interacts with the platform (e.g. **IWriter** and **IReader** for I/O).

#### **There are certain Clojure features that are unsupported. Why is that?**

Clojure JVM is implemented on a platform that allows mutability, which is not the case on the BEAM.

[Transient data structures](https://clojure.org/reference/transients) for example, rely on the fact that parts of the underlying representation can be updated in-place. The whole point of their existence is to allow for faster operations without the cost of creating new instances after each modification. This cannot be achieved on the BEAM if we want to use the native immutable data structures.

I have not explored the path of implementing a whole set of data structures through [NIFs](https://erlang.org/doc/tutorial/nif.html) that would maybe make this possible. I'm not convinced this is a good idea though, for a number of reasons. The first one is that it would be a lot of work and we would end up with an implementation that needs to be battle-tested before it can be relied upon. The second is that the cost of calling a NIF is not zero and the result might not even provide significant performance gains. And the third is that it would not be possible to use any of the built-in Erlang functions from the standard library or any of the optimizations for them added to the BEAM.

Another feature that is not implemented for Clojure on the BEAM is [Refs and Transactions](https://clojure.org/reference/refs). This feature is heavily dependent on how the JVM works and it is also not something that is very widely used (as far as I know) in the wild.

ClojErl relies only on the numeric types provided by the platform. This means that things such as ratios, big decimals, and flags about unchecked math are not available. The BEAM is not designed to provide good performance around numerical operations, so if that is your use case you are better off using another set of tools for that purpose.

#### **How good is the interoperability with Erlang? What about Elixir?**

One of the design principles for ClojErl was to make interoperability with the platform as seamless as possible.

A function call to an Erlang function is equivalent to any other Clojure function call: **(module/function arg1 arg2 … argN)**.

Data structures are not equivalent, Clojure's are implemented on top of Erlang's. All Clojure core functions related to data structures (e.g. count, first, map, etc.) work for all of Erlang's though, since the necessary protocols are implemented for them to work. It is possible to write expressions for literal Erlang data structures by using the **#erl** reader macro before a Clojure literal (e.g. **#erl{:a 1}** would be compiled to a literal Erlang map).

As mentioned before ClojErl currently provides only the numerical data types available on the BEAM: integer (unbound) and float (64 bits).

ClojErl strings are Erlang UTF-8 binaries. It is possible to write literal Erlang strings (i.e. lists of integers) by using the #erl reader macro.

Pattern matching is also available in ClojErl when using any of the special forms where bindings are created (i.e. **fn*** , **let*** , **loop*** and **case***).

A ClojErl anonymous function can be used as an argument to any of the Erlang BIFs that expect a function, as long as the ClojErl function doesn't use variadic arity or multiple arities. These two features are specific to Clojure, which means that Erlang code wouldn't know how to correctly call the function in that case.

The story for Elixir is similar to Erlang’s (or any other language on the BEAM). Any function from an Elixir module can be called from ClojErl. Elixir is a little particular in that all its modules have an implicit “**Elixir.** ” prefix added by the compiler to them. There have been some people recently trying this out with some success (see [here](https://twitter.com/marcio_lopes/status/1400256642478903299)).

#### **What was/is the most challenging part of the project?**

The most challenging part was and still is finding ways to reconcile what the BEAM offers with the semantics of the Clojure language. Sometimes the conclusion is that we can't support a feature (e.g. transient collections), other times we need to provide something similar but a little more limited than the original (e.g. vars), and yet other times we add something completely new to the language because we want to have interoperability with platform features (e.g. pattern matching).

Another big challenge has been performance. Some features, when implemented on the JVM, do not translate very well to how the BEAM works (e.g. transducers) which results in a much worse performance (i.e. an order of magnitude slower) than what the JVM offers. The release of OTP 24 saw the inclusion of a JIT compiler, preliminary micro-benchmarking using this release showed a lot of improvement in the run time performance of some expressions. There is still quite a lot of work to be done performance wise (both with time and memory usage) on ClojErl.

#### **Are there currently any interesting use cases for ClojErl?**

If we talk about production environment use cases, the short answer is no. The project is still in beta and there hasn't been (that I know of) any company or individual that has used ClojErl in a production environment.

But there are some use cases that I have found interesting and fun.

One of them is [doodler](https://github.com/clojerl/doodler) which is an implementation of a canvas for creating animations inspired in the [quil](http://quil.info/?example=fireworks) Clojure(Script) project.

Another one is the application behind [try.clojerl.online](http://try.clojerl.online/) which is built in ClojErl. I think I spent more time on the JS client-side console than on the code necessary to have a remote running ClojErl REPL.

#### **Is the project open for contributions? If so, how should people get started?**

Yes, absolutely, 100%!

There are open issues to which I haven’t had time to dedicate myself and anyone that is interested in working on them and any other features or improvements, can reach out through the [GitHub repository](https://github.com/clojerl/clojerl), [Twitter](https://twitter.com/jfacorro) ot the [#ClojErl Slack channel](https://erlanger.slack.com/archives/C7KBUEAMC).

The fastest way to have a working development environment is by using [gitpod.io](https://gitpod.io/), which provides an online IDE for any public project hosted in the major code repositories (e.g. GitHub). Firing up a new environment is as simple as following [this link](https://gitpod.io/#github.com/clojerl/clojerl).

How to navigate code is a little bit more complicated because the documentation around this is lacking. There is some documentation in the [ClojErl.org](https://www.clojerl.org/) page and there are also [API docs for the Erlang modules in hex.pm](https://hexdocs.pm/clojerl/clj_compiler.html). But they provide a limited view and there are some important things that are not included there, therefore until there is more documentation for developing ClojErl I am available for people to reach out with their questions.

Other areas that need some love are tools for developing. The **rebar3_ClojErl** plugin currently provides pretty good support for compiling, testing, building applications and script; and starting up a REPL. The area that is not so great is the editor support for ClojErl. Syntax highlighting is available and simple to get, but it would be an amazing developer experience if [**Erlang-ls**](https://github.com/erlang-ls/erlang_ls) could also parse ClojErl files and help navigate the code both in Erlang and ClojErl.

#### Can I use any library written in Erlang directly in ClojErl?

Yes! ClojErl is “just” an Erlang library, which means you can combine it with any other Erlang library and/or application by using **rebar3** and the dedicated **rebar3_ClojErl** plugin.
