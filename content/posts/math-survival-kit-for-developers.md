+++
title = "Math Survival Kit for Developers"
date = 2022-08-19
slug = "math-survival-kit-for-developers"

[extra]
feature_image = "/images/2025/12/Gallen_Kallela_The_Forging_of_the_Sampo.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["Math", "cryptography"]
+++

## Introduction

When working with cryptographic applications you need to understand some of the underlying math (at least, if you want to do things properly). For example, the RSA cryptographic system (which was one of the earliest methods and most widely adopted, until it lost ground to better methods, such as those based on elliptic curves) works by encrypting a message $M$ (expressed as a number in the range 1,2,3,...$n-1$, with $n$ a large composite number) with a public key $e$ doing the following calculation:  
$E(M)=M^e \pmod{n}$  
If you want to decrypt the message, you need the private key, $d$ and perform:  
$M=E(M)^d \pmod{n}$.  
Now, what do all these calculations mean and why does RSA work? The trick relies on Euler's theorem and the fact that $d$ and $e$ are related by $d\times e \equiv 1 \pmod{\phi(n)}$, so that when we apply $e$ and afterward $d$, "it is the same as" elevating the message to 1. Of course, there are quite many symbols you might not understand, but some key concepts are, in fact, quite straightforward. They are just shrouded in the mist by all the math jargon, which makes things very easy to state for those knowing the meaning, but it can be quite challenging for someone who is not acquainted with them.

