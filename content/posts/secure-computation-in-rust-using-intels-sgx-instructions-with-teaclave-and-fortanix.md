+++
title = "Secure computation in Rust: Using Intel's SGX instructions with Teaclave and Fortanix"
date = 2022-05-05
slug = "secure-computation-in-rust-using-intels-sgx-instructions-with-teaclave-and-fortanix"
description = "TEEs can be thought of as processes that are running \"isolated\" from the OS and upper layers in a secure part of the CPU. The idea of this is to help to significantly reduce the attack surface. "

[extra]
feature_image = "/images/2025/12/Queen_Victoria_at_the_Tomb_of_Napoleon-_24_August_1855.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["Rust", "security", "assembly", "cryptography", "sgx"]
+++

If you have been following this blog you should already know that I am a distributed system and Rust zealot.   
I started playing with Rust 2014 since it was implemented in OCaml, a language I love, and because it had green threads similar to the ones of Erlang. At the end of 2014, start of 2015 Rust's runtime system and green-threading model was removed. I continued using Rust because of its great community and its C + ML roots. In addition to this it is a great complement to Erlang since it is has almost opposite semantics, specially in its error handling philosophy.

At the end of 2017 I started working on the crypto space, mostly because I needed the money. I've not been very public about it since I was skeptical of the whole movement. Even if I liked working on the technical problems that appeared on the space I thought that most crypto projects were ponzi-scheme or completely useless for users.

In these years I've met great engineers and technologies that made me believe more in the movement. That is one of the reasons why we started working on the zero knowledge proof space. One of this projects we are working with requires high standards of data security and privacy. For this we need to abstract ourselves from potential OS security vulnerabilities hosted in third party servers.  
The following blog post follows our journey discovering Intel SGX and it's integration in the development of Rust applications.

As you can already guess this is a project full of challenges, from performance ones to potential security issues. So we would like to abstract ourselves from potential OS security vulnerabilities that the host devices might have, more so when you deploy your application in the cloud. So we've been tasked with deploying essential parts of the project in a specific Trusted Execution Environments (or TEEs for short), Intel's SGX.

The following blog post follows our journey discovering Intel SGX and its integration in the development of Rust applications.

