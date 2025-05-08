# Security

This standard provides basic functionality to transfer tokens, as well as allow tokens to be approved so that they can be spent by another on-chain third party.

It allows any tokens on Ethereum to be re-used by other applications: from wallets to decentralized exchanges.

NOTE: Callers must handle `false` from `return (bool success)`. 
Callers must not assume that `false` is never returned. 

## Most Important ERC20 Attacks & Vulnerabilities

### 1. Approval Race Condition

What is the problem?
When a user tries to change an allowance by calling `approve(spender, newAmount)`, ERC20 does not prevent the spender from using the old allowance in the meantime. 

This creates a race condition -- where the spender can front-run the allowance change and drain more tokens than intended. 

Step-by-Step Example
Let's say Alice approves Bob to spend her tokens:
- Alice calls: `approve(Bob, 100)`
- Later, Alice wants to reduce Bob's limit and calls: `approve(Bob, 50)`
- But Bob sees her transaction in the mempool
- Before it's mined, Bob sends: `transferFrom(Alice, ..., 100)`
- If Bob's tx is mined first -> he gets 100 tokens
- Then Alice's tx sets allowance to 50
- Now Bob sends another transferFrom for 50 more
- Total stolen: 150 tokens (Alice only meant 100, then 50)

Why is this possible?
- ERC20 doesn't define how multiple `approve()` calls should behave
- Most implementations just overwrite the old value
- There's no check if some of it was already used

This is an API-level flaw, not a bug in one contract -- it affects all standard-compliant ERC20 tokens. 

What can go wrong?

| Issue                                      | Risk                             |
|-------------------------------------------|----------------------------------|
| Spender front-runs allowance changes      | Can drain extra tokens           |
| Wallets don't warn users                  | UX issues and potential token loss |
| No atomic way to change allowance safely  | Causes logic bugs in dApps       |

Mitigation
- Use `increaseAllowance()` and `decreaseAllowance()` instead of overwriting with `approve()`
- If you must change the allowance, do a 2-step reset:
```solidity
approve(spender, 0);
wait for tx to confirm
approve(spender, newValue);
```

What should have been in ERC20?

- Suggested Fix
```solidity
function approve(address spender, uint256 currentAllowance, uint256 newAllowance)
```

Only changes allowance if current value matches, like a `safeApprove`.

Real World Cases
- This is a known bug in Uniswap V2 token interactions
- Many wallets (like MetaMask) still expose users to this risk
- Even OpenZeppelin contracts don't prevent it - they just recommend workarounds

### 2. Infinite Approval Griefing

What is it?
Most dApps (like Uniswap, OpenSea) ask users to approve infinite allowance when interacting with an ERC20 token.
That means setting:
```solidity
approve(spender, type(uint256).max);
```

Which equals:
```
0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff (2^256 - 1)
```

The idea: you approve once, and the contract (like Uniswap) can spend your tokens as needed, without repeated approval popups. 

Why is this risky?
An infinite allowance creates a permanent power relationship:
- The spender can drain your tokens at any time, without your awareness
- If the spender contract gets compromised, or has flawed logic, all approved balances are at risk
- It breaks user expectations: once approved, you have no upper limit

Griefing Angle
The griefing happens when:
- A contract or malicious actor encourages you to approve a huge allowance, or sets it silently
- Then they abuse it later, or exploit bugs in the spending logic

Even if they don't steal your tokens, the mere presence of such an allowance:
- Makes revoking expensive
- May be used to block you or spam your wallet
- Can be used to manipulate dApp behavior (e.g. force more approvals, gas usage)

Technical Insight
Normally, ERC20 `transferFrom()` does this:

```solidity
require(allowance[from][msg.sender] >= amount);
allowance[from][msg.sender] -= amount;
```

But if allowance is `MAX_UINT256`, OpenZeppelin (and others) optimize:

```solidity
if (allowance != type(uint256).max) {
    allowance -= amount;
}
```

So the allowance stays infinite - never decreases, saving gas.

How to Protect Users
If you're a dApp dev:
- Use `permit()` or `increaseAllowance()` where possible
- Inform users clearly what they are approving
- Auto-revoke if interaction fails or ends

As a Security Researcher, you should check:
- Does the contract rely on `MAX_UINT256` approvals?
- Does it decrease allowance after use?
- Is there logic like:
```solidity
if (allowance != type(uint256).max) {
    allowance -= amount;
}
```
- Does the contract emit `Approval` events on update?
- Are there any fallbacks or silent approvals?

If you're a user:
- NEVER approve infinite allowance for unknown dApps


