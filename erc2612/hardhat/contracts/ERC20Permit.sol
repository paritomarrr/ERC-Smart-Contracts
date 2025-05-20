// SPDX-License-Identifie: MIT
pragma solidity ^0.8.20;

// ==== IMPORTS ==== //
import {IERC20Permit} from "./interfaces/IERC2612.sol"; // ERC-2612 interface with `permit()`, `nonces()`, and `DOMAIN_SEPARATOR()`;
import {ERC20} from "./helper/ERC20.sol"; // Base ERC-20 token contract
import {ECDSA} from "./utils/ECDSA.sol"; // Used to recover signer from signature
import {EIP712} from "./extensions/EIP712.sol"; // Used to build EIp-712 compliant digests
import {Nonces} from "./utils/Nonces.sol"; // Handles nonce tracking per account

/**
 * @title ERC20Permit (EIP-2612)
 * @dev Enables gasless approvals on an ERC20 token by using signatures instead of on-chain transactions.
 *
 * This allows an owner to approve a spender with a signed message
 * Without calling `approve()` (and this without requiring ETH)
 *
 * This is ideal for:
 * - Meta-transactions
 * - Token-based UX flows (approve + action in one signed blob)
 */
abstract contract ERC20Permit is ERC20, IERC20Permit, EIP712, Nonces {
    // ==== EIP-712 STRUCT TYPE HASH ==== /
    // This is the precomputed hash of the Permit struct:
    // Permit(address owner, address spender, uint256 value, uint256 nonce, uint256 deadline)
    bytes32 private constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    // ==== ERRORS ==== /
    /// @dev Triggered when the `deadline` passed into `permit()` has expired
    error ERC2612ExpiredSignature(uint256 deadline);

    /// @dev Triggered when signature recovered from ECDSA does not match `owner`
    error ERC2612InvalidSigner(address signer, address owner);

    /**
     * @dev initializes the EIP-712 domain separator with:
     * - `name`: passed in from the ERC20 token name
     * - `version`: hardcoded to `"1"` (recommended by the EIP)
     *
     * This sets up all the internal EIP712 domain caching from the base contract.
     */
    constructor(string memory name) EIP712(name, "1") {}

     /**
     * @notice Approves `spender` to spend `value` tokens on behalf of `owner` via a signature.
     * @dev Implements EIP-2612: gasless approvals via `permit()`.
     *
     * The function uses EIP-712 typed structured data hashing + signing.
     * The signature must be valid, not expired, and match the expected `owner`.
     *
     * Requirements:
     * - `deadline` must be a timestamp in the future
     * - `v`, `r`, and `s` must be a valid `secp256k1` signature from `owner` over a valid permit digest
     * - `nonces(owner)` will be used and incremented to prevent replay
     *
     * Emits no events directly, but triggers `Approval` via `_approve()`.
     *
     * @param owner The address granting approval
     * @param spender The address being approved
     * @param value The amount of tokens to approve
     * @param deadline A timestamp after which the permit is no longer valid
     * @param v Signature component v
     * @param r Signature component r
     * @param s Signature component s
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        // === STEP 1: Check deadline === //
        // Revert if the current timestamp exceeds the deadline
        if (block.timestamp > deadline) {
            revert ERC2612ExpiredSignature(deadline);
        }

        // === STEP 2: Build EIP-712 struct hash === //
        // Hash the Permit struct with all required parameters including current nonce
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                _useNonce(owner), // fetch and increment nonce in one call
                deadline
            )
        );

        // === STEP 3: Compute EIP-712 digest === //
        // Combine struct hash with the domain separator to create a final signed message hash
        bytes32 hash = _hashTypedDataV4(structHash);

        // === STEP 4: Recover the address from the signature === //
        address signer = ECDSA.recover(hash, v, r, s);

        // === STEP 5: Validate that recovered signer matches the claimed owner === //
        if (signer != owner) {
            revert ERC2612InvalidSigner(signer, owner);
        }

        // === STEP 6: Signature is valid — update allowance === //
        _approve(owner, spender, value);
    }


     /**
     * @notice Returns the current nonce for the given `owner` address.
     * @dev This value is used to prevent signature replay in `permit()` calls.
     *
     * Each successful call to `permit()` will consume the current nonce
     * and increment it by 1. This ensures every signature is used only once.
     *
     * @param owner The address whose nonce is being queried.
     * @return The current nonce associated with the given owner.
     */
    function nonces(
        address owner
    ) public view virtual override(IERC20Permit, Nonces) returns (uint256) {
        // Delegate to Nonces base contract to fetch the current nonce value
        return super.nonces(owner);
    }

    

    /**
     * @notice Returns the domain separator used in the encoding of the signature.
     * Required by the IERC20Permit interface.
     *
     * This is a `view` into the cached value from EIP712.
     */
    function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
        return _domainSeparatorV4();
    }
}
