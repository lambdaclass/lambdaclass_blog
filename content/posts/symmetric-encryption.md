+++
title = "Symmetric encryption"
date = 2023-01-17
slug = "symmetric-encryption"

[extra]
feature_image = "/content/images/2025/12/Sandys-_Frederick_-_Morgan_le_Fay.jpeg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["cryptography"]
+++

## Introduction

Encryption has been the main application of cryptography for a very long time. Its goal is to transform a message into another one and send it through an insecure channel, such that only the intended parties (who know all the elements necessary to reverse the transformation) can read it while looking like absolute nonsense to everybody else. For example, suppose that you are a general during a war, and you need to communicate the battle plan to your reinforcement battalions (which are still far from you) and launch a surprise attack at the precise moment. If you sent some messenger with an unencrypted letter containing the plans, then anyone reading the letter would know your strategy and act in consequence. Besides, the messenger could betray you, exchange that information with your enemies, and thwart your masterminded tactic.

Encryption uses an algorithm called cipher and some key to change the message into a random-looking text. More precisely, it takes a plaintext and outputs a ciphertext through some mathematical computations. The cyphertext can only be decrypted if the key is known. In modern encryption, only the key is secret; the details of the encryption algorithm are publicly known. This construction is in accordance with Kerkhoff's principle, which states that, in a cryptographic system, only the key should be secret. In older times, people tried to hide the message by using unknown algorithms or strategies, hoping that the enemy would not be able to figure out the secret; we call this security through obscurity. Needless to point out, this strategy has failed numerous times with catastrophic consequences.

Symmetric encryption is widely used today, and there are efficient algorithms, some even implemented on hardware. Examples of symmetric encryption algorithms are AES (Advanced Encryption Standard), 3DES, ChaCha, Salsa, Twofish, Blowfish, and Serpent. In this type of encryption, we use the same key to encrypt and decrypt messages (therefore, if someone can send encrypted messages, he can decrypt them as well). We will see in a later chapter that there is asymmetric encryption (or public key cryptography), where we have two different keys: a public key (used to encrypt messages) and a private key (used to decrypt).

Once we have the key, we can send secure messages between the parties. It is unlikely that unwanted parties will decrypt them, thanks to the math and heuristics behind it and the appropriate security levels. However, we find ourselves with the problem of agreeing on the key between the involved parties. If we tried sending it in plaintext over an insecure channel, it could be compromised, and the symmetric encryption would be pointless since adversaries could have obtained it. We will focus in a later post on how to perform key exchanges.

There are two main ciphers types for symmetric encryption: block and stream ciphers. We will analyze their characteristics in the following sections.

## Formalization

We have two parties wanting to communicate securely, which we will call Alice and Bob (for A and B, respectively). Alice wants to send Bob a plaintext, \\( P \\), so that only Bob can read it and learn its contents. They have previously agreed on a common secret key, \\( k \\), and they will use some algorithm, such as AES. The encryption algorithm is some function, $E$, taking they plaintext and the key and outputting the ciphertext \\( C \\):  
\\[ E(P,k)=C \\]  
The decryption algorithm, \\( D \\), on the other hand, takes the ciphertext and the key and returns the plaintext  
\\[ D(C,k)=P \\]

We want some things from our encryption algorithm and the output ciphertext. First, the ciphertext should appear as a random text with no clear patterns. We would also like that if we change even a single bit from the message, the resulting ciphertext is utterly different from the original one: We call this the avalanche effect.

These are related to two properties that a secure cipher should have: confusion and diffusion. Confusion serves to hide the relationship between the key and the ciphertext. Diffusion is related to the fact that the value in the ciphertext of one bit depends on others; equivalently, if we changed one bit from the plaintext, we could expect that many bits would also change their values, which is related to the avalanche effect.

A cipher's permutation should satisfy the following three conditions to be secure:

        * The key should determine the permutation.
        * Different keys should give rise to different permutations.
        * The permutations should look random.

The first condition guarantees that we need the key to be able to decrypt. If the key does not determine the permutations, it plays no role in the process, and anyone could decrypt things without it. The second one means that no two keys yield the same permutation. If it were so, then we could decrypt the messages encrypted with one key with another, and that would make it easier to break the cryptosystem. The third one implies that we should not be able to learn anything about the plaintext from the ciphertext (an example where this fails is on some bitmaps with ECB mode encryption).

