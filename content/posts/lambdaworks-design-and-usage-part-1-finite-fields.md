+++
title = "Lambdaworks Design and Usage: Part 1 - Finite Fields"
date = 2024-01-02
slug = "lambdaworks-design-and-usage-part-1-finite-fields"

[extra]
feature_image = "/content/images/2025/12/Hubert_Robert_-_Studio_of_an_Antiquities_Restorer_in_Rome_-_Google_Art_Project_-cropped-.jpg"
authors = ["LambdaClass"]
+++

## Introduction

In this series of blog posts, we will see how Lambdaworks is implemented and the standard tools needed to develop provers. This first part will briefly overview the library and then focus on the finite field design and usage.

Lambdaworks at its core is a library to create proving systems, and a collection of associated provers and verifiers ready to use. In this blog post, we will explore the building blocks of the proving systems and the Lambdaworks library.

The most relevant sections of the library are:

        * Math
        * Crypto
        * Provers

Provers has a collection of proof systems. Crypto contains some primitives like MSM, hashes, and Merkle trees. Math has logic related to finite fields and elliptic curves.

## Math

At the core of the Math library are finite fields, the main building block of all the constructions we use in Lambdaworks.

The basic structure is designed under a relationship between a `Field` and its `FieldElement`. Let's see how it works.

### Field and Elements: Main Ideas

A `Field` is an abstract definition. It knows the modulus and defines how the operations are performed.

We usually create a new `Field` by instantiating an optimized backend. For example, this is the definition of the Pallas field:
    
    // 4 is the number of 64-bit limbs needed to represent the field
    type PallasMontgomeryBackendPrimeField<T> = MontgomeryBackendPrimeField<T, 4>;
    
    #[derive(Debug, Clone, PartialEq, Eq)]
    pub struct MontgomeryConfigPallas255PrimeField;
    impl IsModulus<U256> for MontgomeryConfigPallas255PrimeField {
        const MODULUS: U256 = U256::from_hex_unchecked(
            "40000000000000000000000000000000224698fc094cf91b992d30ed00000001",
        );
    }
    
    pub type Pallas255PrimeField =
        PallasMontgomeryBackendPrimeField<MontgomeryConfigPallas255PrimeField>;
    

As it can be seen, it is enough to define its modulus and instantiate it over a `PallasMontgomeryBackendPrimeField`.

Internally, it resolves all the constants needed and creates all the required operations for the field. Notice that there are no macros involved. This holds for all the Lambdaworks code.

Generics and traits are the only tools used to have genericity. This makes the job easier for the compiler to suggest possible functions to be called and makes the code easier to understand. Moreover, minimal traits are used to make the code easier to understand.

Back to the fields, you will notice that other backends can be more efficient for some fields. For example, Mersenne31 and Goldilocks are defined over their backend.

Back to the usage, suppose we want to create a `FieldElement`. This is as easy as instantiating the `FieldElement` over a `Field` and calling a `from_hex` function.

For example:
    
    let an_element = FieldElement::<Stark252PrimeField>::from_hex_unchecked("030e480bed5fe53fa909cc0f8c4d99b8f9f2c016be4c41e13a4848797979c662")
    

Notice we can alias the `FieldElement` to something like
    
    type FE = FieldElement::<Stark252PrimeField>;
    

if we want to shorten the code and do not care about being explicit with the field.

Once we have a field, we can make all the operations. We usually suggest working with references, but copies work too.
    
    let field_a = FE::from_hex("3").unwrap();
    let field_b = FE::from_hex("7").unwrap();
    
    // We can use pointers to avoid copying the values internally
    let operation_result = &field_a * &field_b
    
    // But all the combinations of pointers and values works
    let operation_result = field_a * field_b
    

Sometimes, optimized operations are preferred. For example,
    
    // We can make a square multiplying two numbers
    let squared = field_a * field_a;
    // Using exponentiation
    let squared = 
    field_a.pow(FE::from_hex("2").unwrap())
    // Or using an optimized function
    let squared = field_a.square()
    

all compute the square of a number, but performance-wise, there is quite a big difference.