_Subscribe to our_[ _newsletter_](/#/portal/signup) _to receive news and updates from Not a Monad Tutorial delivered directly to your inbox._

## Introduction

Imagine you are building a piece of software which handles sensitive information. And that you decided to deploy your application in the cloud.

Since our project handles private keys used to access transactions and e-wallets, we need to ensure enhanced confidentiality and integrity, even in the presence of privileged malware at the OS, BIOS, VMM, or SMM layers.

### TEEs

TEEs can be thought of as processes that are running "isolated" from the OS and upper layers in a secure part of the CPU. The idea of this is to help to significantly reduce the attack surface. TEEs aim to ensure a subset of data integrity, code integrity and data privacy, which fits our sensitive data manipulation needs. Each CPU vendor has their own implementation, some of which are:

  * Intel SGX
  * ARM TrustZone
  * AMD Secure Encrypted Virtualization
  * ZAYA TEE for RiscV

From now on we'll be focusing on Intel SGX.

### Intel SGX

SGX is an Intel ISA extension with TEEs support. The environments are called **enclaves**.

Some important aspects:

  * **It's not possible to read nor write the enclave's memory space from outside the enclave** , regardless of the privilege level and CPU mode.
  * In production, it's not possible to debug enclaves by software nor hardware.
  * Entering the enclave via function calls, jumps or stack/register manipulation is not possible. To do so you have to use a specific CPU instruction which also does some safety checks ([E]call, [O]call).
  * **Enclave's memory is encrypted** , and the key used changes on every power cycle. It's stored within the CPU and is not accessible.

![](https://i.imgur.com/Lb332Bp.png)Source: Microsoft Azure Confidential Computing [Documentation](https://docs.microsoft.com/en-us/azure/confidential-computing/confidential-computing-enclaves)

**Warning** : if you are considering developing an SGX application, we'd highly suggest [checking your CPU](https://github.com/ayeks/SGX-hardware#desktop-cpus-affected-by-the-product-change-notification-from-2015) and whether it has SGX support. Intel's C++ SDK has some simulation capabilities (as we'll see later), but those aren't fully fleshed out. We managed to run in a Macbook Pro some sample projects using Teclave's simulation mode... but at what cost? So, only if you like stepping on Legos for fun try running SGX in your M1.

![](https://i.imgur.com/hqeSchG.png)

## SGX Rust Development

The Intel SGX's SDK is implemented on C++, so usually you'll implement your application using C/C++ and their [toolkit](https://www.intel.com/content/www/us/en/developer/tools/software-guard-extensions/get-started.html).  
As a starting point Intel gives a [couple of code examples](https://github.com/intel/linux-sgx/tree/master/SampleCode) for different implementations.  
But, are there any developers worth their salt that want to develop a solid blockchain project in those languages when you've got the hip and cool option that is Rust? (in fact, yes) _We don't look forward to that._

![](https://i.imgur.com/Whhj2XE.png) Recreation of what the Rust SDK developers may have thought

Since our source code is already written in Rust we looked for crates that allow us an easy and seamless integration of our code with the SGX enclaves.  
We found 2 alternatives for this, which use different approaches. Both are open source:

  * Teaclave SGX SDK
  * Fortanix Enclave Development Platform

## Teaclave

It wraps the Intel SGX's SDK. You can check their [GitHub repo](https://github.com/apache/incubator-teaclave-sgx-sdk).

![](https://i.imgur.com/Bd8I1r5.png)Source: [https://www.trentonsystems.com/blog/what-is-intel-sgx](https://www.trentonsystems.com/blog/what-is-intel-sgx)

With Teaclave SDK you will split your application into two:  
\- Trusted, also called the _enclave_.  
\- Untrusted, called the _app_.

Remember, under the hood you're still using Intel SDK library.

![](https://i.imgur.com/ixchGF6.png)Source: [https://www.infoq.com/presentations/intel-sgx-enclave/](https://www.infoq.com/presentations/intel-sgx-enclave/)

The Untrusted code is in charge of initializing and shutting down the enclave, and you have to define an interface for the app and the enclave to communicate with each other. During compilation, those interfaces get transformed into [E]calls and [O]calls. In the end you would end up with something like this:

![](https://i.imgur.com/rzWrjSw.png)Source: Slide from Yu Ding's [talk](https://www.infoq.com/presentations/intel-sgx-enclave/) at infoq about Intel SGX enclaves on Rust

But as the saying goes, not everything that shines is gold. The enclave will run under `#[no_std]`, so keep in mind that your favorite crates might not be supported. However, the maintainers have been porting and developing a bunch of useful crates to work with and of course you can also port the ones you want as well. Among them there's the `libc`, the `std` (or part of it), synchronization primitives (e.g. `SgxMutex`, `SgxRWLock`) and more. However, there is not support for async Rust yet.

The repo is populated with some sample projects, which are great to start learning how to structure the project works and some conventions you need to follow and it's also where you can take some as templates for your own application.

### Simulation Mode

Since under the hood it uses Intel's SDK, you still need to meet the necessary requirements. However, Intel also has simulation libraries (although those don't have all the features implemented) which might come in handy to test your enclave locally despite not having an Intel processor.  
You also have available a docker image and you can check the details on how to run it [here](https://github.com/apache/incubator-teaclave-sgx-sdk#running-without-intel-sgx-drivers).

## Fortanix EDP

Fortanix EDP is developed by a company named _Fortanix_. From their website we read:

> Fortanix secures sensitive data across public, hybrid, multicloud and private cloud environments, enabling customers to operate even the most sensitive applications in any environment.

They came up with a different solution to running Rust code on Intel enclaves.

![](https://i.imgur.com/M5pt0Zd.png)Source: Fortanix EDP [architecture documentation](https://edp.fortanix.com/docs/concepts/architecture/)

First, instead of building an _app_ and an _enclave_ Fortanix EDP helps you build only the enclave and the way of communicating between the app and the enclave is up to you.

The enclave runner is responsible for initializing and shutting down enclaves and handling via a usercall interface the enclave's needs.

Since it avoids this interfacing between app and enclave, it greatly reduces a lot of bureaucracy regarding project structure and setup. This was one of the benefits considered when [TVM swapped Teaclave for Fortanix](https://github.com/apache/tvm/issues/2887). You can also see from this Fortanix [example crate](https://github.com/fortanix/rust-sgx/tree/master/examples/mpsc-crypto-mining) that only a few lines were added to the `Cargo.toml`, and the rest is a standard pure Rust project.

### Supported crates and std Caveats

Of course most of the time there's going to be a catch. You might sometimes need to create an implementation of a crate for the SGX target. The process is [documented](https://edp.fortanix.com/docs/tasks/dependencies/) as well. Also some crates have been adding SGX support for the `x86_64-fortanix-unknown-sgx` target, such as the [rand](https://github.com/rust-random/rand/pull/680/files) crate.

This project is already a tier 2 target for the Rust compiler (more on [Rust tiers](https://doc.rust-lang.org/nightly/rustc/platform-support.html#tier-2)), and that's great news! It's based on `libstd`, practice which may have its drawbacks since it assumes `time/net/env/thread/process/fs` are implemented. Some of those are still not implemented (`fs` for example) and will throw a runtime panic instead of a compile error, breaking the Rust's philosophy of "if it compiles it works". More info on [Rust std support](https://edp.fortanix.com/docs/concepts/rust-std/) on Fortanix's documentation.

### I/O

The recommended way of handling input/output in the enclave is via byte streams, particularly using [`TcpStream`](https://edp.fortanix.com/docs/concepts/rust-std/#stream-networking) and using TLS (Transport Layer Security is a protocol used to provide secure communications to a network and mostly known for its use on _https_) on top of that is strongly suggested.  
There are primitives for dealing with pointers to user space as well. These primitives use Rust's borrowing and ownership mechanism to avoid data races among other issues, and also prevent creating dangerous Rust references to user memory. Still, using `TcpStream` is preferred.

## An example using both Fortanix and Teaclave

We're going to show a simplified of the hello-world [example](https://github.com/apache/incubator-teaclave-sgx-sdk/tree/master/samplecode/hello-rust) from the Teaclave repo and see how we would do a similar thing using Fortanix's EDP.

We'll be omitting some details, so if you're interested in getting them we suggest that you check out Teaclave's repo.

### Teaclave

The project structure is:

![](https://i.imgur.com/mm0n8rE.png)Example of project structure using Teaclave

Notice that we have the `app/` and the `enclave/` directories. First let's see the app's code:
    
    
    extern {
        fn say_something(eid: sgx_enclave_id_t, retval: *mut sgx_status_t,
                         some_string: *const u8, len: usize) -> sgx_status_t;
    }
    

We define the function that we want to run in the enclave as an external function, notice that we are not using Rust's `String` here, we need to pass the raw parts instead.

You need to initialize the enclave with a `SgxEnclave::create` call before running code on it. Remember to **always initialize** the enclave first.
    
    
    // Initialize the enclave - proceed on success
    let enclave = match init_enclave() {
        Ok(r) => {
            println!("[+] Init Enclave Successful {}!", r.geteid());
            r
        },
        Err(x) => {
            println!("[-] Init Enclave Failed {}!", x.as_str());
            return;
        },
    };
    
    let input_string = String::from("This is a normal world string passed into Enclave!\n");
    let mut retval = sgx_status_t::SGX_SUCCESS;
    

Then we make the `[E]call` into the enclave. This needs to be wrapped with an unsafe block and we need to split the String into its pointer and length.
    
    
    let result = unsafe {
        say_something(enclave.geteid(),
                      &mut retval,
                      input_string.as_ptr() as * const u8,
                      input_string.len())
    };
    

The `[E]call` will return with a `sgx_status_t` we can check against to see if the enclave ran successfully.
    
    
    match result {
        sgx_status_t::SGX_SUCCESS => {},
        _ => {
            println!("[-] ECALL Enclave Failed {}!", result.as_str());
            return;
        }
    }
    println!("[+] say_something success...");
    

You have to destroy the enclave before exiting. From the documentation it reads:

> It is highly recommended that the sgx_destroy_enclave function be called after the application has finished using the enclave to avoid possible deadlocks.
    
    
    enclave.destroy();
    

Now into the enclave's code:

Each `[E]call` should follow the signature `#[no_mangle] pub extern "C" fn func_name(args) -> sgx_status_t`.
    
    
    #[no_mangle]
    pub extern "C" fn say_something(some_string: *const u8, some_len: usize) -> sgx_status_t 
    

Again, we need the unsafe block to call `from_raw_parts` and we get our string slice back.
    
    
    let str_slice = unsafe { slice::from_raw_parts(some_string, some_len) };
    
    // A sample &'static string
    let rust_raw_string = "This is a in-Enclave ";
    
    // Construct a string from &'static string
    let mut hello_string = String::from(rust_raw_string);
    
    // Ocall to normal world for output
    println!("{}", &hello_string);
    
    sgx_status_t::SGX_SUCCESS
    

And there's even more. You need to define the `[E]call/[O]call` interface in the enclave subdirectory in an `Enclave.edl` file.

It would look something like:
    
    
    enclave {
        from "sgx_tstd.edl" import *;
        // you would have other imports here
        
        trusted {
            /* define ECALLs here. */
    
            public sgx_status_t say_something([in, size=len] const uint8_t* some_string, size_t len);
        };
        untrusted {
            /* define OCALLs here. */
        }
    };
    
    

There are even more files we haven't touched yet. But this is enough to show that while Teaclave might give you a lot of control of what's going on, it's not easy and increases the overall complexity of your project.

### Same implementation using Fortanix EDP

As Fortanix's documentation says:

> EDP applications should be thought of as providing a service to other parts of your system. An EDP application might interact with other services which themselves might be EDP applications. The service may be implemented as a gRPC server, an HTTPS server with REST APIs, or any other service protocol.

**Disclaimer** : we haven't been able to get our hands into an Intel SGX capable machine, hence we weren't able to test this example. However, we think this serves as a good illustration example and gives some credit to Teaclave and Intel for the simulation capabilities.

Let's see how can we accomplish our hello world using Fortanix EDP. Our final project looks like this:

![](https://i.imgur.com/8Wh6Nk4.png)Example of a project structure using Fortanix

Let's look at what the `main.rs` has to offer:

We needed to add this two lines to the `.cargo/config` file:
    
    
    [target.x86_64-fortanix-unknown-sgx]
    runner='ftxsgx-runner-cargo'
    

And that's the only setup we needed (besides the Rust code).
    
    
    use std::net::{TcpListener, TcpStream};
    use std::io::Read;
    
    fn main() {
        let listener = TcpListener::bind("127.0.0.1:7878").unwrap();
    
        let (mut stream, _addr) = listener.accept().unwrap();
        let mut message = [0; 128];
        stream.read(&mut message).unwrap();
        println!("new client: {:?}", std::str::from_utf8(&message).unwrap());
    }
    

Pretty much like good ol' Rust code right? In fact, we're able to compile it without the Fortanix runner and have it running.

![](https://i.imgur.com/GPPD8IR.png)

This only constitutes the enclave, but an easy way to test it is by making the TCP request, so it should be enough to run the following command:
    
    
    echo "Hello World!" | nc 127.0.0.1 7878
    

The way this is built means that you could call this from another language as long as you can make the TPC connection.

[_Full code here_](https://github.com/lambdaclass/sgx_with_rust_blog_post)

## Teaclave vs. Fortanix

One significant difference between the two is their size: Teaclave's repo contains ~80K lines of Rust code while Fortanix's one has ~18K lines of code, which is about 4 times less. Some of these could be atributed to the amount of examples Teaclave has in their repo but still that doesn't make up for the whole difference.  
Also, Fortanix is mostly written using Rust code, while Teaclave has another 80K more lines of non Rust code... yikes!

In terms of community activity we ran a comparison of both thru [github-statistics](https://vesoft-inc.github.io/github-statistics/).

![](https://i.imgur.com/bejTcAq.png)Comparison between Fortanix and Teaclave repos stats

Teaclave seems to have more traction based on the amount of stars and forks. Nevertheless, during 2021 there is a clear increase of the activity in the Fortanix's EDP repository. So it seems like Teaclave is more widely used but it's development has stagnated somewhat while Fortanix is taking the lead, a dynamic that has been reinforced since attaining [Rust tier 2 in january on 2019](https://users.rust-lang.org/t/sgx-target-is-now-a-rust-tier-2-platform/24779).

## Weighting pros and cons

### Teaclave

  * ✅ Uses Intel's libs, and they're supposed to be the experts on that.
  * ✅ There are simulation libraries which expand the support a bit.
  * ✅ Already solves connecting the app and the enclave.
  * ✅ There are a few more examples available ([Teaclave SGX SDK repo](https://github.com/apache/incubator-teaclave-sgx-sdk/tree/master/samplecode) and [Rust 101 repo](https://github.com/glassonion1/rust-101/tree/main/sgx-sdk)).
  * ❌ Uses Intel's libs, and they're supposed to be the experts on that. This might not be a bad thing by itself, but you could think of this as adding an extra dependency with a centralized entity such as Intel. Which is why in a decentralized environment might not be ideal (debatable).
  * ❌ Integrating SGX to an existing system using this SDK is a bit tedious, since you need to restructure your application, use some Makefiles to handle linking the enclave with the application, declaring the interface connecting your applications in a separate `.edl` file with its own syntax and more.

![](https://i.imgur.com/vMOMK15.png)Enclave folder using Teaclave vs Fortanix

### Fortanix

  * ✅ You can write all Rust code.
  * ✅ Officially target tier 2 of the Rust compiler.
  * ✅ Add a few lines to your `Cargo.toml` and you are set.
  * ✅ We trust the fact that it is open source and therefore audited by many users, and being included as a tier 2 target for the Rust compiler means that it has earned some respect from the Rust community as well.
  * ❌ Well, sometimes it's not that easy. Not all crates have support for SGX although you can add your own implementation for the Fortanix target.
  * ❌ since it uses `libstd` it assumes that you have implementations for `time/net/env/thread/process/fs`, which SGX does not entirely support. This will generate runtime panics when used and you won't be getting compilation errors.
  * ❌ It's easier to develop on, but that is because it hides some of the complexity away and you may ask yourself if we can trust on its security when many things are hidden away from the developer.

## Conclusions

We don't find a clear winner between Teaclave and Fortanix, as both have their pros and cons.

Having to make a choice we tend to go with Fortanix as its easier to develop in pure Rust. Also as Fortanix is endorsed as Tier 2 we can have a high confidence about its compatilibity with our software allowing for a seamless implementation. As an added bonus this level of trust from the Rust developers gives us a somewhat indirect clue that there aren't blatant security issues hidden in the code that are meaningful enough to make us to doubt it.

## Further readings

  * [SGX product brief](https://www.intel.com/content/dam/develop/public/us/en/documents/intel-sgx-product-brief-2019.pdf)
  * [Intel technical library - Software Guard Extensions](https://www.intel.com/content/www/us/en/developer/library.html?s=Newest&f:@stm_10309_en=%5BIntel%C2%AE%20Software%20Guard%20Extensions%20\(Intel%C2%AE%20SGX\)%5D)
  * [Fortanix resources](https://fortanix.com/intel-sgx/)
  * [Teaclave documentation](https://teaclave.apache.org/docs/)