Another problem frequently showing up is finding prime numbers (in general, very large numbers, with 100 or more digits) or determining whether a certain number is prime or composite. For example, in zk-SNARKs (zero-knowledge succinct non-interactive arguments of knowledge), one of the key ingredients is the ability to perform (something similar to) homomorphic encryption. This is achieved in practice by pairing two elliptic curves over two sets of numbers, where the total number of elements is the prime $m$, satisfying $m=k\times 2^N+1$, with $k$ an odd number and $N$ a large number. We say that $m$ has large 2-adicity and is expressed in compact form as $m-1\equiv 0 \pmod{2^N}$ or $2^N \mid m-1$ (this is read as $2^N$ divides $m-1$). In RSA, the number $n$ is the product of two large prime numbers, $p$ and $q$, that is, $n=p\times q$. If you choose two primes that are very close to each other, your cryptographic system could be easily broken using [Fermat's method to factorize numbers](https://en.wikipedia.org/wiki/Fermat%27s_factorization_method).

We see, therefore, that we need to understand the math behind it to know which tricks we can apply to solve a problem easily, how to break a cryptographic system or what are the limitations or weaknesses of our own systems. We will be explaining many key ideas of number theory and abstract algebra to help you build the foundations you need to deal with cryptography.

## Natural numbers, Integers, Rational, Real and Complex numbers.

Natural numbers are those we use to count objects and were the first things we learned at school: $1,2,3,4...$ are natural numbers. The set (collection) of these numbers is frequently represented by $\mathbb{N}$. Numbers like $-1$, $-2$, $0$, etc, are part of the integers; the set is represented by $\mathbb{Z}$ (from German, _zahlen_ , numbers). Numbers that can be expressed as the ratio of two integers $a$ and $b$ (with $b\neq 0$) are called rational, $r=a/b$ and the set is denoted by $\mathbb{Q}$. Rational numbers can be extended with the addition of irrational numbers (such as $\pi$ and $e$) to form the set of real numbers $\mathbb{R}$. You might have also heard of the complex numbers $\mathbb{C}$, which contain numbers such as $i$, where $i^2=-1$.

In the integers, we have the four basic operations: addition, subtraction, multiplication and division. Let's focus first on addition and subtraction:  
If we take $a$ and $b$ in $\mathbb{Z}$, then $c=a+b$ and $d=a-b$ are also in $\mathbb{Z}$. We say the sum and subtraction are closed operations on the set.  
2\. If we add $0$ to any number $a$, we get $a$, that is, $a+0=0+a=a$. $0$ is the additive identity of $\mathbb{Z}$.  
3\. We know that if we sum $a$ and $-a$ we get $0$. That is, $a+(-a)=a-a=0$, so subtracting is the same as adding $-a$. $-a$ is the additive inverse of $a$.  
4\. Given $a$, $b$ and $c$, $a+(b+c)=(a+b)+c$. This is the associative property.

## Groups

The above properties show that the set of integers $\mathbb{Z}$ with the $.+.$ operation form an algebraic group. Other sets, combined with different operations, have the same mathematical structure. For example, positive rational numbers with multiplication have a group structure. $n\times n$ invertible matrices form a group under the matrix multiplication. [Vector spaces](https://en.wikipedia.org/wiki/Vector_space) form a group under the addition (if you take any two vectors $u$ and $v$, their sum is always in the vector space). Elliptic curve cryptography uses the fact that adding two points over an elliptic curve always results in a third point over the curve. Groups appear in many applications in Mathematics, Physics and Chemistry. We can define a group as a (non-empty) set $G$ together with a binary operation (that is, an operation that takes two input elements from the set $G$) $\times$ satisfying:  
G1. If $a$ and $b$ are in the set, then $a\times b=c$ is also in the set.  
G2. There is an identity element, $e$, such that $e\times a=a\times e=a$.  
G3. If $a$ is in the set, there is some $b$ in the set such that $a\times b=e$. We say that $b$ is the inverse of $a$ and denote it $b=a^{-1}$.  
G4. For $a,b,c$, $a\times (b\times c)=(a\times b)\times c$.

The notation in groups is sometimes confusing and people can freely use additive (+) or multiplicative ($\times$) notation, and call their identities either $0$ or $1$. This doesn't matter much, since the binary operation can be quite weird (such as "addition" on elliptic curves). If you can start by looking at things a little bit more abstractly, it will pay off very quickly.

_Exercise: Take the space of $n\times n$ matrices, such that their determinant is non-zero (that is, the set of invertible matrices). Show that this is a group._

We also learned at school that addition in the integers is commutative (that is, the order of the factors does not change the result $a+b=b+a$). Not all groups satisfy this condition, though. For those privileged groups, we have the name Abelian (or commutative) group. An Abelian group has an additional condition:  
G5. If $a$, $b$ are in $G$, $a\times b = b\times a$.

When we look at multiplication and division in the integers, we see that there are some problems.

        1. If $a$ and $b$ are integers, $a\times b=c$ is also an integer. The operation is closed under multiplication.
        2. If we multiply any number by $1$, we get the same number. $1$ is the multiplicative identity.
        3. Given $a,b,c$, we have $a\times (b\times c)=(a\times b)\times c$.
        4. Given $a$, $b$ and $c$, $a\times (b+c)=a\times b+a\times c$ and $(b+c)\times a=b\times a+c\times a$. This is the distributive property.
        5. If $a$ and $b\neq 0$ are integers, their division $a/b$ is not necessarily an integer. For example, $a=3$ and $b=2$ results in $c=3/2$, which is a rational (not integer) number. In other words, the operation is not closed.

## Rings and fields

The set $\mathbb{Z}$ together with addition and multiplication forms a ring. The polynomials with ordinary addition and multiplication also form a ring. $n\times n$ matrices also form a ring under addition and multiplication. Formally, a ring is a set $R$ with two operations $+$ and $\times$ such that:

        1. R is an abelian group under $+$ (that is, R fulfills all the conditions for a group G1 to G4, plus commutativity, G5).
        2. There is a multiplicative identity $e$, such that $a\times e=e\times a=a$. Frequently, we use $e=1$.
        3. Multiplication is associative.
        4. We have the distributive property of multiplication concerning addition.

_Exercise: Check that the $n\times n$ matrices form a ring with ordinary matrix addition and multiplication._

If we look at the rational numbers, for any non-zero element, we have a multiplicative inverse. For example, $1/5$ is the multiplicative inverse of $5$, since $5\times 1/5=1$. The division is now a closed operation. Besides, multiplication is also commutative. $\mathbb{Q}$ with the ordinary addition and multiplication is a field. Other examples of fields are $\mathbb{R}$ and $\mathbb{C}$. When the number of elements in the set is finite (such as $4$, $2^{255}-19$, etc), the field is known as a finite field. These will be very important for cryptography.

## Some concepts from number theory

### Divisibility

We will start by talking about divisibility. Given two natural numbers, $a$ and $b$, we say that $a$ divides $b$ (and write it $a\mid b$) if there is another number $c$ such that $a\times c=b$. $a$ is called a divisor of $b$. If $a$ does not divide $b$, we write $a\nmid b$ and we can write $b=q\times a+r$, where $r<a$, with $q$ the quotient and $r$ the remainder of the division. If $a$ divides $b\times c$, then $a\mid b$ or $a\mid c$. Another fact is that if $a\mid b$ and $a\mid c$, then $a\mid (x\times b+y\times c)$ for any numbers $x,y$.

### Prime Numbers

A number $p>1$ is called prime if its only divisors are $1$ and itself. Otherwise, the number is composite. Examples of prime numbers are $2,3,5,7,11,13,17,19,23,29,31,...$. The [fundamental theorem of arithmetic](https://en.wikipedia.org/wiki/Fundamental_theorem_of_arithmetic) tells us that any number can be expressed in a unique way (up to ordering) as a product of powers of prime numbers. For example, $20=2^2\times 5$, $186=2\times 3\times 31$, $5=5$, etc. Finding prime numbers is crucial for cryptography. One easy way (but by no means practical for large numbers) to see whether a number $p$ is prime or not consists in checking whether it is divisible by all primer numbers smaller than $p$. The problem is that, if $p$ is very large, this can be pretty inefficient. There are some better and faster algorithms, but we will cover them some other time.

_Exercise: Find all prime numbers that are smaller than 100._

### Greatest common divisor and Euclid's algorithm

An important concept is that of the greatest common divisor: given two numbers $a$ and $b$ we want to find the largest number $c$ such that $c\mid a$ and $c\mid b$. We denote this by $c=gcd(a,b)$ or simply $c=(a,b)$. For example, $20=2^2\times 5$ and $50=2\times 5^2$. Both numbers are divisible by $1,2,5,10$. $10$ is the greatest number dividing both and so $gcd(20,50)=10$. Two numbers $a,b$ are called relatively prime (or coprime) if $gcd(a,b)=1$. If $a$ and $b$ are both prime (and different), $1$ is the only common divisor. However, $8$ and $9$ are not prime themselves ($8=2^3$ and $9=3^2$), but their only common divisor is $1$ and are coprime.

The greatest common divisor satisfies the following equation, for some $x$ and $y$:  
$x\times a+y\times b=gcd(a,b)$  
The greatest common divisor can be found very efficiently using the [Euclidean algorithm](https://en.wikipedia.org/wiki/Euclidean_algorithm) and the numbers $x$ and $y$ can also be found with little extra cost using the extended Euclidean algorithm.

To understand the algorithm, let's look at an example: say we want to calculate the gcd(2502,864). The algorithm takes advantage that the remainder is always less than the divisor, so we can "chop down" the larger number; this chopping does not affect the largest common divisor.

        1. Let's find the remainder of $2502/864$, $r_0=774$.
        2. Let's find the remainder of $864/774$, $r_1=90$.
        3. The remainder of $774/90$ is $r_2=54$.
        4. $r_3=36$
        5. $r_4=18$
        6. $r_5=0$, since $36$ is divisible by $18$. So, the greatest common divisor is $18$.

We can see, from the factorization of $864=2^5\times 3^3$ and $2502=2\times 3^2\times 139$, that the $gcd$ is equal to $2\times 3^2=18$. The advantage is that we found it in a few steps (6) and we didn't have to know the factorization (which, for large numbers can be really hard to find. As a matter of fact, that is the key to the RSA cryptosystem).

### Congruences and modular arithmetic

One problem we face with computers is that the numbers we can work with are limited. Besides, in some cases, we are not interested in a number itself, but rather in its belonging to a certain class or group. For example, when we bet on a roulette, we can choose whether the result will be even or odd. If it is even, then $r=2\times k$, for some $k \in {0,1,2,3...18}$. If it is odd, then $r=2\times k+1$. We notice that if we want to check parity, we only need to look at the remainder, which can take two values in this case: $0$ or $1$. In fact, when we want to check whether a number is even in the computer, we look at the leftmost bit and check whether it is zero or not. For the case of $2$, we see that any number $a$ satisfies either:  
$a\equiv 0 \pmod{2}$  
$a\equiv 1 \pmod{2}$  
We say that $a$ is congruent to $0$ (or $1$) modulo $2$. This way, we split all the numbers into two categories: even and odd. We can do the same for any number $p>1$, remembering that the remainder is $0 \leq r \leq p-1$. This can also be seen as $a\equiv r \pmod{p}$ as $p\mid a-r$ or $a=k\times p+r$. This notation was invented by Gauss and is really powerful to study a lot of complex problems. We can perform usual operations such as addition and multiplication, but we have to be careful of how things work, given that results will always have to be in the range $0 \leq r \leq p-1$ (As a side note, you could choose a different range, such as ${-2,-1,0,1,2,p-3}$, but it can be confusing and we should better stick to our first choice).

In the case of the sum, we can add them just as regular numbers and, if the result exceeds $p$, take the remainder. For example, let's take $p=7$, so the elements we have are ${0,1,2,3,4,5,6}$. First, we see that $0$ is an element of the set and that adding it to any number does not change the result. If we add $2$ and $3$ the result is $5$. If we add $5$ and $4$, we get $9$, but  
$4+5=9\equiv 2 \pmod{7}$  
$2$ is just the remainder of the division of $9$ by $7$. We see that the result stays in the original set. What happens when we add $4$ and $3$?  
$4+3=7\equiv 0 \pmod{7}$  
We get $0$! That is because $7$ is divisible by itself and the remainder is $0$. We see that $4$ is the additive inverse of $3$ under this arithmetic. Similarly, $1$ and $6$ are each other's inverse, $2$ and $5$. We can recognize that the set ${0,1,2,3,4,5,6}$ with the sum done modulo $7$ is an abelian group. Subtraction can be easily defined as adding the inverse of the number or just performing ordinary subtraction and then taking the result modulo $p$.

With multiplication we get something similar. For example,  
$4\times 5=20\equiv 6 \pmod{7}$.  
Taking the modulo operation ensures that we always stay inside the set. We also see that $1$ works as the multiplicative identity since any number multiplied by $1$ stays the same. Let's look at what happens with $6\times 6$:  
$6\times 6=36\equiv 1 \pmod{7}$.  
We multiplied $6$ by itself and got $1$! We talked before that division $a/b$ could be restated as $a\times b^{-1}$, where $b\times b^{-1} = 1 = b^{-1} \times b$. We see that $6$ is its own multiplicative inverse with the multiplication modulo $p$. We can also see that:  
$3\times 5 = 15\equiv 1 \pmod{7}$  
$2\times 4 = 8\equiv 1 \pmod{7}$  
So, $3 = 5^{-1}$ and $2 = 4^{-1}$! This can sound weird, but we have to remember that we are working with congruence. We can understand the precise meaning of this by rephrasing. Let's take the case of $6$ and $6$. There are two numbers $a = q_1\times 7+6$ and $b = q_2\times 7+6$ (because that is what the congruence means). Let's take the product $a\times b$:  
$a\times b = (q_1\times 7+6)\times (q_2\times 7+6)$  
Let's apply the distributive law:  
$a\times b = q_1\times q_2 \times 7^2+6\times 7\times (q_1+q_2)+36$  
Let's split this further $36=1+35=1+7\times 5$ and regroup, taking as a common factor $7$:  
$a\times b = 7\times (q_1\times q_2\times 7+6\times(q_1+q_2)+5)+1$  
The first term is divisible by $7$, so it is congruent to $0$. Or, if we subtract $1$ to $a\times b$, we see that it is divisible by $7$ (since it is the product of $7$ and an integer).

We can see that, if $p$ is prime, then the set ${0,1,2,...p-1}$ with addition and multiplication modulo $p$ is a finite field.

_Exercise: Prove that this is indeed a finite field._

### $\mathbb{Z}/n\mathbb{Z}$ as a group. Cyclic groups.

You will frequently see these sets are denoted as $\mathbb{Z}/p\mathbb{Z}$. We have to be very careful if we want to work with $n$ not prime in $\mathbb{Z}/n\mathbb{Z}$ (in this case, it is not a finite field either). For example, let's try to solve this equation:  
$(x+2)\times(x+1)\equiv 0 \pmod{12}$  
We could use our knowledge of math and, when the product of two numbers is $0$, at least one of them is $0$ (spoiler's alert: this will go wrong):

        1. $(x+2)\equiv 0 \pmod{12}$. If $x=10$, then $x+2=12\equiv 0$, since it is divisible by 12.
        2. $(x+1)\equiv 0 \pmod{12}$. If $x=11$, then $x+1=12\equiv 0$, since it is divisible by 12.  
Let's pick now $2$ and see what happens:  
$(2+2)\times(2+1)=12\equiv 0 \pmod{12}$.  
So $2$ is a solution to the equation, but $2+2\equiv 4\not\equiv 0$ and $2+1\equiv 3\not\equiv 0$. This happens because $12$ is not a prime number.

As a matter of fact, given $a$ and $n$, we have that $a$ has an inverse (modulo $n$) if and only if $gcd(a,n)=1$, that is, $a$ and $n$ are coprime. In the previous example, $3$ is not coprime to $12$ (they have $3$ as a common divisor).

If the set is not too large, we can find inverses just by trial and error. However, it would be nice to have some results that help us compute inverses and how to calculate (integer) powers of numbers.

Let's focus on a prime number $p$ and take all the non-zero elements of the set, $(\mathbb{Z}/p\mathbb{Z})^\star$. Let's fix $p=7$, so $(\mathbb{Z}/p\mathbb{Z})^\star = {1,2,3,4,5,6}$ and let's focus on multiplication over the set. We can define the power $a^n=a\times a\times a\times ...\times a$. Obviously, $1$ is not interesting, because $1^n=1$, so let's take $5$:  
$5^1\equiv 5 \pmod{7}$  
$5^2\equiv 4 \pmod{7}$  
$5^3\equiv 6 \pmod{7}$  
$5^4\equiv 2 \pmod{7}$  
$5^5\equiv 3 \pmod{7}$  
$5^6\equiv 1 \pmod{7}$  
$5^7\equiv 5 \pmod{7}$  
$5^8\equiv 4 \pmod{7}$  
$5^{13}\equiv 5 \pmod{7}$  
We see that the powers of $5$ span all the elements of the group. We also see that numbers repeat themselves at an interval of $6$, that is $4 = 5^2 = 5^8 = 5^{14}...$. Let's look at $3$:  
$3^1\equiv 3 \pmod{7}$  
$3^2\equiv 2 \pmod{7}$  
$3^3\equiv 6 \pmod{7}$  
$3^4\equiv 4 \pmod{7}$  
$3^5\equiv 5 \pmod{7}$  
$3^6\equiv 1 \pmod{7}$  
$3^7\equiv 3 \pmod{7}$  
We got all the elements (albeit in a different order). Finally, let's look at $2$:  
$2^1\equiv 2 \pmod{7}$  
$2^2\equiv 4 \pmod{7}$  
$2^3\equiv 1 \pmod{7}$  
$2^4\equiv 2 \pmod{7}$  
This time we didn't span all the elements of the group and we got to the same number after $3$. We will show that these results are valid in general (provided we're working modulo a prime number).

First, we can prove that the set $(\mathbb{Z}/ p\mathbb{Z})^\star$ together with multiplication forms an abelian group (the product can never give 0 since all the numbers are not divisible by $p$). Second, the group is finite, since the number of elements is finite (6 in our example); its order is $6$. We also saw that by repeatedly multiplying $5$ by itself (that is, taking powers of $5$), we can generate all the elements of the group (note that everything repeats after $6$, which is the order of the group). Since the group can be generated by one of its elements, it is a (finite) cyclic group.

For an element $a$, the lowest positive integer $n$ such that $a^n\equiv 1 \pmod{p}$ is known as the order of $a$. The elements of the group with their respective order in parentheses are: $1 (1)$, $2 (3)$, $3 (6)$, $4 (2)$, $5(6)$, $6(2)$. We can see that the orders of each element divide the order of the group, $6$. We will present the following theorems, which show that this is not a coincidence.

### Three useful theorems and the magic behind RSA

[Fermat's Little Theorem](https://en.wikipedia.org/wiki/Fermat%27s_little_theorem): If $p$ is prime, then, for any integer $a$ we have that $a^p-a$ is divisible by $p$:  
$a^p\equiv a \pmod{p}$.  
_Exercise: Check that this is indeed valid for all elements of $(\mathbb{Z}/7\mathbb{Z})^\star$_  
If $a$ is coprime to $p$, we can write this equivalently:  
$a^{p-1}\equiv 1 \pmod{p}$  
An interesting consequence is that we can calculate inverses by doing $a^{-1} = a^{p-2}$, even though in some cases we are overestimating the power (for example, $6\times 6\equiv 1 \pmod{7}$).

[Euler's theorem](https://en.wikipedia.org/wiki/Euler%27s_theorem): If $a$ and $n$ are positive coprime integers, then $a^{\phi(n)}\equiv 1 \pmod{n}$, where $\phi(n)$ is [Euler's phi (or totient) function](https://en.wikipedia.org/wiki/Euler%27s_totient_function).

Euler's $\phi(n)$ function counts the numbers $m < n$ that are coprime to $n$. For example, if we take $n = 5$, the numbers $1,2,3,4$ are all coprime to $5$ and $\phi(5) = 4$ (this is reasonable, since $5$ is prime). If we take $8$, we have ${ 1 , 2 , 3 , 4 , 5 , 6 , 7}$; however, only $1,3,5,7$ are coprime to $8$, so $\phi(8)=4$. For prime numbers, we have  
$\phi(p)=p-1$  
so, Euler's theorem gives us Fermat's theorem as a particular case. Another useful property is that if $m$ and $n$ are relatively prime, then  
$\phi(m\times n)=\phi(n)\times \phi(m)$  
This shows that $\phi$ is a [multiplicative function](https://en.wikipedia.org/wiki/Multiplicative_function). In particular, if $n$ is the product of two primes, $p$ and $q$, then  
$\phi(n) = (p-1)\times (q-1)$  
RSA's working principle is here. The public key $e$ and private $d$ are multiplicative inverses, modulo $\phi(n)$,  
$d\times e \equiv 1 \pmod{\phi(n)}$  
This means that $d\times e = 1+k\phi(n)$ for some integer $k$, so when we compute  
$M^{ e \times d } = M^{ 1 + k \phi(n) } = M \times M^{ k \phi(n) } \equiv M \pmod{n}$  
since $M^{k \phi(n) } = {(M^{ \phi(n) })}^k \equiv 1^k \pmod{n}$. RSA is only as hard as it is factoring the number $n$ and over the years the length of the keys has increased significantly (it is around 2000 to 4000 bits); elliptic curves, on the other hand, give the same level of security for shorter keys.

### Subgroups. Lagrange's theorem

We saw that the order of $(\mathbb{Z}/7\mathbb{Z})^\star$ was 6 and that if we take any element $a$, doing $a^6\equiv 1 \pmod{7}$. However, for $2$ we can do $2^3\equiv 1 \pmod{7}$. A subgroup $H$ is a subset of $G$, that is itself a group, that is, satisfies G1-G4. For example, if we consider the subset $H={1}$, this is a subgroup of order $1$. Why? Because $1\times 1=1$, so the operation is closed and all other properties follow from the operations of the group $G$. $G$ is also a subgroup of itself. These two are called the trivial subgroups of $G$ (which are not very interesting). The set ${1,2,4}$ is a subgroup of $(\mathbb{Z}/7\mathbb{Z})^\star$. To check this, we need to see that if an element is in the set, so is its inverse, the identity belongs to the set and the operation is closed. Let's check this:

        * $1$ is in the set and $1$ is its own inverse.
        * The operation is closed, because $2\times 2\equiv 4 \pmod{7}$, because $4\times 4=16\equiv 2 \pmod{7}$ and because $2\times 4=8\equiv 1 \pmod{7}$ (we don't need to check the products with $1$ since that is obvious). We also checked the inverses, since $4=2^{-1}$.

The subset ${1,2,4}$ forms a subgroup of order $3$. [Lagrange's theorem](https://en.wikipedia.org/wiki/Lagrange%27s_theorem_\(group_theory\)) states that the order of a subgroup divides the order of the group. We have another subgroup ${1,6}$, which is of order $2$. These are non-trivial subgroups. If the order of a group is prime, then its only subgroups are the trivial subgroups (since $p$ is prime, the subgroups can only be of order $1$ and $p$). A group whose only subgroups are the trivial ones is known as a simple group. For example, $\mathbb{Z}/7\mathbb{Z}$ with addition is the group ${0,1,2,3,4,5,6}$ of order $7$. There are no subgroups other than the whole group and ${0}$. Note that the order of each element (other than zero, which has order $1$) is $7$, since $7\times a=a+a+a+a+a+a+a$ is divisible by $7$ and, therefore, congruent to $0$ modulo $7$. The fact that some groups can be broken down into smaller subgroups is of concern when working with elliptic curves: if the group is not of prime order, it can be broken down into smaller groups and an attacker may break the system by performing searches on these subgroups.

### The discrete logarithm problem

Given a group, we can apply the operation repeatedly on a point $g$ to get to a point $P$, that is $g^k=g\times g\times g\times ... \times g=P$. For example, in $(\mathbb{Z}/7\mathbb{Z})^\star$, $5$ generates all the elements by successive multiplications with itself. We could then ask how many times $x$ should we multiply $5$ with itself to get to $3$, that is, $5^x\equiv 3 \pmod{7}$. Since we know that the order of the group is $6$, we should only concern ourselves with numbers $0-6$. If we look above or try all combinations, $5^5\equiv 3 \pmod{7}$ so $x=5$. Similarly, if we look for $y$ such that $5^y\equiv 4 \pmod{7}$, we get $y=2$. The problem of finding $x$ so that $g^k=P$ is known as the discrete logarithm problem (in number theory, $x$ and $y$ are known as indices). We quickly see that this logarithm works quite differently from the common logarithm on the real numbers (though the idea is the same, given $y$, find $x$ such that $e^x=y$). There is no obvious pattern, it is not increasing and if we had to search over a large set, it could be really daunting. Many cryptographic systems rely on the hardness of this problem over a finite cyclic group.

## Summary

We presented some basic terms and concepts from number theory and algebra that will be useful when reading cryptography, since many key concepts and strategies rely on math. The notions of groups, rings and fields and prime numbers show up almost all the time. Soon we will continue with other important tools and concepts that will help us understand how elliptic curve cryptography works, how to perform faster operations over groups and how to combine elliptic curves to build zk-SNARKs.