Some useful instantiation methods are also provided for common constants and whenever const functions can be called. This is when creating functions that do not rely on the `IsField` trait since Rust does not support const functions in traits yet,
    
    // Defined for all field elements
    // Efficient, but nonconst for the compiler
    let zero = FE::zero() 
    let one = FE::one()
    
    // Const alternatives of the functions are provided, 
    // But the backend needs to be known at compile time. 
    // This requires adding a where clause to the function
    
    let zero = F::ZERO
    let one = F::ONE
    let const_intstantiated = FE::from_hex_unchecked("A1B2C3");
    

For many use cases, we can treat these fields as a `PrimeField` instead of treating them as a `Field`. If the word `FieldExtension` is irrelevant, `PrimeField` is the right choice.

You will notice traits are followed by an `Is`, so instead of accepting something of the form `IsField`, you can use `IsPrimeField` and access more functions. The most relevant is `.representative()`. This function returns a canonical representation of the element as a number, not a field.

If the internal number is in Montgomery form, this function will reverse it.

This allows us to make comparisons where it makes sense. Since fields work like circular lists of elements, order doesn't make much sense.

If we are in $\mathbb{F_3}$, for example, $4$ may look bigger than $2$, but $4$ is also $1$, and $1$ seems smaller than $2$. The question of "which element is bigger" doesn't make much sense. This gets even messier if we interpret some numbers as negatives as other libraries.

For this reason, comparisons are only allowed when we interpret the `FieldElement` as a number through the `representative()` function.

### Field and Elements: Serialization and Deserialization

For serialization, we recommend using Serde with bincode. This has given the best results all around while maintaining good usability. By default, the serialization is done in the most compact mode possible and is not human-readable.

To enable a human-readable serialization, where fields are written as strings, the feature `lambdaworks-serde-string` can be enabled.

Serde is available at all levels of the library. So, if you have a FieldElements struct, you can simply derive a serialization.

`FieldElements` also have different algorithms to transform into bytes in the `ByteConversion` trait. This is a `from_bytes_le`, `from_bytes_be`, `to_bytes_le` and `to_bytes_be`.

These smaller conversions to bytes are helpful when doing small tasks like appending data to a transcript but can become cumbersome when you have to serialize complex structures.

### Field and Elements: Advanced usage, Extensions, and Internals deep dive

Field extensions are used in two scenarios requiring slightly different properties: pairing computations and working with small fields with proof systems.

#### Pairings

When doing pairings, a degree $12$ extension is commonly used. This extension is usually created with a tower of extensions, where we make a degree $2$ extension of a degree $2$ extension of a degree $3$ extension. This is a non-naïve of making a degree $12$ extension.

For example, we can see on the code:
    
    pub type Degree12ExtensionField = QuadraticExtensionField<Degree6ExtensionField, LevelThreeResidue>;
    
    pub type Degree6ExtensionField = CubicExtensionField<Degree2ExtensionField, LevelTwoResidue>;
    

Using quadratic and cubic extensions, we are building the tower of fields. The key design for this to work is in the internal structure of the `IsField`. A field internally has a `BaseType` that, in practice, can either be a BigInteger, which we call `UnsignedInteger` to enable multiple backends of BigInts, or another `FieldElement.`

This works nicely for this scenario, but there is another to handle.

#### Working with smaller fields

When working with proving systems that use small fields, like it could be a Stark with a 32-bit BabyBear, we need an extension to avoid security being broken. This is because we need to sample a random challenge from a much larger set than the degree of the polynomials involved. We will also use an extension to sample random challenges from a bigger set in this case.

But this time, the critical issue is that we will be doing a lot of operations between the field and its subfield. These operations can be solved more efficiently than just doing them naïvely. Think of it as multiplying a complex number for a real one when needed instead of constantly multiplying complex numbers even when the imaginary part is 0.

We define each `Field` as a `SubField` of another `Field` to solve this issue. For an unextended field, we define it as a subfield of itself, which is a true statement that you will not notice. When working with an extension, two sets of operations are defined—one for the field and one for the field against its subfield.

The resolution of which operation to use is done with the type system, and so these optimizations are invisible when using the library. When using an operator, Lambdaworks picks the correct operation by itself.

## Conclusion

Finite Fields are at the core of many proving systems, and having optimized backends is necessary for performance. Lambdaworks has developed its own backend, emphasizing performance and usability. The library also has other features, such as cryptographic primitives and different proof systems. In future blog posts, we will cover these parts, show how to use them, and explain some of the design decisions and the advantages that they may offer.
