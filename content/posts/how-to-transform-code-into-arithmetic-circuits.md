+++
title = "How to transform code into arithmetic circuits"
date = 2023-01-14
slug = "how-to-transform-code-into-arithmetic-circuits"

[extra]
feature_image = "/images/2025/12/WATERHOUSE_-_Ulises_y_las_Sirenas_-National_Gallery_of_Victoria-_Melbourne-_1891._O--leo_sobre_lienzo-_100.6_x_202_cm-.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["zero knowledge proofs"]
+++

## Introduction

The use of efficient [zk-SNARKs](/the-hunting-of-the-zk-snark/) (zero-knowledge succinct non-interactive arguments of knowledge) has given rise to many new and vital applications. For example, we can [delegate expensive computations](/decentralized-private-computations-zexe-and-veri-zexe/) to untrusted servers and receive proof showing the integrity of the computations. This proof is short and can be verified much faster than the naïve approach of re-executing the whole calculation. How can this be possible? The key idea is that the integrity of the computation can be expressed as the solution or satisfiability of a non-deterministic polynomial (NP)-complete problem. Before we explain what NP-complete means, let's look at an example. When you write down code in a high-level language, the compiler transforms it into machine code. It is then executed in the processor, which has dedicated circuits for performing the necessary operations. We can express any complex computation in the form of some circuit. The idea with SNARKs is that we can transform the code into an arithmetic circuit made of operations such as the addition and multiplication of integers and prove the correctness of the execution by checking that the values involved in the calculation satisfy the circuit.

An NP-complete problem is such that:

        * We can verify its solution in polynomial time. We can always find the answer by executing a brute-force search over all possibilities. These conditions correspond to the class NP.
        * We can use the problem to simulate any other in the NP class.

Examples of NP-complete problems are circuit satisfiability, the graph coloring problem, and the traveling salesman problem.

We don't want to write down the circuit corresponding to a program every time we want to code something. Doing this would be like writing code in assembly language or machine code instead of using a higher-level language. To do so, we need to construct a dedicated compiler, which reads our code and transforms it into an arithmetic circuit. We will see that some operations lead to a straightforward representation as arithmetic circuits (such as the addition or multiplication of integers). In contrast, other simple functions, such as XOR, AND, or equality checks, have a more complex structure.

## Arithmetic circuits

An arithmetic circuit is a directed acyclic graph involving the multiplication and addition of numbers. We can think of it as evaluating some polynomial over those numbers. For example, the following circuit expresses the calculation of the following polynomial, \\( p(x) = x^3 + x^2 + 1 \\)

![](/images/external/ruVa3AS.jpg)  
We can also have circuits taking different values and representing a multivariate polynomial, such as \\( p(x_1,x_2) = x_1 x_2 + x_1 + x_2^2\\).

![](/images/external/Ky9wLuo.jpg)

Arithmetic circuits can also be expressed as rank one constraint system, such that there is a one-to-one correspondence between them.

As we mentioned, the only operations we have are addition and multiplication; operations such as division have to be simulated. For example, if we want to perform  
\\[ a/b=c\\]  
we can introduce an additional variable (the multiplicative inverse of \\( b \\), that is, \\( b^{-1}\\)),  
\\(x\times b=1 \\)  
\\(a\times x=c \\)  
The first condition ensures that \\( x \\) is \\( b^{-1} \\), and the second performs the calculation we wanted. The arithmetic circuit would look like  
![](/images/external/TrjZGXD.jpg)  
We could have also worked this by remembering that the multiplicative inverse of an integer (using modular arithmetic) is \\( b^{-1 } = b^{p-2} \\) . However, this leads to a more complex circuit since we would have to evaluate, in general, a large power, which needs many multiplication gates, even if done efficiently (of the order of \\( \log(p) \\)). Therefore, when trying to express a non-native operation over arithmetic circuits, we must think about the most efficient way.

## R1CS

