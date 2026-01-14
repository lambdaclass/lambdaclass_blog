+++
title = "LAM: an actor-model VM for WebAssembly and native"
date = 2021-02-26
slug = "lam-an-actor-model-vm-for-webassembly-and-native"
description = "An interview with its creator, Leandro Ostera"

[extra]
feature_image = "/images/2025/12/Screenshot-2025-12-17-at-10.43.57---AM.png"
authors = ["LambdaClass"]

[taxonomies]
tags = ["Actor Model", "Vm", "Webassembly", "Erlang", "Beam"]
+++

An interview with its creator, Leandro Ostera.

![](/images/max/2000/1-ZA5-hKa-yYGz8FX-kmZh9g.png)Source: [https://abstractmachines.dev/](https://abstractmachines.dev/)

Here, at NAMT, we are in love with the Actor Model.  
Within this paradigm, the basic units of computation are called actors. There is no shared state between them, instead, they interact via message passing. This has the advantage that actors become trivial to paralellize (in Erlang, an actor is called a _process_) and errors became easier to handle.

The actor model is a concurrency paradigm created by Carl Hewitt in 1973 with the goal of making the task of writing concurrent programs simpler. It is based on the idea of actors, entities that can only send, receive and process messages. By reducing the amount of shared state it reduces the need of locks for synchronization. There exists several battle-tested implementations of the Actor Model such as Erlang/OTP, Akka (Scala/Java) and Orleans (C#).

In this interview, we chat with Leandro Ostera, the founder of Abstract Machines. Ostera is working on LAM, The Little Actor Machine, an embeddable virtual machine for the actor model that runs native or compiles to WebAssembly.

_The questions for this interview were thought by Juan Pablo Amoroso, Javier Chatruc & Federico Carrone. Joaquín Centeno and Juan Bono wrote the introduction and edited the article._

* * *

**Tell us a bit about your project lab, Abstract Machines. What kind of work do you do?**

I started Abstract Machines with a single goal in mind: build tools that would help me think more clearly.

Right now what I do think about the most is writing software. I think typed languages help me think clearly, so I’m building Caramel, an OCaml for the BEAM. I also think that understanding the program that runs your programs is fundamental to thinking clearly about the quality of what you build, so I’m building LAM, an actor-model VM.

**LAM’s tagline is “A Little Actor Machine that runs on Native and WebAssembly”. Could you give us a brief overview of the actor system?**

The original name was Leandro’s Abstract Machine. Like Prolog’s WAM was named after Warren, Warren’s Abstract Machine, and the early Erlang VM was JAM after Joe’s Abstract Machine. But Little I think it’s a much better name overall: LAM should be small, tiny even.

The actor system it implements is in spirit very close to Erlang’s take on the actor model — processes with mailboxes, message passing across them, fair scheduling through reduction counting. There’s a few more things in the roadmap, like process linking and monitoring. Overall, if you have worked with Erlang or Elixir before, you should feel right at home with LAM.

**What is the motivation behind LAM? Why build a BEAM alternative?**

LAM’s mission is to make Actor concurrency available everywhere by providing a specified, lightweight runtime. Think LuaVM meets the Actor Model. I’ve always liked the LuaVM, there’s a certain elegance to it that I find very appealing.

One of the reasons to build an alternative is that the BEAM is rather large, and the implementation is the only real spec. [Erik Stenmans’ Beam Book] or [kvavks Beam Wisdoms] have tried to document it, but without an official effort to produce a JVM style spec (like the one you can get in a bookshelf), it’s unlikely we will have a reliable drop-in alternative any time soon.

So I thought I could instead make a new thing that could learn from both the LuaVM and the BEAM. At 35 instructions, LAM can run an interesting amount of Erlang programs, in fact I’d like most code that runs on the BEAM to be bytecode-translatable to run on LAM. Not all of it tho, and we’ll see what doesn’t make the cut.

**One of LAM’s targets is WebAssembly. Is there any alternative actor system for the web? How do they compare with LAM?**

Yes, there are plenty! A most promising one these days is Lunatic, but on the Erlang side of things, there’s the up-and-coming Lumen.

Most of the rest are libraries for building actor applications in other languages, like how Actix lets you use Actors in Rust. Lumen in particular is more of a compiler + runtime that brings Erlang down to LLVM and gives you this single optimized executable.

LAM by contrast is a higher level VM: you feed it bytecode (spawn, send, receive, call, make list, etc), and as it runs it, side-effects happen through FFI/Bindings depending on the platform.

Around LAM there’s a tiny compilation toolchain that takes that bytecode, lowers it to something that can be run a little faster, and packs it _with the VM_ in a single binary that is optimized for a specific platform.

Because the VM is tiny, and the FFIs are pluggable, it’s straightforward to compile it to WebAssembly and run your bytecode there.

**The documentation mentions that one of the goals is to support Erlang/OTP’s supervision tree structure. Would this allow more reliable/resilient web UIs, capable of gracefully recovering from errors?**

Absolutely! I expect it to let you build even more natural and flexible UIs. After all the “event” model fits perfectly: when process Button receives message Click, do this/that.

The main problem is that preemptive scheduling makes it impossible to guarantee certain processes will have enough time to make stuff like animations run smoothly. But I’m borrowing the idea of dirty schedulers and considering introducing Greedy Processes instead, that can either request upfront how much time they need, or just run to completion. Definitely interesting to experiment with hard-real time scheduling as well.

**What are some interesting use cases for LAM?**

Off the top of my head, there’s 2. The first one is perhaps why I want it the most these days: fast cli tools. Write ’em in Erlang/Elixir/Caramel, ships as a single binary.

The second one will have the largest impact on how we build for the BEAM: actually writing full-stack applications in a single BEAM Language.

Write your backend in Elixir and run it on the BEAM, write your frontend in Elixir too but run it on LAM. And it doesn’t have to be a web-based app, it could be an actual native GUI application too.

**Why write it in Rust? Is the Rust-WASM toolchain mature enough to target WASM reliably with LAM?**

I love Rust. It’s a good language and the learning curve has certainly taught me a lot about how to build software. I think the Rust-wasm toolchain is pretty mature these days too.

**Besides performance (LAM compiles AOT), what will be the advantages of LAM over the BEAM?**

Really the AOT stuff I can’t consider an advantage — I don’t expect LAM to be fundamentally faster than the BEAM, especially after the BeamJIT work. Nor do I expect it to compete in speed with Lumen.

What I see as an advantage is that LAM is being built to have a Specification and to be Embeddable.

**WebAssembly lacks a garbage collector and the BEAM is a GC environment. How does LAM tackle this?**

There is a wasm-gc spec in the works, and some other folks are waiting on it as well (like the OCaml-wasm efforts).

But since WebAssembly isn’t the only LAM target, we’ll have to embed a GC anyway. I expect it to work very closely to the BEAMs (per process collections, ref counted binary strings, etc). I haven’t looked so deeply into this, but I have a chunky book waiting for me (The Garbage Collection Handbook).

**Is this a solo project or are you looking for contributors? If you are looking for contributors, how should they get started (first issues, roadmap, etc)?**

So far it is just me, but I’d love to build a friendly and welcoming community around it. At the moment I’ve been focused on getting this vertical slice of the project up and running so it becomes easier to do some horizontal scoping: how far along are we with the specification, or how much of the BEAM bytecode can we support via translation.

There’s tons of work to do starting at the design level. From figuring out how to build the right layers to FFIs across platforms (native, wasi, web), to how to optimize the main emulator loop to crunch the bytecode as fast as possible, to GC and bundling the final binaries, to writing the spec and the manual.

Formalizing the spec is a big topic where I hope I can get some interest from the TLA+ community to guide me into doing justice to both TLA+ and LAM.

LAM could use help across the board, so if you’re reading this please tweet at me ([@leostera](https://twitter.com/leostera/))!

**For our last question, in general, what are your favorite books, articles or resources for programmers?**

I think that if you asked me this a year ago I would have regurgitated a bunch of books that I should list here, but that didn’t really further my understanding. There’s a lot of reference material that is just terrible for learning, because its meant to be a compendium of information rather than a pedagogically written introduction to a subject.

For example, Types and Programming Languages by Benjamin Pierce is deemed _the ultimate_ reference for type stuff. But I learned more about the nature of typing by reading The Little Typer. After that it was a lot easier to get into the right headspace to understand what Pierce wanted me to get out of the book.

So if you’re getting into a subject, don’t rush for the ultimate reference, and find something written to teach you _the core_ of the subject. Then the rest becomes a little easier.

Virtual Machines by Iain D. Craig, and Formal Development of a Network-Centric RTOS have been very useful in working with LAM. Hillel Wayne’s Practical TLA+, and Alloy’s Software Abstraction books have been really good to get a better grip on how to specify systems as well. Of course [“Specifying Systems” by Lamport](http://lamport.azurewebsites.net/tla/book.html) has been a good reference as well.

Some books that have had a massive impact in how I think and communicate have (unsurprisingly) nothing to do with computers. Like Umberto Eco’s “6 Walks in the Fictional Woods” (focused on how to create narratives and rhetoric) or Mandelbrot’s “The (Mis)Behavior of Markets” (a historical account of how fractal geometry describes better the financial markets). Nonetheless, they’ve helped shape the way I think and I’ve come out a better programmer.

![](/images/max/2000/0-nPPWbd4-7dJavk5P.gif)
