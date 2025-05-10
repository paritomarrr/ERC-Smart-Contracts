# ERC-2612: Permit Extension for EIP-21 Signed Approvals Deep Dive

## Introduction

### Motivation Behind ERC-2612
ERC-2612 was introduced to address one of the biggest usability pain points of ERC-20 tokens: the need for a two-step process to interact with smart contracts.

In standard ERC-20 tokens, if a user wants a smart contract to spend their tokens on their behalf, they must:

1. Call `approve(spender, amount)` - a transaction signed and sent from the token owner's wallet.

2. Then call `transferFrom(from, to, amount)` - which is often done by the spender (usually a contract). 

This 2-step flow requires:
- Two separate on-chain transactions.
- ETH in the user's wallet to pay gas for both.
- The user to interact directly with the blockchain, even if a dApp is mediating.

This creates UX friction, especially for:
- New users unfamiliar with gas and approvals.
- Users who don't hold ETH.
- Mobile / web-based wallet flows where users expect a single action. 

Example Friction:
Imagine a user wants to deposit DAI into a lending protocol. They must first approve the protocol to spend their DAI and only then can they deposit. This adds latency, cost, and complexity - and leads to a poor onboarding experience. 

### Limitations of Standard `approve()`
- Requires ETH: Even for basic approvals, the sender must hold ETH to cover gas fees.
- 2-Step UX: As mentioned, interacting with DeFi often requires both approve and then a function like deposit or swap, adding extra steps.
- Not flexible: Approvals can’t be batched or delegated easily.
- Message sender (msg.sender) bound: Only the token owner (EOA) can issue the approval, making smart contract wallets less interoperable.

### Benefits of Gasless Approvals
ERC-2612 introduces the `permit()` function, allowing approval via a signed message, rather than a transaction. This enables:

- Gasless User Onboarding: Users don’t need ETH to approve spending — a relayer or dApp can submit the transaction on their behalf.

- Single-Transaction Flows: By including a permit signature, a smart contract can call `permit()` and `transferFrom()` in one transaction.

- Off-chain Approval Logic: Approvals are now detached from msg.sender. This enables:

> dApp-native meta-transactions.
> More flexible transaction bundling and batching.
> Wallets to generate signed approvals without sending them on-chain.

- Wallet Compatibility via EIP-712: `permit()` uses EIP-712 typed structured data, which is already widely supported in:

> Metamask
> WalletConnect
> Safe (Gnosis)
> Ledger/Trezor

## Conceptual Overview
### How `permit()` works at a high level

At its core, the `permit()` function allows a token holder to grant an allowance to a spender via an off-chain signature instead of an on-chain `approve()` transaction. 

The flow looks like this:
1. The user signs a message off-chain (containing: owner, spender, amount, deadline, nonce).
2. The dApp or relayer submits that signed message on-chain via `permit()` function. 
3. The contract:
- Validates the signature
- Confirms the nonce hasn't been used
- Confirms it hasn't expired (`block.timestamp <= deadline`)
- Sets `allowance[owner][spender] = amount`
- Emits an `Approval` event

### Key Idea
The actual spender does not need to be signer. Anyone can submit the permit - it's the signature that proves authorization, not `msg.sender`.
This decouples gas from user intent - making gasless approvals possible.

### The Role of EIP-712 Typed Data
ERC-2612 uses EIP-712, which defines a standard way to sign structured data. Why?
Because:
- Signing typed data is safer than signing raw hashes.
- It allows wallets to display what the user is signing in human-readable form.
- It prevents signature collision across dApps and networks.

How It's Structured:
EIP-712 defines a "domain separator" unique to the dApp, network, and contract - and then signs a typed `Permit` struct with the relevant parameters.

```solidity
keccak256(abi.encode(
    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
    owner,
    spender,
    value,
    nonce,
    deadline
));
```

This is then wrapped in a special `EIP-712` hash format to produce a final digest, which is signed off-chain.

### Off-Chain Signing, On-Chain Submission
- Off-chain: The user signs the permit with their private key using a wallet like MetaMask or Safe. 
- On-chain: The relayer or smart contract submits `permit(...)` with the signature and relevant data.

This is common in gasless DeFi interactions or meta-transactions, where someone else pays gas but the user still authorizes action via signature. 

> A relayer can post a `permit()` + `transferFrom()` in one go, completely gasless for the user. 

### Replay Protection via Nonces
Every `permit()` uses a nonce - a number that increments after each successful signature for a given owner. 
This provides:
1. Replay protection - the same signature can't be reused.
2. Order enforcement - each permit must have the correct nonce or it will revert.
3. Off-chain UX safety - dApps can display the current nonce before signing.