## Information versus Computational security.

One important key is related to the security proofs of our cryptographic schemes. In some cases, one can prove that specific methods are mathematically secure, even if the attacker has unbounded computational power. These schemes are known as information-theoretically secure. However, we need to introduce some assumptions to build practical cryptographical schemes. Modern cryptographic algorithms can be proven computationally secure, where the adversary has bounded computing power and can break the system only after spending a lot of time or resources, even with the fastest and most powerful devices available nowadays.

Instead of perfect security, computational security relies on the following:

        * Security is preserved only against efficient adversaries.
        * Adversaries can succeed, but only with negligible probability.

We can consider our schemes secure for practical purposes if we have sufficiently reasonable bounds for computational power and the probability of success is small enough.

There are two common approaches to analyzing the security of our cryptographic protocols:

        1. Concrete.
        2. Asymptotic.

In the concrete case, we bound the probability of success, \\( \epsilon \\), after the attacker has spent time \\(t \\). We say that the scheme is \\( (t,\epsilon) \\)-secure if an adversary spending time \\(t \\) has a probability of success of at most \\( \epsilon \\).

The asymptotic approach is related to complexity theory. It views the running time of the attacker and his success probability as functions of a security parameter, \\( \lambda \\) (for example, the secret key size). It only guarantees security provided \\( \lambda \\) is sufficiently large.

We say an algorithm is efficient if its running time is polynomial in \\( \lambda \\), that is \\( c_1 \lambda^{c_2} \\) for some numbers \\( c_1 \\) and \\( c_2\\). We can also write this in big O notation, \\( \lambda^{c_2}\\).

As for the probability of success, we consider them to be small if it is smaller than any inverse polynomial in \\( \lambda \\). More precisely, for every constant \\( c \\), the attacker's success probability is smaller than the inverse polynomial in \\( \lambda \\), \\( \lambda^{-c}\\). A function growing slower than any inverse polynomial is called negligible.

A scheme is secure if every probabilistic, polynomial-time attacker succeeds in breaking it with only negligible probability.

## Bit operations: exclusive OR (XOR)

One operation frequently used in cryptography is the exclusive OR operator (XOR). It is a binary operation, taking two bits and outputting another; we will represent the operation with the \\( \oplus \\) symbol. Its truth table is:  
\\( 0\oplus 0=0\\)  
\\( 0\oplus 1=1\\)  
\\( 1\oplus 0=1\\)  
\\( 1\oplus 1=0\\)

We can also view the XOR operation as an addition modulo \\( 2 \\):  
\\( 0+0\equiv 0 \pmod{2}\\)  
\\( 1+0\equiv 1 \pmod{2}\\)  
\\( 1+1\equiv 0 \pmod{2}\\)  
These results are expected: adding two odd or two even numbers is always even, whereas adding one odd and one even number is always odd.

Why is this operation helpful? Suppose we want to encrypt a message given as a sequence of bits. One way to encrypt it is to generate a sequence of (pseudo) random bits and XOR each bit to get the ciphertext. An attacker can try to decipher the text, but he finds the following problem:

        * If he sees \\( 0 \\) in the ciphertext, it could be because the plaintext had \\( 1 \\) and the random bit was also \\( 1 \\), or both were zero. So, he has a \\( 50 % \\) chance of guessing correctly!
        * If he sees \\( 1 \\) in the ciphertext, either the plaintext is \\(1 \\) and the random bit is \\( 0 \\) or the other way round. Again, he has a \\( 50 % \\) chance of guessing correctly.

If the message is composed of several bytes (for example, 16 bytes - 128 bits), the probability of guessing the correct message is \\( 3\times 10^{-39} \\)!

We see that the XOR operation is hard to reverse unless we know one of the original inputs. In that case, if \\( c=m\oplus r\\), then  
\\[ m=c\oplus r\\]

## Stream and Block ciphers

A block cipher takes a message of fixed length (128 bits, for example) and encrypts it by performing some random permutation of its elements. Two values characterize the block cipher: the block size (for example, 16 bytes -128 bits-) and the key size. Both determine the level of security of the cipher. This cipher does not operate with individual bits but with fixed-sized blocks.

Block sizes must be neither very large nor very small. In the first case, it can impact the cost and performance of the encryption since the memory footprint and ciphertext length will be significant. However, if the block size is small, it is susceptible to a codebook attack.