A (quadratic) rank-one constrain system is a system of equations of the form:  
\\( \left(a_{01}+\sum a_{k1} x_k\right)\left(b_{01}+\sum b_{k1} x_k\right)=\left(c_{01}+\sum c_{k1} x_k\right) \\)  
\\( \left(a_{02}+\sum a_{k2} x_k\right)\left(b_{02}+\sum b_{k2} x_k\right)=\left(c_{02}+\sum c_{k2} x_k\right) \\)  
\\( \left(a_{0n}+\sum a_{kn} x_k\right)\left(b_{0n}+\sum b_{kn} x_k\right)=\left(c_{0n}+\sum c_{kn} x_k\right) \\)

The number \\( n \\) gives the total number of constraints in the system. We can show that any bounded computation can be expressed as an R1CS. What happens if we want to perform computations involving something like \\( y^5 \\)? We can use a simple approach known as flattening. We introduce new variables for the intermediate computations:  
\\( y\times y=y_1=y^2\\)  
\\( y\times y_1=y_2=y^3 \\)  
\\( y_1 \times y_2= y_3=y^5 \\)  
For this simple calculation, the vector \\( x \\) is simply \\( x=(y,y_1,y_2,y_3) \\). Most of the elements \\( a_{ij},b_{ij},c_{ij} \\) are zero. The non-zero elements are \\( a_{11},b_{11},c_{11},a_{12},b_{22},c_{32},a_{23},b_{33},c_{34}\\), which are all equal to one. We could also express the R1CS as  
\\(y\times y=y_1 \\)  
\\(y_1\times y_1=y_2 \\)  
\\(y\times y_2=y_3 \\)  
Both represent the same calculation, but the constraints look a bit different. Therefore, there can be multiple representations for a given problem.

R1CS keeps track of the values involved in the calculation and the relationships between the variables. We have a deciding function to check whether or not a given assignment of the variables \\( x \\) satisfies the R1CS. We have to replace the values of \\( x \\) into the system of equations and see that the right and left-hand sides are equal. Equivalently,  
\\( \left(a_{01}+\sum a_{k1} x_k\right)\left(b_{01}+\sum b_{k1} x_k\right)-\left(c_{01}+\sum c_{k1} x_k\right)=0 \\)  
\\( \left(a_{02}+\sum a_{k2} x_k\right)\left(b_{02}+\sum b_{k2} x_k\right)-\left(c_{02}+\sum c_{k2} x_k\right)=0 \\)  
\\( \left(a_{0n}+\sum a_{kn} x_k\right)\left(b_{0n}+\sum b_{kn} x_k\right)-\left(c_{0n}+\sum c_{kn} x_k\right)=0 \\)

One advantage of R1CS stems from its modularity. If we have two systems of constraints, \\( CS_1, CS_2 \\), we can obtain a new one \\( CS_3 \\) which has to satisfy both systems.

## Compilers

We have seen that circuits and R1CS have a modularity property, allowing us to derive more complex circuits or systems of equations by combining simpler ones. We can leverage this by developing a compiler that generates the circuits/constraints associated with each data type and associated operations.

The native elements for arithmetic circuits are the [field elements](/math-survival-kit-for-developers/), that is, \\( 0,1,2,3,...p \\), which we can also interpret as \\( -p/2+1,-p/2+2,...,0,1,2,...p/2 \\) and the operations \\( + \\) and \\( \times \\). Data types such as `u8`, `u16`, `u64`, and `i128` are not and have to satisfy specific properties. Likewise, we have to express their operations in terms of arithmetic circuits. For example, `u16` is an integer value between 0 and 65535, much smaller than the field elements' range. If we want such a data type, we must perform a range check to ensure that the value is between 0 and 65535. This condition adds overhead since we have to add constraints to the circuit associated with the range check.

