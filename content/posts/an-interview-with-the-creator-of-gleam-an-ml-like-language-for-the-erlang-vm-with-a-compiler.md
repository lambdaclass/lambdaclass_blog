+++
title = "An interview with the creator of Gleam: an ML like language for the Erlang VM with a compiler…"
date = 2019-04-01
slug = "an-interview-with-the-creator-of-gleam-an-ml-like-language-for-the-erlang-vm-with-a-compiler"
description = "I have been writting soft real time systems with Erlang for almost a decade and for that task I think it is the best tool we have around…"

[extra]
feature_image = "/content/images/2025/12/Leo_Tolstoy02.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["Erlang", "Rust", "Programming Languages"]
+++

### An interview with the creator of Gleam: an ML like language for the Erlang VM with a compiler written in Rust

![](/content/images/max/2000/1-ivv-xih7D4rulPdRNmSYkg.png)

I have been writting soft real time systems with Erlang for almost a decade and for that task I think it is the best tool we have around. The concurrency model, the preemptive scheduler, the GC, the profiling tools, the libraries and the community are excellent for the task. Distribution libraries like [Lasp](https://lasp-lang.readme.io/docs) or distributed systems frameworks like [Riak Core](https://github.com/lambdaclass/riak_core_tutorial) are not easily available in other languages. At last, cheap processes, non shared state, supervisors and the let it crash philosophy are great tools when you are writing backends. Instead of trying to catch all the errors at compile time, you accept that it is impossible to catch all the possible problems and you deal with that reality. It is a very different error handling model from what you can find in Haskell or OCaml.

However Erlang language is pretty simple. I always miss sum types when I am coding in Erlang. I miss ML’s type system expressiveness, safety and practicality. That is why I am interested in the development of Gleam, a statically typed functional programming language for the BEAM.

Another interesting thing about Gleam is that its compiler is written in Rust. I think that Rust is a sort of ML + C language. I like C since the developer is at the driver seat driving with manual transmission. I can’t explain very well but I have always seen C as a simple and powerful language but I have always disliked C++. Knowing that I like ML and C you might understand why I find Rust an interesting language.

To sum up we (me and [Juan Bono](https://twitter.com/JuanBono)) decided to do this interview with [Louis Pilfold](https://twitter.com/louispilfold) not only because of what it is, but also because it is implemented in Rust. Go ahead and check [Gleam’s repo](https://github.com/lpil/gleam)!

![](/content/images/max/2000/1-x_OU1YRmBR8037eqsSAfYA.png)

* * *

**Tell us a little about yourself. Have you been working on programming languages for long?**

Professionally I’m a web programmer, but over the last 4 years my hobby projects have largely been compilers in one form or another. Two of the most popular ones have been Dogma (an Elixir to angry error message compiler) and exfmt (an Elixir to slightly prettier Elixir formatter). For the last year I’ve been focusing on Gleam, which is an ML inspired statically typed language for the Erlang ecosystem.

**What was the first programming language you learned?**

The first language I attempted to learn was C, though with no experience and nothing but a few youtube videos I didn’t make much progress. After that I discovered an online version of MIT’s introduction to computer science and worked my way through that, so Python was the first program I successfully learnt. After finishing the course I discovered Ruby, which became my day-to-day language and my introduction to the world of web dev and professional programming, and then Haskell, which really shaped how I think about solving problems with code.

**Why do you think that the ML languages are a good fit for the BEAM VM?**

Both families share the same lambda calculus core, and once you’ve discarded the various bells and whistles of the individual languages (such as processes, type classes, module functors, etc) they all have strikingly similar semantics. Given these shared semantics I think we can take the much loved type systems of ML languages and the proven value of the BEAM VM to create a language that has the best of both, or at least lots of fun :)

**How does Gleam compare to the other ML-like initiatives targeting the Erlang VM? (Alpaca, Elchemy, etc). What are the main differences and what motivated you to create Gleam?**

I think Gleam has a subtly different outlook to the other projects, it is more focused on using the learnings of ML to enhance the BEAM rather than creating an actual ML language. This thinking has resulted in some design differences such as simple interop in both directions, no auto-currying, no effects system, curly brace based syntax, and an Erlang style module system.

I’m very glad that there are multiple projects working in this area. If Gleam fails and one of the other projects manages to build a healthy community then I’ll still be happy, I just want at one to succeed so I can use it in the real world.

**Do you compile Gleam directly to BEAM bytecode?**

The Gleam compiler has had a few full rewrites. The previous version compiled to BEAM bytecode via Core Erlang, which is an intermediate representation with the Erlang compiler, but the current version compiles to regular Erlang source code that has been pretty-printed. This has a few nice advantages such as providing an escape hatch for people who no longer wish to use Gleam, and enabling Erlang/Elixir/etc projects to use libraries written in Gleam without having to install the Gleam compiler.

**What kind of type system Gleam uses? (Hindley-Milner?)**

Gleam uses a Hindley-Milner type system with a fairly standard implementation of Algorithm W. One slightly unusual addition is that row types are used to represent both records (which are Erlang maps) and modules, making them polymorphic in a way that I believe fits the way we use maps and modules in Erlang/Elixir.

**Does the static typing provide any run-time guarantees beyond the compilation checks?**

At runtime all types have been erased and there are no run-time checks. This is nice for performance and makes calling Gleam from Erlang easier, but it means there’s no way of automatically handling an incorrect type annotation when calling Erlang from Gleam.

If you have an unruly or unreliable Erlang function that you wish to call from Gleam the standard library provides a module for handling dynamically typed data that can be used to handle the return values safely at runtime.

**How does the type system interact with message passing and distribution? How do you handle the message passing features of erlang? Have you given any thought on protocol specification as type checking?**

Currently we don’t have a good solution for typed message passing and such, and development is currently focused on building the more run-of-the-mill parts of the language. Rather than introduce a flawed stop-gap solution that will later need to be replaced I’ve opted not to have first class support for the BEAM’s low level concurrency primitives, so these will have to be used via Erlang FFI.

On the other hand OTP behaviours such as gen_server can be implemented using Gleam’s first class module system, which is enough to start writing OTP applications using Gleam today.

**Why did you choose Rust for implementing the Gleam compiler? (instead of choosing erlang/elixir, etc)**

Gleam started as a few little experiments in Elixir but fairly quickly shifted over to Erlang. In December 2018 I realised I was going to have to refactor the type inference module in a fairly major fashion in order to correct a mistake in the design. The typer was easily the most complex part of the compiler and had accrued a lot of technical debt as I learnt and iterated on the language so I wasn’t feel very confident about the refactoring, especially without a static type system to guide me.

I decided that a full rewrite of the compiler would give me a chance to produce a better application without the mistakes of the first version, and using a statically typed language would enable me to refactor more easily in future. I picked Rust, and after roughly 3 months I had a new compiler with roughly the same features, fewer bugs, and less tech debt. It’s also considerably faster.

**Is Rust a good language for implementing programming languages?**

Yes, I think so. The type system is sophisticated and robust enough to take refactorings that would have bested me in the Erlang version and complete them with relatively little stress and fewer bugs. The tooling, documentation, and libraries are delightful, and the community is exceptionally friendly and helpful.

As a nice little bonus the performance of Rust has improved the user experience somewhat; Compilation is faster and there’s no longer a noticeable lag caused by the Erlang virtual machine booting and loading the various modules.

However it’s certainly not a perfect language for compiler implementation. Rust’s linear type system means it doesn’t need a garbage collector, but it can be a very frustrating experience learning how to write code that type checks, and the resulting code can be quite verbose. I speculate that if I had opted to use OCaml instead the type inference code would be under half the size it currently is.

I’m quite sure that someone with more Rust experience could make a lot of my code more concise and remove unnecessary memory allocations, but what we have today performs well and isn’t too difficult to modify. Overall I’m very happy with the decision to use Rust.

**What kind of features do you plan to add to Gleam in the future (if any)? Were you inspired by a specific language?**

The two main features I’ve been asked about are typed message passing (as you have enquired about above!) and some form of ad-hoc polymorphism like Haskell’s type classes. I don’t think that type classes are a good fit for Gleam, though perhaps something like OCaml’s proposed implicit module system could be worth exploring. Either way it will be a long time before we can start to design and experiment here, there’s plenty to do beforehand.

I’d like to enhance how atoms are represented at type level. Currently we can say “this value is an atom”, but that’s about it. It would be more useful if we could say “this value is the atom ‘ok’ or the atom ‘error’”, or “this function can takes the atom ‘up’ or the atom ‘down’, but no other atom”. This could also be extended to create polymorphic enum variants too, though I’m unsure whether it makes sense to have those as well as Gleam’s existing pre-declared enums.

It could be fun to have some alternative backends for the compiler so that we can compile to Javascript or a native binary, allowing Gleam to be used for cloud functions, command line tools, and other applications to which BEAM is less suited.

A much more mundane feature I’m interested in is record punning, as found in Javascript or Haskell. It would be nice to be able to write this

let {name, score} = player

Instead of

let {name = name, score = score} = player

However that syntax has already been taken by tuples, so something would need to change for us to have this feature.

**What recommendations would you give to someone who wants to start writing their first programming language?**

Write lots of code in your language before writing the compiler! Solve lots of simple problems and compile it in your mind so that you can work out how all the different features would interplay and how it might work under the hood. Writing a compiler takes a lot of time so the more experimentation and learning you can do to build confidence in your language design the better. Changing syntax when you have one file of fake code takes seconds, while with a compiler it may take many hours. Worse still, changing the semantics of your language in your compiler could take days or weeks. It pays to get the design right first.
