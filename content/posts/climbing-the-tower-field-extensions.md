+++
title = "Climbing the tower: field extensions"
date = 2023-01-25
slug = "climbing-the-tower-field-extensions"

[extra]
feature_image = "/images/2025/12/Aeneas-_Flight_from_Troy_by_Federico_Barocci.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["Math"]
+++

## Introduction

Finite fields are a central piece in every cryptography and [zk-SNARKs](/the-hunting-of-the-zk-snark/). The most common finite fields appearing in practice are the fields with prime order $\mathbb F_p$. There are multiple ways of defining them. A usual one is seeing $\mathbb F_p$ as the set  
$$ \{0, 1, \cdots, p-1\}$$  
together with the rule of addition and the rule of multiplication modulo $p$. But other finite fields play important roles, too. For example, when dealing with pairing-friendly elliptic curves. You may have seen them denoted by things like $\mathbb F_{p^n}$.  
The usual way of defining and introducing them is through the theory of field extensions that involve quotients of [polynomial rings](/math-survival-kit-for-developers/). It is the most natural and correct way from a mathematical standpoint, mainly to prove things about them. But going down that road can be obscure and confusing if you are unfamiliar with the mathematical tools involved.

The idea is straightforward, and those fields are very concrete mathematical objects. This post aims to give a non-standard but more down-to-earth way of understanding extensions of finite fields.

