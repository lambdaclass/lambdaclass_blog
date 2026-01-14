+++
title = "Julia GPU"
date = 2020-10-20
slug = "julia-gpu"
description = "How the Julia language is making it easy for programmers to use GPU capabilities"

[extra]
feature_image = "/content/images/2025/12/Screenshot-2025-12-17-at-10.54.04---AM.png"
authors = ["LambdaClass"]

[taxonomies]
tags = ["Julia", "Gpu", "Cuda", "Data Science", "Machine Learning"]
+++

### How the Julia language is making it easy for programmers to use GPU capabilities with JuliaGPU

![](/content/images/max/2000/1-KJX3T1Y9T1Cj0aV3m-A22w.png)

We are living in a time where more and more data is being created every day as well as new techniques and complex algorithms that try to extract the most out of it. As such, CPU capabilities are approaching a bottleneck in their computing power. GPU computing opened its way into a new paradigm for high-performance and parallel computation a long time ago, but it was not until recently that it become massively used for data science.  
In this interview, [Tim Besard](https://twitter.com/maleadt), one of the main contributors to the JuliaGPU project, digs into some of the details about GPU computing and the features that make Julia a language suited for such tasks, not only from a performance perspective but also from a user one.

* * *

#### Please tell us a bit about yourself. What is your background? what is your current position?

I’ve always been interested in systems programming, and after obtaining my CS degree I got the opportunity to start a PhD at Ghent University, Belgium, right when Julia was first released around 2012. The language seemed intriguing, and since I wanted to gain some experience with LLVM, I decided to port some image processing research code from MATLAB and C++ to Julia. The goal was to match performance of the C++ version, but some of its kernels were implemented in CUDA C… So obviously Julia needed a GPU back-end!

That was easier said than done, of course, and much of my PhD was about implementing that back-end and (re)structuring the existing Julia compiler to facilitate these additional back-ends. Nowadays I’m at Julia Computing, where I still work on everything GPU-related.

#### What is JuliaGPU? What is the goal of the project?

JuliaGPU is the name we use to group GPU-related resources in Julia: There’s a [GitHub organization](https://github.com/JuliaGPU) where most packages are hosted, a [website](https://juliagpu.org/) to point the way for new users, we have [CI infrastructure](https://github.com/JuliaGPU/gitlab-ci) for JuliaGPU projects, there’s a Slack channel and Discourse category, etc.

The goal of all this is to make it easier to use GPUs for all kinds of users. Current technologies often impose significant barriers to entry: CUDA is fairly tricky to install, C and C++ are not familiar to many users, etc. With the software we develop as part of the JuliaGPU organization, we aim to make it easy to use GPUs, without hindering the ability to optimize or use low-level features that the hardware has to offer.

#### What is GPU computing? How important is it nowadays?

GPU computing means using the GPU, a device originally designed for graphics processing, to perform general-purpose computations. It has grown more important now that CPU performance is not improving as steadily as it used to. Instead, specialized devices like GPUs or FPGAs are increasingly used to improve the performance of certain computations. In the case of GPUs, the architecture is a great fit to perform highly-parallel applications. Machine learning networks are a good example of such parallel applications, and their popularity is one of the reasons GPUs have become so important.

#### Do you think Julia is an appropriate language to efficiently use GPU capabilities? Why?

Julia’s main advantage is that the language was designed to be compiled. Even though the syntax is high-level, the generated machine code is  
compact and has great performance characteristics (for more details, see [this paper](http://janvitek.org/pubs/oopsla18b.pdf)). This is crucial for GPU execution, where we are required to run native binaries and cannot easily (or efficiently) interpret code as is often required by other language’s semantics.

Because we’re able to directly compile Julia for GPUs, we can use almost all of the language’s features to build powerful abstractions. For example, you can define your own types, use those in GPU arrays, compose that with existing abstractions like lazy "Transpose" wrappers, access those on the GPU while benefiting from automatic bounds-checking (if needed), etc.

#### From a Python programmer perspective, how does CUDA.jl compare to PyCUDA? Are their functionalities equivalent?

PyCUDA gives the programmer access to the CUDA APIs, with high-level Python functions that are much easier to use. CUDA.jl provides the same, but in Julia. The `hello world` from PyCUDA’s home page looks almost identical in Julia:
    
    
    using CUDA
    
    
    function multiply_them(dest, a, b)
     i = threadIdx().x
     dest[i] = a[i] * b[i]
     return
    end
    
    
    a = CuArray(randn(Float32, 400))
    b = CuArray(randn(Float32, 400))
    
    
    dest = similar(a)
    @cuda threads=400 multiply_them(dest, a, b)
    
    
    println(dest-a.*b)

There’s one very big difference: "multiply_them" here is a function written in Julia, whereas PyCUDA uses a kernel written in CUDA C. The reason is straightforward: Python is not simple to compile. Of course, projects like Numba prove that it is very much possible to do so, but in the end those are separate compilers that try to match the reference Python compilers as closely as possible. With CUDA.jl, we integrate with that reference compiler, so it’s much easier to guarantee consistent semantics and follow suit when the language changes (for more details,  
refer to [this paper](https://arxiv.org/abs/1712.03112)).

#### Are the packages in the JuliaGPU organization targeted to experienced programmers only?

Not at all. CUDA.jl targets different kinds of (GPU) programmers. If you are confident writing your own kernels, you can do so, while using all of the low-level features CUDA GPUs have to offer. But if you are new to the world of GPU programming, you can use high-level array operations that use existing kernels in CUDA.jl. For example, the above element-wise multiplication could just as well be written as:
    
    
    using CUDA
    
    
    a = CuArray(randn(Float32, 400))
    b = CuArray(randn(Float32, 400))
    
    
    dest = a .* b

#### Is it necessary to know how to code in CUDA.jl to take full advantage of GPU computing in Julia?

Not for most users. Julia has a powerful language of generic array operations ("map", "reduce", "broadcast", "accumulate", etc) which can be applied to all kinds of arrays, including GPU arrays. That means you can often re-use your codebase developed for the CPU with CUDA.jl ([this paper](https://www.sciencedirect.com/science/article/abs/pii/S0965997818310123) shows some powerful examples). Doing so often requires minimal changes: changing the array type, making sure you use array operations instead of for loops, etc.

It’s possible you need to go beyond this style of programming, e.g., because your application doesn’t map cleanly onto array operations, to use specific GPU features, etc. In that case, some basic knowledge about CUDA and the GPU programming model is sufficient to write kernels in CUDA.jl.

#### How is the experience of coding a kernel in CUDA.jl in comparison to CUDA C and how transferable is the knowledge to one another?

It’s very similar, and that’s by design: We try to keep the kernel abstractions in CUDA.jl close to their CUDA C counterparts such that the programming environment is familiar to existing GPU programmers. Of course, by using a high-level source language there’s many quality-of-life improvements. You can allocated shared memory, for example, statically and dynamically as in CUDA C, but instead of a raw pointers we use an N-dimensional array object you can easily index. An example from the [NVIDIA developer blog](https://developer.nvidia.com/blog/using-shared-memory-cuda-cc/):
    
    
    __global__ void staticReverse(int *d, int n)
    {
     __shared__ int s[64];
     int t = threadIdx.x;
     int tr = n-t-1;
     s[t] = d[t];
     __syncthreads();
     d[t] = s[tr];
    }

The CUDA.jl equivalent of this kernel looks very familiar, but uses array objects instead of raw pointers:
    
    
    function staticReverse(d)
     s = @cuStaticSharedMem(Int, 64)
     t = threadIdx().x
     tr = length(d)-t+1
     s[t] = d[t]
     sync_threads()
     d[t] = s[tr]
     return
    end

Using array objects has many advantages, e.g. multi-dimensional is greatly simplified and we can just do "d[i,j]". But it’s also safer, because these accesses are bounds checked:
    
    
    julia> a = CuArray(1:64)
    64-element CuArray{Int64,1}:
     1
     2
     3
     ⋮
     62
     63
     64
    
    
    julia> @cuda threads=65 staticReverse(a)
    ERROR: a exception was thrown during kernel execution.
    Stacktrace:
     [1] throw_boundserror at abstractarray.jl:541

Bounds checking isn’t free, of course, and once we’re certain our code is correct we can add an "@inbounds" annotation to our kernel and get the high-performance code we expect:
    
    
    julia> @device_code_ptx @cuda threads=64 staticReverse(a)
    .visible .entry staticReverse(.param .align 8 .b8 d[16]) {
     .reg .b32 %r<2>;
     .reg .b64 %rd<15>;
     .shared .align 32 .b8 s[512];
    
    
    mov.b64 %rd1, d;
     ld.param.u64 %rd2, [%rd1];
     ld.param.u64 %rd3, [%rd1+8];
     mov.u32 %r1, %tid.x;
     cvt.u64.u32 %rd4, %r1;
     mul.wide.u32 %rd5, %r1, 8;
     add.s64 %rd6, %rd5, -8;
     add.s64 %rd7, %rd3, %rd6;
     ld.global.u64 %rd8, [%rd7+8];
     mov.u64 %rd9, s;
     add.s64 %rd10, %rd9, %rd6;
     st.shared.u64 [%rd10+8], %rd8;
     bar.sync 0;
     sub.s64 %rd11, %rd2, %rd4;
     shl.b64 %rd12, %rd11, 3;
     add.s64 %rd13, %rd9, %rd12;
     ld.shared.u64 %rd14, [%rd13+-8];
     st.global.u64 [%rd7+8], %rd14;
     ret;
    }
    
    
    julia> a
    64-element CuArray{Int64,1}:
     64
     63
     62
     ⋮
     3
     2
     1

Tools like "@device_code_ptx" make it easy for an experienced developer to inspect generated code and ensure the compiler does what he wants.

#### Why does having a compiler have such an impact in libraries like CUDA.jl? (How was the process of integrating it to the Julia compiler?)

Because we have a compiler at our disposal, we can rely on higher-order functions and other generic abstractions that specialize based on the arguments that users provide. That greatly simplifies our library, but also gives the user very powerful tools. As an example, we have carefully implemented a `mapreduce` function that uses shared memory, warp intrinsics, etc to perform a high-performance reduction. The implementation is generic though, and will automatically re-specialize (even at run time) based on the arguments to the function:
    
    
    julia> mapreduce(identity, +, CuArray([1,2,3]))
    6
    
    
    julia> mapreduce(sin, *, CuArray([1.1,2.2,3.3]))
    -0.11366175839582586

With this powerful `mapreduce` abstraction, implemented by a experienced GPU programmer, other developers can create derived abstractions without such experience. For example, let’s implement a `count` function that evaluates for how many items a predicate holds true:
    
    
    count(predicate, array) = mapreduce(predicate, +, array)
    
    
    julia> a = CUDA.rand(Int8, 4)
    4-element CuArray{Int8,1}:
     51
     3
     70
     100
    
    
    julia> count(iseven, a)
    2

Even though our `mapreduce` implementation has not been specifically implemented for the `Int8` type or the `iseven` predicate, the Julia compiler automatically specializes the implementation, resulting in kernel optimized for this specific invocation.

#### What were the biggest challenges when developing packages for JuliaGPU, particularly writing a low level package such as CUDA.jl in a high level programming language such as Julia?

Much of the initial work focused on developing tools that make it possible to write low-level code in Julia. For example, we developed the [LLVM.jl](https://github.com/maleadt/LLVM.jl) package that gives us access to the LLVM APIs. Recently, our focus has shifted towards generalizing this functionality so that other GPU back-ends, like [AMDGPU.jl](https://github.com/JuliaGPU/AMDGPU.jl) or [oneAPI.jl](https://github.com/JuliaGPU/oneAPI.jl) can benefit from developments to CUDA.jl. Vendor-neutral array operations, for examples, are now implemented in [GPUArrays.jl](https://github.com/JuliaGPU/GPUArrays.jl) whereas shared compiler functionality now lives in [GPUCompiler.jl](https://github.com/JuliaGPU/GPUCompiler.jl). That should make it possible to work on several GPU back-ends, even though most of them are maintained by only a single developer.

#### Regarding the [latest release](https://juliagpu.org/2020-07-18-cuda_1.3/) announced in the JuliaGPU blog about multi-device programming, what are the difficulties that this new functionality solves? Is this relevant in the industry where big computational resources are needed?

In industry or large research labs, MPI is often used to distribute work across multiple nodes or GPUs. Julia’s MPI.jl supports that use case, and integrates with CUDA.jl where necessary. The multi-device functionality added to CUDA 1.3 additionally makes it possible to use multiple GPUs within a single process. It maps nicely on Julia’s task-based concurrency, and makes it easy to distribute work within a single node:
    
    
    Threads.@threads for dev in devices()
     device!(dev)
     # do some work here
    end

#### **What are the plans for the near future?**

There aren’t any specific roadmaps, but one upcoming major feature is proper support for reduced-precision inputs, like 16-bits floating point. We already support Float16 arrays where CUBLAS or CUDNN does, but the next version of Julia will make it possible to write kernels that operate on these values.

Other than that, features come as they do :-) Be sure to subscribe to the [JuliaGPU blog](https://juliagpu.org/post/) where we publish a short post for every major release of Julia’s GPU back-ends.

* * *

You can find Tim at @[maleadt](https://twitter.com/maleadt) on Twitter!
