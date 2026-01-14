+++
title = "Verifiable AES: encryption using zero-knowledge proofs"
date = 2023-01-07
slug = "verifiable-encryption-using-zero-knowledge-proofs"
description = "Encryption is transforming messages into random-looking texts to ensure confidentiality between two parties.\n\nWhat is our objective here? We want to generate proof allowing us to verify an encryption algorithm, ensuring it does what it was designed for. "

[extra]
feature_image = "/images/2025/12/Zonaro_GatesofConst.jpg"
authors = ["LambdaClass"]

[taxonomies]
tags = ["zero knowledge proofs", "Computer Science"]
+++

![download-1](/images/2023/01/download-1.jpeg)

## Scope

At Lambdaclass, we want to try and test different cryptographic primitives that we can use to develop new products and applications to empower individuals and organizations, with an increased focus on security and requiring minimal trust between parties. In a series of posts, we will cover powerful primitives such as zero-knowledge proofs and fully homomorphic encryption, their applications, and use cases.

Encryption is transforming messages into random-looking texts to ensure confidentiality between two parties.

**What is our objective here?**  
We want to generate proof allowing us to verify an encryption algorithm, ensuring it does what it was designed for.

**Why do we need this?**  
We need this so that the user does not need to trust that the other party performed the encryption correctly; we replace trust with cryptographic proofs. There a few use cases where the receiver doesn't want to decrypt the message unless it's an emergency. But at the same time the receiver needs to make sure the encryption was correctly done so that the message is there waiting for him to open it.

**When is this useful?**  
Whenever we want to receive unknown data from untrusted parties in a secure way and be sure that we are not being cheated.

