# Security

This standard provides basic functionality to transfer tokens, as well as allow tokens to be approved so that they can be spent by another on-chain third party.

It allows any tokens on Ethereum to be re-used by other applications: from wallets to decentralized exchanges.

NOTE: Callers must handle `false` from `return (bool success)`. 
Callers must not assume that `false` is never returned. 

## Most Important ERC20 Attacks & Vulnerabilities

1. Approval Race Condition

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