Example:
- First permit: nonce = 0
- Next permit: nonce = 1
- If someone reuses the old signature (nonce = 0), it will fail, even if all other data is valid. 

## 3. Spec Breakdown
This section breaks down the three main components of ERC-2612 and how they extend the base ERC-20 interface. 

### `function permit(...)`
```solidity
function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
) external;
```

Purpose:
Grants `spender` the right to spend `value` tokens on behalf of `owner`, via an EIP-712 signature.

Key Requirements:
- `block.timestamp <= deadline`: prevents signature reuse beyond a certain time. 
- Signature must match EIP-712 typed message format. 
- Signature must be signed by `owner`, not any other party.
- `owner` must not be zero address.
- `spender` must not be zero address.
- `nonces[owner]` must match the one used to generate the signature.
- Once validated:
> `allowance[owner][spender] = value`
> `nonces[owner]++`
> `Approval` event is emitted

Effect:
A successful call to `permit()` results in the same effect as a successful `approve()`, but without requiring an on-chain transaction from the token owner.

### `function nonces(address owner)`

```solidity
function nonces(address owner) external view returns (uint256);
```

Purpose:
Returns the current nonce associated with a given `owner`.
This nonce is crucial to replay protection - it must be included in the signed message and increments with every successful `permit()` call. 

Usage Flow:
1. dApp reads `nonces(owner)`
2. Includes it in the permit signature
3. Contract checks that the passed `nonce` matches `nonces[owner]`
4. After success, `nonces[owner]++`

### `function DOMAIN_SEPARATOR()`

```solidity
function DOMAIN_SEPARATOR() external view returns (bytes32);
```

Purpose:
Returns the EIP-712 domain separator for this token contract.

Why it matters:
The domain separator is part of the EIp-712 signature scheme, and ensures that a signature:
- Cannot be reused across different contracts
- Cannot be reused across forks (if `chainId` changes)

Typical Construction:
```solidity
DOMAIN_SEPARATOR = keccak256(
    abi.encode(
        keccak256("EIP712Domain(string name,string version,iint256 chainId,address verifyingContract)"),
        keccak256(bytes(name)),
        keccak256(bytes("1")).
        block.chainId,
        address(this)
    )
)
```

This value is used when computing the final digest to verify signatures via `ECDSA.recover`.

Typehash: PERMIT_TYPEHASH

This is a constant hash used to represent the structured data for the `permit()` function.

```solidity
bytes32 constant PERMIT_TYPEHASH = keccak256(
    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
);
```

It's used when encoding the full message for signing and verification:
```solidity
bytes32 structHash = keccak256(abi.encode(
    PERMIT_TYPEHASH,
    owner,
    spender,
    value,
    nonce,
    deadline
));
```

This structHash is then passed to `_hashTypedDataV4()` to produce the final message digest. 

## 4. Anatomy of a `permit()` call
This section provides a step-by-step breakdown of how a `permit()` call works - from the creation of the off-chain signature to the on-chain execution and allowance update.
It connects the abstract EIP-2612 logic with concrete implementation behavior. 

### Step-by-Step Flow
1. User wants to approve a spender to spend their tokens - without sending a transaction.
2. They generate a signature off-chain over a structured message.
3. A relayer or dApp sends the signature on-chain by calling `permit(...)` on the token contract.
4. The token contract:
- Verifies the signature
- Updates the allowance mapping
- Increments the `nonce`
- Emits an `Approval` event

At no point does the owner need to hold or spend ETH - this is gasless approval.

### Signature Creation Process
To sign data off-chain, you must:
- Follow the EIP-712 typed data format
- Create a domain separator
- Create the structured Permit message
- Hash everything
- Use your wallet (like MetaMask) to sign it

| Parameter           | Description                              |
| ------------------- | ---------------------------------------- |
| `owner`             | The token holder                         |
| `spender`           | Who will be allowed to spend tokens      |
| `value`             | Amount to approve                        |
| `nonce`             | Current nonce of `owner`                 |
| `deadline`          | Expiry timestamp (must be in the future) |
| `name`              | Token name used in domain separator      |
| `version`           | Usually `"1"`                            |
| `chainId`           | Chain ID (e.g., 1 for Ethereum mainnet)  |
| `verifyingContract` | Token contract address                   |

### EIP-712 Message Structure
```typescript
const domain = {
    name: "MyToken",
    version: "1",
    chainId: 1,
    verifyingContract: "0xYourTokenAddress"
};

const types = {
    Permit: [
        {name: "owner", type: "address"},
            { name: "spender", type: "address" },
    { name: "value", type: "uint256" },
    { name: "nonce", type: "uint256" },
    { name: "deadline", type: "uint256" }
    ]
};

const message = {
    owner: "0xOwnerAddress",
    spender: "0xSpenderAddress",
    value: ethers.parseUnits("1000", 18),
    nonce: 0,
    deadline: Math.floor(Date.now() / 1000) + 3600 // 1 hour from now
};
```