If you want to see examples of finite field extensions in zk-SNARKs, you can look at the [arkworks](https://github.com/arkworks-rs/algebra/tree/master/ff) finite field arithmetic library, where they build field extensions to work with elliptic curve pairings.

## What is a field?

To kick this off, let's revisit what a field is. The actual definition is [here](https://en.wikipedia.org/wiki/Field_\(mathematics\)#Classic_definition).

Loosely speaking, a field is a set $F$ with addition and multiplication rules that behave, for example, like real numbers. There has to be an element in $x_0 \in F$ that behaves like $0$. That means that $x_0 + x = x$ for all $x$ in $F$. We even denote this element just by $0$. Similarly, there has to be an element $1$ in $F$ such that $1\cdot x = x$ for all $x$ in $F$. They are called the _neutral elements_ of multiplication and addition, respectively. In $\mathbb F_p$, these are already denoted by $0$ and $1$, so no surprises there.

A field also has to have a _multiplicative inverse_ for all elements different from $0$. This means that if $x$ is any element of $F$ different from $0$, there has to be another element $y$ such that $x\cdot y = 1$. This element $y$ is unique and is denoted by $x^{-1}$. For example, in $\mathbb F_3$ we have $2^{-1} = 2$.

We can deduce lots of things from the defining properties of a field. We will need this one later: if $x\cdot x = 0$, then $x=0$.

## The case of complex numbers

Computer scientists are very good at naming things, like _neural networks_ and _artificial intelligence_. Mathematicians, on the other hand, are very often terrible at it. Early in our lives, we encounter one of the worst examples: _complex numbers_. There are at least three problems with them. First of all, the name. It biases everyone to think it's a complex concept. Second, the obscure notation $a + bi$, and finally, the fact that the new symbol is called an _imaginary number_. This makes an explosive combination and hides its simplicity. Complex numbers are just pairs of real numbers, also called the _cartesian plane_. And the interesting thing is that there is a way to define addition and multiplication rules on this set of pairs that extends the ones of the real numbers. These even have geometric interpretations!

We introduce this because we will take a similar approach to finite fields. The approach is: we start from a field, in this case, $\mathbb R$, with the usual addition and multiplication rules. We then add a new coordinate to obtain the pairs of real numbers $(a, b)$. This set is usually denoted $\mathbb R^2$. On this set we define the addition component-wise $(a,b) + (c, d) := (a+c, b+d)$. We then try to define a multiplication rule on it. That is, we want to come up with a rule for the expression $(a, b)\cdot(c, d)$ such that:

        1. It forms a field together with the component-wise addition.
        2. It extends the operations of the real numbers in the following way. For all real numbers $a$ and ${b,}$ the equality $(a,0)\cdot(b,0) = (ab, 0)$ should hold. This means we can think of the real numbers as sitting inside $\mathbb R^2$. They are those elements with a null second coordinate. And the new operation boils down to the usual one on this restricted set.

If we try to define the multiplication component-wise, we will need something else. That is, if we define $(a, b)\cdot(c, d) = (ac, bd)$, then the whole thing won't be a field. For example, there won't be a neutral element for multiplication (think about it!). It is not evident, but it turns out that a formula that works is the following:

$$ (a, b) \cdot (c, d) := (ac - bd, ad + bc).$$

Here the neutral element of the multiplication is $(1, 0)$. The set of pairs of real numbers $\mathbb R^2$ together with this multiplication and the component-wise addition is the field of complex numbers $\mathbb C$.

### Notation $a + bi$

Let's play around with this to arrive at the more familiar form $a + bi$. This will also be key to understanding the usual constructions of finite fields out of the rings of polynomials.

Since we can identify the real numbers inside $\mathbb R^2$ as the elements with a null second coordinate, we can abuse notation and write $a$ instead of $(a, 0)$. If we try to do the same with second coordinates, we need a way to distinguish them from the previous ones. So we write the elements of the form $(0, b)$ as $bi$. The $i$ means that it is not a real number. Now, the point $(a, b)$ is equal to $(a, 0) + (0, b)$. And with the new notation, it is written as $a + bi$. Notice that the notation $bi$ is consistent with our identification of $\mathbb R$ inside $\mathbb R^2$ and the multiplication rule. What we mean is that $bi$ is equal to $b\cdot i$ when we think $b$ as being $(b, 0)$ and $i$ as being the element $(0, 1)$. That is, $(b,0)\cdot(0, 1)=(0, b)$.

Last but not least, note that $(0, 1) \cdot (0, 1) = (-1, 0)$. So under this notation, this is $i^2 = -1$.

So why do we prefer the $a + bi$ notation over the $(a, b)$ one? I can think of a few reasons. It is more explicit that we want to think of the real numbers as sitting inside the complex numbers. It is also handier since it does not involve all the parenthesis. But it is just a notation.

The takeaway is that complex numbers are a field constructed from real numbers by adding more coordinates. The same process creates all the finite fields. The difference is that we start from the fields $\mathbb F_p$ instead of $\mathbb R$.

#### Wait, what about other extensions of the real numbers?

Now that we have the complex numbers $\mathbb C:= \mathbb R^2$ constructed as before, we could try to perform the same process and define a multiplication on the pairs of complex numbers $\mathbb C^2$ that together with addition component-wise is again a field.

Another thing we could do is start from the real numbers again, but this time add three or more copies of it. That is, try to define a multiplication on triplets of real numbers $(a,b,c)$ to form a field.

Both of these will need to be changed. This is called the [Frobenius theorem](https://en.wikipedia.org/wiki/Frobenius_theorem_\(real_division_algebras\)). It states that the best we can do is to define a non-commutative multiplication on $\mathbb C^2$ so that it won't be a field. It is called the _quaternions_. It is a fascinating object with many applications, for example, in computer graphics, to deal with rotations.

The good news is that both constructions will work in the land of finite fields!

## Binary strings of length $2$

Let's start simple. Consider $\mathbb F_2$. It has only two elements

$$\mathbb F_2 = \{0, 1\}$$

The addition and multiplication rules have $0$ as the neutral element for addition, $1$ as the neutral element for multiplication, and $1+1$ equals $0$. The addition is the usual XOR on the set of bits. This will be our building block. The field $\mathbb F_2$ will play the role of the real numbers in the previous section.

Let us now add one more coordinate and consider the set of all binary strings of length $2$. So our set now is ${ (0,0), (0,1), (1,0), (1,1)}$. We will call this set $\mathbb F_2^2$ for now. We want to find a multiplication rule on $\mathbb F_2^2$ just like in the case of complex numbers. The addition on is the component-wise addition of $\mathbb F_2$

$$(a,b) + (c, d) = (a+b, c+d).$$

So for example $(1,1) + (0,1) = (1, 0)$. This is again the XOR but now on strings of length $2$. The challenge is again to come up with a multiplication rule.

Let's try to reverse-engineer it. Assume it is somehow defined and has all the properties we want. Essential to what follows is that we also require the multiplicative neutral element to be $(1, 0)$. This is the $1$ in $\mathbb F_2$ under its usual identification as the elements with null second coordinate.

Let's find out what would be $(0,1)\cdot(0,1)$. It surely is one of the elements of $\mathbb{F}_2^2$. So there are only four possible choices. It cannot be $(0,1)\cdot(0,1)=(0,0)$, otherwise we would get $(0, 1) = (0,0)$. This is the property we mentioned in the first section of this post: in a field, if $x\cdot x$ equals the neutral element of the addition $0$, then $x = 0$. Here the neutral element is $(0,0)$ because we are in $\mathbb F_2^2$ with the component-wise addition.

Another possibility is that $(0,1)\cdot(0,1) = (1,0)$, then we could do the following reasoning.  
\\[ \begin{align} (1,1)\cdot(1,1) &= ((1,0) + (0,1))\cdot((1,0) + (0,1)) \\  
&= (1,0)\cdot(1,0) + 2(1,0)\cdot(0,1) + (0,1)\cdot(0,1) \\  
&= (1,0)\cdot(1,0) + (0,1)\cdot(0,1) \\  
&= (1,0) + (1,0) \\  
&= (0,0) \end{align} \\]  
This is bad for the same reason, we got $(1,1)\cdot(1,1) = (0,0)$ but $(1,1)$ is different from $(0,0)$.  
So we are left with only two options for the result of $(0, 1)\cdot(0, 1)$. Either $(0,1)\cdot(0,1)$ is equal to $(1,1)$ or it is equal to $(0, 1)$. But a similar argument to the ones we gave rules out $(0, 1)$. And so, the only possible candidate is  
$$(0, 1)\cdot(0, 1) = (1, 1)$$

With this fact, we can construct the rest of the multiplication table. For example  
$$(1,1)\cdot(1,1) = (1,0)\cdot(1,0) + (0,1)\cdot(0,1) = (1,0) + (1,1) = (0,1).$$

And this works fine. Although not evident at first sight, it satisfies all the properties we want. The proof is easy but tedious now that there's a candidate for the multiplication rule. We would have to go through all the properties and verify that they are satisfied (this is a finite amount of checks).

#### Notation

Let's introduce a notation with the same spirit as the complex numbers' $a + bi$ notation. Similar to that case, let's use the identification of $\mathbb F_2$ inside $\mathbb F_2^2$ and write $0$ and $1$ to mean $(0, 0)$ and $(1, 0)$. Now instead of the symbol $i$ as with the complex numbers let's use $x$ to mean $(0, 1)$. There's no real reason for it. Just that $i$ is highly associated with complex numbers, we want to emphasize that this is not that field. So now we have

$$(0,0) = 0 + 0x = 0$$  
$$(1, 0) = 1 + 0x = 1$$  
$$(0, 1) = 0 + 1x = x$$  
$$(1,1) = 1+1x = 1 + x$$

And using the multiplication rule we just discovered, we obtain $x^2 = 1 + x$.  
This equation is all we need to be able to multiply any two elements by repeatedly applying it whenever a power larger than $1$ appears. For example:  
$$(1+x)x = x + x^2 = x + 1 + x = 1.$$

The set $\mathbb F_2^2$ with this addition and multiplication has its symbol: it is denoted $\mathbb F_4$ and is called _the field with four elements_.

## Binary strings of length $3$

The same process can be done with triplets $(a,b,c)$ of elements of $\mathbb F_2$. The elements of this set are $(0,0,0), (1,0,0), (0,1,0),(1,1,0)$, etc. It has $8$ elements, and we will denote it by $\mathbb F_2^3$. We have the component-wise addition  
$$(a,b,c) + (a',b',c') = (a+a', b+b', c+c')$$  
We can play the same game as before and discover a multiplication rule on $\mathbb F_2^3$ such that it forms a field together with the component-wise addition. In this case, we can even find one such that $(0,1,0)\cdot(0,1,0) = (0,0,1)$. We are not going to show the whole process. You can try it out for yourself!

Similar to the previous case, this field is denoted $\mathbb F_8$, and it's the unique field with $8$ elements.

#### Notation

We identify $\mathbb F_2$ in $\mathbb F_8$ as the elements with null second and third coordinates. That is, $\mathbb F_2$ is ${(0,0,0), (1,0,0)}$.

Now that we have three coordinates, we need two new symbols, $x$ and $y$, to write an element $(a,b,c)$ as $a + bx + cy$. But, since $(0,1,0)\cdot(0,1,0)$ equals $(0,0,1)$, we have $x^2 = y$. So we need only one symbol and can write $(a,b,c)$ as $a + bx+ cx^2$.

If you construct the multiplication rule as in the case of binary strings of length $2$ you'll find that $(0,1,0)\cdot(0,0,1) = (1,1,0)$. With this notation, this is $x^3 = 1 + x$. Similar to the previous case. This equation is all we need to multiply elements. For example

$$(1 + x^2)(1 + x) = 1 + x + x^2 + x^3 = 1 + x + x^2 + 1 + x = x^2.$$

## General case!

Suppose we start with $\mathbb F_p$, where $p$ is some prime number. We can consider the set of tuples $(a_0, a_1, \dots, a_{n-1})$, all of the same length $n$, and call that set $\mathbb F_{p^n}$. In there, we have the component-wise addition. A theorem states that there always exists a multiplication rule on $\mathbb F_{p^n}$ such that it forms a field! Moreover, all multiplication rules are essentially the same. And so this means that there is a unique field of $p^n$ elements.

Everything we showed for the binary strings of length $2$ and $3$ works here. We can write every element $(a_0, a_1, \dots, a_{n-1})$ as  
$$a_0 + a_1x + a_2x^2 + \cdots + a_{n-1}x^{n-1}$$

This notation is consistent with the multiplication rule, just like before. Also, there will be an equality of the form $x^n = b_0 + b_1x + \cdots + b_{n-1}x^{n-1}$ for some elements $b_i$ in $\mathbb F_p$.

And every finite field is of this form!

### Towers of fields

The same works if we use any finite field $F$ as a building block. For example, we could start from $F = \mathbb F_8$. We can consider tuples $(a_0, \cdots, a_{n-1})$ of elements of $F$, and everything follows the same. There will always be a multiplication rule on $F^n$, making it a field. This is useful for constructing large extensions in small steps.

Say for example we need to work with $\mathbb F_{p^{12}}$, the field with $p^{12}$ elements (for some prime number $p$). We could construct it from scratch by finding a multiplication rule on $\mathbb F_p^{12}$, the set of tuples of length $12$ elements of $\mathbb F_p$.  
Another approach is as follows. Construct first the field $\mathbb F_{p^6}$ of $p^6$ elements. Then consider tuples $(a,b)$ with $a,b \in \mathbb F_{p^6}$. There is a multiplicative rule on that set of tuples, making it a field. That will be $\mathbb F_{p^{12}}$. These are called field towers and are a common way of constructing finite fields.

The case of $\mathbb F_{p^{12}}$ is particularly interesting when working with the BLS12-377 or BLS12-381 curves. It is the field where all the points relevant to the pairings are defined.

## The set of bytes

Note that $\mathbb F_{256}$ is the set of all possible bytes. Its elements are tuples $(a_0, a_1,\dots, a_7)$ of elements of $\mathbb F_2$. We denote them by $a_0 + a_1x + a_2x^2 + \cdots + a_7x^7$. Here the equation is $x^8 = x^4 + x^3 + x + 1$.

The [Advanced Encryption Standard](https://en.wikipedia.org/wiki/Advanced_Encryption_Standard) (AES) uses this field as part of the block cipher!

## Summary

In the same way that complex numbers are just pairs of real numbers, field extensions of finite fields are just tuples of elements of some $\mathbb F_p$. It is not evident how to come up with the multiplication rule, but mathematicians have proved that it always exists, and the resulting field is essentially unique in a rigorous way we are not mentioning here. Field extensions are essential in many proving systems, especially those relying on Kate-Zaverucha-Goldberg (KZG) commitments.
