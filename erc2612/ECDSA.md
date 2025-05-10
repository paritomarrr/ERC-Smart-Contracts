# ECDSA Deep Dive

## 1. Introduction to Digital Signatures

### What are Cryptographic Signatures?
A cryptographic signature is a mathematical mechanism that proves the authenticity and integrity of a message or piece of data. Just like a handwritten signature proves authorship on a paper document, a cryptographic signature proves that a message was signed by the owner of a specific private key, and that the message was not tampered with.

A signature is:

- Verifiable: Anyone can check if the signature is valid.
- Non-repudiable: The signer cannot later deny having signed the message.
- Tamper-evident: If the message is changed, the signature becomes invalid.

A digital signature algorithm consists of three main operations:

- Key generation: Produce a private key (secret) and a public key (can be shared).
- Signing: Use the private key to generate a signature for a message.
- Verification: Use the public key to verify that the signature is valid for a message.

### Use Cases in Ethereum
Digital signatures are fundamental to Ethereum and power many core functionalities:

1. Transactions
Every Ethereum transaction is signed by the sender’s private key. This:

- Proves ownership of the account.
- Authorizes the transfer of funds or contract execution.
- Ensures the transaction hasn’t been tampered with.

2. Messages (Off-chain)
Using `eth_sign`, `personal_sign`, or `EIP-712`, users can sign arbitrary messages off-chain.

Use cases:

- Prove ownership of an address without sending a transaction.
- Sign messages in dApps (like logging into Uniswap or OpenSea).
- Off-chain voting or agreement signing.

3. Meta-Transactions
These allow someone else (a relayer) to submit a transaction on your behalf:

- You sign a message authorizing an action.
- The relayer pays the gas and submits it to the blockchain.

This is especially useful in dApps where you want gasless UX for users.

4. ERC-2612: Permit
- Lets you approve ERC20 allowances via signature, not via transaction.
- Saves gas, removes the need for approve() and transferFrom() to be separate.
- Popularized by Uniswap and Aave.

### ECDSA vs Other Signature Schemes
| Algorithm                                              | Curve / Structure          | Used In                 | Key Size   | Strengths                                                               |
| ------------------------------------------------------ | -------------------------- | ----------------------- | ---------- | ----------------------------------------------------------------------- |
| **ECDSA** (Elliptic Curve Digital Signature Algorithm) | secp256k1                  | Bitcoin, Ethereum       | 256-bit    | Compact keys, fast signing, widely adopted                              |
| **RSA** (Rivest–Shamir–Adleman)                        | Prime number factorization | Legacy systems, SSL/TLS | 2048+ bits | Simpler to understand, but large key size                               |
| **EdDSA** (Edwards-curve Digital Signature Algorithm)  | Ed25519                    | zkSync, Solana          | 256-bit    | Deterministic signatures, better randomness safety, faster verification |


### Why Ethereum Uses ECDSA:
- Compact key/signature size → cheaper on-chain storage.
- Based on secp256k1, which Bitcoin also uses.
- Well-supported by existing libraries and wallets.
- Proven security under the Elliptic Curve Discrete Logarithm Problem.

## 2. Theoretical Foundations

### What is ECDSA?
ECDSA (Elliptic Curve Digital Signature Algorithm) is a digital signature scheme that uses elliptic curve cryptography (ECC) to produce compact, efficient, and secure digital signatures. It is the signature algorithm used in Bitcoin, Ethereum, and many modern blockchains and cryptographic systems.

ECDSA is used to:
- Sign a message (e.g., a transaction or permit) using a private key.
- Allow anyone to verify that signature using the corresponding public key.

ECDSA is:
- Asymmetric: You sign with a private key and verify with the public key.
- Deterministic (with RFC 6979 or EdDSA): Ensures repeatable results with same inputs.
- Based on ECC: Uses elliptic curve algebra instead of large primes like RSA.

### Why Use Elliptic Curves in Cryptography?
Elliptic curves offer equivalent security to RSA with much smaller key sizes.

| Scheme | Security Level | Key Size  |
| ------ | -------------- | --------- |
| RSA    | 128-bit        | 3072 bits |
| ECC    | 128-bit        | 256 bits  |

Why elliptic curves?
- Faster computations: Signatures and key generation are faster.
- Smaller keys: Less storage, bandwidth, and gas usage.
- Stronger math: Based on a harder problem (discrete logarithms on elliptic curves).
- Efficient for blockchains: Every byte costs gas.

### Basics of Elliptic Curve Cryptography (ECC)
An elliptic curve is defined by an equation of the form:

```sql
y² = x³ + ax + b   (over a finite field)
```

In Ethereum, we use the secp256k1 curve:

