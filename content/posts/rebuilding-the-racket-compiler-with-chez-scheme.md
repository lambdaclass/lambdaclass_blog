+++
title = "Rebuilding the Racket Compiler with Chez Scheme"
date = 2020-11-26
slug = "rebuilding-the-racket-compiler-with-chez-scheme"
description = "An interview on Racket CS with programmers Gustavo Massaccesi Matthew Flatt"

[extra]
feature_image = "/content/images/2025/12/Screenshot-2025-12-17-at-10.51.21---AM.png"
authors = ["LambdaClass"]

[taxonomies]
tags = ["Chez Scheme", "Lisp", "Racket", "Racket Cs", "C"]
+++

#### An interview on Racket CS with programmers Gustavo Massaccesi Matthew Flatt

![](/content/images/max/2000/1-so5Q8KpDmcaIAKUHU5V9mw.png)Still from a [2018 talk by Matthew Flatt](https://www.youtube.com/watch?v=t09AJUK6IiM), intervened by us

Racket flaunts the title of being _the programmable programming language_. With extensibility at its core, it takes metaprogramming to the next level by encouraging developers to implement their own DSLs to solve the problem at hand.

Following this same principle, its development team attacks the complexity of writing a compiler by stacking layers of DSLs to implement many of its components.

On the other hand, the project had many legacy components written in C that became a development bottleneck, so in 2017, Matthew Flatt made an announcement on a Racket Developers group:

![](/content/images/max/2000/1-oXZFdbH7adA58JPU4Cu2tw.png)[Source](https://groups.google.com/g/racket-dev/c/2BV3ElyfF8Y/m/4RSd3XbECAAJ?pli=1)

Chez is a Scheme implementation which was open sourced by Cisco in 2016. Its performance has no match among other schemes and it has a long history of being used in production.

To learn more about this endeavor, we contacted Gustavo Massaccesi, and Matthew Flatt, who were part of what is now called the **Racket CS** project. In this interview, they explain the background and details of this project.

We're big fans of Matthew Flatt's work and of the Racket endeavor. For further reading we recommend reading Flatt's article [Creating languages in Racket](https://queue.acm.org/detail.cfm?id=2068896), [this book](https://gumroad.com/l/lop-in-racket-cultural-anthro) that interviews 38 Racket programmers, and the book [Beautiful Racket](https://beautifulracket.com/), which Flatt prologued.

* * *

#### **Tell us about Racket. What makes it stand out in the LISP family?**

Let’s distinguish “Racket the language” and “Racket the project”.

The Racket language is a general-purpose, Scheme-like language with an especially rich set of constructs for extending the language — even by Scheme standards. Racket includes support for writing quick-and-dirty macros, but it also supports nice macros with a good error checking that avoid surprising errors created in the expanded code. The close integration of macros and modules, an enforced phase separation between run-time and compile-time code, and the `#lang` mechanism for selecting the surface syntax all distinguish Racket from other Lisp variants.

Even the main language Racket is written in a simpler language, and that is written in an even more simple language. This tower of languages makes development easier. You can look under the hood and see all the internal languages, or just ignore all of them and get a nice high level language.

Less prominent, but also as important in practice for building language abstractions and composing them into large systems, are Racket’s run-time constructs: first-class control with continuation marks, custodians for simple and reliable task termination, reachability-based memory accounting, message-based parallelism via places, and Concurrent ML-style constructs for event-driven programs. Many of these constructs need support at lower levels of the runtime system, but then they can be used to build a wide variety of languages and libraries that mesh well.

The Racket project synthesizes research, production, and education efforts toward the overall language-building goal. The idea of “A Programmable Programming Language” serves along those directions, from building student-friendly learning environments to domain-specific languages in application to pushing the frontiers of language design and implementation.

The main page is <https://racket-lang.org/>

#### **What does it mean that you can write your own language?**

For example, when you install Racket, it comes with 20 or 30 additional languages. (I’m not sure if someone has counted all of them.)

There are a few “Student” languages that are designed for students. They are less powerful but have more compile time checks to detect common errors in beginners. And they have different levels so once you master one, you can use the next one that includes more features.

Another language is Typed Racket, that adds types to the Racket expressions, so it refuses to compile unless the types check. And it also uses the type information to optimize the code, so the compilation is slower, but the generated code can be faster.

There are languages that implement the version of Scheme in R5RS and R6RS and many of the SRFI. And you can install a package that adds the version in the R7RS-small.

And there are also more different languages with a very different syntax like a complete implementation of Algol 60.

All these languages share the same backend and you can call the libraries written in one language from any of the other languages that are included in the distribution, the additional languages you can download as packages, or the languages you create.

**What’s the difference between Racket and Scheme?**

Racket started out as a Scheme implementation, and we would still call it “a Scheme.” Even though it does not fit a Scheme standard, it’s obviously derived from Scheme. There are many specific differences, such as the fact that `cons` always creates an immutable pair in Racket, but the main difference is philosophy: Scheme is meant to be a small language that gives you just enough to express lots of things. Racket is meant to be a big language, and while it gives you the same core pieces (and more) that can express lots of things, it also codifies the way many things are done to enable more cooperating libraries and languages.

#### **What is Chez Scheme, how is it different from other Scheme implementations?**

Chez Scheme is one of the oldest Scheme implementations, and its evolution informed many parts of the Scheme standard through R6RS. (Racket’s influence on the Scheme standard, in contrast, is limited to aspects of the R6RS library design.) Chez Scheme is a relatively small language, but like all instantiations of Scheme, the implementation provides a lot more than the standard specifies.

Chez Scheme’s biggest claim to fame is its performance. It has always been among the best-performing Scheme implementations. Its object-tagging and allocation regime, its hybrid stack–heap implementations of continuations, and its compiler structure all remain state-of-the-art, even in 2020.

For most of its existence, Chez Scheme was a proprietary, closed-source implementation, but it became open source in mid-2016. As it happens, we started considering a new Racket reimplementation around the start of 2017.

#### **Why did you choose Chez Scheme over other Schemes to rebuild Racket?**

The biggest weakness of the Racket BC (“before Chez”) implementation are its back-end compiler structure, its inefficient internal calling conventions (over-adapted to C), and its poor implementation of first-class continuations. Those are exactly the strengths of Chez Scheme. Furthermore, Racket’s evaluation model was always closely aligned with Chez Scheme, such as the emphasis on interactive evaluation and compilation.

It was clear up front that Chez Scheme lacked significant features that Racket needs, such as support for continuation marks and reachability-based memory accounting. However, the high quality of the Chez Scheme design and implementation, in contrast to old Racket’s implementation, made adapting Chez Scheme more appealing than retrofitting Racket’s old implementation further.

#### **Why reimplement with Chez Scheme to reduce the C part instead of implementing the C stuff in Racket?**

Mostly, we did reimplement the C stuff in Racket. The I/O subsystem, the concurrency subsystem (which includes the scheduler for “green” threads, Concurrent ML-style events, and custodians), and the regexp matcher were all rewritten in Racket. Those pieces followed the rewrite of the macro expander in Racket. Other things that needed to be moved out of C, such as the compiler and the extensive support for numbers that Racket inherited from Scheme, were already written in Scheme in Chez Scheme’s implementation.

A big part of the process was to understand what to implement in Racket, what in Chez Scheme, and what new layers to introduce in translation. This work and reorganization benefits other Racket implementation efforts, such as Pycket and RacketScript.

#### **Besides improving maintainability, what are the advantages of building Racket with CS over C?**

With the exception of the garbage collector and similar low-level parts of the runtime system, much of Racket’s implementation benefits from higher-level abstractions. Writing a macro expander in C was a particularly poor choice, since higher-level abstractions obviously make tree manipulations easier, but the same reasons apply for the I/O layer or numeric primitives. Even the garbage collector in [the Racket variant of] Chez Scheme is now half implemented by a specification and compiler that are written in Scheme.

The other big advantage is that the Racket community has a lot of Racket programmers, not C programmers. It’s easier to convince a fan of Racket to look at some code in Racket or Chez Scheme and try to find some bug or a new feature to contribute. The people that like to read and write code in C are probably making contributions to a C compiler.

#### **What were the most challenging parts to implement?**

The most challenging part is not really one part, but the overall scale. Racket is a big language, and it all has to work the same in the new implementation. That means not just getting the right result and/or a specific kind of error message, but getting results with the same or better performance characteristics. For example, if a macro generates a giant expansion that nevertheless compiles in reasonable time in Racket BC, then it needs to compile in reasonable time in Racket CS.

When it comes to specific pieces that we had to implement, perhaps the most challenging were adding type reconstruction to the compiler, adding support for continuation marks, allowing record values to act as procedures, reimplementing Racket’s I/O, and upgrading Chez Scheme’s garbage collector to support memory accounting, in-place marking for large heaps, and parallelism.

#### **What improvements have been made since the paper came out?**

There have been a lot of fixes of small bugs and incompatibilities between Racket BC and Racket CS. Also the performance of Racket CS has improved, and now both variants have a more consistently similar end-to-end performance. The speed of generated code was rarely the problem with Chez Scheme as a backend, but the layers newly implemented in Racket needed lots of tuning. So, the things that used to be faster in BC are now generally about as fast in CS, while things that have been faster in CS are even faster.

One of the most important improvements at the Chez Scheme level is flunum unboxing. Until recently, the floating-point numbers were stored in a box-like object under the hood, so they can be used in a vector or other container that expects a reference to an object. Now, in many cases, the compiler detects that the box is not necessary and skips it. That reduces the number of allocations and increases the speed of programs that use a lot of floating-point numbers.

The other big area of improvement was in the garbage collector. When we started Racket CS, Chez Scheme had an admirably simple collector that performed very well on traditional Scheme programs. But Racket needed a lot more functionality from the collector. We’ve improved support for large heaps, for GUI and game-like situations that benefit from incremental collection, and for programs with parallelism.

#### **Do you know of any uses of Racket on CS outside academia?**

You can download Racket CS from the download page and it is a drop down replacement of the current version of Racket BC. Both the Racket BC and Racket CS include all the libraries and the IDE that is also written in Racket. All the code written in Racket should run without changes in the BC or CS versions, except for some corners of the foreign-function interface.

Gustavo used it in the university to edit an move quiz from a Moodle server to another. The mdz files are like .tar.gz files, so you can use the standard libraries in Racket to uncompress them, edit the xml files that are inside and then repackage the result in a new mdz file. (Does this count as “outside academia”?)

The biggest site that is using Racket is Hacker News <https://news.ycombinator.com,> that is a forum about programming and related topics. It is programmed in their own language called Arc that is programmed in Racket. They have more than 5.5M hits a day and something between 4M and 5M unique visitors a month. They are using the BC version anyway.

There is a list of other sites and organizations that use Racket in <https://github.com/racket/racket/wiki/Organizations-using-Racket>

#### **To target CS, you ended up patching the language to accommodate its differences with Racket, was that the intention from the beginning? What was the biggest difference between the two languages?**

This possibility was considered from the beginning. There are some differences of opinion between Racket and Chez Scheme, so sooner or later some change that is useful for Racket would not be useful in Chez Scheme.

For example, Racket is more strict in checking that a function returns a single value in positions that expect a single value. This is an undefined case in the Scheme standard, so Chez Scheme sometimes ignores it. In the common case that the function actually returns a single value, Chez Scheme may be slightly faster, and in the other cases Racket may report a better error. It’s a design decision, and each team has different preferences. So the version of CS in Racket has some additional checks to track the single return expression and avoid the unnecessary checks when possible.

#### **Is there a use case the VM is optimized for?**

It would be fair to say that the Chez Scheme runtime system is optimized for functional programming. There’s a write barrier on object modifications, for example, and the compiler is happier when variables are not mutated. It would also be fair to say that it’s designed for settings with plenty of memory and computing power, and not more constrained, embedded settings.

#### **What do you hope to improve in the future (i.e. new features, better performance)?**

Gustavo’s contributions in this rewrite has been in a type recovery pass for the patched version of Chez Scheme used in Racket. It reduces the number of run time checks of the types, so the final code is faster. There is still a lot of room to make the translation from Racket to Chez Scheme more optimizer friendly, and the optimization pass more translation friendly, so I expect a gain of performance in this area next year. Also, we can improve the cooperation with the high level parts of Racket that use types, like the contract system and Typed Racket.

Writing the optimizations steps in Chez Scheme opens a lot of possibilities, for example Gustavo wanted to add some escape analysis to use that information to avoid copies, or the creation of temporal struct, and other similar reductions. It was too scary to try that in C, but it looks more possible to write it in Chez Scheme. [Probably in 2022.]

Matthew has run out of immediate tasks, and he is hoping to spend less time at the level of the compiler and runtime system. Now that Racket CS has generally caught up and stabilized, he hopes to go back more to language design via the Rhombus project.

#### **Are there plans to expand Racket? in which areas? Where would you like to see Racket in 5 years?**

The Rhombus project is an experiment at starting fresh with the surface language and library design while preserving all of the language-building constructs, compilation pipeline, and runtime system that we now have in place in Racket. It’s still early — and still earlier than we thought it might be, since Racket CS development continued to dominate our efforts — but if this design succeeds, then we expect that to be the next direction for Racket.

#### **How has the community reception been to Racket CS?**

Initially, some people were afraid of the performance drop for adding a new layer between Racket and the hardware. The initial version was slower, but the current version has a similar speed, and in many benchmarks it’s faster. Most likely, the January release of Racket will be version 8.0 with Racket CS (based on Chez Scheme) as the default implementation.

Other people were worried because the development of the low level part of Racket would be slowed down for some time, while making the new version. Now that the CS version has an almost equivalent performance, so hopefully the increase of the development speed in the CS version will compensate for the delay. Anyway, Racket is a big project so while the CS version was developed other areas had a lot of improvement, like new libraries or a more efficient contract system, and all of these new features are available in both versions.

#### **On a different note, what books would you recommend to a programmer?**

We’d certainly recommend _How to Design Programs_ (<https://htdp.org>). While it’s mainly intended for beginning programmers, it can also provide a crash course in functional programming for programmers who do not already have a lot of experience with it. _Essentials of Programming Languages_ by Dan Friedman and Mitch Wand is a classic for learning about programming languages from the same perspective that informs HtDP.

While it’s not about programming directly, Matthew recommends _Working in Public: The Making and Maintenance of Open Source Software_ by Nadia Eghbal. The book is a lucid reflection on the history and state of open-source software — partly the idea of open source, but especially how that idea has played out in practice.

Gustavo wants to recommend _Gödel, Escher, Bach: an Eternal Golden Braid_. It is not related to Racket, but it has a few nice discussions about the transforming formulas/code to numbers/data, that is one of the main ideas behind the macros in the LISP family.
