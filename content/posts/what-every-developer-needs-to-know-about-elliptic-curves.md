+++
title = "What every developer needs to know about elliptic curves"
date = 2022-08-06
slug = "what-every-developer-needs-to-know-about-elliptic-curves"

[extra]
feature_image = "/images/2025/12/Jose--_Moreno_Carbonero_-_Fundacio--n_de_Buenos_Aires.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["cryptography", "elliptic curves", "Math"]
+++

Elliptic curves (EC) have become one of the most useful tools for modern cryptography. They were proposed in the 1980s and became widespread used after 2004. Its main advantage is that it offers smaller key sizes to attain the same level of security of other methods, resulting in smaller storage and transmission requirements. For example, EC cryptography (ECC) needs 256-bit keys to attain the same level of security as a 3000-bit key using RSA (another public-key cryptographic system, born in the late 70s). ECC and RSA work by hiding things inside a certain mathematical structure known as a finite cyclic group (we will explain this soon). The hiding is done rather in plain sight: you could break the system if you could reverse the math trick (spoiler alert: if done properly, it would take you several lifetimes). It is as if you put $1.000.000 inside an unbreakable glass box and anyone could take it if they could break it.

In order to understand these objects and why they work, we need to go backstage and look at the math principles (we won't enter into the hard details or proofs, but rather focus on the concepts or ideas). We will start by explaining finite fields and groups and then jump onto the elliptic curves (over finite fields) and see whether all curves were created equal for crypto purposes.

## Finite fields

We know examples of fields from elementary math. The rational, real and complex numbers with the usual notions of sum and multiplication are examples of fields (these are not finite though).

A finite field is a set equipped with two operations, which we will call + and ×. These operations need to have certain properties in order for this to be a field:

  1. If _a_ and _b_ are in the set, then _c=a+b_ and _d=a×b_ should also be in the set. This is what is mathematically called a closed set under the operations +, ×. 
  2. There is a zero element, 0, such that _a_ +0=_a_ for any a in the set. This element is called the additive identity.
  3. There is an element, 1, such that 1× _a_ =_a_ for any a in the set. This element is the multiplicative identity.
  4. If a is in the set, there is an element _b_ , such that _a+b_ =0. We call this element the additive inverse and we usually write it as _−a_.
  5. If _a_ is in the set, there is an element _c_ such that _a×c=1_. This element is called the multiplicative inverse and we write is as _a_ −1.

Before we can talk about examples of finite fields, we need to introduce the modulo arithmetic. 

We learned that given a natural number or zero, _a_ and a non-zero number _b_ , we could write out a in the following way _a=q×b+r_ where _q_ is the quotient and _r_ is the remainder of the division of _a/b_. This _r_ can take values 0,1,2,...,b−1 We know that if _r_ is zero, then a is a multiple of _b_. It may not seem new, but this gives us a very useful tool to work with numbers. For example, if _b_ =2 then _r_ =0,1. When it is 0, _a_ is even (it is divisible by 2) and when it is 1, _a_ is odd. A simple way to rephrase this (due to Gauss): 

a≡1(mod2) 

if _a_ is odd and 

a≡0(mod2) 

if _a_ is even. We can see that if we sum two odd numbers _a1_ and _a2_ , 

a1+a2≡1+1≡0(mod2)

This shows us that, if we want to know whether a sum is even or not, we can simply sum the remainders of their division by 2 (an application of this is that in order to check divisibility by two, we should only look at the last bit of the binary representation). 

Another situation where this arises every day is with time. If we are on Monday at 10 am and we have 36 hours till the deadline of a project, we have to submit everything by Tuesday 10 pm. That is because 12 fits exactly 3 times in 36, leading to Mon-10 pm, Tue-10 am, Tue-10 pm. If we had 39 hours, we jump to Wed-1 am. 

An easy way to look at this relation (formally known as congruence modulo p) is that if _a≡b_(mod _p_), then _p_ divides _a−b_ , or _a=k×p+b_ for an integer _k_. 

More informally, we see that operating (mod _p_) wraps around the results of certain calculations, giving always numbers in a bounded range by _p_ −1. 

We can see that if a1≡b1(modp) and a2≡b2(modp), then a1+a2≡b1+b2(mod _p_) (if b1+b2>p we can wrap around the result). Similar results apply when using subtraction and multiplication. Division presents some difficulties, but we can change things a little bit and make it work this way: instead of thinking of dividing _a÷b_ we can calculate _a×b−1_ , where _b_ −1 is the multiplicative inverse of _b_ (remember _b×b −1_=1). Consider _p_ =5, so the elements of the group are 0,1,2,3,4. 

We can see that 1 is its own multiplicative inverse, since 1×1=1≡1  (mod5). If we take 2 and 3, then 2×3=6≡1  (mod5) (so 3 is the multiplicative inverse of 2) and 4×4=16≡1 (mod5). The set and the operations defined satisfy the conditions for a field. 

We can also define integer powers of field elements in a simple way. If we want to square a number _a_ , it is just doing _a×a_ and take mod _p_. If we want a cube, we do _a×a×a_ and take mod _p_. RSA uses exponentiation to perform encryption. It is easy to see that if the exponent is rather large (or the base is very large, or both), numbers get really big. For example, we want to evalute 265536(mod _p_). When we reach a 1000, we get numbers with over 300 digits and we are still a long way to go. We can do this calculation much simpler realizing that 65536=216 and squaring the number and taking the remainder every time. We end up doing only 16 operations like this, instead of the original 65536! thus avoiding huge numbers. A similar strategy will be used when we work with ECs! 

## Groups

We saw that whenever we add two even integers, we get another one. Besides, as 0 is even and if we sum _a_ and _−a_ we get 0, which is the identity element for the sum. Many different objects have a similar behavior when equipped with a certain operation. For example, the multiplication of two invertible matrices results in an invertible matrix. If we consider the set of invertible matrices of _N_ × _N_ equipped with the multiplication, we can see that if _A_ is in the set, _A −1_ is in the set; the identity matrix is in the set (and it plays the role of identity element with respect to multiplication). In other words, some sets equipped with a certain operation share some properties and we can take advantage of the knowledge of this structure. The set, together with the operation, forms a group. Formally, a group is a set _G_ equipped with a binary operation × such that: 

     1. The operation is associative, that is, _(a×b)×c=a×(b×c)_.
     2. There is an identity element, _e: e×a=a_ and _a×e=a_. 
     3. For every element _a_ in the set, there is an element _b_ in the set such that _a×b=e_ and _b×a=e_. We denote _b=a−1_ for simplicity.

We can easily see that any field is, in particular, a group with respect to each one of its two operations (conditions 1, 2 and 4 for the field indicate it is also a group with respect to the sum and 1, 3 and 5 for multiplication). If the operation is commutative (that is, _a×b=b×a_) the group is known as an abelian (or commutative) group. For example, the invertible matrices of _N×N_ form a group, but it is not abelian, since _A×B≠B×A_ for some matrices _A_ and _B_. 

We will be interested in finite groups (those where the set contains a finite number of elements) and, in particular, cyclic groups. These are groups which can be generated by repeatedly applying the operation over an element _g_ , the generator of the group. The _n_ -th roots of unity in the complex numbers form an example of a cyclic group under multiplication; this is the set of solutions of _x n_=1, which are of the form exp(2 _πik/n_), with _k_ =0,1,2...,_n_ −1. This group can be generated by taking integer powers of exp(2 _πi/n_). The roots of unity play an important role in the calculation of the fast Fourier transform (FFT), which has many applications. 

## Elliptic curves in a nutshell

Elliptic curves are very useful objects because they allow us to obtain a group structure with interesting properties. Given a field _F_ , an elliptic curve is the set of points _(x,y)_ which satisfy the following equation: 

_y 2+a1xy+a3y=x3+a2x2+a4x+a6 _

This is known as the general Weierstrass equation. In many cases, this can be written in the simpler form 

_y 2=x3+ax+b_

which is the (Weierstrass) short-form. Depending on the choice of the parameters a and b and the field, the curve can have some desired properties or not. If _4a 3+27b2≠0 _, the curve is non-singular. 

We can define an operation which allows us to sum elements belonging to the elliptic curve and obtain a group. This is done using a geometric construction, the chord-and-tangent rule. Given two points on the curve _P1=(x 1,y1)_ and _P 2=(x2,y2)_, we can draw a line connecting them. That line intersects the curve on a third point _P 3=(x3,y3)_. We set the sum of _P 1_ and _P 2_ as _(x 3,−y3)_, that is, point _P 3_ flipped around the _x_ -axis. The formulae are:  ![](/images/2022/12/imagen-1.png)

We can easily see that we have a problem if we try to sum _P 1=(x1,y1)_ and _P 2=(x1,−y1)_. We need to add an additional point to the system, which we call the point at infinity _O_. This inclusion is necessary to be able to define the group structure and works as the identity element for the group operation. 

Another problem appears when we want to sum _P 1_ and _P 1_ to get to _P 3=2P1_. But, if we draw the tangent line to the curve on P1, we see that it intersects the curve at another point. If we want to perform this operation, we need to find the slope of the tangent line and find the intersection: 

$$s=\frac{3x21+a}{2y1}$$  
$$x3=s2−2x1$$  
$$y3=s(x1−x3)−y1$$

![](/images/2022/12/imagen-5.png)

It takes a little bit of work, but we can prove that the elliptic curve with this operation has the properties of a group. We will use finite fields to work with these curves and the groups that we will obtain are finite cyclic groups, that is, groups which can be generated by repeteadly using the operation on a generator, _g: g,2g,3g,4g,5g,...._ ![](/images/2022/12/imagen-3.png)

If we plot the collection of points onto a graph, we see that the points are distributed in a rather "random" fashion. For example, _2 g_ could be very far from _3 g_ which in turn are very far from _4 g_. If we wanted to know how many times _k_ we have to add the generator to arrive at a certain point _P_ (that is solving the equation _kg=P_) we see that we don't have an easy strategy and we are forced to perform a brute search over all possible _k_. This problem is known as the (elliptic curve) discrete logarithm (log for friends) problem (other friends prefer ECDLP). 

On the other hand, if we know _k_ , we can compute in a very fast way _P=kg_. This offers us a way to hide (in plain sight) things inside the group. Of course, if you could break the DLP, you could get k, but it is rather infeasible. If we want to calculate 65536 _g_ , we can do it by realizing that _g+g=2 g, 2g+2g=4g, 4g+4g=8_...until _32768 g+32768g=65535g_, so we narrowed the operations 65536 to 16. There are many useful algorithms that allow us to speed up the operations over elliptic curves, allowing us to avoid expensive calculations such as inversions, which appear when we want to calculate the slope. 

## Are all elliptic curves useful for crypto?

The strength of elliptic curve cryptography lies on the hardness to solve the discrete logarithm problem. This is related to the number of elements (the order of the set) making the cyclic group. If the number is a very large prime, or it contains a very large prime in its factorization (that is, the number is a multiple of a large prime), then the problem becomes infeasible. However, if the order is made up of small primes, it is possible to search over the subgroups and reconstruct the answer with help from the [Chinese Remainder Theorem](https://en.wikipedia.org/wiki/Chinese_remainder_theorem). This is because the difficulty depends on the size of the largest prime involved.

Some curves have desired properties and have been given names. For example, Bitcoin uses secp256k1, which has the following parameters: 

_a=0_  
_b_ =7 _p_ =2256−232−977 _g x_=_0x79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798_ _g y=0x483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8_ _r=0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141_

To get an idea on the number of elements of the group, they're about _r_ ≈1077. Even if we had 1012 supercomputers performing over 1017 search points per second for a hundred million years we wouldn't even get close to inspecting all the possibilities. 

To be able to guarantee 128-bits of security, ECs need group orders near 256-bits (that is, orders with prime factors around 1077). This is because there are algorithms which can solve the problem doing operations around √r. If the largest prime is less than 94-bits long, it can be broken with help from a desktop computer. Of course, even if your group is large enough, nothing can save you from a poor implementation. 

The question arises: how can we know the number of elements of our EC? Luckily, math comes once again to our aid like the Hasse bound, Schoof's algorithm and how to test whether a number is prime or not. Next time we will continue revealing the math principles behind useful tools in cryptography.