### 3. Zero Address Usage

What's the issue?
The ERC20 standard does not explicitly forbid sending tokens to `address(0)` (aka the zero address), but OpenZeppelin's ERC20 implementation blocks it with:
```solidity
require(to != address(0), "ERC20: transfer to the zero address");
```

This created a long-standing debate:
Should `address(0)` be allowed for transfers?
Or should it be banned for safety?

Why do people want to allow it?
Because some smart contracts burn tokens by sending them to `address(0)`.
Example:
```solidity
token.transfer(0x0000000000000000000000000000000000000000, amount);
```

This way, the tokens are permanently gone — there’s no private key for 0x0.
But OpenZeppelin disallows this, breaking compatibility with contracts that rely on that pattern.

Why do OpenZeppelin (and others) disallow it?
Sending to `0x0` is dangerous by default. Why?
- It could happen due to user error, not intention (e.g. empty input)
- Bad wallets or dApps may misparse an address and default to 0x0
- Once sent, tokens are permanently lost - even if it was a bug

Using a dedicated `burn()` function that:
- Reduces `balanceOf(user)`
- Reduces `totalSupply`
- Emits a `Transfer(from, address(0), amount)` event

Should we use `0xdead` instead?
Some devs suggest using:
```solidity
0x000000000000000000000000000000000000dEaD
```

This address is known as the "dead address", often used in burn mechanism.

Why it's better:
- It's still unspendable
- It clearly signals intention to burn
- It's not accidentally defaulted to by bad inputs

But: Even this is not part of the ERC20 standard. 

If you're auditing / writing ERC20 code: 
Check:
- Does the contract allow transfers to `0x0`?
- If yes, is it intentional (burn)? Or accidental (bug)?
- Is `burn()` implemented safely and reducing `totalSupply`?
- Are tokens ever transferred to unknown or placeholder addresses?

If you want to burn:
- Use `burn()` if you control the token
- Use `0xdead` if burning from outside (and it’s allowed)
- Never send tokens to `0x0` unless you're sure it's permitted and safe

### 4. Incorrect Return Value

What's the issue?
According to the ERC20 standard, the functions
```solidity
function transfer(address recipient, uint256 amount) external returns (bool) {}
function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {}
```

are expected to return a `bool` - indicating whether the transfer was successful. 
But, many tokens do not follow this rule. Some don't return anything. Some always return `true`, even if the transfer failed internally. 

Why this is dangerous
Smart contracts often assume the transfer worked and don't check the return value:

```solidity
token.transfer(user, amount); // no check
```

If the token silently fails:
- The contract assumes the transfer went through
- But the user never receives the tokens
- The contract state becomes desynced
- This can be exploited or cause unexpected loss

Real World Example
A well-known case is USDT (Tether).
- Its `transfer()` and `transferFrom()` functions do not return a boolean.
- If you try to `require(token.transfer(...))`, it throws an error — because no value is returned.

So if your contract assumes `bool success = token.transfer(...)`, it fails for USDT.

What developers must do
If you're integrating with unknown ERC20s, always:
```solidity
bool success = token.transfer(to, amount);
require(success, "Transfer failed");
```

But if you're dealing with non-compliant tokens (like USDT, OMG, etc), use:

```solidity
(token.call(abi.encodeWithSelector(token.transfer.selector, to, amount)));
```

Or wrap the token in a SafeERC20 wrapper
```solidity
SafeERC20.safeTransfer(token, to, amount);
```

### 5. No Revert on Failure

What's the issue?
Some ERC20 tokens - like ZRX (0x token) - do not revert on failure. 
Instead of `revert()`, their `transfer()` and `transferFrom()` just return `false` if the transfer fails. 

```solidity
bool success = token.transferFrom(...); // returns false on failure, but doesn't revert
```

If the developer forgets to check that return value - and just assumes success - the contract logic continues as if the transfer happened. 

Result: No tokens moved, but everything else proceeds - leading to major security flaws. 

Real World Exploit Scenario
Case: A malicious user initializes a vault that should hold 100 ZRX tokens

But:
- ZRX `transferFrom()` fails silently
- Vault creation logic doesn't check the return value
- Vault gets created anyway - with 0 actual tokens inside
- Another user buys the option and pays Ether
- When exercising the option, they receive nothing

Ether is lost, tokens were never there, but vault logic proceeds as if they were.

```solidity
// transferFrom returns false silently
bool success = token.transferFrom(sender, vault, amount); 
// No require(success)
// Vault is now "created" with 100 tokens that never arrived
```

