+++
title = "How we implemented the BN254 Ate pairing in lambdaworks"
date = 2024-08-20
slug = "how-we-implemented-the-bn254-ate-pairing-in-lambdaworks"

[extra]
feature_image = "/images/2025/12/Vernet-_Horace_-_The_pope_Iulius_II_orders_the_works_of_Vatican_and_Saint-Peter_basilica_-_Louvre_INV_8364.jpg"
authors = ["LambdaClass"]
+++

## Introduction

The elliptic curve BN254 is currently the only curve with precompiled contracts on Ethereum, making it the most practical choice of a pairing-friendly curve suitable for on-chain [zk-SNARK](/pinocchio-verifiable-computation-revisited/) verification with proof systems such as [Groth16](/groth16/) and [PlonK](/all-you-wanted-to-know-about-plonk/). This work arises from the need to have our [own implementation of the BN254 Ate pairing](https://github.com/lambdaclass/lambdaworks/blob/main/math/src/elliptic_curve/short_weierstrass/curves/bn_254/pairing.rs). The idea of this post is to serve as a companion for our implementation, explaining the mathematical theory and algorithms needed to understand it. Several papers and articles present different algorithms for this pairing and its functions, so we thought organizing all that information into a single post would be helpful.

Regarding the mathematical background necessary to follow this reading, we only assume a slight notion of Groups, Finite Fields, and Elliptic Curves. If you do not feel confident in those topics we recommend reading our posts [Math Survival Kit for Developers](/math-survival-kit-for-developers/) and [What Every Developer Needs to Know About Elliptic Curves](/what-every-developer-needs-to-know-about-elliptic-curves/).

## Curve Parameters

The BN254 (in Lambdaworks `BN254Curve`) is the Barreto-Naehrig pairing friendly elliptic curve $E$ of the form  
$$y^2 = x^3 + 3$$  
over a finite field $\mathbb{F_p}$ where:

        * $p = 36x^4 + 36x^3 + 24x^2 + 6x + 1$ is the 254-bit prime number:
    
    p = 21888242871839275222246405745257275088696311157297823662689037894645226208583
    x = 4965661367192848881
    

        * $t = 6x^2 + 1$ is the trace of Frobenius.
        * $r = 36x^4 + 36x^3 + 18x^2 + 6x + 1 = p + 1 - t$ is the number of points in the curve $E(\mathbb{F_p })$.

## Point Coordinates

Since we define the elliptic curve as the set of points that satisfy the equation written above, it is natural to think of an element $P \in E(\mathbb{F_p })$ using two coordinates $P = (x, y)$. This representation is called _Affine Representation_ and its coordinates are known as _Affine Coordinates_. However, many times to optimize the arithmetic, it will be convenient to use what is known as _Projective Coordinates_ , which represent the points with three coordinates $x,$ $y,$ $z$, and is constructed in the following way:  
If $P = (x, y)$ is a point in affine coordinates, then $(x, y, 1)$ is its projective representation. And if $P = (x, y, z)$ is a point in projective coordinates, then $(\frac{x}{z}, \frac{y}{z})$ is its affine representation. You'll see in our implementation that we use both representations depending on what we need in each case, using functions like `to_affine()`.

There is a third representation that we won't use, but you may find in some papers, called _Jacobian Coordinates_ : If $P = (x, y, z)$ is a point in Jacobian coordinates, then $(\frac{x}{z}, \frac{y}{z^2 }, z)$ and $(\frac{x}{z^2 }, \frac{y}{z^3 })$ are its projective and affine coordinates respectively.

## Field Extension Tower

A pairing is a map $e: \mathbb{G_1 } \times \mathbb{G_2 } \to \mathbb{G_t }$, and this means that it takes as input two points, each from a group with the same number of points (or order) $r$. This number $r$ must be prime, and to guarantee security, it must be large. Also, for rather technical reasons, these two groups need to be distinct. So, to define a pairing, we need to choose these domains and codomain groups. The group $\mathbb{G_1 }$ will be the curve $E(\mathbb{F_p })$, but to define $\mathbb{G_2 }$ and $\mathbb{G_t }$ we'll need to _extend_ the field $\mathbb{F_p }$. We are not going to stop to explain in detail what field extensions are and how they are built, so if you are looking for a better understanding, we recommend reading the section [Field Extensions](https://hackmd.io/@benjaminion/bls12-381#Field-extensions) from _BLS12-381 For the Rest of US_. Here, we'll summarize the basic concepts necessary to understand our implementation and the algorithms we use.

Roughly speaking, our goal is to extend the field $\mathbb{F_p }$ to $\mathbb{F_{ p^{12} }}$, and we will do it in the following way. First, we extend $\mathbb{F_p }$ to $\mathbb{F_{ p^2 }}$ in the same way that the field of real numbers $\mathbb{R}$ is extended to the field of complex numbers $\mathbb{C}$: We define $$\mathbb{F_{ p^2 }} = \mathbb{F_p } [u] / (u^2 + 1).$$ That's a lot of symbols to process. The good news is that all we need to understand is that $F_{ p^2 }$ is a finite field whose elements are polynomials of degree 1 and variable $u$; that is, they have the form $$a + bu \quad \text{ with } a, b \in \mathbb{F_p }.$$ If we think it as complex numbers, $a$ would be the real part and $b$ the imaginary one. Note that $\mathbb{F_p } \subseteq \mathbb{F_{ p^2 }}$ because we can think of the elements of the left one as elements of the right one with "imaginary part" zero or $b = 0$. So, $\mathbb{F_{ p^2 } }$ is indeed an extension of $\mathbb{F_p }.$  
Secondly, we extend $\mathbb{F_{ p^2 }}$ in a similar way defining $$\mathbb{F_{ p^6 }} = \mathbb{F_{ p^2 }} [v] / (v^3 - (9 + u)).$$ In this case, since $v^3 - (9 + u)$ is a polynomial of degree 3, the elements of $\mathbb{F_{ p^6 }}$ will be polynomials of degree 2 and variable $v$ of the form $$a + bv + cv^2 \quad \text{ with } a, b, c \in \mathbb{F_{ p^2 }}.$$ Finally, we extend $\mathbb{F_{ p^6 }}$ defining $$\mathbb{F_{ p^{12} }} = \mathbb{F_{ p^6 }} [w] / (w^2 - v),$$ that is, its elements are again polynomials of degree 1 with variable $w$ of the form $$a + bw \quad \text{ with } a, b \in \mathbb{F_{ p^6 } }.$$  
Now, in practice, using lambdaworks, we have two different ways to define an element $f = a + bw \in \mathbb{F_{ p^{12} }}$. We can use `new()`,
    
    let f = Fp12E::new([a, b])
    

or we can use `from_coefficients()`.
    
    let f = Fp12E::from_coefficients([
    "a_00", "a_01", "a_10", "a_11", "a_20", "a_21", 
    "b_00", "b_01", "b_10", "b_11", "b_20", "b_21"
    ])
    

In the last case we use 12 coefficients to define $f$ because $f = a + bw$, where $a, b \in \mathbb{F_{ p^6 }}$. Then, $$a = \style{color: magenta} {a_0} + \style{color: magenta} {a_1}v + \style{color: magenta}{a_2}v^2 \quad \text{and} \quad b = \style{color: orange}{b_0} + \style{color: orange}{b_1}v + \style{color: orange}{b_2}v^2,  
$$ with $a_i, b_i \in \mathbb{F_{ p^2 }}$. And therefore, $$\style{color: magenta}{a_i} = a_{i0} + a_{i1} u \quad \text{and} \quad \style{color: orange}{b_i} = b_{i0} + b_{i1} u,$$ thus reaching the 12 coefficients.

There is another representation of the elements of $\mathbb{F_{ p^{12} }}$ that you could find in papers and algorithms that we used in our implementation. Since $v^3 = 9 + u$ and $w^2 = v$, we have that $w^6 = 9 + u$ and then, $$\mathbb{F_{ p^{12} }} = \mathbb{F_{ p^2 }} [w] / (w^6 - (9 + u)).$$ Again, you don't have to understand the previous sentence; the important thing is that we can not only represent $f$ as a polynomial of degree 1 and as a polynomial of degree 11 but also as a polynomial of degree 5 using $a_i$ and $b_i$ in the following way:  
$$ f = \style{color: magenta}{a_0} + \style{color: orange}{b_0} w + \style{color: magenta}{a_1} w^2 + \style{color: orange}{b_1} w^3 + \style{color: magenta}{a_2} w^4 + \style{color: orange}{b_2} w^5.$$ So every time you see an element of $\mathbb{F_{ p^{12} }}$ represented as a polynomial of degree 5, you will know how to write it as $a + bw$, constructing $a = \style{color: magenta}{a_0} + \style{color: magenta}{a_1}v + \style{color: magenta}{a_2}v^2$ and $b = \style{color: orange}{b_0} + \style{color: orange}{b_1}v + \style{color: orange}{b_2}v^2$ using its coefficients (and vice versa). Having different representations of the same extension field will allow us to apply some optimizations when implementing the pairing (see the section [Tower of Extension Fields](https://hackmd.io/@Wimet/ry7z1Xj-2#Tower-of-Extension-Fields) of _Computing the Optimal Ate Pairing Over the BN254 Curve_).

This may be a lot of new information, but don't worry; you don't need to understand it in detail. When reading the implementation, the idea is to have these equalities at hand to recognize where each variable belongs and how many coefficients it has. In lambdaworks `bn_254` you'll find these fields $\mathbb{F_p} ,$ $\mathbb{F_{ p^2 }},$ $\mathbb{F_{ p^6 }}$ and $\mathbb{F_{ p^{12} }}$ (with their operations implemented) as `BN254PrimeField`, `Degree2ExtensionField`, `Degree6ExtensionField` and `Degree12ExtensionField`.

## Twist

Since doing arithmetic in $\mathbb{F_{ p^{12} }}$ is complicated and inefficient, we will use a _twist_ that is like a coordinate conversion which tranforms our $E(\mathbb{F_{ p^{12} }})$ curve into the following curve $E'$ defined over $\mathbb{F_{ p^2 }}$:  
$$y^2 = x^3 + \frac{3}{9 + u} .$$  
We will call $b = \frac{3}{9 + u}$ implemented as `BN254TwistCurve::b()` .
    
    b = 19485874751759354771024239261021720505790618469301721065564631296452457478373 
        + 266929791119991161246907387137283842545076965332900288569378510910307636690 
        * u
    

So, in summary, we will use the following subgroups as inputs for the pairing:  
$$\mathbb{G_1} = E (\mathbb{F_p} ),$$  
$$\mathbb{G_2} \subseteq E^\prime ( \mathbb{F_{ p^2 }}) .$$  
And the output:  
$$\mathbb{G_t} \subseteq \mathbb{F_{ p^{12} } }^{\star} ,$$ where $\mathbb{F_{ p^{12} } }^{\star} = \mathbb{F_{ p^{12} } } - {0}$ (the multiplicative group of the field).

Knowing precisely which subgroups $\mathbb{G_2 }$ and $\mathbb{G_t }$ we should take is not relevant to understand our implementation. We will just say for those who have the mathematical background or are interested in going deeper into those topics, that $\mathbb{G_1 }$ and $\mathbb{G_2 }$ are the $r$-_torsion groups_ (i.e. the set of elements of _order_ $r$), while $\mathbb{G_t }$ is the set of the $r$-_th roots of unity_.

## The Pairing

### What is a pairing?

Let's better understand it now that we have defined everything necessary to build our pairing. A pairing is a bilinear map $e: \mathbb{G_1 } \times \mathbb{G_2 } \to \mathbb{G_t }$. _Bilinear_ means that it has the following property: For all points $P_1, P_2 \in \mathbb{G_1 }$ and $Q_1, Q_2 \in \mathbb{G_2 }$,  
$$\begin{align} e(P_1, Q_1 + Q_2) &= e(P_1, Q_1) \cdot e(P_1, Q_2) \newline  
e(P_1 + P_2, Q_1) &= e(P_1, Q_1) \cdot e(P_2, Q_1)\end{align}$$ And from this property, it can be deduced the next one: For all $n, m \in \mathbb{N}$,  
$$e(nP, mQ) = e(mQ, nP) = e(P, mQ)^n = e(nP, Q)^m = e(P, Q)^{nm}.$$ Recall that in general, the additive notation $+$ is used to denote the operation of the groups $\mathbb{G_1 }$ and $\mathbb{G_2 }$, and multiplicative notation $\cdot$ is used to denote the operation of $\mathbb{G_t }$.

### Ate Pairing Algorithm

We will use the algorithm of the Ate pairing from [this paper](https://eprint.iacr.org/2010/354.pdf) (Page 4, Algorithm 1):

* * *

**Inputs** : $P \in \mathbb{G}_1$ and $Q \in \mathbb{G}_2$  
**Output:** $f \in \mathbb{G}_t$

        1. define $T \in \mathbb{G}_2$;
        2. $T \leftarrow Q$;
        3. define $f \in \mathbb{G}_t$;
        4. $f \leftarrow 1$;
        5. for $i =$ `miller_length` $- 2$ to 0 do
        6.      $f \leftarrow f^2$;
        7.      $T \leftarrow 2T$;
        8.      if `MILLER_CONSTANT`$[i] = -1$ then
        9.          $f \leftarrow f \cdot l_{T, -Q}(P)$;
        10.          $T \leftarrow T - Q$;
        11.      else if `MILLER_CONSTANT`$[i] = 1$ then
        12.          $f \leftarrow f \cdot l_{T, Q}(P)$;
        13.          $T \leftarrow T + Q$;
        14.      end if
        15. end for
        16. $Q_1 \leftarrow \varphi(Q)$;
        17. $f \leftarrow f \cdot l_{T, Q_1 }(P)$;
        18. $T \leftarrow T + Q_1$;
        19. $Q_2 \leftarrow \varphi(Q_1)$;
        20. $f \leftarrow f \cdot l_{T, - Q_2}(P)$;
        21. $f \leftarrow f^{ \frac{ p^{12} - 1 }{r}}$;
        22. return f;

* * *

where:

        * The number `MILLER_CONSTANT` $=6x + 2$ with $x$ as the curve parameter we mentioned before. However, we need a particular representation of this number using powers of 2 and the coefficients $\\{- 1, 0, 1 \\}$. This representation is similar to a [NAF representation](https://en.wikipedia.org/wiki/Non-adjacent_form#:~:text=The%20non%2Dadjacent%20form%20\(NAF,8%20%E2%88%92%202%20%2B%201%20%3D%207\)), although it isn't a NAF because it has non-zero values adjacent.
              
              // MILLER_CONSTANT = 6x + 2 = 29793968203157093288 =
              // 2^3 + 2^5 - 2^7 + 2^10 - 2^11 + 2^14 + 2^17 + 2^18 - 2^20 + 2^23 
              // - 2^25 + 2^30 + 2^31 + 2^32 - 2^35 + 2^38 - 2^44 + 2^47 + 2^48 
              // - 2^51 + 2^55 + 2^56 - 2^58 + 2^61 + 2^63 + 2^64
              pub const MILLER_CONSTANT: [i32; 65] = [
                  0, 0, 0, 1, 0, 1, 0, -1, 0, 0, 1, -1, 0, 0, 1, 0, 0, 1, 1, 0, -1, 0, 0, 
                  1, 0, -1, 0, 0, 0, 0, 1, 1, 1, 0, 0, -1, 0, 0, 1, 0, 0, 0, 0, 0, -1, 0, 
                  0, 1, 1, 0, 0, -1, 0, 0, 0, 1, 1, 0, -1, 0, 0, 1, 0, 1, 1
              ];
              
              
              let miller_length = MILLER_CONSTANT.len()
              

        * The function $l_{T, Q}(P)$ is the line that passes through $T$ and $Q$ evaluated in $P$. We'll see how to compute it later.

        * The Frobenius morphism $\varphi: E'(\mathbb{F_{ p^2 } }) \to E'(\mathbb{F_{ p^2 }})$ is defined as $\varphi(x, y) = (x^p, y^p)$. We'll also see it later.

### Batch

We will divide the algorithm presented into Miller Loop and Final Exponentiation to implement it. The `miller()` function does all the work from lines 1 to 20 of the algorithm, while `final_exponentiation()` computes only the last line 21 (which is a computation that requires some work). However, if we have different pairs of points $(P, Q)$ and we want to calculate each of their pairings to multiply all the results together (and see, for example, if it equals $1$), the most efficient way to do it is first to execute the Miller Loop for each pair of points, multiply the results and then apply the Final Exponentiation to the final result. The function that does this procedure is called `compute_batch()`.
    
    fn compute_batch(
        pairs: &[(&Self::G1Point, &Self::G2Point)],
    ) -> Result<FieldElement<Self::OutputField>, PairingError> {
        let mut result = Fp12E::one();
        for (p, q) in pairs {
            // do some checks before computing the Miller loop
            // ...
            if !p.is_neutral_element() && !q.is_neutral_element() {
                let p = p.to_affine();
                let q = q.to_affine();
                result *= miller(&p, &q);
            }
        }
        Ok(final_exponentiation(&result))
    }
    

## Subgroup Check

Before applying the pairing to a given pair of points $(P, Q)$, it is necessary to check that the points belong to its domain. In other words, we need to see that $P \in \mathbb{G_1 }$ and $Q \in \mathbb{G_2 }$. Since $\mathbb{G_1 } = E(\mathbb{F_p })$, there is nothing to check about $P$. But, since $\mathbb{G_2 }$ is distinct from $E'(\mathbb{F_{ p^2 }})$, we need an efficient way to check that $Q$ belongs to the subgroup.

We'll use [this post](https://hackmd.io/@Wimet/ry7z1Xj-2#Subgroup-Checks) that states that a point $Q \in E'(\mathbb{F_{ p^2 }})$ belongs to $\mathbb{G_2 }$ if and only if  
$$(x + 1)Q + \varphi (xQ) + \varphi^2 (xQ) = \varphi^3 (2xQ).$$ Recall that $x$ is one of the curve's parameters and $\varphi$ is the Frobenius Morphism mentioned before. So first, we need to implement this morphism efficiently, avoiding powering elements to $p$ (because $p$ is a very large number). For that, we'll use two constants $\gamma_{1,2}, \gamma_{1,3} \in \mathbb{F_{ p^2 }}$ (later on, we'll see them in more detail).
    
    pub const GAMMA_12: Fp2E = Fp2E::const_from_raw([
        FpE::from_hex_unchecked("2FB347984F7911F74C0BEC3CF559B143B78CC310C2C3330C99E39557176F553D"),
        FpE::from_hex_unchecked("16C9E55061EBAE204BA4CC8BD75A079432AE2A1D0B7C9DCE1665D51C640FCBA2"),
    ]);
    
    pub const GAMMA_13: Fp2E = Fp2E::const_from_raw([
        FpE::from_hex_unchecked("63CF305489AF5DCDC5EC698B6E2F9B9DBAAE0EDA9C95998DC54014671A0135A"),
        FpE::from_hex_unchecked("7C03CBCAC41049A0704B5A7EC796F2B21807DC98FA25BD282D37F632623B0E3"),
    ]);
    

Having these constants, it's very easy to compute $\varphi$. We simply use that $$\varphi(x, y) = (\gamma_{1,2} \bar x, \gamma_{1,3} \bar y),$$ where $\bar x$ is the notation for the conjugate of $x$: If $x = a + bw \in \mathbb{F_{ p^2 }}$, then $\bar x = a - b w.$
    
    pub fn phi(&self) -> Self {
        let [x, y, z] = self.coordinates();
        Self::new([
            x.conjugate() * GAMMA_12,
            y.conjugate() * GAMMA_13,
            z.conjugate(),
        ])
    }
    

Now that we have $\varphi$, we can implement a function that determines if a certain point $Q$ of the twist curve $E'(\mathbb{F_{ p^2 }})$ belongs to the subgroup $\mathbb{G_2 }$.
    
    pub fn is_in_subgroup(&self) -> bool {
        let q_times_x = &self.operate_with_self(X);
        let q_times_x_plus_1 = &self.operate_with(q_times_x);
        let q_times_2x = q_times_x.double();
        
        q_times_x_plus_1.operate_with(&q_times_x.phi().operate_with(&q_times_x.phi().phi()))
            == q_times_2x.phi().phi().phi()
    }
    

## The Line

Let's see now how to implement for all $T, Q \in \mathbb{G_2 }$ and $P \in \mathbb{G_1 }$ the line $l_{T, Q}(P)$, called in lambdaworks `line()`, the fundamental function of the Miller Loop. First, we could have two cases: $T = Q$ or $T \neq Q$. In the first case, $l_{T, T} (P)$ is the tangent line of $T$ evaluated in $P$. In the second case, it is the line that passes through $T$ and $Q$ evaluated in $P.$

For our implementation, we relied on the algorithm proposed in [The Realm of the Pairings](https://eprint.iacr.org/2013/722.pdf). We use equation 11 on page 13 for the case $T = Q$ and the first equation on page 14 for the case $T \neq Q.$ You can also see the [Arkworks implementation](https://github.com/arkworks-rs/algebra/blob/master/ec/src/models/bn/g2.rs#L25) of the same algorithm, where the function that computes the case $T=Q$ is called `double_in_place()`, and the one for the case $T \neq Q$ is called `add_in_place()`. You will see that both the paper and Arkworks define more variables than we do. That's because those functions compute the line and $2T$ (in the first case) and $T + Q$ (in the second case), necessary values for the lines 7, 10, 13, and 18 of the Ate pairing algorithm. We didn't have to do it that way because in those lines, to double an element or to add two elements of a group, we used the lambdaworks functions `operate_with_self()` and `operate_with()`. To simplify understanding, we kept the same variable names appearing in the paper and Arkworks. Notice that adding or duplicating points the way they do it there only requires including a couple of lines to our function `line()`, so it's straightforward to compare both implementations and optimize ours if needed.

Finally, it's helpful to remark that the paper gives the result of the line as a polynomial of degree 5, while in lambdaworks, the elements of $\mathbb{F_{ p^{12} }}$ have another representation. So, we need to use the transformation explained in the Field Extensions Towers section.
    
    fn line(p: &G1Point, t: &G2Point, q: &G2Point) -> Fp12E {
        let [x_p, y_p, _] = p.coordinates();
    
        if t == q {
            let b = t.y().square();
            let c = t.z().square();
            //Define all the variables necessary
            //...
            
            // We transform one representation of Fp12 into another one:
            Fp12E::new([
                Fp6E::new([y_p * (-h), Fp2E::zero(), Fp2E::zero()]),
                Fp6E::new([x_p * (j.double() + &j), i, Fp2E::zero()]),
            ])
        } else {
            let [x_q, y_q, _] = q.coordinates();
    
            let theta = t.y() - (y_q * t.z());
            let lambda = t.x() - (x_q * t.z());
            let j = &theta * x_q - (&lambda * y_q);
    
            Fp12E::new([
                Fp6E::new([y_p * lambda, Fp2E::zero(), Fp2E::zero()]),
                Fp6E::new([x_p * (-theta), j, Fp2E::zero()]),
            ])
        }
    }
    

## Final Exponentiation

The last thing we need is to compute efficiently $f^{ \frac{ p^{12} - 1}{r}}.$ We took the final exponentiation algorithm from [here](https://hackmd.io/@Wimet/ry7z1Xj-2#Final-Exponentiation), which divides the exponent in the following way:  
$$\frac{ p^{12} - 1 }{r} = ( p^6 - 1) ( p^2 + 1) \frac{ p^4 - p^2 + 1}{r}$$

### The Easy Part

We want to compute  
$$f^{ ( p^6 - 1)( p^2 + 1)} = (f^{ p^6 } f^{ - 1})^{ p^2 } \cdot (f^{ p^6 } f^{- 1 }) .$$  
This will be easy to do using:

        * $f^{ p^6 } = \bar f$ and we can calculate it using `conjugate()`. This is true because $f \in \mathbb{F_{ p^{12} }}$ and this property follows from the [Frobenius morphism as seen here](https://github.com/mratsim/constantine/blob/master/constantine%2Fmath%2Fpairings%2Fcyclotomic_subgroups.nim#L154).

        * The function `inv()` computes $f^{ - 1}$.

        * To compute $(f^{ p^6 } f^{ - 1})^{ p^2 }$ we can use the Frobenius squared morphism $\pi_p^2 : \mathbb{F_{ p^{12} }} \to \mathbb{F_{ p^{12} }},$ defined as $$\pi_p^2 (f) = \pi_p ( \pi_p (f)) = f^{ p^2 }.$$ In the last section, we explain how to implement it.
    
    let f_easy_aux = f.conjugate() * f.inv().unwrap();
    let f_easy = &frobenius_square(&f_easy_aux) * f_easy_aux;
    

### The Hard Part

Now we need to raise the result of the easy part to the power $\frac{p^4 - p^2 + 1}{r}.$ We took the exact algorithm presented [here](https://hackmd.io/@Wimet/ry7z1Xj-2#The-Hard-Part) as four steps, where `f_easy` is called there $m$. As explained in that post, this algorithm can be improved using a vectorial addition chain technique.

## Frobenius Morphism

Finally, let's see how to implement the Frobenius morphisms $\pi_p$, $\pi_p^2$, and $\pi_p^3$ used in the Final Exponentiation.

You may remember that we have already implemented a Frobenius morphism $\varphi$. Although they have the same name, there is a slight difference between $\varphi$ and $\pi_p$: The function $\pi_p$ raises elements of $\mathbb{F_{ p^{12} }}$ to the power $p$, while $\varphi$ raises the coordinates of the twisted curve points to the power $p$. In other words, $\pi_p : \mathbb{F_{ p^{12} }} \to \mathbb{F_{ p^{12} }}$ while $\varphi : E'(\mathbb{F_{ p^2 }}) \to E'(\mathbb{F_{ p^2 }})$. That is why their implementations are not exactly the same.

To implement these morphisms we need to define for all $j = 1, \ldots 5$, the constants $$\begin{align}\gamma_{ 1 , j } &= (9 + u)^{ \frac{ j ( p - 1) }{6}} \  
\gamma_{2,j} &= \gamma_{1,j} \cdot \overline{\gamma_{1,j}} \newline  
\gamma_{3,j} &= \gamma_{1,j} \cdot \gamma_{2,j}\end{align}$$
    
    pub const GAMMA_11: Fp2E = Fp2E::const_from_raw([
        FpE::from_hex_unchecked("1284B71C2865A7DFE8B99FDD76E68B605C521E08292F2176D60B35DADCC9E470"),
        FpE::from_hex_unchecked("246996F3B4FAE7E6A6327CFE12150B8E747992778EEEC7E5CA5CF05F80F362AC"),
    ]);
    
    pub const GAMMA_12: Fp2E = Fp2E::const_from_raw([
        FpE::from_hex_unchecked("2FB347984F7911F74C0BEC3CF559B143B78CC310C2C3330C99E39557176F553D"),
        FpE::from_hex_unchecked("16C9E55061EBAE204BA4CC8BD75A079432AE2A1D0B7C9DCE1665D51C640FCBA2"),
    ]);
    
    // etc.
    

Now, we use that if $f = a + bw$, then
    
    pub fn frobenius(f: &Fp12E) -> Fp12E {
        let [a, b] = f.value();
        let [a0, a1, a2] = a.value(); 
        let [b0, b1, b2] = b.value(); 
    
        let c1 = Fp6E::new([
            a0.conjugate(),
            a1.conjugate() * GAMMA_12,
            a2.conjugate() * GAMMA_14,
        ]);
    
        let c2 = Fp6E::new([
            b0.conjugate() * GAMMA_11,
            b1.conjugate() * GAMMA_13,
            b2.conjugate() * GAMMA_15,
        ]);
    
        Fp12E::new([c1, c2])
    }
    
    // similarly, frobenius_square and frobenius_cube.
    // ...
    

Lastly, if we apply twelve times $\pi_p$, six times $\pi_p^2$, or four times $\pi_p^3$ to $f$, we get $f$ (i.e., they become the identity function). That's because $f \in \mathbb{F_{ p^{12} }}$, and then $f^{ p ^{12} } = f.$ This property will help us test if we implemented these morphisms correctly.

## Summary

This post explored how we combined various works and papers to implement our pairing. In doing so, we successfully integrated algorithms from different implementations by making transformations between point coordinates or different representations of the same extension of fields.

#### What's next?

Now that we have a pairing working, the next step is to know how this implementation compares with others. So, we will perform some benchmarks and make some optimizations that we are already aware of. As it's written in [Lambda’s Engineering Philosophy](/lambdas-engineering-philosophy/):, "Make it work, then make it beautiful, then if you really, really have to, make it fast."
