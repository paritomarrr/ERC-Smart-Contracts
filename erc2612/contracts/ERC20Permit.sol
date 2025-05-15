// SPDX-License-Identifie: MIT
pragma solidity ^0.8.20;

// ==== IMPORTS ==== //
import {IERC20Permit} from "../interfaces/IERC2612.sol"; // ERC-2612 interface with `permit()`, `nonces()`, and `DOMAIN_SEPARATOR()`
import {ERC20} from "../../erc20/contracts/ERC20.sol"; // Base ERC-20 token contract
import {ECDSA} from "../utils/ECDSA.sol"; // Used to recover signer from signature
import {EIP712} from "../utils/EIP-712/EIP712.sol"; // Used to build EIp-712 compliant digests
import {Nonces} from "../utils/Nonces.sol"; // Handles nonce tracking per account

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
     * This sets up all the internal EIp712 domain caching from the base contract.
     */
    constructor(string memory name) EIP712(name, "1") {}

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        // Revert if deadline is in the past
        if (block.timestamp > deadline) {
            revert ERC2612ExpiredSignature(deadline);
        }

        // == EIP-712 STRUCT HASH == /
        // This hash is keccak256 of the ABI-encoded Permit struct
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                _useNonce(owner),
                deadline
            )
        );

        // ==== EIP-712 FINAL DiGEST === /
        // This includes domain separator + struct hash
        bytes32 hash = _hashTypedDataV4(structHash);

        // === SIGNER VERIFICATION === //
        // Recover the signer from the ECDSA signature
        address signer = ECDSA.recover(hash, v, r, s);

        // Make sure signer matches expected owner
        if (signer != owner) {
            revert ERC2612InvalidSigner(signer, owner);
        }

        // Signature is valid: set allowance
        _approve(owner, spender, value);
    }

    /**
     * @notice Returns the current nonce for a given owner.
     * Each call to `permit()` will consume and increment this.
     *
     * @dev Overrides from both IERC20Permit and Nonces base.
     */
    function nonces(
        address owner
    ) public view virtual override(IERC20Permit, Nonces) returns (uint256) {
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