This structured data is then passed to :
```typescript
const signature = await signer._signTypedData(domain, types, message);
```

You get back: `{v, r, s}` - the ECDSA Signature.

### What Happens in `permit()`
The token contract's `permit()` function performs:
1. Revert if expired: 

```solidity
if (block.timestamp > deadline) {
    revert ERC2612ExpiredSignature(deadline);
}
```

2. Compute the struct hash using the `PERMIT_TYPEHASH`:
```solidity
keccak256(
    abi.encode(
        PERMIT_TYPEHASH,
        owner,
        spender,
        value,
        nonce,
        deadline
    )
);
```

3. Wrap the struct hash in an EIP-712 domain separator:
```solidity
hash = _hashTypedDataV4(structHash);
```

4. Recover signer from signature:
```solidity
address signer = ECDSA.recover(hash, v, r, s);
```

5. Check signer matches owner:
```solidity
if (signer != owner) {
    revert ERC2612InvalidSigner(signer, owner);
}
```

6. Consume nonce:
Read and increments `nonces[owner]` to prevent replays.

7. Approve tokens:
```solidity
_approve(owner, spender, value);
```

8. Emit Approval event:
```solidity
emit Approval(owner, spender, value);
```

## 5. Domain Separator (EIP-712)
The DOMAIN_SEPARATOR is a crucial part of the EIP-712 standard that ensures signatures are valid only for a specific contract on a specific chain. It helps prevent signature replay attacks across different domains (contracts or chains).

### What is the DOMAIN_SEPARATOR?
The `DOMAIN_SEPARATOR` is a unique, per-contract-per-chain value used to isolate the context of a signature. It's combined with the hashed permit message to form the final digest that the user signs.

In simpler terms:

> It binds a signature to a specific smart contract instance and chain ID.

It is defined as:
```solidity
DOMAIN_SEPARATOR = keccak256(
    abi.encode(
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
        keccak256(bytes(name)),
        keccak256(bytes("1")), // version
        block.chainid,
        address(this)
    )
);
```

This ensures:

- The same signature can’t be reused across multiple tokens
- It’s chain-aware: signatures on mainnet can't be used on a testnet (and vice versa)

### How it's used in ERC-2612
When `permit()` is called, the signature must be over the EIP-712 typed data, which includes the `DOMAIN_SEPARATOR`.

Final hash being signed:

```solidity
keccak256(
    abi.encodePacked(
        "\x19\0x1",
        DOMAIN_SEPARATOR,
        keccak256(abi.encode(
            PERMIT_TYPEHASH,
            owner,
            spender,
            value,
            nonce,
            deadline
        ))
    )
);
```

Without the domain separator, this hash would be replayable on any contract that accepts the same struct - a serious security flaw. 

### Preventing Replay Across Chains and Contracts
Let’s say a user signs a permit message off-chain. Without a domain separator:

- An attacker could replay the exact same signature on another ERC-20 contract — draining their funds.

- Or they could replay it on another chain (if the same contract was deployed to multiple networks).

The domain separator protects against this by ensuring:

- The contract address is baked into the hash

- The chain ID is included

So even if everything else in the signature is identical, it would fail validation on the wrong chain or contract.

### Static vs Dynamic Domain Separator
There are two common ways to compute the `DOMAIN_SEPARATOR`:

Static (computed once at deployment):
```solidity
constructor() {
    DOMAIN_SEPARATOR = keccak256(abi.encode(...));
}
```

Pros:
- Gas-efficient 
- Simple to understand

Cons:
- Breaks if chain forks and the `chainid` changes
> Replay attacks possible if someone re-deploys the contract on a new chain with same address

Dynamic
```solidity
function _domainSeparatorV4() internal view returns (bytes32) {
    return keccak256(abi.encode(..., block.chainid, address(this)));
}
```

Pros:
- Always accurate
- Safe against chain splits / forks

Cons:

- Slightly more gas to recompute every time
- OpenZeppelin’s EIP712 base contract uses the dynamic approach, and is the recommended best practice.

## 6. Nonces and Replay Protection
One of the most critical components of the permit() mechanism is its replay protection. Without it, a valid off-chain signature could be reused indefinitely — draining user funds or setting unintended allowances.

This is where nonces come in.

### `nonces(owner)` mechanics
Every account `(owner)` has an associated incrementing nonce.

```solidity
mapping(address => uint256) private _nonces;
```