Recommended Fixes
1. Always check return values
```solidity
bool success = token.transferFrom(sender, recipient, amount);
require(success, "ERC20 transfer failed");
```

2. Use OpenZeppelin `SafeERC20`
```solidity
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

SafeERC20.safeTransferFrom(token, sender, recipient, amount);
```

This handles:

- Silent false returns
- Tokens that don’t return any value at all (e.g., USDT, OMG)
- Inconsistent ERC20 behavior

### 6. Missing Event Emissions

What's the problem?
The ERC20 standard requires that every successful `transfer` or `approve` emits an event:

```solidity
event Transfer(address indexed from, address indexed to, uint256 value);
event Approval(address indexed owner, address indexed spender, uint256 value);
```

But not all ERC20 tokens follow this rule. 
Some: 
- Simply omit the `emit Transfer(...)`
- Or emit incorrect event data
- Or emit the event without a real transfer happening

Why is this dangerous?
Without reliable event emissions:
- Wallets, indexers, explorers (like Etherscan) get out-of-sync
- Off-chain apps think a transfer happened, but nothing actually moved
- Hackers can fake asset movements just by emitting Transfer events
- Security tools relying on events can be silently bypassed

Real World Example
Case: Fake Transfer Event
A contract does this:
```solidity
emit Transfer(msg.sender, to, amount); // Emits the event
// but no tokens are actually moved
```

To a blockchain explorer or wallet: 
> "Transfer occured"

But the token balances don't change. 
This can be used to:
- Trick users
- Fake activity
- Scam bots and wallets
- Spoof balance updates

How do users detect this?
They can't, unless:
- They verify the contract source code
- They compare balances before and after
- They analyze the transaction bytecode, which is hard

And for unverified contracts?
> You just have to trust the developer or skip the token entirely.

Event-Only Tokens = Red Flag
A contract that emits events but doesn't change state is a known scam pattern.
Example:
- Fake token emits `Transfer` to high-profile wallets
- Appears in wallets as "airdrop" - but is not real
- Users click and get phished

How to Prevent This
As a dev:
- Always use proper event emission:
```solidity
_transfer(from, to, amount) {
    balances[from] -= amount;
    balances[to] += amount;
    emit Transfer(from, to, amount); // must come *after* the state change
}
```

- Never emit events unless the action really happened

As a security researcher:
Check:
- Does `transfer()` change balances?
- Is `emit Transfer(..)` present after the update?
- Is `totalSupply` changed in `_mint()` / `_burn()` before emitting events?

### 7. Minting Without Access Control
What's the problem?
The `mint()` function in an ERC20 contract increases total supply by creating tokens out of thin air. 
If this function is not properly restricted, anyone can call it-- and mint unlimited tokens.

That breaks:
- Total supply logic
- Trust in the token's value
- Integrity of DeFi protocols using the token

This is a critical vulnerability that has caused millions in losses.

Real-World Example
Many careless ERC20 tokens launch with:
```solidity
function mint(address to, uint256 amount) public {
    _mint(to, amount);
}
```

No `onlyOwner`, `onlyRole`, `restricted`, or `require(msg.sender == ...)` check.

This means anyone can mint.
Even if the function isn't shown in the UI - bots and attacks can still call it on-chain.

Why access control matters?
Every sensitive function (like `mint`, `burn`, `pause`, `upgrade`) should be gated behind some form of access control, such as:
- Ownable
- AccessControl 
- AccessManager

Secure Patterns
> Basic Ownership: Ownable
```solidity
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, Ownable {
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
```

Only the owner (set during deployment or transferred) can mint. 

> Granular Roles: AccessControl
```solidity
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MyToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(address minter) {
        _grantRole(MINTER_ROLE, minter);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
}
```

Multiple minters can be assigned or revoked using admin roles.

> Centralized Management: AccessManager
```solidity
import "@openzeppelin/contracts/access/manager/AccessManaged.sol";

contract MyToken is ERC20, AccessManaged {
    constructor(address manager) ERC20("MyToken", "TKN") AccessManaged(manager) {}

    function mint(address to, uint256 amount) public restricted {
        _mint(to, amount);
    }
}
```

Minting rights are handled externally by a single manager contract.
Good for big systems with many modules (DAOs, protocol tokens, etc.).

### 8. Reentrancy via Hooks or External Calls 

What is Reentrancy?
Reentrancy is a vulnerability where an external contract is called before internal state updates are complete, allowing the external contract to call back into the original function and exploit the incomplete state.
Most famously used in the DAO hack, it remains one of the top threats in smart contract security today. 