The repository of the project can be found [here](https://github.com/lambdaclass/AES_zero_knowledge_proof_circuit).

## General Introduction

Two parties (we will call them Alice and Bob) can communicate securely by using encryption schemes. We can broadly classify encryption schemes into the following categories:

        * Private (symmetric) key encryption. Commonly used methods are AES and ChaCha20.
        * Public (asymmetric) key encryption. Commonly used methods are RSA and ElGamal.

In symmetric encryption, Alice and Bob must agree on a shared key before sending messages. The problem is how they can agree on something if they can't send messages to each other securely? Luckily, key agreement schemes, such as Diffie-Hellman, allow them to choose a secret key. We will focus here on the Elliptic Curve Diffie-Hellman protocol. The key ingredients are a finite field $\mathbb{F_p}$ (where $p$ is a large prime) and an elliptic curve $\mathcal{C}$ defined over $\mathbb{F_p}$ (which contains a subgroup of prime order $r$ with a generator $g$). It consists of the following steps:

        1. Alice chooses an element $s_A$ in $\mathbb{F_p}$ and computes her public key, $g_A=s_A g$.
        2. Alice sends her public key $g_A$ to Bob.
        3. Bob chooses an ephemeral key, $s_B$ in $\mathbb{F_p}$, and computes his public key $g_B=s_B g$ and the shared secret $g_{AB}=s_B g_A=s_As_B g$.
        4. Bob sends $g_B$ to Alice; Alice can also derive the shared secret by doing $g_{AB}=s_A g_B$.
        5. They can calculate the symmetric key, $sk$, from the same key derivation function, $sk=KDF(g_{AB})$.

Given a message $m$, Bob can encrypt it and send it to Alice by using a scheme such as AES and the key,  
$$c=E(m,sk)$$  
Any encryption scheme must satisfy the following consistency check:  
$$ m=D(E(m,sk),sk)=D(c,sk)$$

### Goal

Alice needs Bob to send her some secret, $sc$, which she does not know directly (otherwise, she would not need to communicate with Bob). She only knows a hash of $sc$ (for example, a Pedersen commitment). To send the secret, they need to agree on the key first. Then, Bob has to use that key to encrypt $sc$ and send it to Alice. The biggest problem is that Alice does not fully trust Bob. He could encrypt another message or use a different key. We want to develop a scheme where Bob can prove to Alice that he encrypted the message $sc$ using the key $sk$ without obviously leaking information about the key or the message.

Concisely, we can say that the goal is the following: Bob has to prove that the ciphertext $c$ is the result of the encryption of $m$ (whose commitment is $cm_m$) under a scheme (AES) using the symmetric key $sk$.

The following list shows all the input variables, indicating whether they are sensitive (should be secret) or not:

        * Secret: Bob's ephemeral key, $s_B$, the message, $sc$.
        * Public/Not secret: ciphertext, $c$, Alice and Bob's public keys, $g_A$ and $g_B$, the commitment to the message $cm_{sc}$.

All other elements, such as the curve and finite field, have been previously agreed on and are publicly known.

### Steps

The following calculations would allow Bob to achieve his goal:

        1. Using his ephemeral key, show that $g_B==s_B g$. If he succeeds, he gets a boolean variable, $b_1=1$.
        2. Using $s_B$ and $g_A$, he derives $sk$, encrypts $m$ and shows that $c==E(sc,sk)$. If this passes, he gets $b_2=1$.
        3. Using $sc$, he computes $cm_m$ and compares whether $cm_{sc}=\mathrm{commit}(sc)$. If this is correct, he gets $b_3=1$.
        4. If $b_1 \wedge b_2 \wedge b_3=1$.

The big question is how can he prove all these conditions without revealing sensitive information? Here is where zero-knowledge proofs come into play.

## What are zero-knowledge proofs?

Zero-knowledge proofs (ZKP) are powerful cryptographic primitives which allow us to prove the validity of a statement or computation without revealing information other than the truth of the statement. We can represent any bounded computation as an arithmetic circuit, $C$. ZKP allow us to prove that we know some secret $w$ and public known values, $x$, such that $C(z=(x,w))=0$. In our case, the circuit is given by the computation performing checks 1-4. The variable $w$ contains $s_B$ and $sc$, $w=(s_B,sc)$. The public instance $x$ contains $g_A,g_B,c,cm_{sc}$ and the intended output, $1$, $x=(g_A,g_B,c,cm_{sc},1)$.

ZKP use polynomials and their properties to prove statements. Zk-SNARKs are ZKP with the following additional properties: succinctness (proofs are brief and faster to verify than naïve re-execution of the calculation) and non-interactive (prover and verifier do not need to exchange messages). There are two building blocks to most SNARKs: an information-theoretic device (most commonly, polynomial interactive oracle proofs, PIOP) and a cryptographic commitment scheme (in particular, polynomial commitment schemes, PCS). In this case, we will work with Marlin (PIOP) and the Kate-Zaverucha-Goldberg (KZG) commitment scheme.

The first step is to transform our code into arithmetic circuits or, equivalently, as a (quadratic) rank-one constraint system (R1CS). The latter is a system of equations of the form:  
$$ Az\cdot Bz=Cz$$  
where $A,B,C$ are matrices of the same size and $\cdot$ indicates the componentwise product.

Then, we will express these constraints as polynomials and generate the proof. Polynomial commitments come into play to ensure the prover does not cheat and make the protocol zero-knowledge. We will now focus on the proof generation and verification of step 2 (AES encryption).

## Encryption using the Advanced Encryption Standard (AES)

AES is a [block cipher](https://en.wikipedia.org/wiki/Block_cipher): it takes a 128-bit message (interpreted as a $4\times 4$ matrix of bytes) and a secret key, $sk$, and performs a pseudorandom permutation. AES has a round function, which is applied a fixed number of times, each using a different key, to encrypt the message. We use the key scheduling function to derive all the round keys from the master key, $sk$. The round function consists of the following operations:

        1. Add a round key.
        2. Substitute bytes (S-boxes).
        3. Shift rows.
        4. Mix columns.

Each of these operations is necessary to guarantee that AES is secure. Repeating the operations in multiple rounds guarantees that elements are sufficiently shuffled and mixed, leading to semantic security (that is, we cannot learn anything about the plaintext just by looking at the ciphertext).

AES is described in the [NIST standard](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.197.pdf). AES needs to use a mode to deal with messages of size greater than 128 bits. Some standard modes are AES-CBC (cipher block chaining) and AES-GCM (Galois counter mode, which provides authenticated encryption).

### Add round key

This is the step that makes the encryption depend on the key. For each round, a round key is derived from the master key ($sk$). The function is straightforward: it consists of an XOR operation between the round key and the state (the message or its transformations). To make it consistent with the code,  
$$ \mathrm{ret}=\mathrm{input_text}\oplus \mathrm{key} $$
    
    pub fn add_round_key(input_text: &[u8], key: &[u8; 16]) -> [u8; 16] {
        let mut ret = [0_u8; 16];
    
        let _ = zip(input_text, key)
            .map(|(cell_i, key_i)| cell_i ^ key_i)
            .collect_slice(&mut ret[..]);
    
        ret
    }
    

The XOR operation appears frequently in cryptography. Unless we know the key, we have a 50 % chance of guessing the correct value for each bit, which is as good as flipping a fair coin and guessing.

### Substitute bytes / S-boxes

The S-boxes add the non-linear component to the block cipher. Here, each byte of the matrix is one-to-one mapped onto another byte. Here we present the complete code for the S-boxes, but this is done via a lookup table in practice. This will prove helpful in generating the proof since looking at the table requires fewer constraints than the whole operation.

In AES, we interpret bytes as polynomials of degree at most $7$, with coefficients in ${0,1}$. For example, the byte $10010110$ is interpreted as the polynomial $x7+x4+x^2+x$, and $00100001$ is $x^5+1$. We can multiply polynomials, but if the degree is larger than 7, we have to take the remainder of the product and the irreducible polynomial $m(x)=x8+x4+x^3+x+1$.
    
    fn rotate_left(byte: u8, n: u8) -> u8 {
        (byte << n) | (byte >> (8 - n))
    }
    
    pub fn substitute_byte(byte: u8) -> Result<u8> {
        if byte == 0x00 {
            return Ok(0x63);
        }
    
        let mut p = 1_u8;
        let mut q = 1_u8;
        let mut sbox = [0_u8; 256];
    
        /* loop invariant: p * q == 1 in the Galois field */
        loop {
            /* multiply p by 3 */
            p = p ^ (p << 1_u8) ^ (((p >> 7_u8) & 1) * 0x1B);
    
            /* divide q by 3 (equals multiplication by 0xf6) */
            q ^= q << 1_u8;
            q ^= q << 2_u8;
            q ^= q << 4_u8;
            q ^= ((q >> 7_u8) & 1) * 0x09;
    
            /* compute the affine transformation */
            let xformed =
                q ^ rotate_left(q, 1) ^ rotate_left(q, 2) ^ rotate_left(q, 3) ^ rotate_left(q, 4);
    
            let p_as_usize: usize = p.try_into()?;
            *sbox
                .get_mut(p_as_usize)
                .to_anyhow("Error saving substitution box value")? = xformed ^ 0x63;
            if p == 1 {
                break;
            }
        }
    
        let byte_index: usize = byte.try_into()?;
    
        Ok(*sbox
            .get(byte_index)
            .to_anyhow("Error getting substitution box value")?)
    }
    

In the first step, each byte is mapped to its multiplicative inverse. If $p(x)$ is the polynomial associated with the byte, there exists another polynomial $q(x)$ such that $p(x)q(x)\equiv 1 \pmod{m(x)}$ (there is $q(x)$ such that $m(x)$ divides $p(x)q(x)-1$). The only edge case is the 0 byte, which has no inverse and is mapped onto itself (this is the if at the beginning of the function).

The following steps give the calculation of the inverse:
    
    let mut p = 1_u8;
    let mut q = 1_u8;
    p = p ^ (p << 1_u8) ^ (((p >> 7_u8) & 1) * 0x1B);
    q ^= q << 1_u8;
    q ^= q << 2_u8;
    q ^= q << 4_u8;
    q ^= ((q >> 7_u8) & 1) * 0x09;
    

Next, we perform an affine transformation on the inverse, which combines the bits at different positions:
    
    let xformed =
                q ^ rotate_left(q, 1) ^ rotate_left(q, 2) ^ rotate_left(q, 3) ^ rotate_left(q, 4);
    

This last operation consists of four left rotations and four XOR operations.

### ShiftRows

This function changes the order of the elements in each row by performing a cyclic shift. The second row shifts each element one place to the left, the third one two places, and the fourth three. This transformation is linear; the constraints associated with it will also be linear.
    
    pub fn shift_rows(bytes: &[u8; 16], cs: &ConstraintSystemRef<ConstraintF>) -> Result<[u8; 16]> {
        // Add each number to the constraint system.
        for byte in bytes {
            UInt8::new_witness(ark_relations::ns!(cs, "shift_rows_witness"), || Ok(byte))?;
        }
    
        // Turn the bytes into the 4x4 AES state matrix.
        // The matrix is represented by a 2D array,
        // where each array is a row.
        // That is, let's suppose that the flattened_bytes variable
        // is formed by the bytes
        // [b0, ..., b15]
        // Then the AES state matrix will look like this:
        // b0, b4, b8, b12,
        // b1, b5, b9, b13,
        // b2, b6, b10, b14,
        // b3, b7, b11, b15
        // And our array will look like this:
        //[
        //  [b0, b4, b8, b12],
        //  [b1, b5, b9, b13],
        //  [b2, b6, b10,b14],
        //  [b3, b7, b11,b15]
        //]
        let mut state_matrix = [[0_u8; 4]; 4];
        for (i, state) in state_matrix.iter_mut().enumerate() {
            *state = [
                *(bytes.get(i).context("Out of bounds"))?,
                *(bytes.get(i + 4).context("Out of bounds")?),
                *(bytes.get(i + 8).context("Out of bounds")?),
                *(bytes.get(i + 12).context("Out ouf bounds")?),
            ];
        }
    
        // Rotate every state matrix row (u8 array) as specified by
        // the AES cipher algorithm.
        for (rotations, bytes) in state_matrix.iter_mut().enumerate() {
            // For the moment, this operation does not generate constraints in the
            // circuit, but it should in the future.
            bytes.rotate_left(rotations);
        }
    
        // Turn the rotated arrays into a flattened
        //16-byte array, ordered by column.
        let mut flattened_matrix = [0_u8; 16];
        for i in 0..4 {
            for j in 0..4 {
                *flattened_matrix
                    .get_mut((i * 4) + j)
                    .to_anyhow("Error getting element of flattened_matrix slice")? = *state_matrix
                    .get(j)
                    .to_anyhow("Error getting element of state_matrix")?
                    .get(i)
                    .to_anyhow("Error getting element of state_matrix")?;
            }
        }
        Ok(flattened_matrix)
    }
    

### MixColumns

The MixColumn function operates over each column of the state matrix. Every four-byte column is interpreted as a polynomial degree four polynomial, modulo $x^4+1$. We can view each column as the result of a linear combination. Each byte can be multiplied by 1, 2 or 3. If the result exceeds the modulus, we have to reduce the result, similar to what we did in substitute bytes.
    
    fn gmix_column(input: [u8; 4]) -> Option<[u8; 4]> {
        let mut b: [u8; 4] = [0; 4];
        /* The array 'a' is simply a copy of the input array 'r'
         * The array 'b' is each element of the array 'a' multiplied by 2
         * in Rijndael's Galois field
         * a[n] ^ b[n] is element n multiplied by 3 in Rijndael's Galois field */
    
        for (i, c) in input.iter().enumerate() {
            let h = (c >> 7_usize) & 1; /* arithmetic right shift, thus shifting in either zeros or ones */
            *b.get_mut(i)? = (c << 1_usize) ^ (h * 0x1B); /* implicitly removes high bit because b[c] is an 8-bit char, so we xor by 0x1b and not 0x11b in the next line */
            /* Rijndael's Galois field */
        }
    
        Some([
            b.first()? ^ input.get(3)? ^ input.get(2)? ^ b.get(1)? ^ input.get(1)?,
            b.get(1)? ^ input.first()? ^ input.get(3)? ^ b.get(2)? ^ input.get(2)?,
            b.get(2)? ^ input.get(1)? ^ input.first()? ^ b.get(3)? ^ input.get(3)?,
            b.get(3)? ^ input.get(2)? ^ input.get(1)? ^ b.first()? ^ input.first()?,
        ])
    }
    
    pub fn mix_columns(input: &[u8; 16]) -> Option<[u8; 16]> {
        let mut ret = [0_u8; 16];
    
        for (pos, column) in input.chunks(4).enumerate() {
            let column_aux = [
                *column.first()?,
                *column.get(1)?,
                *column.get(2)?,
                *column.get(3)?,
            ];
            let column_ret = gmix_column(column_aux)?;
    
            // put column_ret in ret:
            *ret.get_mut(pos * 4)? = *column_ret.first()?;
            *ret.get_mut(pos * 4 + 1)? = *column_ret.get(1)?;
            *ret.get_mut(pos * 4 + 2)? = *column_ret.get(2)?;
            *ret.get_mut(pos * 4 + 3)? = *column_ret.get(3)?;
        }
    
        Some(ret)
    }
    

### Key scheduling

This function derives the round keys from the master key.
    
    pub fn derive_keys(secret_key: &[u8; 16]) -> Result<[[u8; 16]; 11]> {
        const ROUND_CONSTANTS: [u32; 10] = [
            u32::from_be_bytes([0x01, 0x00, 0x00, 0x00]),
            u32::from_be_bytes([0x02, 0x00, 0x00, 0x00]),
            u32::from_be_bytes([0x04, 0x00, 0x00, 0x00]),
            u32::from_be_bytes([0x08, 0x00, 0x00, 0x00]),
            u32::from_be_bytes([0x10, 0x00, 0x00, 0x00]),
            u32::from_be_bytes([0x20, 0x00, 0x00, 0x00]),
            u32::from_be_bytes([0x40, 0x00, 0x00, 0x00]),
            u32::from_be_bytes([0x80, 0x00, 0x00, 0x00]),
            u32::from_be_bytes([0x1B, 0x00, 0x00, 0x00]),
            u32::from_be_bytes([0x36, 0x00, 0x00, 0x00]),
        ];
    
        let mut result = [0_u32; 44];
    
        result[0] = to_u32(&secret_key[..4]).to_anyhow("Error converting to u32")?;
        result[1] = to_u32(&secret_key[4..8]).to_anyhow("Error converting to u32")?;
        result[2] = to_u32(&secret_key[8..12]).to_anyhow("Error converting to u32")?;
        result[3] = to_u32(&secret_key[12..16]).to_anyhow("Error converting to u32")?;
    
        for i in 4..44 {
            if i % 4 == 0 {
                let substituted_and_rotated = to_u32(&substitute_word(rotate_word(
                    *result.get(i - 1).to_anyhow("Error converting to u32")?,
                ))?)
                .to_anyhow("Error converting to u32")?;
    
                *result.get_mut(i).to_anyhow("Error getting elem")? =
                    (result.get(i - 4).to_anyhow("Error getting elem")? ^ (substituted_and_rotated))
                        ^ ROUND_CONSTANTS
                            .get(i / 4 - 1)
                            .to_anyhow("Error getting elem")?;
            } else {
                *result.get_mut(i).to_anyhow("Error getting elem")? =
                    result.get(i - 4).to_anyhow("Error getting elem")?
                        ^ result.get(i - 1).to_anyhow("Error getting elem")?;
            }
        }
    
        let mut ret = [[0_u8; 16]; 11];
    
        for (i, elem) in result.chunks(4).enumerate() {
            elem.iter()
                .flat_map(|e| e.to_be_bytes())
                .collect_slice(&mut ret.get_mut(i).to_anyhow("Error getting elem")?[..]);
        }
    
        Ok(ret)
    }
    
    fn to_u32(value: &[u8]) -> Option<u32> {
        let array_aux: [u8; 4] = [
            *value.first()?,
            *value.get(1)?,
            *value.get(2)?,
            *value.get(3)?,
        ];
        Some(u32::from_be_bytes(array_aux))
    }
    
    fn rotate_word(input: u32) -> [u8; 4] {
        let bytes: [u8; 4] = input.to_be_bytes();
        [
            *bytes.get(1).unwrap_or(&0),
            *bytes.get(2).unwrap_or(&0),
            *bytes.get(3).unwrap_or(&0),
            *bytes.first().unwrap_or(&0),
        ]
    }
    

## Circuits and gadgets

If we tried hardcoding the circuit of AES, this would be an impossible task, given the kind and number of operations we have to perform. For example, suppose we want to perform the XOR operation between one byte of the message and the round key, $st[i] \oplus rk[i]=st^\prime [i]$. First, we need to decompose each byte into its constituent bits and check that each of them is indeed either $0$ or $1$:  
$st[i,j]\times st[i,j]=st[i,j]$  
$rk[i,j]\times rk[i,j]=rk[i,j]$  
$st^\prime[i,j]\times st\prime[i,j]=st\prime[i,j]$  
Next, we need to compute the XOR operation between bits,  
$2st[i,j]\times rk[i,j]=st[i,j]+rk[i,j]-st^\prime[i,j]$  
We have eight equations per byte, so there are 32 constraints for every byte XOR (we could remove the checks for $st^\prime$ since the XOR guarantees that they are 0 or 1, reducing the count to 24). Every add round key function takes 16 bytes, so we take 512 (or 384) constraints per round!

We can implement a gadget that adds the constraints corresponding to its binary decomposition whenever we define a new byte variable. We can also implement an XOR gadget between bytes, adding the constraints for the operation. The following code makes use of gadgets for `u8`:
    
    use ark_r1cs_std::bits::uint8::UInt8;
    
    let a = UInt8::new_input(cs, || Ok(1))?;
    
    let result = a.xor(&a)?;
    let zero = UInt8::constant(0);
    result.enforce_equal(&zero)?;
    

What happens with the substitution boxes? We could implement a gadget for the whole operation. The problem is that the number of constraints scales super fast! There are more than 10 XOR operations per step, which is time-consuming. The s-boxes are generally obtained from a lookup table, which has all the possible output values precomputed.
    
    fn substitute_byte(byte: &UInt8Gadget, lookup_table: &[UInt8Gadget]) -> Result<UInt8Gadget> {
        Ok(UInt8Gadget::conditionally_select_power_of_two_vector(
            &byte.to_bits_be()?,
            lookup_table,
        )?)
    }
    
    pub fn substitute_bytes(
        bytes: &[UInt8Gadget],
        lookup_table: &[UInt8Gadget],
    ) -> Result<Vec<UInt8Gadget>> {
        ensure!(
            bytes.len() == 16,
            "Input must be 16 bytes length when substituting bytes"
        );
    
        let mut substituted_bytes = vec![];
        for byte in bytes {
            substituted_bytes.push(substitute_byte(byte, lookup_table)?);
        }
    
        ensure!(substituted_bytes.len() == 16, "Error substituting bytes");
        Ok(substituted_bytes)
    }
    

## Proof generation

The first step to generating the proof is to obtain the proving and verification keys. These are derived from the structured reference string (SRS) obtained from a secure multiparty computation.
    
    let (proving_key, verifying_key) = synthesize_keys(message_length)?;
    

Here is the definition of the synthesize keys function:
    
    pub fn synthesize_keys(plaintext_length: usize) -> Result<(ProvingKey, VerifyingKey)> {
        let rng = &mut simpleworks::marlin::generate_rand();
        let universal_srs =
            simpleworks::marlin::generate_universal_srs(1_000_000, 250_000, 3_000_000, rng)?;
        let constraint_system = ConstraintSystem::<ConstraintF>::new_ref();
    
        let default_message_input = vec![0_u8; plaintext_length];
        let default_secret_key_input = [0_u8; 16];
        let default_ciphertext_input = vec![0_u8; plaintext_length];
    
        let mut message_circuit: Vec<UInt8Gadget> = Vec::with_capacity(default_message_input.len());
        for byte in default_message_input {
            message_circuit.push(UInt8Gadget::new_witness(constraint_system.clone(), || {
                Ok(byte)
            })?);
        }
    
        let mut secret_key_circuit: Vec<UInt8Gadget> =
            Vec::with_capacity(default_secret_key_input.len());
        for byte in default_secret_key_input {
            secret_key_circuit.push(UInt8Gadget::new_witness(constraint_system.clone(), || {
                Ok(byte)
            })?);
        }
    
        let mut ciphertext_circuit: Vec<UInt8Gadget> =
            Vec::with_capacity(default_ciphertext_input.len());
        for byte in default_ciphertext_input {
            ciphertext_circuit.push(UInt8Gadget::new_input(constraint_system.clone(), || {
                Ok(byte)
            })?);
        }
    
        let _ciphertext = encrypt_and_generate_constraints(
            &message_circuit,
            &secret_key_circuit,
            &ciphertext_circuit,
            constraint_system.clone(),
        );
    
        simpleworks::marlin::generate_proving_and_verifying_keys(&universal_srs, constraint_system)
    }
    

Since this is only a test, we generate the SRS from a function instead of reading it from the result of the multiparty computation.

We now define a function that contains all the steps to generate the proof:
    
    pub fn encrypt(
        message: &[u8],
        secret_key: &[u8; 16],
        ciphertext: &[u8],
        proving_key: ProvingKey,
    ) -> Result<MarlinProof> {
        let rng = &mut simpleworks::marlin::generate_rand();
        let constraint_system = ConstraintSystem::<ConstraintF>::new_ref();
    
        let mut message_circuit: Vec<UInt8Gadget> = Vec::with_capacity(message.len());
        for byte in message {
            message_circuit.push(UInt8Gadget::new_witness(constraint_system.clone(), || {
                Ok(byte)
            })?);
        }
    
        let mut secret_key_circuit: Vec<UInt8Gadget> = Vec::with_capacity(secret_key.len());
        for byte in secret_key {
            secret_key_circuit.push(UInt8Gadget::new_witness(constraint_system.clone(), || {
                Ok(byte)
            })?);
        }
    
        let mut ciphertext_circuit: Vec<UInt8Gadget> = Vec::with_capacity(ciphertext.len());
        for byte in ciphertext {
            ciphertext_circuit.push(UInt8Gadget::new_input(constraint_system.clone(), || {
                Ok(byte)
            })?);
        }
    
        encrypt_and_generate_constraints(
            &message_circuit,
            &secret_key_circuit,
            &ciphertext_circuit,
            constraint_system.clone(),
        )?;
    
        // Here we clone the constraint system because deep down when generating
        // the proof the constraint system is consumed and it has to have one
        // reference for it to be consumed.
        let cs_clone = (*constraint_system
            .borrow()
            .ok_or("Error borrowing")
            .map_err(|e| anyhow!("{}", e))?)
        .clone();
        let cs_ref_clone = ConstraintSystemRef::CS(Rc::new(RefCell::new(cs_clone)));
    
        let proof = simpleworks::marlin::generate_proof(cs_ref_clone, proving_key, rng)?;
    
        Ok(proof)
    }
    

Finally, we run the following lines to get the proof:
    
    let message = [1_u8; 16]; \\Example message
    let secret_key = [0_u8; 16]; \\Example key
    
    let proof = encrypt(&message, &secret_key, &primitive_ciphertext, proving_key)?;
    

## Verification

To verify the proof, we first encapsulate all the steps in this function, reading the verifying key, the proof and the ciphertext:
    
    pub fn verify_encryption(
        verifying_key: VerifyingKey,
        proof: &MarlinProof,
        ciphertext: &[u8],
    ) -> Result<bool> {
        let mut ciphertext_as_field_array = vec![];
    
        for byte in ciphertext {
            let field_array = byte_to_field_array(*byte);
            for field_element in field_array {
                ciphertext_as_field_array.push(field_element);
            }
        }
    
        simpleworks::marlin::verify_proof(
            verifying_key,
            &ciphertext_as_field_array,
            proof,
            &mut simpleworks::marlin::generate_rand(),
        )
    }
    

Then, we run and check the result
    
    let result = verify_encryption(
        verifying_key,
        &proof,
        &primitive_ciphertext
    )?;
    
    assert!(result);
    

## Summary

AES is the most widely used encryption method. In this post, we addressed the problem of offering cryptographic proof for the correct execution of the AES encryption function for a given plaintext-key pair. Using the Arkworks library, we implemented AES and obtained its representation as an R1CS. Afterward, using Marlin and the Kate-Zaverucha-Goldberg polynomial commitment scheme, we generated a cryptographic proof. The verifier, using the ciphertext as input, can verify the proof to assert the correct execution of the function.
