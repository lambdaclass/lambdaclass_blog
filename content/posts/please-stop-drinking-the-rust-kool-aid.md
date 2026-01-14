+++
title = "Please stop drinking the Rust Kool-Aid"
date = 2023-05-24
slug = "please-stop-drinking-the-rust-kool-aid"

[extra]
feature_image = "/images/2025/12/The-Marriage-of-Alexander-the-Great-and-Roxane-of-Bactria.jpg"
authors = ["LambdaClass"]
+++

We've been using Rust since 2014. We're big fans of Rust. This doesn't imply that Rust is the perfect language that solves all your problems. Security vulnerabilities come in a wide array of flavors. Some of them allow a malicious actor to take over a system. Others allow to peek at information they shouldn’t be able to. Smaller ones, but critical too, allow a malicious actor to shut down a service relatively cheaply. This kind of attack is called DoS, a denial of service. Shutdown systems are expensive for real people.It’s even worse if the system shutdowns without external interference.

Some days ago, Péter Szilágyi, team lead at Ethereum, said that the C version of the KZG library crashed on some systems:

[![](/images/2023/05/twitter.png)](https://twitter.com/peter_szilagyi/status/1650608687810068480)

If we want to build safe and robust systems, they need to take into account the possibility of crashes, whether they’re written in C, Rust, Erlang or Java. Rust Language is one of the most used for new performant systems.

Rust introduces a great new concept about memory management and prevents many categories of bugs at compile time. It prevents you from accessing invalid memory positions, a null pointer, double-freeing the memory, or using freed memory.

The concept behind this is excellent: don’t trust the programmer for this memory management when the compiler can do the hard work. The cost to pay here is that it is a bit harder to code.

If you have long-living software, e.g., a web server, a blockchain node, or something like that, a crash means that your system is out of service.  
For example, if you have a node receiving a request from the public, when you crash, you get your node off. That’s a vulnerability of your system.  
Resiliency comes not only from the lone program processing traffic and data, but also from the surrounding system monitoring it and the state and error management within it. They key in this case is what happens when you hace unexpected failures.

## Memory leaks

**Memory leaks** are a subtle bug that is difficult to see and address.

A memory leak occurs when a program manages memory allocations in a way that memory that is no longer needed is not released.

In Rust, it’s hard to have Reference Cycles. You can do that [with and _Rc <T>_ and _RefCell <T>_](https://doc.rust-lang.org/book/ch15-06-reference-cycles.html). Rust does not guarantee the absence of memory leaks, even in safe code. Dealing with Reference Cycles is easy to fall into a leak because neither of the two references is freed.

This situation can be hard to detect by inspecting the source code.

Many other situations can lead to a memory leak, such as functions running in async code (especially when you mix them with threads).

In a long-living program, many memory leaks can lead to a denial of service because the whole system can run out of memory.

## Error handling and panic

Rust has some tools for error handling, encoding the error value in the _Result_ enum. There are no _exceptions_ like in other languages. On the other side, Rust has the concept of panicking.

![](/images/external/kgwvbvw.png)

Panics terminate the running program.

Rust prefers panics before undefined behaviour, which is hard to track and debug.

That being said, a panic in Rust usually occurs when a condition that absolutely must not happen is reached.

Rust book has a section about panicking:  
<https://doc.rust-lang.org/book/ch09-03-to-panic-or-not-to-panic.html#to-panic-or-not-to-panic>

The most obvious (and probably the most used) way of getting a panic is unwrapping a Result when it’s an Err.

Sometimes panics are hidden in harmless operations, like accessing arrays by index with **[ ]** operator (when the index is out of bound) or doing mathematical operations (like diving by zero).

It’s worth mentioning that the std has functions to avoid panics in such operations. For example, the _get()_ accesses an element by index returning an Option value, not panicking.

# Threads safety

While Rust provides “ _Fearless concurrency_ ,” the language doesn’t guarantee there won’t be bugs or security issues derived from concurrency.

**Concurrency** is about scheduling instructions between threads in the CPU (in one or more cores). This scheduling is arbitrary, and we call a scenario to one possible order of execution of those atomic instructions of different threads.

While we have checks that guarantee each thread has access to the data we intend to, and there isn’t some accidental sharing of memory, we can still write code with Deadlocks or Race Conditions.

Rust compiler can’t check (at compile time) that your multi-thread program has a possible deadlock. So Rust doesn’t guarantee your program will not get stuck in a stalemate. In that situation, your program doesn’t progress.

For example, we could have a channel expecting data that never comes, blocking its thread. While this is easy to spot with one thread, if we have multiple threads using multiple channels and shared data with locks, this can be harder to see. In concurrency, this is called **starvation**.

Quoting the Rustonomicon **Rust does not prevent general race conditions.** A typical race condition can occur when you check a system condition and then take action based on that condition. This is called **time-of-check to time-of-use** (TOC/TOU). Due to the interleaving of operations between threads, the state of the condition can change with the execution of another thread. So, the action taken by the first thread is invalid (in other words, you decide with _old information_).

## Macros

Rust has a powerful feature of macros. They can expand the possibilities of the language in some places the functionalities are too restrictive. For example, given that Rust has a strongly typed system, the arguments of a function are fixed in the quantity and its type. With macros, we can have a function-style invocation with a variadic quantity and type of arguments. `println!` is the perfect example of that.

A good characteristic of Rust macros is that they are hygienic. This means that the body of the macro is expanded and executed in the context of the macro itself, without taking extra context of the piece of code where the macro is invoked. This feature prevents dangerous and non-expected behavior that can happen in C programs (and hard to debug), due to the inclusion of other variables.

Having said that, the abuse of macros is harmful. First of all, macros make the compilation time slower. The worst part is that the bad practices about macros can lead to a hard comprehension of the code. In practice, they introduce new “keywords” to the language and a re-definition of some rules. The fact that you can receive multiple types in the same macros can be confusing for the reader of the code.

## Unsafe

`Unsafe` in Rust is the key that opens the door to non-checked memory and variables. One of the strengths of the language is the borrow checker and the restriction about how memory is used. `Unsafe` gives that power but also the responsibility to the programmer.

There are indeed some circumstances where there is no choice. In the case we have Rust code interfacing with C code, given that C is an “unsafe” language (from Rust’s perspective), FFI invocations are _unsafe_.

The use of unsafe makes our code more vulnerable (e.g. accessing a non-checked memory position is always dangerous).  
`Unsafe` blocks must be carefully audited.

## Conclusion

Engineering is not a science. Bugs can still occur even with the best practices in place. However, by using languages like Rust and being mindful of potential vulnerabilities like panic situations and concurrency issues, we can minimize the risks of these bugs causing harm to our systems.

It’s important to remember that we are all human, and mistakes can happen. Still, by working together and communicating any bugs or issues in each other’s code, we can create safer and more robust systems for everyone. So let’s keep collaborating and striving towards better, more secure programming practices.
