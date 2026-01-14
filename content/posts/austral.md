+++
title = "Interview with Fernando Borretti about Austral - a systems programming language with linear types"
date = 2023-12-24
slug = "austral"
description = "Austral is a new systems programming language. It uses linear types to provide memory safety and capability-secure code, and is designed to be simple enough to be understood by a single person, with a focus on readability, maintainability, and modularity."

[extra]
feature_image = "/images/2025/12/Salvator_Rosa_-_Pythagoras_Emerging_from_the_Underworld_-_Google_Art_Project.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["Programming Languages"]
+++

## Introduction

It has been many moons since we interviewed a language creator, and are very excited to present a few questions to and share the answers from Fernando Borretti, the creator of the [Austral](https://austral-lang.org/) ([Github](https://github.com/austral/austral)) language. As it says on the tin:

> “**Austral**  is a new systems programming language. It uses linear types to provide memory safety and [capability-secure code](https://en.wikipedia.org/wiki/Capability-based_security), and is designed to be simple enough to be understood by a single person, with a focus on readability, maintainability, and modularity.”

Just as Pascal introduced modules, and Lisp garbage collection, to a generation of programmers; Rust introduced using the type system to enforce rules on resource usage _into the mainstream_.

It has sparked a very interesting and ongoing discussion about memory usage, resource handling, and linear type systems which are inspiring many other languages. We ourselves at Lambda hope to present our own take on this in the future.

Without further ado, here is the interview.

**Why did you create Austral? Doesn't Rust solve the same type of problems?**  
  
I think it was Manuel Simoni who said: the most important thing about a programming language is how it makes you feel.

And to many people that sounds like a joke but I take it very seriously. Programming language design is an affective thing. I stopped working with Python because it made me feel like I was always standing atop a house of cards in a strong wind. It made me feel anxious. JavaScript is a lot like that.

There's something akin to the extended phenotype in biology for programming languages: beyond the core language and the standard library you have the "extended language", the tooling, the ecosystem, the community, the culture. And all of those things come together and define your experience of the language. Some languages like OCaml have a lot of technical merit, but the tooling is horrible and the community has no interest in improving, and so you persist in using it for its technical beauty and then inevitably burn out. And the further away from the core language you go, the less control there is (it's hard to socially engineer an entire language community) but there's a lot of things the language creators have control over, like setting the tone of the community, expectations around documentation, the quality of the tooling.

I wanted a language (and an extended language) that I would feel happy using. I wanted a small, simple language. Simple in the sense of Kolmogorov complexity: it fits in your head and there's not reams and reams of edge cases you need to understand it. I wanted a slow-moving, conservative language, in the spirit of Common Lisp, where code bitrots very very slowly and you can confidently write code today knowing it will compile and run in thirty or more years. And I want to build an extended language to support that: high quality tooling and high quality docs to set the tone and create a community where people value quality, taste, and craftsmanship.

Re: Rust, I like Rust a lot. I work with it professionally. The tooling is a joy to use (after years of being tormented by pip and dune and pretty much everything else). And it's infinitely better designed than most other languages you can find. I will even defend async.

But Rust is a very pragmatic language, and the problem with pragmatism is that it never ends*. Pragmatism has no natural stopping point. Rust is already pretty complex and I expect it will continue to grow as people demand more from the language. And the thing about programming languages is you can't really take features off. And this isn't necessarily wrong: I don't think Rust would be as successful if it didn't have a thousand little ergonomic features, and certainly if it didn't have async there'd be a lot less of an impetus to adopt it for building servers.

There's two ways to build a general-purpose language: one is to make it so that it is not specialized to any one thing, and that's the Austral approach; and one is to make it specialized to every one thing. And things tend to evolve towards the latter, because large companies -- the ones whose employees sit on the boards of programming language foundations, and the ones who pay people to work on the compilers and tooling and such -- have very specific needs, and they're always lobbying to have the language solve their specific problem. So languages grow and accumulate all these features because Google needs to reduce global latency by 0.02%.

*Philip K. Dick originally said this of introspection, and he was right.  
  
**Which languages inspired you the most?**

Rust gets a lot of credit because it's the only industrial language to have anything like linear types.

Cyclone, which also inspired Rust, was a research language, a better dialect of C, didn't take off but they published a few papers about it. There were very interesting ideas about region-based memory management there.

Haskell for type classes done right. Haskell 98 type classes in particular are a jewel of good design. Standard ML for its module system. Ada for the syntax, module system, and ideas about security.

**What is a linear type system, why is it useful? What type of software do you think that can be improved by using a linear type system?**

I’ve written a bit about this in different places:

<https://borretti.me/article/type-systems-memory-safety>

<https://borretti.me/article/how-australs-linear-type-checker-works>

<https://borretti.me/article/introducing-austral>

<https://austral-lang.org/linear-types>

Part of me wants to consolidate these into one “definitive” explanation, but another part thinks it’s valuable to have different approaches to the same idea. So I have a number of different elevator pitches:

One way to think about it is linear types let you enforce protocols at compile time. There’s two kinds of values in programming: plain data and protocol handles. The latter are things like sockets, file objects, database handles, IPC channels. In languages with manual memory management they include heap-allocated objects.

These have to conform to a particular protocol, with the right state transitions. No double-free (you can’t free memory twice) and no use-after-free. Linear types allow you to enforce this at compile time. This is the main benefit: you get manual memory management with high performance and without safety footguns.

But you can also make your own protocols for your own types and enforce higher-level API contracts than what a normal type system allows.

Another way to think about it is that linear types make values work like real-world objects. In reality things can only ever be in one place. They move, but can’t be copied. In computers, copying is the primitive operation. Values can be aliased because pointers are unrestricted.

It turns out a lot of the problems with mutation are really problems with aliasing. And when you restrict pointer aliasing through linear types, you get referential transparency with pervasive mutation. You get code that is easy to reason about and very high performance.

As for what kinds of software could be improved: mainly, anything that manually-manages memory or uses external resources that need to respect protocols. That’s the main improvement. But when you start to think about designing APIs with linear types from the ground up, it becomes a lot more general, because a whole lot of APIs can be improved by using linear types to enforce high-level contracts and protocols.

**What are the disadvantages of using a linear type system? Do you think that developer experience or the learning curve are necessarily impacted?**

There are two main disadvantages:

        1. Explicitness and verbosity: you have to call destructors by hand, and a lot more things require destruction (e.g. any string).
        2. Linear types are incompatible with traditional exception handling techniques: <https://borretti.me/article/linear-types-exceptions>

**Your post explaining the linearity checker details the implementation. Some modern languages are exploring implementing their type systems as rule sets in logic inference engines e.g. Datalog. Do you have thoughts on this trend?**

I don't know enough logic programming to implement the type checker in it. There's this Racket tool called Redex which I'm aware of but haven't played with, it basically lets you write typing judgments in Gentzen notation (like PLT papers) but have those judgements type-checked. Which is a vast improvement over writing the type system in LaTeX.

Another thing is that the type system is not too complicated. The goal is to be simple in the C. A. R. Hoare sense of "simple enough that there are obviously no bugs".

**Incremental compilation is also a hot topic today. In your post explaining the design of the Austral compiler you mention that for simplicity it does batch compilation. Have you considered incremental compilation an interesting feature or do you see it as an implementation detail?**

Incremental and separate compilation are a must have in a production compiler but I think you can live without them in the early days, particularly because there's just not that much code written in the language in the first place. You could take the entire ecosystem, 10x it in volume, and still not suffer from slow compile times.

I think this is an area where there's room for improvement relative to other languages like Rust, because in Austral the module is the compilation unit, while in Rust the crate is the compilation unit. In Rust, all the modules that make up a crate are loaded at once, and only then compiled, so you can have e.g. circular dependencies between modules within a crate. The problem is build times are the main complaint people have about Rust, and people have to turn to bad solutions like manually splitting codebases into multiple crates.

**In your introduction to Austral, you mention that type inference is an anti-feature. Can you expand on what led you to this decision?**

I feel that type inference is a science experiment that broke its cage and escaped the lab, to the detriment of many people. As in, it should have remained an academic curiosity.

The fundamental problem is that type inference doesn't know whether the input you give it is correct or a mistake, but it will use it as a constraint in inference anyways. I had this problem in OCaml constantly: I'd make a mistake where in Java I'd get an error message saying "you made a mistake", while in OCaml the compiler would make a best-effort inference, propagating my mistake upwards and sideways and every which way, and then I'd get an incomprehensible type error, sometimes many tens or hundreds of lines removed from the place where I made the actual mistake.Sometimes the only solution to such errors is to start adding type annotations (to function signatures, to variables) to constrain the inference process, and this can take a long time. And then you find the error and it was the most trivial thing, and in a less bigbrained language it would not have happened in the first place.

The next problem is languages that infer too much. Again, in OCaml (and unlike Rust) you can leave the parameters to a function unannotated. You save microseconds of typing, and for the rest of the lifetime of that codebase you will spend multiple minutes trying to figure out what the type of something is. And you can say, well, simply annotate all your function signatures. But that's why languages have to have hard rules: if something is optional, people will take the shortcut and not do it all the time.

So type inference in ML family languages is a failed idea because you end up annotating the types anyways: you have to annotate the types of functions for documentation, and you frequently end up annotating the types of local variables for both readability and to constrain the type inference engine and make the errors easier. It's just this really frustrating, circuitous way of doing what in Java you'd be forced to do in the first place. And I see people using VS Code with an LSP set up to display the types of the variables over the code and think, well, why not just have them written? Then you can read the code outside your dev environment, like in a GitHub diff for example.

I've found that type inference is only useful in a very narrow set of circumstances where type information doesn't flow strictly downwards and annotations would be cumbersome. The best example of this is the `Option` type. If you have this in Rust:

enum Option<T> {  
Some(T),  
None,  
}

Then in the `Some` constructor, there's no need for inference, because type information flows downwards: `Some: T -> Option<T>`. But without type inference the `None` constructor is harder: it doesn't take a value, so in a language without type inference, you have to tell the compiler which type should be used in place of `T`. But a general type inference engine is such a complex piece of machinery for such a narrow use case.

And then there's the performance cost. The more advanced the type system, the more expensive inference becomes . There's also the fact that type inference wastes a lot of academic effort. Academic papers on PLT will introduce a new type system, and then spend pages and pages describing the type reconstruction algorithm. And I'm like, this is the least interesting part of it! Let me annotate things manually and show me what this thing can do to solve real problems!

So in Austral type information flows in one direction only, and variables and everything require annotations everywhere. The cost is you spend unobservable extra milliseconds writing. The gain is the code is instantly more readable and you never again have to deal with weird inference bugs.

**Macros are also mentioned as an anti-feature but in your writings you mention Lisp. Do you consider there are valid use cases in general or in Austral for metaprogramming, and for which kinds of metaprogramming?**

I used to write Common Lisp a lot. And macros work decently well in CL*. One of the things that attracted me to Lisp is that every programmer is a language designer. I used to think that was a very good thing: you can implement language features in a few seconds that Java programmers have been begging for in mailing lists for years. But then I saw what people do with macros and changed my mind.

This is part of a general pattern that when I was younger I wanted expressive power, and I was attracted to Common Lisp because in Common Lisp you can wave your magic wand and change the world. But after 10y of cleaning up people's horrible code I realize what I want are fewer nightmares. Macros make everyone a language designer, and that, I realize, is a very bad thing because most people should not be anywhere near language design. Macros might work in a language that is only used by like, insane PL geniuses who also have great communication skills and write lots of docs, but "this feature can only be used by discerning geniuses with great taste" is not sustainable in the real world.

What do people use macro systems (and related things like Java-style annotations) for? Largely to build nightmares: codebases shot through with magic, where every type has like seven different annotations involving serialization, RPC, SQL mappings and the like. The code you see on the page is not what's running: it's an input to a vast, ill-defined, ad-hoc programming language made up of third-party macros that transforms the code in unpredictable ways. Errors become impossible to trace because nobody can tell you concretely what control flow looks like. Changes to the codebase become unpredictable.

So macros are kind of a bait and switch. The bait is, "it would be nice to have to have a shorthand way to write this common code". The switch is you end up with a codebase nobody can understand.

And the solution is build-time code generation. It's a lot like macros, but you can inspect the generated code, commit it to version control, debug it, and it is cleanly separate from the rest of the code you write.

        * I wrote about why here: <https://borretti.me/article/why-lisp-syntax-works>

**The capability-based security description sounds strikingly similar to OpenBSD’s  `pledge`. Did you take inspiration from them?**

This is one area where I wish I'd kept something like a lab notebook while iterating on the language design. It would be invaluable to be able to go back and see what I was aware of and when, which papers I read and such. I think I was aware of pledge and how it works at the time. I really like the pledge API. Linux and FreeBSD capabilities are hellishly complicated when compared to the bare-bones simplicity of pledge. Austral's capability security is similar to pledge in that in both systems, you start with infinite capabilities, and you can then surrender those capabilities, irreversibly, one at a time. But Austral's system is more granular because it doesn't rely on a hardcoded list of syscalls, but, rather, you get pledge() at the value level, you can pledge individual files and other objects.

**What is the most difficult part of designing a programming a new programming language like Austral?**

I should say building a community, getting people interested, but honestly the most frustrating thing has been writing the compiler.

There's this tension between, on the one hand, you want the simplest, most MVP, most prototype bootstrapping compiler so you can get to the stage where you can write real running programs and actually start playing with the language. That tells you a lot about ergonomics, about possible soundness issues. Because when things are vague and ill-defined they're always great, it's only when you concretize things (by implementing them) that you start to notice the flaws and the tradeoffs.

But if the compiler is too MVP you will have bugs you can't easily figure out, because the error reporting is very poor for example. Compilers are really uniquely hellish to test and debug.

So you're always changing course between "build a simple MVP compiler so I can quickly iterate on it" and "build something with production-grade diagnostics and error reporting".

**Are you planning on building a community or userbase? How do you think you can generate momentum to attract Rust or C programmers to develop with Austral?**

I have a little Discord. I want to do more work to have something more substantial especially around the standard library and build tooling before spending much more effort on marketing. I think a lot of programmers are very tired of language churn and framework churn and library churn, and the idea of a small, simple, conservative, slow-moving language is appealing. Here's a thing you can learn in an afternoon, and the code you write will compile and run thirty years from now, and you won't have to jump ship in horror in a decade.

**Do you think you can reuse existing tooling from other languages (like gdb, or rust-analyzer)? What is the state of the standard library and how do you see it evolving?**

The current compiler spits out C. I don't want that to become a trait of the language ("Austral compiles to C"), since it's just an implementation detail of the compiler. So gdb and valgrind should be usable.

rust-analyzer, I doubt it. It's a huge thing and is essentially the most complex parts of a compiler frontend specifically for Rust.

I think it would be a good idea to write the production compiler with a view towards making it usable also as an LSP.

The standard library is very minimal: simple containers and typeclasses. I see myself making small additions to it. A lot of people hate dependencies but I'm a big believer in lots of small libraries actually, so I like the idea of the standard library being just code that is either "eternal" (e.g. a resizable array type) or pervasive (e.g. date and time) or binding some platform-specific thing (e.g. file I/O).

**Is interoperability with other languages (e.g. FFI) part of the roadmap? How would it interact with linear types and capabilities?**

Interoperability with C is already there. That's the most useful one because the C calling convention is basically the lingua franca of every language.

Some languages advertise e.g. automatic interoperability with C++. That is vastly more effort and I think it's entirely misguided. e.g. the Clasp compiler for Common Lisp was built essentially so the author could access C++ libraries that use templates and such from Common Lisp. It's a tremendous amount of effort when you can simply write a light extern C wrapper around the C++ code you need (in Common Lisp you can even automate much of this). So I'm not too worried about C++ interop. In the future we'll just have an LLM port the entire C++ codebase over no problem.

**What are your future plans for Austral? Do you plan to grow the language and add new features like concurrency primitives?**

Standard library, build system and package manager, better docs. That's the first thing.

I'm procrastinating on concurrency models because I don't know enough about them, and I don't want to prematurely specialize the language to an approach that might not pan out. Go has green threads and goroutines and that hasn't worked out for them, the design gives up a lot of performance. OCaml has green threads now and that seems to be working out for them so far. I think Rust-style async is very unfairly maligned, but it also has practical problems in that, because of the way it interacts with lifetimes, everyone ends up putting all of their shared resources under reference-counted pointers. And so in theory the perf ceiling is very high but in practice people will leave a lot of performance on the table to get code that can be feasibly written and refactored.

So I'm happy to sit back and let the world define itself for me, and when there's a clear and compelling right thing to do, I'll implement it in Austral in the simplest, most orthogonal way possible.

## Conclusion

If you enjoy interviews to programming language creators, you might also enjoy these previous ones:

        * Dec 8, 2014 [https://blog.lambdaclass.com/indie-languages-interview-pixie-and-timothy-baldridge/](/indie-languages-interview-pixie-and-timothy-baldridge/)
        * Aug 26, 2015 [https://blog.lambdaclass.com/interview-with-brian-mckenna-about-roy-purescript-haskell-idris-and-dependent-types/](/interview-with-brian-mckenna-about-roy-purescript-haskell-idris-and-dependent-types/)
        * Aug 28, 2015 [https://blog.lambdaclass.com/interview-with-nenad-rakocevic-about-red-a-rebol-inspired-programming-language/](/interview-with-nenad-rakocevic-about-red-a-rebol-inspired-programming-language/)
        * Nov 27, 2015 [https://blog.lambdaclass.com/efene-an-erlang-vm-language-that-embraces-the-python-zen/](/efene-an-erlang-vm-language-that-embraces-the-python-zen/)
        * Dec 28, 2015 [https://blog.lambdaclass.com/interview-with-jesper-louis-andersen-about-erlang-haskell-ocaml-go-idris-the-jvm-software-and/](/interview-with-jesper-louis-andersen-about-erlang-haskell-ocaml-go-idris-the-jvm-software-and/) Dec 29, 2015 [https://blog.lambdaclass.com/interview-with-jesper-louis-andersen-about-erlang-haskell-ocaml-go-idris-the-jvm-software-and-60901251608c356716f2f92e/](/interview-with-jesper-louis-andersen-about-erlang-haskell-ocaml-go-idris-the-jvm-software-and-60901251608c356716f2f92e/)
        * Feb 29, 2016 [https://blog.lambdaclass.com/interview-with-robert-virding-creator-lisp-flavored-erlang-an-alien-technology-masterpiece/](/interview-with-robert-virding-creator-lisp-flavored-erlang-an-alien-technology-masterpiece/)
        * Feb 12, 2018 [https://blog.lambdaclass.com/interview-with-brad-chamberlain-about-chapel-a-productive-parallel-programming-language/](/interview-with-brad-chamberlain-about-chapel-a-productive-parallel-programming-language/)
        * Apr 1, 2019 [https://blog.lambdaclass.com/an-interview-with-the-creator-of-gleam-an-ml-like-language-for-the-erlang-vm-with-a-compiler/](/an-interview-with-the-creator-of-gleam-an-ml-like-language-for-the-erlang-vm-with-a-compiler/)
