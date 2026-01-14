+++
title = "Do You Want Quality Code? Learn How to Use Differential Fuzzers!"
date = 2023-04-14
slug = "do-you-want-quality-code-learn-how-to-use-differential-fuzzers"

[extra]
feature_image = "/content/images/2025/12/-Hercules_and_Achelous-_by_Cornelis_Cornelisz._van_Haarlem-_1590.jpg"
authors = ["LambdaClass"]
+++

Let’s be honest, who hasn’t missed testing an edge case in their life? Surely it has happened to you, and maybe you realized it months after having implemented it (maybe when it’s already in production!). Some cases escape even the most experienced tester, and to avoid explanations to your manager, today we present the concept of fuzzing, and one of its types: the differential fuzzer.

As stipulated by the OWASP Foundation:

> Fuzz testing or Fuzzing is a Black Box software testing technique, which consists in finding implementation bugs using malformed/semi-malformed data injection in an automated fashion.

Fuzzing is a very efficient technique when looking for errors in our code. This is achieved by generating a massive set of random entries that are used to test a program. The resulting tests often manage to reach less common cases, the kind that can go usually be overlooked.  
If you are interested in learning more about the fuzzer concept in general you can watch the videos we made on the subject, [hacking with fuzzers](https://www.youtube.com/watch?v=z-THCexE4zs) and [fuzzing tools](https://www.youtube.com/watch?v=F3CtyKm7SV4&t=79s)

However, this tool is not limited to a single program, or to only finding errors that end up causing a crash; we can also compare the outputs of at least two different implementations of the same program and check that they follow the same behavior; this is known as differential fuzzing.

## When should we use differential fuzzing?

The cases in which we can use the differential fuzzing technique are where we have two different implementations of the same algorithm. For example, let’s think about all the different languages in which the [Ethereum Virtual Machine](https://ethereum.org/en/developers/docs/evm/) is implemented. The simple magic of the differential fuzzer is to test massively with different inputs that all implementations return the same result when running the same process or function. If this is not the case, at least one of the implementations has logic errors and is giving us a result that was not expected.

## Structure of a differential fuzzer

The structure of a differential fuzzer is simple, first, we define which tool we are going to use for fuzzing since we have a large number of tools for this purpose like [Honggfuzz](https://github.com/google/honggfuzz), [Cargofuzz](https://github.com/rust-fuzz/cargo-fuzz), [Atheris](https://github.com/google/atheris) and many more.

Whichever tool you choose (we do not judge preferences here), all tools should provide us with the same thing, a series of random inputs that we will inject into the code to be tested.

With the input provided by the fuzzer, we adapt it to each of the implementations. In this way, both should have the same input at the end, and we tell the fuzzer to return an error if the results differ. This will give us a list of inputs where at least one of the implementations has an error in its logic, giving a different result than the expected one.

For this, we may need intermediate functions to ensure that the result returned by both implementations is comparable.

## Example of a differential fuzzer
    
    #![no_main]
    use libfuzzer_sys::fuzz_target;
    use std::io::prelude::*;
    use inflate::inflate_bytes;
    use libflate::deflate::Decoder;
    
    // This differential fuzzer panics if two different implementations for deflate
    // decode function returns different results 
    
    fuzz_target!(|data: &[u8]| {
        let mut libflate_decoded = Decoder::new(data);
        let mut decoded_data = Vec::new();
        let libflate_res = libflate_decoded.read_to_end(&mut decoded_data).is_ok();
    
        let inflate_decoded = inflate_bytes(data).is_ok();
        
        if libflate_res != inflate_decoded {
        panic!("differential fuzz failed {}-{}",
                libflate_res, inflate_decoded)
        }
        
    });
    
    

In the example, we can see an example of a differential fuzzer. This fuzzer is created using the `libfuzzer` tool, meant to be used in Rust. the structure of the code is simple and it’s the same for all the fuzzer tools that you want to use.

First, we have the imports that include the implementations we want to compare in our fuzzer. Then we have the function that´s going to run the fuzzer, in this case, is the `fuzz_target!()` function. This function supplies us with a randomly generated input, in this case, the variable `data`. With the previous `data` generated, we run the piece of code that we want to test. In cases like the one in the example code used by `libflate,` we need to adjust the random `data` to be received by the code in the first instance. As the last step we do the differential magic, that is, we compare the result returned by the different implementations.

![](https://i.imgur.com/DzicizT.png)

In this case, as we can see in the image when we run the fuzzer, it finds a crash because one of the implementations returns a valid result and the other one an error.

## Inputs and outputs

According to every particular case of inputs and outputs, we might need to provide some extra code.

Let’s understand what that means with a simple example. We might be comparing two implementations of some code that receives a [quadratic equation](https://en.wikipedia.org/wiki/Quadratic_equation) and an answer and returns if the answers responds to the equation. In this case, one of the implementations receives 4 numbers that correspond to the index of the equation and the answer and the other receives the input as a string with the equation, something like “axx+bx+c=d”.
    
    # Implementation 1 
    def check_if_answer(a,b,c,d, answer):
        result = (a * answer^2) + (b * answer) + c 
         
        if result == d: { 
            True
        } 
        else: {
            False
        }
        
    # Implementation 2
    def check_if_anwer(equation, answer):
        
        string_without_x = remove_x_from_string(equation) # This returns "a+b+c=d"
        array_of_indexes = split_string(string_without_x) # This returns [a,b,c,d]
        [a,b,c,d] =  array_of_indexes
        result = (a * answer^2) + (b * answer) + c 
         
        if result == d: { 
            True
        } 
        else: {
            False
        }
    

To give the different implementations the “same” input we need to adjust the starting input so it’s the same for both. In the output, we have to do the same. One of the implementations might return True/ False while the other return 0/1, we need to adjust the outputs so the equality works as it has to.

This applies to both regular and differential fuzzers.

## Conclusion

A differential fuzzer is a very valuable tool in case you are implementing a process that already has another implementation to ensure that even the edge cases are handled consistently. This tool can also be used in the case of choosing implementations of a solution that we want to use for our project, by comparing the effectiveness of each one.
