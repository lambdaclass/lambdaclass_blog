+++
title = "How to create your own crappy RSA as a software developer"
date = 2022-08-26
slug = "how-to-create-your-own-crappy-rsa-as-a-software-developer"

[extra]
feature_image = "/images/2025/12/Entrada_de_Roger_de_Flor_en_Constantinopla_-Palacio_del_Senado_de_Espan--a-.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["cryptography", "RSA"]
+++

## Introduction

One of the key developments in cryptography was the introduction of public key (or asymmetric) cryptosystems. These rely on pairs of keys: one of them is the public key (known to everybody) and the other is the private key (known only to the specific user). The public key is used to encrypt messages (anybody can do this since it is public), while the private key is used to decrypt the messages. This contrasts with symmetric encryption, where there is one key that can perform both operations (and was the only method available before the 1970s). This meant that a secure channel was needed to exchange/decide on the key, so that only certain priviledged parties were able to do cryptography. The real-time cryptography and the internet as we know it was enabled by public key cryptography. Depending on the method used, the keys could be numbers -for example, (RSA) or, in the case of elliptic curve cryptography (ECC), a number and a point of an elliptic curve. The algorithm of encryption and decryption is also publicly known, so the security of the whole system depends on never revealing the private key (this is known as [Kerckhoff's principle](https://en.wikipedia.org/wiki/Kerckhoffs%27s_principle)). Asymmetric cryptography plays a fundamental role in many applications and protocols, offering confidentiality, authenticity, and non-repudiability of data and electronic communications. Internet standards, such as TLS, SSH, and PGP rely on this cryptographic primitive.

RSA (named after Rivest, Shamir, and Adleman) is one of the first public key cryptosystems, the most widely used, and one of the simplest to understand and implement (1). We will discuss today how RSA works, how to implement its basic structure, and what are some of the pitfalls and weaknesses of this system (which have led to its losing ground against ECC).

We will be using some math and cryptography concepts below; you may want to review our math [survival kit](/math-survival-kit-for-developers/) first.

## How RSA works

### Non-rigorous mathematical idea

RSA relies on four key steps: key generation, key distribution, encryption, and decryption. Instead of describing each of them in sequence, we will give an overview of the whole process and then go into the details. The basic idea is the following: given a number $n$ (public), there are two numbers $e$ (public key, used for encryption) and $d$ (private key, used for decryption), which are multiplicative inverses (that is, $d\times e=1$, so $e=d^{-1}$). Given a message $M$, expressed as a number between $0$ and $n-1$, the encryption $E(M)$ is done by taking the $e$-th power of $M$,  
$E(M)=M^e$  
Decryption is done similarly by taking the $d$-th power of the encrypted message,  
${E(M)}d=(M{e})d=M{d\times e}=M$  
Of course, if you think in terms of high-school math, there are several problems, starting with the obvious fact that knowing $e$ allows you to calculate $d$ and that the encrypted message can grow into a very large number (and take a lot of space). This is where number theory and modular arithmetic come to our rescue.

### Steps

Let's now look in more detail at each of the steps and how we can get something that is very difficult to crack unless you know the secret key.

        1. Key generation:
        * Pick large random prime numbers $p$ and $q$ and keep them secret (2).
        * Calculate $n=p\times q$. $n$ is released as part of the public key parameters.
        * Compute the value of [Euler's totient function](https://en.wikipedia.org/wiki/Euler%27s_totient_function) $\phi(n)=(p-1)\times (q-1)$ and keep it secret (3).
        * Choose an integer $1<e<\phi(n)$ which is coprime to $\phi (n)$ (that is, their only common divisor is 1). $65537=2^{16}+1$ is a typical choice since it offers rather fast encryption and security. Another popular choice is $3$, but it is known that this leads to insecure encryption in many settings.
        * Calculate $d=e^{-1} \mod{\phi(n)}$, that is, $d$ is the multiplicative inverse of $e$ modulo $\phi(n)$ (4). This can be done via taking powers of $e$ or in a faster way using the [extended Euclidean algorithm](https://en.wikipedia.org/wiki/Extended_Euclidean_algorithm).
        2. Key distribution: If two people Alice and Bob want to communicate, each sends the other their public parameters $(e_A,n_A)$ and $(e_B,n_B)$. Of course, an obvious question arises, how do Bob and Alice know that they got each other's public parameters and not someone else's (the infamous man-in-the-middle)?
        3. Encryption:
        * Convert the message $P$ into an integer $1<m<n$ by using an agreed padding scheme.
        * $E(m)$ is calculated $E(m)\equiv m^e \pmod{n}$.
        4. Decryption:
        * Compute the message $m$ by doing ${E(m)}^d\equiv m \pmod{n}$.
        * Reverse the first step of encryption to convert $m$ to $P$.

### Example of the calculations

Let's pick a toy model to illustrate how the calculations are done (of course, no real model uses these simple numbers, because it is rather easy to break, even by brute force attempts).

        1. We choose two random primes 17 and 19.
        2. $n=17\times 19=323$
        3. We evaluate $\phi(323)=288$ or $\lambda(323)=144=lcm(16,18)$.
        4. We pick $e=5$ (remember, a small $e$ is not a good choice). We cannot pick $3$ because $3$ is not coprime to $\phi(n)=288=2^5 \times 3^2$.
        5. $d=5^{11}\equiv 29 \pmod{144}$. (We use Carmichael's totient function since it is faster). Let's check we did right: $5\times 29=145\equiv 1 \pmod{144}$, since $145=1\times 144+1$. An even faster alternative would be using the extended Euclidean algorithm.
        6. Our message is $11$. Therefore $E(11)=11^5\equiv 197\pmod{323}$.
        7. We now attempt to decrypt $197^{29}\equiv 11 \pmod{323}$

### The math behind the scenes

The trick works because we have two numbers $d$ and $e$, such that $d\times e \equiv 1 \pmod{\phi(n)}$. In other words, $d\times e=k\phi(n)+1$. If we perform encryption, followed by decryption, we get  
${(me)}d=m^{e\times d}=m^{1+k\phi(n)}=m\times (m{\phi(n)})k \equiv m \pmod{n}$  
The last step is a consequence of Euler's theorem, since  
$a^{\phi(n)}\equiv 1 \pmod{n}$, given $a$ and $n$ are coprime.

### Security issues

There are several issues with RSA, especially when it is not implemented properly. When generating random prime numbers, these must be truly random (therefore, always use a pseudorandom generator that works for cryptographic applications). Many attacks depend on getting to the factorization of the public parameter $n$. If we can find $p$ or $q$, then we get the other and we can calculate $\lambda (n)$ or $\phi(n)$, the multiplicative inverse of $e$, which is none other than the private key. For example, if $p$ and $q$ are very similar in length, we know $p \approx q \approx \sqrt{n}$ and Fermat's factorization as two squares $n=a2-b2$ is possible. It is easy to see that $a2-b2=(a+b)\times (a-b)$ and so we have both numbers. If we know many different $n$, we can try breaking the factorization by finding the least common divisor. For example, say we know for two people $n_1$ and $n_2$ and that they share a common factor $p$. Then we have $p=gcd(n_1,n_2)$ and the gcd can be found extremely fast (in polynomial time) thanks to Euclid's algorithm. This way, we break the security of both accounts.

Other methods work even if the factorization is not known. In the case of low exponents $e$ (such as $3$), it may happen that $M^3$ does not exceed the modulus $n$ and so it may be easily broken by taking the cubic root. On the other hand, if the private key is small, you can use [Wiener's](https://en.wikipedia.org/wiki/Wiener%27s_attack) or [Boneh-Durfree's attacks](https://eprint.iacr.org/2020/1214.pdf) and get the key. A collection of several strategies is on the following [link](https://github.com/RsaCtfTool/RsaCtfTool). You can build your own factorization methods or try using open source tools such as [SageMath](https://www.sagemath.org/) to try and see how easy is to perform the factorization of a composite number.

## Implementing some of the key functions

To be able to perform operations with RSA, we need to implement first some of the arithmetic operations and define field elements. We will show how to implement some of these in Rust.
    
    use::std::ops::{Add, Sub, Mul, Div};
    pub struct FieldPoint {
        num: u128,
        prime: u128,
    }
    

The first line imports the standard library (in particular, the operations of addition, subtraction, multiplication, and division) which will allow us to override these operators with the expressions we need to use in modular arithmetic.

In the second line, we define a public structure named `FieldPoint`, which has two fields: `num` (a number in the range 0 to prime) and `prime` (this will give us the size and we will perform all operations modulo prime). For practical applications, we need to replace the unsigned integers `u128` with appropriate variables that allow us to store large integers.

We can now instantiate some methods over `FieldPoint`, such as how to create one or how to multiply or divide field elements.
    
    impl FieldPoint {
        pub fn new(num: u128, prime: u128) -> FieldPoint {
            if num > prime {
                panic!("Not a valid input for a field point, num should be nonnegative and less than prime, obtained {}", num);
            } else {
                FieldPoint {num:num, prime:prime}
            }
        }
    }
    

Methods are defined following the keyword `impl` and the name of the `struct`. We have a constructor for the `FieldPoint`, which takes two unsigned `u128` integers.

To define addition, we can implement the trait `Add` for `FieldPoint` in this way
    
    impl Add for FieldPoint {
        type Output = Self;
        fn add(self, other: Self) -> Self {
            if self.prime == other.prime {
                FieldPoint {num: (self.num + other.num).rem_euclid(self.prime), prime: self.prime}
            } else {
                panic!("Cannot add these field points, different prime values {},{}",self.prime,other.prime);
            }
        }
    }
    

The addition is simply adding the `num` fields and if the result exceeds the modulus `prime`, we take the remainder of the Euclidean division between the sum and the modulus.

Multiplication works in a similar way
    
    impl Mul for FieldPoint {
        type Output = Self;
        fn mul(self, other: Self) -> Self {
            if self.prime == other.prime {
                FieldPoint {num: (self.num*other.num).rem_euclid(self.prime), prime: self.prime}
            } else {
                panic!("Cannot multiply these field points, different prime values, {},{}",self.prime,other.prime);
            }
        }
    }
    

We need to define the powers of `FieldElement`. We can do this in a rather efficient way by squaring and taking the remainder:
    
    pub fn power(&self,index: u128) -> Self {
            if index == 0 {
                FieldPoint {num: 1u128, prime: self.prime}
            } else {
                let mut aux=index.rem_euclid(self.prime-1u128);
                let mut acc: u128 = 1;
                let mut base: u128 =self.num;
                while aux >0{
                    if aux%2 == 0 {
                        base = (base*base).rem_euclid(self.prime);
                        aux=aux/2u128;
                    } else {
                        acc = (acc*base).rem_euclid(self.prime);
                        aux=aux-1u128; 
                    }
                }
                FieldPoint {num: acc, prime: self.prime}
            }
    
        }
    

The power function takes a `FieldElement` and `index`, a `u128`. If the index is $0$, the result is trivial and we output a `FieldElement` with `num` equal to $1$. In any other case, we first reduce `index` (if `index` exceeds `prime`, we can take the remainder of `index` by `prime-1` -this works when the modulus is prime since Euler's theorem says that $a^{p-1}\equiv 1 \pmod{p}$-. A better version would reduce `index` by $\phi(n)$) and store it in `aux`. We also define a variable to calculate the result `acc` and `base`, where we will repeatedly square and take the remainder of the `num`.

We now focus on the squaring and the updating of the result:
    
    while aux >0{
        if aux%2 == 0 {
            base = (base*base).rem_euclid(self.prime);
            aux=aux/2u128;
        } else {
            acc = (acc*base).rem_euclid(self.prime);
            aux=aux-1u128; 
        }
    }
    

We will go decreasing the index stored in `aux`: if it is even (the first condition -this could be checked much faster, by inspecting the last bit of `aux`-), we divide `aux` by two and update `base` to the remainder of its square. If it is odd, then we proceed to update the result in `acc` and decrease `aux` by one (which means that in the next step it will be even).

To convince ourselves, let's take a short numerical example, while we follow the instructions. Let's take `prime` as 11, `num` as 4, and `index` as 39.

        1. We set `aux` equal to the remainder of 39 and 10 (which is also $\phi(11)$). We get `aux=9`.
        2. Since $9>0$, we go inside the while loop. $9$ is odd, so `acc=9` and `aux=8`.
        3. `aux` is even, so `base=4*4=16`; we have to reduce the number by taking the remainder by $11$, so `base=5` and `aux=4`.
        4. `aux` is even, so `base=5*5=25` and we get `base=3` and `aux=2`.
        5. `aux` is once again even, `base=9` and `aux=1`.
        6. `aux` is odd, we get `acc=9*4=36->3` and `aux=0`.
        7. Since `aux=0`, we jump outside the while loop and the function returns the `FieldPoint` (`num`=3,`prime`=11).

Another function that we need is the greatest common divisor. A very simple form of the algorithm looks like this
    
    pub fn gcd(a: u128,b: u128) -> u128 {
        let mut r0: u128=b;
        let mut r1: u128=a;
        if a>b {
            r0 = b;
            r1 = a;
        } 
        let mut r2: u128 = 1;
        while r2 >0 {
            r2=r1.rem_euclid(r0);
            r1=r0;
            r0=r2;
        }
        r1
    }
    

We take two numbers $a$ and $b$ and we output their greatest common divisor. If $a$ is smaller than $b$ we initialize the dividend as $b$ and the divisor as $a$ (this makes us chop the larger number by the smaller one); otherwise we invert the selection. Next, we begin by reducing $r_1$ by $r_0$ and we change the roles (since $r_2$ is smaller then $r_0$). A numerical example helps illustrate the points:

        1. Take a=12, b=8 (we can immediately see that the right answer is 4, but this helps us see how the algorithm finds it).
        2. $r_0=8$, $r_1=12$, $r_2=1$ so we immediately enter the while loop.
        3. $r_2=4$ since the remainder of $12$ divided by $8$ is 4.
        4. $r_1=8$ and $r_0=4$.
        5. Since $r_2$ is not zero, we keep it inside the loop.
        6. $r_2=0$ (since $8$ is divisible by $4$), $r_1=4$ and $r_0=0$.
        7. Now $r_2=0$ so we exit the loop and the function outputs $gcd=4$.

Carmichael's totient function can be easily calculated with the help from the previous function:
    
    pub fn lambda(p: u128,q: u128) -> u128 {
        let greatest_div: u128=gcd(p-1,q-1);
        (p-1)*(q-1)/greatest_div
    }
    

Inverses can be easily calculated with help from the extended Euclidean algorithm:
    
    pub fn inversion(a:i128,b:i128) -> i128 {
        let mut t=0i128;
        let mut r=b;
        let mut t1=1i128;
        let mut r1=a;
        while r1 != 0i128 {
            let q=r.div_euclid(r1);
            (t,t1)=(t1,t-q*t1);
            (r,r1)=(r1,r-q*r1);
        }
        if r != 1i128 {
            return 0i128;
        }
        if t<0{
            t=t+b;
        }
        t
    }
    

Let's see how it works for a simple case: $a=3$, $b=5$; the inverse of $3$ (modulo 5) is $2$. The algorithm begins:

        1. $t=0$, $t_1=1$, $r=5$, $r_1=3$.
        2. Since $r_1=3 \neq 0$ we loop: $q=1$, $t=1$, $t_1=0-1\times 1=-1$, $r=3$, $r_1=2$.
        3. $r_1 \neq 0$, $q=1$, $t=-1$, $t_1=1-1\times (-1)=2$, $r=2$, $r_1=1$.
        4. $r_1 \neq 0$, $q=2$, $t=2$, $t_1=-1-2\times 2=-5$, $r=1$ and $r_1=0$.
        5. $r_1 = 0$, so the function outputs $t=2$, which is the correct answer.

We can test primality using the [Miller-Rabin test](https://en.wikipedia.org/wiki/Miller%E2%80%93Rabin_primality_test). Given an odd number $n$, we can write it as $n=2^r\times d +1$, for some $r> 0$ and $d$ an odd number. If $d$ is prime, then:  
$a^d \equiv 1 \pmod{n}$  
$a{2r \times d}\equiv -1 \pmod{n}$  
If $n$ is prime, then it satisfies Fermat's little theorem and the only square roots of $1$ are $-1$ and $1$. If any of these conditions is not fulfilled, $n$ is not prime (if it passes, it could be composite, depending on the choice of $a$, known as the witness). Checking several $a$ allows us to make sure that the test passed for a composite number. The decomposition is easy to do:
    
    pub fn decompose(n: u128) -> (u128,u128) {
            let mut d: u128=n-1;
            let mut r: u128=0;
            while d%2 == 0 {
                d /= 2;
                r += 1;
            }
            (d,r)
        }
    

Since $n-1$ is even, we can take factors of $2$ repeatedly, until $d$ is no longer divisible by $2$. The condition can be checked faster by looking at the last bit of $n-1$.

The core of the Miller-Rabin test is (it yields true if it is probably prime):
    
    fn miller_rabin(a: u128, n: u128, d: u128, r: u128) -> bool {
            let n_minus_one: u128 = n - 1u128;
            let field=FieldPoint::new(a,n);
            let mut x = field.power(d);
            let mut count: u128 =1;
            if x.num == 1 || x.num == n_minus_one {
                return true;
            }
            while count < r {
                x = x.power(2u128);
                if x.num == n_minus_one {
                    return true;
                }
                count += 1u128;
            }
            false
        }
    

If you have a composite number and try several witnesses, it is very likely it will fail at least one (and stop at the first one) and so we can discard the number.

## Summary

We covered the basics of RSA and discussed its mathematical foundations. We also gave some of the attacks it may subjected to, especially when the implementation is not done properly. Finally, we gave some of the basic functions to build RSA (such as modular powers, calculating inverses and checking for primality via the Rabin-Miller test). Even if you could build your own RSA from scratch, it is not advisable, since it could be vulnerable to several attacks (unless it is very well implemented, of course).

## Notes

(1) Even if you can code it very fast, there is no guarantee that your implementation is useful for real-life. There are several things to check and one should try to follow the standards. Besides, you should know cryptography and understand some of the underlying math).  
(2) For security reasons, $p$ and $q$ should have different number of digits (unless you want your system to be vulnerable to [Fermat's factorization](https://en.wikipedia.org/wiki/Fermat%27s_factorization_method)) and the selection should be truly random (careful with pseudorandom generators which are not meant for cryptographic applications, they are part of the recipe for disaster).  
(3) If you want something better, compute [Carmichael's totient function](https://en.wikipedia.org/wiki/Carmichael_function) $\lambda (n)=lcm(q-1,p-1)$, where $lcm$ stands for least common multiple of $q-1$ and $p-1$. Whenever $\phi$ shows up, you can replace it with $\lambda$.  
(4) This is the same as saying that $d\times e-1$ is divisible by $\phi(n)$ or $d\times e=k\phi(n)+1$ for some integer $k$. [Euler's theorem](https://en.wikipedia.org/wiki/Euler%27s_theorem) states that $a^{\phi(m)}\equiv 1 \pmod{m}$ if $a$ and $n$ are coprime.  
If we take $m=\phi(n)$ and $a=e$ we see that $e\times e^{\phi(\phi(n))-1}\equiv 1 \pmod{\phi(n)}$, $d=e^{\phi(\phi(n))-1}$, which means that $d$ can be calculated by performing powers of $e$.
