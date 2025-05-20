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

## 6. Verifying a Signature in ECDSA

### Inputs Required for Verification
To verify a signature, the verifier needs:

- `msgHash` → the hash of the original message (usually Keccak-256 in Ethereum)
- `r, s` → the two components of the ECDSA signature
- `Q` → the public key of the signer

> This is why in Ethereum we can recover the address from a signature:
We know the r, s and msgHash, and we recover Q.

### The Verification Equation
ECDSA signature verification relies on the following core equation:

```
P = (z / s) * G + (r / s) * Q
```

Where:
- `z` is the message hash
- `G` is the generator point
- `Q` is the public key (i.e. Q = d * G)
- `r` and `s` come from the signature

If `x(P) ≡ r mod n`, then the signature is valid.

Let’s break that down.

Step-by-Step Verification

1. Check that `r` and `s` are in range
```
1 <= r < n, 1 <= s < n
```
If not, the signature is invalid.

2. Calculate `s⁻¹ mod n` (modular inverse of `s`)

3. Compute Scalars u₁ and u₂

4. Calculate Point P

5. Check x(P) ≡ r mod n

The x-coordinate of point `P` must match `r` (modulo the curve order). If it does, the signature is valid.

### Why  Does this Work?
```
# -----------------------------------------------
# Why Does ECDSA Signature Verification Work?
# -----------------------------------------------

# Recall the signer calculates:
#     s = k⁻¹ * (z + r * d) mod n
#
# Where:
# - k is a random ephemeral secret
# - z is the message hash
# - r is x(k * G)
# - d is the private key
# - s is part of the signature

# Rearranging to isolate k:
#     k = (z + r * d) * s⁻¹ mod n

# Multiply both sides by G (generator point on the curve):
#     k * G = (z * s⁻¹) * G + (r * s⁻¹) * d * G

# Note:
#     d * G = Q  →  public key

# So:
#     k * G = u1 * G + u2 * Q
#     where:
#         u1 = z * s⁻¹ mod n
#         u2 = r * s⁻¹ mod n

# Therefore:
#     P = u1 * G + u2 * Q = k * G

# Remember:
#     r = x(k * G)
# So:
#     r == x(P)

# Conclusion:
# If the reconstructed point P = u1 * G + u2 * Q has x-coordinate equal to r,
# then the signature is valid. Otherwise, it is invalid.


```

## 7. ECDSA in Ethereum

### Where ECDSA Is Used
ECDSA is foundational to Ethereum’s security model and is used in multiple critical places:

- Transactions: Every Ethereum transaction is signed with ECDSA to prove the sender's authenticity.
- Signed messages: Off-chain messages (like `personal_sign`) use ECDSA signatures to verify intent.
- EIP-712: Typed structured data signing, widely used for improving UX/security in DeFi & DAOs.
- ERC-2612: Enables gasless approvals for ERC-20 tokens by signing `permit(...)` messages off-chain.

Ethereum Signature Format: `{r, s, v}`
Ethereum uses a 65-byte signature composed of:

- `r`: 32-byte x-coordinate of the ephemeral point `R = k * G`

- `s`: 32-byte scalar derived from the signing equation

- `v`: 1-byte recovery identifier that helps reconstruct the public key (27 or 28, sometimes 0/1 internally)

```
Signature = { r: bytes32, s: bytes32, v: uint8 }
Total size = 65 bytes
```

Public Key Recovery: `ecrecover`
In Ethereum, rather than sending the full public key, signatures include `{r, s, v}`, and the recipient recovers the public key from the signature using the `ecrecover` precompile at address `0x01`.


```
address recovered = ecrecover(messageHash, v, r, s);
```

This allows anyone to verify that the signer (owner of private key) matches an Ethereum address — without the sender having to send their full public key.

Chain ID and `v` Role: EIP-155
To prevent cross-chain replay attacks, Ethereum introduced EIP-155, which modifies the `v` value to encode the chain ID.

Instead of being just 27 or 28, `v` becomes:

```
v = chain_id * 2 + 35 or 36
```

- Helps distinguish the intended chain of the transaction

- Ensures the signature is invalid on other EVM-compatible chains

This is why v can often look like 137, 138 (for chainId 51), etc.

## 8. Signature Encoding in ECDSA

### `r`, `s`, and `v` Components
ECDSA signatures consist of three main values:

- `r` — the x-coordinate of the ephemeral point `R = k * G`
- `s` — a scalar computed as `s = k⁻¹(z + r * d) mod n`
- `v` — the recovery identifier (either 27/28 or 0/1), indicating which of two possible public keys is valid

### Ethereum's Concatenated Signature Format (65 Bytes)
Ethereum uses a flat binary format for signatures:

```
Signature = r (32 bytes) || s (32 bytes) || v (1 byte)
           = total 65 bytes
```

This format is optimized for gas and simplicity.