In practice, a block cipher is the repetitive application of permutation and substitution steps; these take place in rounds. The main building blocks are:

        * Substitution boxes (S-boxes).
        * Mixing permutations.
        * Key schedule.

If we call \\(f_k \\) the function corresponding to round \\( k \\), the ciphertext is  
\\[ C= f_n(f_{n-1}(...f_2(f_1(P))))\\]

The round functions have the same operations but are parametrized by a different key (which leads to other substitutions and permutations). We should not use the same key for all steps; otherwise, our cryptosystem can be vulnerable to slide attacks.

Decryption is the successive application of the inverse functions \\( g_k=f_k^{-1}\\),  
\\[ P=g_1(g_2(...g_{n-1}(g_n(C))))\\]

Stream ciphers work very differently; instead of combining blocks of text and the key, they deterministically generate a sequence of "random" bits (called the keystream) from the key and perform XOR operations with the text.

The keystream, \\( KS \\), is derived from the secret key \\( k \\) and a public nonce \\( \mathrm{nonce} \\). If we have our message, \\( \mathrm{m} \\) to encrypt we perform \\( C=KS \oplus \mathrm{m} \\). To decrypt, we simply XOR again, \\( \mathrm{m}=KS\oplus C\\). We can easily see that the encrypt and decrypt operations are essentially the same; we only need the keystream to be able to do it. It is important that \\( \mathrm{nonce} \\), which need not be secret, is never reused. To see why, suppose we have two messages \\( \mathrm{m}_1 \\) and \\( \mathrm{m}_2\\), and their corresponding ciphertexts, which have been encrypted using the same key \\( k \\) and \\( \mathrm{nonce} \\). We can recover the message \\( \mathrm{m}_1 \\) using the following operation:  
\\[ \mathrm{m}_1=C_2\oplus C_1 \oplus \mathrm{m}_2 \\]

The above was an implementation error that Microsoft Excel and Word had: they reused the same nonce, which meant that decryption could be done if two versions of the same file were available.

## Encryption algorithms

In the following sections, we will cover the basics of each type of cipher, analyzing two commonly used ones. We will start with AES (a block cipher), the most widely used cipher nowadays, and ChaCha (a stream cipher), commonly used in android systems in the form of ChaCha20-Poly1305.

## AES

