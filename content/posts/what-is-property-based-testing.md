+++
title = "What is property-based testing?  Two examples in Rust"
date = 2023-02-03
slug = "what-is-property-based-testing"

[extra]
feature_image = "/images/2025/12/Francisco_de_Zurbara--n_053.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["Rust"]
+++

This article will explore property-based tests and demonstrate their use in two of our open-source projects.  
First, let's explain what a property-based test (PBT) is: If a picture is worth a thousand words, a PBT is worth a thousand unit tests (although this is tunable, as we will see later).  
It was born in the functional programming community and is very different from conventional methods. It's a great tool to consider when testing the correctness of our programs.

As its name suggests, it is based on testing the properties of our code. In other words, invariants or behavior that we expect to be consistent across inputs. When we write a unit test, we test a function/method for a specific set of parameters. So, we usually test with a representative (but small) number of inputs where we think the code may hide bugs. In contrast, a property-based test generates many random inputs and checks that the property is met for all of them. If it finds an unsatisfied value, it proceeds with a shrinking process to find the smallest input that breaks the property. That way, it is easier to reproduce the issue.

## A First Example

Enough talk; let us use a simple example to show how it works in practice. We'll work with Rust to illustrate the benefits of this way of testing.

There are several libraries for doing property-based tests in Rust, but we chose [proptest](https://github.com/proptest-rs/proptest) because it's straightforward to use and is being actively maintained.

In this example, we create a test for a function that adds two positive numbers. The test checks a property of positive number addition: the result is greater than each of the individual parts. We use the `prop_assert!` macro to verify that the property holds.
    
    use proptest::prelude::*;
    
    fn add(a: i32, b: i32) -> i32 {
    	a + b
    }  
    
    proptest! {
    	// Generate 1000 tests.
    	#![proptest_config(ProptestConfig::with_cases(1000))]
    	#[test]
    	fn test_add(a in 0..1000i32, b in 0..1000i32) {
    		let sum = add(a, b);
    		prop_assert!(sum >= a);
    		prop_assert!(sum >= b);
    		prop_assert_eq!(a + b, sum);
    	}
    }
    

Let us see what happens if we change the first property to an incorrect one:
    
    // prop_assert!(sum >= a); previous line
    prop_assert!(sum <= a)
    

We will receive a report with the smallest instance that breaks the property.
    
    ---- test_add stdout ----
    thread 'test_add' panicked at 'Test failed: assertion failed: sum <= a at src/lib.rs:13; minimal failing input: a = 0, b = 1
            successes: 0
            local rejects: 0
            global rejects: 0
    ', src/lib.rs:7:1
    note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
    

To build tests for more complex structures, we can use regular expressions (if we have a way of building our data type from a string) or use [Strategies](https://docs.rs/proptest/latest/proptest/strategy/trait.Strategy.html), which are used to control how values are generated and how the shrinking process is done.

## Case studies

### Case study 1: cairo-rs

Let's start with a more practical example. At LambdaClass, we developed a [Rust implementation of the Cairo virtual machine](https://github.com/lambdaclass/cairo-rs). Cairo stands for CPU Algebraic Intermediate Representation. It's a programming language for writing provable programs, where one party can prove to another that a computation was executed correctly by producing a zero-knowledge proof.

Executing a program made in Cairo involves operating with a lot of field elements (i.e., numbers between 0 and a huge prime number). So every operation (addition, subtraction, multiplication, and division) needs to evaluate to a felt (field element) in the range [0; PRIME -1].
    
    proptest! {
    
      #[test]
      // Property-based test that ensures, for 100 felt values that are randomly generated each time tests are run, that a new felt doesn't fall outside the range  [0, PRIME-1].
      // In this and some of the following tests, The value of {x} can be either [0]  or a huge number to try to overflow the value of {p} and thus ensure the modular arithmetic is working correctly.
      fn new_in_range(ref x in "(0|[1-9][0-9]*)") {
        let x = &Felt::parse_bytes(x.as_bytes(), 10).unwrap();
        let p = &BigUint::parse_bytes(PRIME_STR[2..].as_bytes(), 16).unwrap();
        prop_assert!(&x.to_biguint() < p);
      }
    
      #[test]
      // Property-based test that ensures, for 100 felt values that are randomly generated each time tests are run, that the negative of a felt doesn't fall outside the range [0, PRIME-1].
      fn neg_in_range(ref x in "(0|[1-9][0-9]*)") {
        let x = &Felt::parse_bytes(x.as_bytes(), 10).unwrap();
        let neg = -x;
        let as_uint = &neg.to_biguint();
        let p = &BigUint::parse_bytes(PRIME_STR[2..].as_bytes(), 16).unwrap();
    
        prop_assert!(as_uint < p);
      }
    
      #[test]
      // Property-based test that ensures, for 100 {x} and {y} values that are randomly generated each time tests are run, that multiplication between two felts {x} and {y} and doesn't fall outside the range [0, PRIME-1]. The values of {x} and {y} can be either [0] or a very large number.
      fn mul_in_range(ref x in "(0|[1-9][0-9]*)", ref y in "(0|[1-9][0-9]*)") {
        let x = &Felt::parse_bytes(x.as_bytes(), 10).unwrap();
        let y = &Felt::parse_bytes(y.as_bytes(), 10).unwrap();
        let p = &BigUint::parse_bytes(PRIME_STR[2..].as_bytes(), 16).unwrap();
        let prod = x * y;
        let as_uint = &prod.to_biguint();
    
        prop_assert!(as_uint < p, "{}", as_uint);
      }
    

We already found two hard-to-find bugs by using a suite of property-based tests for each arithmetical operation. Also, it helped us easily change our field elements' internal implementation to a more performant one and be confident that we didn't break anything.

### Case study 2: Patricia Merkle Tree

At LambdaClass, we are also developing a [Merkle Patricia tree library](https://github.com/lambdaclass/merkle_patricia_tree) (like those used in Ethereum and many other cryptography-related projects). To test the correctness of the implementation, we decided to make property-based tests by comparing the results of our library's operations against the results of a reference implementation, [cita-trie](https://github.com/citahub/cita-trie).

For testing, let's generate some inputs for creating two trees: one using the reference implementation and one using our library.  
This time the property that we want to test is that for every generated tree from our library, its root hash matches the root hash of the reference implementation.
    
    fn proptest_compare_root_hashes(path in vec(any::<u8>(), 1..32), value in vec(any::<u8>(), 1..100)) {
    
      use cita_trie::MemoryDB;
      use cita_trie::{PatriciaTrie, Trie};
      use hasher::HasherKeccak;
      
      // Prepare the data for inserting it into the tree
      let data: Vec<(Vec<u8>, Vec<u8>)> = vec![(path, value)];
    
      // Creates an empty patricia Merkle tree using our library and 
      // Keccak256 as the hashing algorithm.
      let mut tree = PatriciaMerkleTree::<_, _, Keccak256>::new();
    
      // insert the data into the tree.
      for (key, val) in data.clone().into_iter() {
        tree.insert(key, val);
      }
    
      // computes the root hash using our library
      let root_hash = tree.compute_hash().as_slice().to_vec();
    
      // Creates a cita-trie implementation of the
      // Patricia Merkle tree.
      let memdb = Arc::new(MemoryDB::new(true));
      let hasher = Arc::new(HasherKeccak::new());
      let mut trie = PatriciaTrie::new(Arc::clone(&memdb), Arc::clone(&hasher));
    
      // Insert the data into the cita-trie tree.
      for (key, value) in data {
        trie.insert(key.to_vec(), value.to_vec()).unwrap();
      }
      // Calculates the cita-tree's root hash.
      let reference_root = trie.root().unwrap();
    
      prop_assert_eq!(
        reference_root,
        root_hash
      );
    }
    

Using this technique, we can ensure that our implementation behaves the same way as the reference one.

## Closing words

In conclusion, property-based testing is a powerful and effective way to test the correctness of our programs. Testing properties helps find bugs and ensure that our program meets invariants across a wide range of inputs. In this article, we demonstrated property-based testing in two open-source projects. We hope you consider it in your testing practices.

## Related Resources

        1. QuickCheck original paper <https://www.cs.tufts.edu/~nr/cs257/archive/john-hughes/quick.pdf>
        2. _Property-Based Testing with PropEr, Erlang, and Elixir_ by Fred Hebert <https://propertesting.com/>
        3. Rust port of QuickCheck <https://github.com/BurntSushi/quickcheck>
        4. proptest book <https://altsysrq.github.io/proptest-book/intro.html>