Example (Hex representation):

```
r: 0x1c4f...29d3 (32 bytes)
s: 0x7aab...f01b (32 bytes)
v: 0x1b        (1 byte = 27)
```

Combined into a single 65-byte signature string.

### DER Encoding vs Ethereum Format
DER (Distinguished Encoding Rules) is a common ASN.1 format used in TLS, OpenSSL, and traditional cryptography libraries.

A DER-encoded ECDSA signature looks like:
```
0x30 + length +
   0x02 + len(r) + r_bytes +
   0x02 + len(s) + s_bytes
```

- Variable length
- Includes metadata like tags and lengths
- Commonly used in Web2 systems and Bitcoin

Ethereum avoids DER for:

- Simplicity
- Fixed-length structure (always 65 bytes)
- Compatibility with ecrecover and EVM precompiles

## 9. EIP-712 & Typed Data Signing

### The Problem: Replay Attacks with Off-Chain Signatures
Traditional signatures using `personal_sign` or `eth_sign` just hash a raw string:

```solidity
hash = keccak256("\x19Ethereum Signed Message:\n" + len(msg) + msg)
```

Problem:
- Same signature could be reused across different contracts or chains.

- Anyone could copy a signed message and reuse it somewhere else (replay attack).

- The original signer might not have intended to approve the second action.

The EIP-712 Solution: Typed, Structured Data

EIP-712 improves message signing by:
- Introducing structured data
- Separating the data into domain, type hash, and message body
- Making signatures human-readable and context-specific

No more raw strings. Everything is structured like a typed object in JSON.

### The Domain Separator
The domain separator anchors the signature to:

- A specific contract
- A specific chain
- A specific dApp context

```solidity
DOMAIN_SEPARATOR = keccak256(
  abi.encode(
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
    keccak256(bytes(name)),
    keccak256(bytes(version)),
    chainId,
    address(this)
  )
);
```

This ensures the signature cannot be used in other contracts or chains.

### How the Hashing Works
EIP-712 uses this formula for the full message hash:

```solidity
hashToSign = keccak256(
  abi.encodePacked(
    "\x19\x01",
    DOMAIN_SEPARATOR,
    keccak256(
      abi.encode(
        TYPEHASH,  // a keccak hash of the struct definition
        ...        // values of the struct
      )
    )
  )
);
```

This `hashToSign` is passed to `ecdsa.recover()` for signature verification.

## 10. ECDSA vs EdDSA

### What is EdDSA?
EdDSA stands for Edwards-curve Digital Signature Algorithm.

It’s a newer digital signature scheme based on elliptic curve cryptography, just like ECDSA — but with several cryptographic and implementation improvements.

The most popular instantiation is:
- Ed25519 (based on the twisted Edwards curve Curve25519)
- Used in protocols like: Signal, Tor, Solana, Starknet (EdDSA on Stark Curve), etc.

### Key Differences:
| Feature             | **ECDSA**                            | **EdDSA (Ed25519)**                     |
| ------------------- | ------------------------------------ | --------------------------------------- |
| Curve               | secp256k1                            | Edwards curve: ed25519 (or stark curve) |
| Determinism         | Non-deterministic (needs random `k`) | Deterministic (uses RFC 8032)           |
| Security Risk       | If `k` reused → private key leak     | Immune to `k` reuse errors              |
| Signature Size      | 65 bytes (r, s, v)                   | 64 bytes                                |
| Speed (Sign/Verify) | Slower                               | Faster                                  |
| Implementation      | Complex & fragile                    | Simple, constant-time, safer            |
| Library Support     | Widely supported                     | Modern but increasingly popular         |
| Ethereum Usage      | Standard everywhere (ECDSA only)     | Not native yet (Starknet supports)      |


### Why EdDSA is Considered Safer & More Modern
1. Deterministic signatures:
- ECDSA’s reliance on random k per message can lead to catastrophic failures (e.g., Sony PlayStation, Blockchain.info bugs).
- EdDSA eliminates that class of bugs with deterministic k derived from the message + private key.

2. Constant-Time Implementation:

- Designed for side-channel resistance and simplicity.
- ECDSA requires extra care to avoid leaking timing information.

3. Simplified Design:

- EdDSA has fewer edge cases and better composability.

### Ongoing Transition in the Blockchain Space
While Ethereum still relies on ECDSA due to legacy and EVM compatibility, newer systems and L2s are actively exploring or adopting EdDSA:

| Ecosystem      | Algorithm                        |
| -------------- | -------------------------------- |
| **Ethereum**   | ECDSA (secp256k1)                |
| **Starknet**   | EdDSA on Stark Curve             |
| **Solana**     | Ed25519                          |
| **ZK Systems** | EdDSA preferred (SNARK-friendly) |
| **Polkadot**   | sr25519 (Schnorr + EdDSA hybrid) |