Boolean variables also face similar problems. In ordinary circuits, a boolean is directly associated with one bit, and operations between bits have been optimized for performance. If we want to represent a boolean variable, which takes as values only 0 and 1, we have to add constraints to enforce these values. One simple way to ensure this is by having the variable \\( b \\) satisfy the following equation  
\\( b(1-b)=0\\)  
The arithmetic circuit associated with this equation is shown below and displays three gates: two multiplications and one addition.  
![](/images/external/qGxf87H.jpg)

If we want to calculate \\( c= \neg b \\), we need to know how to represent NOT in circuit form first. The following equation can represent this  
\\[ c=1-b \\]  
The circuit representation is,  
![](/images/external/CeoYeMi.jpg)  
If we do a naïve pasting of both circuits, we get  
![](/images/external/4z3zqbU.jpg)  
We see that there are a lot of repeated elements (such as \\(1, -1, -b\\). In a later stage, we could optimize the circuit not to introduce redundant elements or computations, as these only increase the proving time.

Suppose we want to represent an integer \\( k \\) in its bit representation (say `u16`). In that case, we have 16 bits, \\( b_k \\), each of which has the same circuit (meaning we have 32 multiplication and 16 addition gates), plus additional checks showing the following:  
\\[ k=\sum_{j=0}^{15} 2^jb_j \\]  
A simple gate does not represent bitwise operations, such as AND, XOR, and NOT. If we want to perform in a naïve way \\(a \oplus b \\) (performing an XOR operation between two bitstrings, which is something you would typically do in a [stream cipher](/symmetric-encryption/) such as ChaCha20), we need to represent the following:

        * Each bitstring.
        * The check that those bits represent \\( a,b \\)
        * The circuits for each XOR operation.

We can use two solutions to avoid this shortcoming. First, instead of trying to represent each non-arithmetic operation by a combination of field operations, we can create tables that show the relations between input and outputs and check the validity of the computation by looking that the combination is in the table. For example, we could store the results of XORing all 8-bit strings in a table and then use a lookup argument to check. This way, we can reduce the number of constraints, reducing the degree of the resulting polynomials and leading to faster proof generation times.

The second solution is to use new cryptographic functions which are SNARK-friendly. We can say that SNARK-friendly primitives have a simple representation as arithmetic circuits (few constraints can represent them); they usually try to use the native operations in the field. Examples of SNARK-friendly hash functions are Poseidon and Rescue.

Circuit compilers work in phases. In the first phase, the compiler starts with the main function. It begins by replacing functions with their corresponding circuits and adding the necessary variables and the circuits associated with their data types. In the second phase, the input variables are replaced by their actual values and all the intermediate results, getting a solution to the system of constraints.

To translate code into arithmetic circuits, we can implement gadgets. These are simply elements that give the behavior of one of the building blocks of a computational problem. For example, we can implement a gadget to test the equality of two integers or one which performs the concatenation of two strings. Given the modularity property, we can glue everything together and obtain the large circuit. For example, [Arkworks](https://github.com/arkworks-rs) gives tools to transform code into R1CS using gadgets.

## Summary

The integrity of a given computation can be expressed as the satisfiability or solution of an NP-complete problem, such as arithmetic circuit satisfiability. To that end, we transform the entire computation into an arithmetic circuit, where the native elements are field elements (instead of bits), and the addition and multiplication of field elements are the natural operations in the circuit. We can equivalently express circuits as constraint systems, such as R1CS. Given the modularity property of circuits and R1CS, we can leave the transformation of code into circuits to a dedicated compiler, which takes every data type and its operations and transforms it into circuit form. All non-native data types and their operations have to be defined in terms of the native elements and operations, which makes certain operations, such as bitwise AND, XOR, NOT expensive. This translation, in turn, makes well-established cryptographic primitives expensive for zk-SNARKs, as each function adds many constraints. The development of new, SNARK-friendly primitives and lookup tables can help reduce the complexity of the circuit representation and speed up proof generation.