The Advanced Encryption Standard (AES) resulted from an open competition organized by NIST in 1997 that lasted for three years. The proposal by Rijmen and Daemen was nominated as the winner and was standardized in 2001 by NIST. We implemented AES and its arithmetization for use in zero-knowledge proofs [here](https://github.com/lambdaclass/AES_zero_knowledge_proof_circuit).

AES offers three levels of security: AES-128, AES-192, and AES-256, with key sizes of 16, 24, and 32 bytes, respectively. As the key's size increases, so does security. However, for most applications, AES-128 provides sufficient security levels (the best-known attacks against AES are only slightly better than brute-force attacks, which would require \\( 2^{128} \\) operations).

AES is a block cipher: it takes a 16-byte block (128 bits) and the variable length key and outputs a 16-byte ciphertext. If the text has less than 16 bytes, it is conveniently padded. After performing decryption, it should be possible to eliminate the padding to recover the message; therefore, we cannot use random padding because we cannot distinguish the original message from the random bits.

Remember that block ciphers are permutations: they map all the possible plaintexts into all possible ciphertexts.

The cipher sees the plaintext as a \\( 4\times 4 \\) matrix of bytes. AES has a round function, which is applied several times to the plaintext, scrambling and mixing everything well until we obtain the ciphertext. Each round uses a different key (which is generated in a deterministic way from the secret key), making the slightest changes in the bits of the secret key result in an entirely different encryption. The steps in each round function (except in the last one) are:

        * SubBytes
        * ShiftRows
        * MixColumns
        * AddRoundKey

The first three are easily reversible, but the last one is not: it performs an XOR operation between the text and the round key. However, all the steps are necessary to achieve the desired security levels.

AES uses ten rounds to perform encryption. All steps contain the four operations, except for the first (only the round key is added) and the 10th (MixColumns is omitted).

SubBytes (also called substitution boxes) provide the substitution step and is a nonlinear function. Given that we encrypt blocks of 16 bytes, we can do the substitution with the aid of lookup tables.

In ShiftRows and MixColumns, the bytes of the columns/rows are moved.

The key schedule function is called to generate the keys for each round: all the keys are derived from the secret key, using the substitution boxes and XOR operations. One drawback of this key scheduling is that if an attacker learns one of the keys, he can reverse the algorithm and discover all other keys, including the secret key.

Why do we need all these operations to have a secure cipher?

        * The MixColumns and ShiftRows guarantee that all the elements are "well mixed". If one of them is missing, then we could break the cipher into smaller blocks and perform a codebook search over \\( 2^{32} \\) possibilities, which is far better than \\( 2^{128} \\).
        * SubBytes gives the nonlinear part to the cipher. Without it, all the operations are linear and easier to reverse.
        * AddRoundKey makes the ciphertext depend on the key. If we skip this step, we don't need any key to decipher.
        * The key schedule prevents us from reusing the same key all the time, making the cipher vulnerable to slide attacks.

When we want to encrypt a message bigger than the block size, we can divide it into blocks of 16 bytes and pad the last one, if necessary. This simple approach is known as the electronic codebook mode (ECB) and should not be used. As encryption is deterministic, we will get the same ciphertext every time we encrypt a given plaintext. This is problematic when we have, for example, an image with repetitive patterns or large areas of one color since the ciphertext will exhibit those patterns too. There are several modes that we can use to avoid this problem:

        * Cipher block chaining (CBC)
        * Propagating cipher block chaining (PCBC)
        * Cipher Feedback (CFB)
        * Output feedback (OFB)
        * Counter (CTR)

For example, in the CBC mode:

        1. Initialize a 16-byte random vector (IV),
        2. Perform \\( \tilde{B}_1=IV \oplus B_1 \\), where \\( B_1 \\) is the first block and set \\( k=1 \\).
        3. Use AES to encrypt \\( E_1= \tilde{B}_1 \\).
        4. Perform \\( \tilde{B_{k+1}}=E_k \oplus B_{k+1} \\)
        5. Use AES to encrypt \\( E_{k+1}= \tilde{B_{k+1}} \\) and do \\( k=k+1 \\)
        6. If \\( k \neq k_{max} \\), go to step 4. Otherwise, it is the end of the encryption.

The IV guarantees that the resulting ciphertext will be different even if the same plaintext is encrypted.

Another problem we face is that, even though the message has been encrypted, we cannot know whether an attacker has modified it. To prevent modification of the ciphertext, we can add message authentication codes (MAC), which we will cover in another post.

## ChaCha20

ChaCha20 is a modification of the Salsa20 cipher, invented by Daniel J. Bernstein in 2005. Its working principle is the same as all stream ciphers: it generates a keystream from the secret key and encrypts by performing an XOR operation between the plaintext and the keystream.

ChaCha20 generates the keystream by repeatedly calling a block function that outputs 64 bytes of keystream. It takes as input:

        * 256-bit key.
        * 96-bit nonce.
        * 32-bit counter.

Every time the function outputs 64 bytes of the keystream, the counter is increased by one, and the process continues until the keystream is larger than the plaintext; then, we truncate it to the plaintext length, and we perform an XOR operation. The maximum size we can encrypt is given by the total value of the counter, \\( 2^{32} \\), and the output of each round, 64 bytes, yielding a maximum of \\( 2^{32}\times 64=256 \\) GB.

The core operation is the Quarter Round. It takes 4 32-bit unsigned integers, denoted \\( a,b,c \\) and \\(d \\) and performs the following operations:  
\\( a=a+b;\space d=d\oplus a;\space d<<<16\\)  
\\( c=c+d;\space b=b\oplus c;\space b<<<12\\)  
\\( a=a+b;\space d=d\oplus a;\space d<<<8\\)  
\\( c=c+b;\space b=b\oplus c;\space b<<<7\\)  
where \\( <<<n \\) denotes an \\( n \\)-bit rotation towards the left.

The ChaCha state comprises 16 32-bit words: the first four are constants; the next eight correspond to the key, followed by the counter and the nonce.

## Summary

Symmetric encryption is one of the most widely used encryption schemes nowadays; it also provides tools upon which we can build hash functions. We can classify symmetric ciphers into two big groups: block (like AES) and stream ciphers (like Chacha20). Both provide confidentiality by scrambling and substituting the message. In a subsequent post, we will deal with how parties can agree on a key over an insecure channel.