- When a user signs a permit() message, they include their current nonce.
- When permit() is successfully called:
> The contract validates that the nonce matches.
> Then it increments the nonce to invalidate that signature going forward.

Example:
If nonces[alice] == 0, her first signature must include nonce = 0.

After it’s used in permit(), her nonce becomes 1, and that signature is now invalid if replayed.

### `_useNonce(owner)`
In OpenZeppelin’s Nonces base contract, this function is responsible for reading and incrementing the nonce in a single atomic step:

```solidity
function _useNonce(address owner) internal returns (uint256 current) {
    current = _nonces[owner];
    _nonces[owner] = current + 1;
}
```
- Returns the current nonce

- Mutates state by incrementing

- Ensures consistent usage inside the permit() function

This eliminates race conditions or bugs where nonce is read and incremented separately.

### Why Single-Use Signatures Matter
Without a nonce system:

- A relayer (or attacker) could re-submit the same permit signature again and again.

- This would allow them to re-set approvals or drain user tokens.

By using a monotonic nonce, each signature becomes:

- Bound to a specific state

- Valid for a single transaction only

- Resistant to replay attacks

### Off-chain Signature Flow Recap
When a dApp wants to use `permit()`, the flow is:

- Wallet fetches current nonce via `nonces(owner)`

- Wallet signs the `permit()` message using `nonce = N`

- The signed message is sent to a smart contract (by the dApp or relayer)

- The contract calls `permit()`:

> Verifies the signature

> Verifies the nonce matches N

> Uses the nonce

> Updates allowance

Any future reuse of the same signature will fail because the nonce is now `N+1`.

## 7. Signature Encoding
ERC-2612 depends on structured, typed signatures to enable secure off-chain approvals. To build and verify these signatures correctly, developers must deeply understand how they are encoded, signed, and validated on-chain.

### Standard Signature Format: `v`, `r`, `s`
Ethereum uses the Elliptic Curve Digital Signature Algorithm (ECDSA) over secp256k1. Any valid signature consists of:

- `r`: 32 bytes

- `s`: 32 bytes

- `v`: 1 byte (27 or 28) — recovery identifier

Combined, this results in a 65-byte signature, commonly passed as 3 parameters.

In ERC-2612, this signature authenticates the structured message produced by EIP-712.

### Constructing the Message to Sign
Here's the digest that must be signed off-chain (with a wallet):

```solidity
keccak256(
  abi.encodePacked(
    "\x19\x01", // EIP-191 version marker
    DOMAIN_SEPARATOR, // prevents cross-contract replay
    keccak256(
      abi.encode(
        PERMIT_TYPEHASH,
        owner,
        spender,
        value,
        nonce,
        deadline
      )
    )
  )
)
```

Where:

- `PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")`

- `DOMAIN_SEPARATOR` is EIP-712 compliant and unique to the contract

This message must be:

- Properly structured
- Properly hashed (matching Solidity’s ABI encoding)
- Signed using ECDSA with the owner’s private key

Most wallets handle this with `eth_signTypedData_v4` (Metamask, WalletConnect, etc.).

### Signing the Permit (Client Side)
Here's how you'd generate a valid permit off-chain

```typescript
const domain = {
  name: "MyToken",
  version: "1",
  chainId: 1, // or your network ID
  verifyingContract: tokenAddress,
};

const types = {
  Permit: [
    { name: "owner", type: "address" },
    { name: "spender", type: "address" },
    { name: "value", type: "uint256" },
    { name: "nonce", type: "uint256" },
    { name: "deadline", type: "uint256" },
  ],
};

const message = {
  owner: ownerAddress,
  spender: spenderAddress,
  value: amountToApprove,
  nonce: await token.nonces(ownerAddress),
  deadline: futureTimestamp,
};

const signature = await signer._signTypedData(domain, types, message);
```

Then split the signature:
```typescript
const { v, r, s } = ethers.utils.splitSignature(signature);
await token.permit(owner, spender, value, deadline, v, r, s);
```


### DAI-Style Permits vs ERC-2612
DAI was the first to introduce a signature-based approval system, but its implementation differs:

| Aspect            | DAI            | ERC-2612                            |
| ----------------- | -------------- | ----------------------------------- |
| Parameter         | `bool allowed` | `uint256 value`                     |
| Expiry field      | `expiry`       | `deadline`                          |
| Message format    | Custom         | EIP-712                             |
| Hashing           | Manual/legacy  | Structured via `_hashTypedDataV4()` |
| Replay protection | `nonce`        | `nonce`                             |

While DAI permits laid the foundation, ERC-2612 brought standardization, EIP-712 compliance, and broader compatibility with wallets.