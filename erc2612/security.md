# Attack Vectors on ERC-2612 


## Mint with Permit() can be broken when using tokens that do not follow the ERC-2612 standard

### What's happening

The function:

```solidity
function mintWithPermit(...) {
    IERC20Permit(underlying).permit(...);
    return mintInternal(mintAmount);
}
```

This assumes that the token's `permit()` can always succeeds.
But in practice, not all tokens implement `ERC2612` correctly -- for example, DAI uses a custom version that:
1\ Doesn't follow the expected signature
2\ Uses non-standard inputs like `bool allowed`
3\ May not revert on failure - instead silently does nothing

### Why is this dangerous?
If the `permit()` fails silently (like DAI's might), the contract will still proceed to call:

```solidity
mintInternal(mintAmount)
```

Without a real approval in place.
Result:
- Funds could be minted without actual user consent
- Or user gets confused why their approval didn't go through, yet logic executed

### The Core Mistake
Blindly assuming all tokens follow ERC-2612 exactly and revert on bad input.
But:
- `ERC20Permit` is a standard, not an enforcement
- DAI (and some other tokens) are "permit-like", but not compliant

### How to fix it
Use `safePermit()` -- this is typically provided by libraries like OZ or custom wrappers:

```solidity
SafeERC20Permit.safePermit(underlying, ...);
```

That wrapper:
- Catches silent failures
- Verifies nonce increased after calling `permit()`
- Reverts if `permit()` didnt actually take effect