```sql
y² = x³ + 7
```

Key Properties:
- Symmetric about the x-axis.
- Every operation (like addition or multiplication) is done modulo a prime number p.
- Points on the curve form a mathematical group, supporting:
> Point addition: Add two points and get a third point.
> Scalar multiplication: Add a point to itself k times (written as k·P).

Example:
if `G` is a base point, and `d` is your private key:

```ini
Q = d . G
```

Here:
- `d` is the private key
- `Q` is the public key (point on the curve)
- `G` is the fixed generator point (defined by secp256k1)

You can easily compute `Q` if you know `d`.
But you cannot `d` if you only know `Q` -- this is the **trapdoor**. 

### Modular Arithmetic in ECC
All arithmetic in ECC is done over a finite field using modulo p operations.

Example:
If p = 17, then:

```lua
5 + 13 = 18 = 1 (mod 17)
```

Why?

- Ensures that all numbers “wrap around” within a finite range.
- Allows cryptographic operations to stay within predictable bounds.
- Keeps calculations safe and efficient for digital systems.

This is important because points on the elliptic curve must be finite and fit in fixed-size keys (like 256 bits in Ethereum).


### The Trapdoor Function
At the heart of ECDSA lies a trapdoor function:

> A mathematical function that is easy to compute in one direction but nearly impossible to reverse without secret knowledge.

In ECDSA:
- It’s easy to compute the public key from the private key:

```ini
Q = d . G
```

- But it’s infeasible to compute d from Q and G due to the Elliptic Curve Discrete Logarithm Problem (ECDLP).

This one-way function guarantees:

- No one can derive your private key from your public key.
- No one can forge your signature without access to your private key.

## 3. The secp256k1 Curve
### Curve Equation
The elliptic curve used in both Ethereum and Bitcoin is defined over a finite field and follows this simple equation:

```
y^2 = x^3 + 7
```

This is a special case of the general Weierstrass form:

```
y^2 = x^3 + ax + b
```

where for secp256k1:
- `a = 0`
- `b = 7`

### Domain Parameters
Every elliptic curve used in cryptography is fully specified by a set of constants, collectively known as domain parameters.

For `secp256k1`, they are:

| Parameter | Meaning                                     | Value                                                                                     |
| --------- | ------------------------------------------- | ----------------------------------------------------------------------------------------- |
| `a`       | Curve coefficient                           | 0                                                                                         |
| `b`       | Curve coefficient                           | 7                                                                                         |
| `p`       | Prime modulus defining the finite field 𝔽ₚ | `0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F` (≈ 2²⁵⁶ - 2³² - 977) |
| `G`       | Base point (generator point)                | A fixed point (x, y) on the curve                                                         |
| `n`       | Order of the base point G                   | `0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141`                      |
| `h`       | Cofactor                                    | 1                                                                                         |


Key Insight:
The curve is defined over a finite field 𝔽ₚ, meaning all coordinates (x, y) must be integers between 0 and p-1, and all arithmetic is done mod p.

### Visualizing the Curve and its Symmetry
Over the real numbers: 
If we plotted this in the real (continous) domain, `y^2 = x^3 + 7` looks like this:

```diff
       |
       |        *
       |      *
       |    *
-------|-----------------------
       |    *
       |      *
       |        *
```

Key features:

- Symmetric about the x-axis
- Smooth and continuous (no sharp corners)
- Has a "bowl-like" shape on both sides of the origin

Over finite field 𝔽ₚ

In Ethereum, we don't use real numbers. Instead, we define the curve over a prime field 𝔽ₚ. So instead of continuous lines, we only have a finite set of integer (x, y) points that satisfy the curve equation mod p.

There are about 2^256 such points — enough to ensure strong cryptographic security.

### Point Addition
Given two points P and Q on the curve, we define P + Q as follows:
1. Draw a straight line between P and Q.
2. That line intersects the curve at exactly one other point, R.
3. Reflect R over the x-axis to get P + Q = −R.

### Formally (when P ≠ Q):
Let:

- `P = (x₁, y₁)`

- `Q = (x₂, y₂)`

Then:
```solidity
λ = (y₂ - y₁) / (x₂ - x₁) mod p
x₃ = λ² - x₁ - x₂ mod p
y₃ = λ(x₁ - x₃) - y₁ mod p
```

so:
```nginx
P + Q = (x₃, y₃)
```

### Point Doubling
Point doubling means computing `2P = P + P`.

Let:

- P = (x, y)

Then:
```solidity 
λ = (3x² + a) / (2y) mod p
x₃ = λ² - 2x mod p
y₃ = λ(x - x₃) - y mod p
```
Since `a = 0` for secp256k1, the formula simplifies to:

```solidity
λ = (3x²) / (2y) mod p
```

### Scalar Multiplication (k.P)
Scalar multiplication is the core cryptographic operation of ECC.

Given:
- A scalar `k`
- A point `P`

Compute:

```ini
Q = k · P = P + P + P + ... (k times)
```

In practice, we use double-and-add or windowed multiplication to compute this efficiently, similar to how exponentiation is optimized in RSA.

Important Properties:
- Easy to compute `Q = k·P`
- Hard to compute `k` given `Q` and `P` — this is the Elliptic Curve Discrete Logarithm Problem (ECDLP)

This one-way property is what makes ECC (and ECDSA) secure.

## 4. Key Generation in ECDSA
At the heart of any digital signature system is the creation of a private key and a corresponding public key. In ECDSA, this process relies entirely on elliptic curve mathematics — particularly scalar multiplication on a chosen curve (secp256k1 for Ethereum and Bitcoin).

### Generating the Private Key `d`
- The private key, denoted `d`, is a random integer:

```
1 <= d <= n
```
where `n` is the order of the base point `G` on the elliptic curve (a large prime number, ~2²⁵⁶ in secp256k1).

- It is critical that d is:
> Truly random (unpredictable)
> Kept secret (never exposed)

 If `d` is predictable or reused across signatures, the entire system becomes vulnerable.


### Deriving the Public Key `Q = d * G`
Once the private key `d` is chosen, we compute the public key `Q`:

```
Q = d * G
```

Where: 
- `G` is the generator point (defined in secp256k1 parameters)

- `*` denotes elliptic curve scalar multiplication — repeatedly adding `G` to itself `d` times

> This is not normal multiplication. It's a special operation on elliptic curves defined by repeated point addition.

Example:
If `d = 7`, then:
```text
Q = 7 * G = G + G + G + G + G + G + G
```

Though this is conceptually straightforward, it is computationally expensive and optimized using techniques like double-and-add or windowed multiplication.

### Irreversibility and the Discrete Log Problem
Why is `Q = d * G` secure?

Because of the Elliptic Curve Discrete Logarithm Problem (ECDLP):

> Given: `Q` and `G`
> Find: `d` such that `Q = d * G`

This problem is:
- Easy to compute in the forward direction (given `d`, find `Q`)
- Infeasible to reverse (given `Q`, find `d`), even with all modern hardware

Why is it hard?
- The number of possible private keys d is ~2^256
- Brute force is computationally infeasible
- There is no known polynomial-time algorithm to solve ECDLP on classical computers

## 5. Signing a Message with ECDSA
To sign a message using ECDSA, we follow a mathematical process that outputs two numbers: r and s — the signature components. The entire security of this system hinges on a small handful of carefully controlled operations and cryptographic assumptions.

### Step 1: Hash the Message
First, the message `msg` (of any length) is hashed:

```solidity
z = keccak256(msg)
```

Why?
- Hashing ensures a fixed-length (256-bit) representation
- Protects the original message content
- Signing a hash is more efficient and secure than signing raw data

In Ethereum, messages are often prefixed before hashing (as in EIP-191 or EIP-712) to prevent cross-protocol replay attacks.

### Step 2: Generate Ephemeral Key `k`
You now choose a fresh random number `k` for the signature only:

```
1 ≤ k < n
```
`k` MUST be unique and unpredictable. Reusing k leaks your private key.

Why is `k` so sensitive?
- The s component of a signature depends on k⁻¹
- If two different messages are signed using the same k, the private key can be fully recovered using simple algebra
- This exact vulnerability broke Sony’s PlayStation 3 and even affected Bitcoin wallets in early days

Best Practice: Use RFC6979 deterministic `k` generation — which derives `k` from the private key and the message hash — removing reliance on randomness.

### Step 3: Compute Signature Components `r` and `s`
Now we calculate the actual signature:

Compute `r`
```
(r, ) = k * Gr = x - coordinateOfPoint(modn)
```

- Use scalar multiplication to compute point `P = k * G`
- `r` is the x-coordinate of the resulting point
- If `r == 0`, pick a new `k` and try again

Compute `s`
```
s = k^-1(z + r * d)modn
```

Where:
- `z` = message hash
- `d` = private key
- `k⁻¹` = modular inverse of `k` under mod `n`
- If `s == 0`, again, pick a new `k`.

### Step 4: Output Signature (r, s)
Your final signature is the pair:

```
signature = (r, s)
```

This is what's sent alongside the message (and public key) to any verifier — either a smart contract (like ERC-2612’s `permit()`), an RPC API, or another off-chain validator.