What does this have to do with ERC20?
Standard ERC20 tokens are typically not vulnerable to reentrancy -- because:
- They do not call external contracts
- They update balances before emitting events

But when an ERC20 token is extended (e.g. taxed tokens, deflationary tokens, hooks, logic during transfer), and you can call external contracts inside transfer functions, you open the door to reentrancy. 

How it Happens: Common Scenarios
1. Calling External Contracts inside `_transfer()`
```solidity
function _transfer(address from, address to, uint256 amount) internal {
    super._transfer(from, to, amount);
    IRewards(to).notifyRewardReceived(amount); // External call after transfer
}
```

If `to` is a contract that calls `transfer()` again -> boom - reentrancy loop.

2. Using Hooks Without Reentrancy Guard
Some custom tokens support `beforeTransfer()` or `afterTransfer()` hooks.
```solidity
function _afterTokenTransfer(...) internal {
        rewardDistributor.onTransfer(msg.sender, amount); // can reenter!
}
```

If that reward contract calls `transferFrom()`, the same `_transfer` runs again.

How to Prevent Reentrancy
> Update state before external calls
```solidity
_balances[from] -= amount;
_balances[to] += amount;

emit Transfer(...);

_someExternalCall(); // only after full state update
```

> Use `nonReentrant` modifier
```solidity
bool private _locked;

modifier nonReentrant() {
    require(!_locked, "Reentrancy");
    _locked = true;
    _;
    _locked = false;
}
```

> Avoid calling unknown `to` address
Especially in:
- `transfer()`
- `_afterTokenTransfer()`
- reward/fee/tax logic

> Follow "Checks-Effects-Interactions" pattern
- Check: all inputs
- Effect: update state
- Interact: call external contracts

### 9. Token Loss via transfer() to Contracts Without Handlers

What's the issue?
ERC20's `transfer()` function allows you to send tokens to any address - even if that address is a contract that doesn't know how to handle them.

If that contract:
- Has no way to call `transfer()` or `transferFrom()` back out
- Has no `withdraw()` or token recovery logic

Then those tokens are trapped forever.

Real-World Example
Let's say you mistakenly call:
```solidity
token.transfer(address(someContract), 100e18);
```

But `someContract`:
- Doesn't call `transfer()` in its code
- Has no `withdraw()` or `sweep()` function
- Is not upgradeable

Your 100 tokens are now stuck permanently.
This is not a big in ERC20, but a dangerous security flaw.

Real Examples
Users have lost millions of USDT and USDC by sending tokens directly to:
- Token contracts
- DEX pool contracts
- Treasury multisigs with no ERC20 logic
- NFT contracts (ERC721/1155)

These addresses can receive ERC20 tokens, but can't do anything with them

Why is this possible?
ERC20 has no built-in reciever check like ERC721 (which uses `onERC721Received()`).
So every address - including:
- Contracts
- Dead addresses
- Token contracts themselves

is technically "valid" for `transfer()`.

Mitigations
1. Add `recoverERC20()` to your contracts
Every contract should include a token rescue function:
```solidity
function recoverERC20(IERC20 token, address to) external onlyOwner {
    uint256 balance = token.balanceOf(address(this));
    require(balance > 0, "No tokens");
    token.transfer(to, balance); 
}
```

This lets you withdraw accidentally received tokens.

2. Use frontends that warn users
Modern dApps (e.g. Uniswap) warn you if you try to send tokens to a known unspendable contract.

Example:

- Don’t allow sending tokens to the token’s own address
- Don’t show transfer() UI for vaults or NFTs

