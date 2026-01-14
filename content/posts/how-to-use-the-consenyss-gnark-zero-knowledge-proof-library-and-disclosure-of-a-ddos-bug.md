+++
title = "How to use the Consenys's Gnark Zero Knowledge Proof library and disclosure of a DoS bug"
date = 2023-03-17
slug = "how-to-use-the-consenyss-gnark-zero-knowledge-proof-library-and-disclosure-of-a-ddos-bug"

[extra]
feature_image = "/images/2025/12/Bartholomeus_van_der_Helst-_Banquet_of_the_Amsterdam_Civic_Guard_in_Celebration_of_the_Peace_of_Mu--nster.jpg"
authors = ["LambdaClass"]
+++

Zero Knowledge Proofs (ZKP) are a powerful cryptographic technique that allows two parties to exchange information without revealing any sensitive data. This method has the potential to revolutionize the way we handle privacy and security in various industries, such as finance, healthcare, and government. However, developing ZKP applications has traditionally been a challenging task, requiring a deep understanding of cryptography, programming, and mathematics.

Fortunately, with the advancement of technology and the development of new libraries and frameworks, writing ZKP applications has become much easier. Nowadays, there are several libraries available that can significantly reduce the complexity of developing ZKP applications, such as [LambdaWorks](https://github.com/lambdaclass/lambdaworks/), [Arkworks](https://github.com/arkworks-rs/), and [Gnark](https://github.com/ConsenSys/gnark). These libraries provide developers with a set of tools and building blocks that simplify the implementation of complex cryptographic protocols.

In this post, we will focus on reviewing Gnark, one of the most powerful and user-friendly libraries available for ZKP development. Gnark is an open-source library that provides developers with a high-level programming language and a set of tools to build efficient and secure ZKP applications. We will explore the features and benefits of gnark and show how it can simplify the process of building ZKP applications.

## What is Gnark

Gnark, written in Go, is a fast ZK-SNARK library that offers both a high-level API and a low-level API to design circuits. The library is open-source and developed under the Apache 2.0 license.

## Why Gnark

We are using Gnark as a backend for [Noir](https://github.com/noir-lang/noir). Noir is a domain-specific language for creating and verifying proofs. Noir compiles to an intermediate language which itself can be compiled to an arithmetic circuit or a rank-1 constraint system. This in itself brings up a few challenges within the design process but allows one to decouple the programming language completely from the backend. This is similar in theory to LLVM.

## ZK with Gnark

The main flow for generating a ZK-Proof and verifying it would be:

        1. Arithmetization: This is generating the R1CS or Sparse R1CS circuit with its constraints.
        2. Generate a proof of execution for this circuit, given some public and private variables.
        3. Verify said proof with the same public inputs used when generating the proof.

Gnark has both a high level API and a low level API. The main difference relies in the arithmetization. In the high level API you, as a user, are abstracted from the `R1CS` or `SparseR1CS` building and in the low level API you need to build them by hand (constraint by constraint).

In the following sections we're going to explain and show some example usage of the high level and the low level APIs. We'll start showing the bright side of Gnark which is the high level API.

## (Always look on) the bright side

![](/images/external/Xs1ASoT.png)

### High-level API

Gnark's high level API lives in the `frontend` package, you could find it in the root of the repo.

Earlier we said that the main difference relies in the arithmetization, but what does this mean? How so? By arithmetization we basically mean building the circuit with which you're going to generate your proof.

In the case of the `frontend` package, building a circuit means to create your circuit struct which fields must be the variables of the circuit (a.k.a. circuit inputs) labeled as public or secret (not labeled fields are assumed secret variables by default). These inputs must be of type `frontend.Variable` and make up the witness. The witness has a secret part known to the prover only and a public part known to the prover and the verifier.

After you have your circuit structure built you need to define the circuits behaviour. You must do this writing a `Define` function. `Define` declares the circuit logic. The compiler then produces a list of constraints which must be satisfied (a valid witness) in order to create a valid ZK-SNARK. The circuit in the example below proves the factorisation of the RSA-250 challenge.

#### Example: RSA (from [gnark's playground](https://play.gnark.io/))
    
    type Circuit struct {
        P   frontend.Variable // p  --> secret visibility (default)
        Q   frontend.Variable `gnark:"q,secret"` // q  --> secret visibility
        RSA frontend.Variable `gnark:",public"`  // rsa  --> public visibility
    }
    
    func (circuit *Circuit) Define(api frontend.API) error {
        // ensure we don't accept RSA * 1 == RSA
        api.AssertIsDifferent(circuit.P, 1)
        api.AssertIsDifferent(circuit.Q, 1)
    
        // compute P * Q and store it in the local variable res.
        rsa := api.Mul(circuit.P, circuit.Q)
    
        // assert that the statement P * Q == RSA is true.
        api.AssertIsEqual(circuit.RSA, rsa)
        return nil
    }
    

## (Join) the dark side

![](/images/external/P4W3s57.png)

### Low-level API

Located in the `constraint` module at the root of the repo, we can find almost everything that we need to write an R1CS (for Groth16) or a Sparse R1CS for (Plonk) "by hand". By hand we mean to build our circuit constraint by constraint. I said almost earlier because we'll also need some stuff from the `gnark-crypto` library (provides elliptic curve and pairing-based cryptography and various algorithms of particular interest to zero knowledge proof systems).

We say that the arithmetization here is by hand because both the circuit structure and the constraints need to be writen manually.

To add the circuit inputs you have the methods `AddPublicVariable`, `AddSecretVariable` and `AddInternalVariable`. Calling this methods will return an index which corresponds to the concrete value of that variable in the witness vector. The order in which you all these matters in the way that an internal current witness index (in the circuit that you're building) is being mutated.

The circuit behaviour, which in the high-level API must be written in the `Define` function abstracted from the manual constraint generation, is defined constraint by constraint with the method `AddConstraint`. A constraint can be built initializing a `constraint.R1C` (in case of Groth16) or a `constraint.SparseR1C` (in the case of Plonk) term by term. Finally, terms can be created using the `MakeTerm` method.

After this, the next steps (proving and verifying) are the same as in the high level API.

#### Example: proving that $x \cdot y = z$

The next piece of code that proves that $x \cdot y = z$ where $x, z$ are public variables and $y$ a private variable (witness):
    
    func Example() {
        // [Y, Z]
        publicVariables := []fr_bn254.Element{fr_bn254.NewElement(2), fr_bn254.NewElement(6)}
        // [X]
        secretVariables := []fr_bn254.Element{fr_bn254.NewElement(3)
    
        /* R1CS Building */
    
        // (X * Y) == Z
        // X is secret
        // Y is public
        // Z is public
        r1cs := cs_bn254.NewR1CS(1)
    
        // Variables
        _ = r1cs.AddPublicVariable("1") // the ONE_WIRE
        Y := r1cs.AddPublicVariable("Y")
        Z := r1cs.AddPublicVariable("Z")
        X := r1cs.AddSecretVariable("X")
    
        // Coefficients
        COEFFICIENT_ONE := r1cs.FromInterface(1)
    
        // Constraints
        // (1 * X) * (1 * Y) == (1 * Z)
        constraint := constraint.R1C{
            L: constraint.LinearExpression{r1cs.MakeTerm(&COEFFICIENT_ONE, X)}, // 1 * X
            R: constraint.LinearExpression{r1cs.MakeTerm(&COEFFICIENT_ONE, Y)}, // 1 * Y
            O: constraint.LinearExpression{r1cs.MakeTerm(&COEFFICIENT_ONE, Z)}, // 1 * Z
        }
        r1cs.AddConstraint(constraint)
    
        constraints, r := r1cs.GetConstraints()
    
        for _, r1c := range constraints {
            fmt.Println(r1c.String(r))
        }
    
        /* Universal SRS Generation */
    
        pk, vk, _ := groth16.Setup(r1cs)
    
        /* Proving */
    
        rightWitness := buildWitnesses(r1cs, publicVariables, secretVariables)
    
        p, _ := groth16.Prove(r1cs, pk, rightWitness)
    
        /* Verification */
    
        publicWitness, _ := rightWitness.Public()
    
        verifies := groth16.Verify(p, vk, publicWitness)
    
        fmt.Println("Verifies with the right public values :", verifies == nil)
    
        wrongPublicVariables := []fr_bn254.Element{fr_bn254.NewElement(1), fr_bn254.NewElement(5)}
        wrongWitness := buildWitnesses(r1cs, wrongPublicVariables, secretVariables)
        wrongPublicWitness, _ := wrongWitness.Public()
        verifies = groth16.Verify(p, vk, wrongPublicWitness)
    
        fmt.Println("Verifies with the wrong public values :", verifies == nil)
    }
    

For you to be able to run this, you'll need the `buildWitness` function:
    
    func buildWitnesses(r1cs *cs_bn254.R1CS, publicVariables fr_bn254.Vector, privateVariables fr_bn254.Vector) witness.Witness {
        witnessValues := make(chan any)
    
        go func() {
            defer close(witnessValues)
            for _, publicVariable := range publicVariables {
                witnessValues <- publicVariable
            }
            for _, privateVariable := range privateVariables {
                witnessValues <- privateVariable
            }
        }()
    
        witness, err := witness.New(r1cs.CurveID().ScalarField())
        if err != nil {
            log.Fatal(err)
        }
    
        // -1 because the first variable is the ONE_WIRE.
        witness.Fill(r1cs.GetNbPublicVariables()-1, r1cs.GetNbSecretVariables(), witnessValues)
    
        return witness
    }
    

### A small bug

There's a minor detail when using the low-level API that you have to take into account. Maybe you've noticed it but if not, take a look at this line in the example above:
    
    _ = r1cs.AddPublicVariable("1") // the ONE_WIRE
    

You're probably wondering why this is necessary if we are not using the variable returned by the function. Well, we like to code so, let's remove the line and the patch for this in the `buildWitness` function (for this patch, remove the -1 in the `witness.Fill` line of the function) execute the code.

When doing that you'll get this error:
    
    18:32:36 ERR error="invalid witness size, got 3, expected 2 = 1 (public) + 1 (secret)" backend=groth16 nbConstraints=1
    

The error says that we are specting 2 variables (1 public and 1 private) when this is wrong. We've already declared 3 variables (2 public and 1 private).

The reason why this happens and why the patch works is beyond the scope of this post but it's a gnark's implementation detail that leaked into the API. You can read more about that in this [issue](https://github.com/ConsenSys/gnark/issues/544).

## Infinite loop during the arithmetization

We found a small bug in the arithmetization code.

Let's modify a little bit our earlier Groth16's example and
    
    func Example() {
        // [Y, Z]
        publicVariables := []fr_bn254.Element{fr_bn254.NewElement(2), fr_bn254.NewElement(5)}
        // [X]
        secretVariables := []fr_bn254.Element{fr_bn254.NewElement(5)}
    
        /* R1CS Building */
    
        // (X * Y) == Z + 5
        // X is secret
        // Y is public
        // Z is public
        // 5 is constant
        r1cs := cs_bn254.NewR1CS(1)
    
        // Variables
        _ = r1cs.AddPublicVariable("1") // the ONE_WIRE
        Y := r1cs.AddPublicVariable("Y")
        Z := r1cs.AddPublicVariable("Z")
        X := r1cs.AddSecretVariable("X")
    
        // Constants
        FIVE := r1cs.FromInterface(5)
        CONST_FIVE_TERM := r1cs.MakeTerm(&FIVE, 0)
        CONST_FIVE_TERM.MarkConstant()
        
        // Coefficients
        COEFFICIENT_ONE := r1cs.FromInterface(1)
    
        // Constraints
        // (1 * X) * (1 * Y) == (1 * Z) + (5 * 1)
        constraint := constraint.R1C{
            L: constraint.LinearExpression{r1cs.MakeTerm(&COEFFICIENT_ONE, X)}, // 1 * X
            R: constraint.LinearExpression{r1cs.MakeTerm(&COEFFICIENT_ONE, Y)}, // 1 * Y
            O: constraint.LinearExpression{
                r1cs.MakeTerm(&COEFFICIENT_ONE, Z)}, // 1 * Z 1
                CONST_FIVE_TERM, // 5
        }
        r1cs.AddConstraint(constraint)
    
        constraints, r := r1cs.GetConstraints()
    
        for _, r1c := range constraints {
            fmt.Println(r1c.String(r))
        }
    
        /* Universal SRS Generation */
    
        pk, vk, _ := groth16.Setup(r1cs)
    
        /* Proving */
    
        rightWitness := buildWitnesses(r1cs, publicVariables, secretVariables)
    
        p, _ := groth16.Prove(r1cs, pk, rightWitness)
    
        /* Verification */
    
        publicWitness, _ := rightWitness.Public()
    
        verifies := groth16.Verify(p, vk, publicWitness)
    
        fmt.Println("Verifies with the right public values :", verifies == nil)
    
        wrongPublicVariables := []fr_bn254.Element{fr_bn254.NewElement(1), fr_bn254.NewElement(5)}
        wrongWitness := buildWitnesses(r1cs, wrongPublicVariables, secretVariables)
        wrongPublicWitness, _ := wrongWitness.Public()
        verifies = groth16.Verify(p, vk, wrongPublicWitness)
    
        fmt.Println("Verifies with the wrong public values :", verifies == nil)
    }
    

At first glance it looks like this should work smoothly, but give it a try and run it. Noticed something wrong? If you tried it your answer'd be yes, because after a while you'll end up with a `signal: killed` message.

No problem, let's fix it. Simply remove the following line:
    
    CONST_FIVE_TERM.MarkConstant()
    

The difference is just one line; we are making the same as above, only we are not marking the constant term as constant.

## The problem

If you run the fix above, you'll see that execution finishes successfully and everyone is happy. Well, not so fast fren. This means you, as a Gnark user, can bypass the issue and build a working circuit. A malicious user, however, can still create faulty circuits that break execution.

With this exploit, a server running a Gnark prover that accepts arbitrary circuits (Noir and Aleo Instructions are one example of languages that allow this behaviour to happen) can be brought down through a DDoS attack. A user can repeatedly send the faulty circuit shown above for execution, wasting cycles and forcing crashes over and over.

## Conclusion

Gnark is from our point of view one of the best for developing ZKP applications with a lot of pros and cons, depending on what you want to do. In general if you want to develop ZKP apps the high-level API would be good enough for you. In our case, we needed to go a little deeper and because of that we found some flaws.

So if you're interested in learning more about how to develop ZKP applications using Gnark, stay tuned for our upcoming blog post. We will provide you with a step-by-step guide and show you how easy it can be to build powerful and secure ZKP applications using this amazing library.