3. Use ERC1363 or ERC223 tokens
These token extensions provide a `tokensReceived()` hook (like ERC721's `onERC721Received()`), preventing transfers to contracts that can't handle them. 
But adoption is low. 

### 10. Gas Griefing

Gas griefing is an attack where a malicious user or contract intentionally causes another user's transaction to fail, by:
- Forcing excessive gas consumption
- Triggering reverts mid-logic
- Exploiting gas refunds or gas-limited callbacks

The goal isn't to steal funds - it's to disrupt a system, break assumptions, or lock user funds. 

Where does this apply in ERC20?
ERC20 itself is gas-efficient.
But protocols built on top (vaults, options, AMMs) often:
- Rely on `transferFrom()` from any address
- Loop through user lists (e.g. `forEach(holder)`)
- Call untrusted user contracts (e.g. for hooks or refunds)

And this is where griefers strike.

Example 1: Transfer Hook Griefing
```solidity
function _afterTokenTransfer(...) internal override {
    IUserHook(to).onReceiveTokens(...); // may use unbounded gas
}
```

The `onReceiveTokens()` contract could contain:
```solidity
function onReceiveTokens(...) external {
    while (true) {} // Infinite loop - eats all gas
}
```

Every transfer to that address bricks the token transfer system. 

Example 2: Gas Limited Calls Fail Midway
```solidity
for (uint i = 0; i < users.length; ++i) {
    token.transfer(users[i], rewardAmount); // one of them reverts
}
```

If one `users[i]` is a griefer, their ERC20 `transfer()` fails due to:
- Reentrancy
- Custom fallback
- Unexpected revert
- Running out of gas

The entire loop fails - no one gets rewards.

Protocols Affected
- Vaults
- Reward distributors
- Airdrop tools
- Batch `transfer()` or `transferFrom()` logic
- AMMs with token callbacks

These protocols assume users behave, but a single malicious address breaks the entire call. 

Mitigations
1. Use `try/catch` when calling untrusted addresses
```solidity
try token.transfer(user, amount) {
    // success
} catch {
    // skip or log failure
}
```

2. Limit per-user gas
In low-level assembly:
```solidity
(bool success, ) = user.call{gas: 10000}(data);
```

Prevents infinite loops or reentrancy.

3. Avoid `for` loops over arbitrary user arrays
- Use pull-based reward claiming (`user calls claim()`)
- Or loop in off-chain batch transactions

4. Sanitize `transferFrom()` inputs
Never trust external `from`/`to` addresses blindly. 

### 11. Transfer Before Deployment

What is the issue?
In Ethereum, you can compute the address of a contract before it is deployed, using: 
- The deploying address and nonce (`CREATE`)
- A salt and bytecode hash (`CREATE2`)

This makes it possible to:
- Send ERC20 tokens to a contract address that doesn't exist yet
- But once deployed, the contract has those tokens - no action required

How this becomes a vulnerability
1. A protocol publishes a future vault address (e.g. using CREATE2)
```solidity
address predicted = computeCreate2Address(...);
```

Users begin sending tokens to that address before deployment

2. Attacker frontruns the deployment
If the deployer doesn't lock deployment permissions, anyone can deploy the contract with a compatible bytecode and steal the tokens.

Mitigations
1. Only send tokens to already deployed contracts
Check `code.length > 0` before transferring:

```solidity
require(target.code.length > 0, "Contract not deployed yet");
```

2. Use safe deployer pattern
Deploy a minimal contract (e.g. proxy or vault) first, then upgrade logic later. This ensures:
- Ownership is controlled
- Funds aren't lost even if logic changes

3. Pre-fund with ETH, not tokens
Use ETH for signalling or deposit instead of non-recoverable ERC20 tokens.

4. Lock CREATE2 deploys
If publishing a salt + bytecode hash, deploy the contract yourself first and disable redeployment by locking salts. 

### 12. ERC20 Decimals Assumptions

What's the issue?
Many dApps, wallets, and smart contracts assume that all ERC20 tokens use 18 decimals - because that's the default in OpenZeppelin and mimics Ether (1 ETH = 18^18 wei).
But in reality:

Decimals are not standardized.
Tokens can (and do) define any number of decimals, including:
- 6 decimals (e.g. USDC, USDT)
- 0 decimaks (e.g. BNB test tokens)
- 2, 8, 12 or more

Why this is dangerous?
If your app or protocol assumes 18 decimals, you might:

| Mistake                    | Consequence                                 |
|---------------------------|---------------------------------------------|
| Divide/multiply incorrectly | Show wrong balances                         |
| Send wrong amounts          | Overpay or underpay                         |
| Miscalculate shares         | Vaults break, wrong APYs                    |
| Underestimate gas costs     | Reverts or out-of-gas                       |
| Misprice assets in DEXs     | Lose money or manipulate prices            |


Real World Problems
> Incorrect Transfer Math
```solidity
// User thinks they're sending 1 USDC
token.transfer(recipient, 1 * 10**18); // actually sends 1,000,000 USDC (USDC uses 6 decimals)
```

> Vault Calculations Assumes 18 Decimals
```solidity
uint shares = amount * 1e18 / totalAssets; // Broken for non-18-decimal tokens
```

How to fetch decimals properly
ERC20 tokens that implement `IERC20Metadata` expose:
```solidity
function decimals() public view returns (uint8);
```

Example usage in Solidity:
```solidity
uint8 decimals = IERC20Metadata(token).decimals();
```

In JavaScript:
```javascript
const decimals = await tokenContract.decimals();
const amount = ethers.utils.parseUnits("1.5", decimals);
```


