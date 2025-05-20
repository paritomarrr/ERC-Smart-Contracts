// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ECDSA (Elliptic Curve Digital Signature Algorithm) Library
 * @notice Helps recover the Ethereum address that signed a message.
 * Used heavily in verifying off-chain signatures (e.g., ERC-2612)
 */
library ECDSA {
    // Error types to standardize failures during recovery
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS // 'S' must be in lower half to prevent malleability
    }

    /**
     * @dev The signatures derives the `address(0)`
     */
    error ECDSAInvalidSignature();

    /**
     * @dev The signature has an invalid length.
     */
    error ECDSAInvalidSignatureLength(uint256 length);

    /**
     * @dev The signature has an S value that is in upper half order.
     */
    error ECDSAInvalidSignatureS(bytes32 s);

    /**
     * @notice Try to recover the signer address from a message hash and its digital signature.
     *
     * This function is used when you have signature in the standard 65-byte format (r, s, v).
     *
     * @param hash The message digest that was signed (typically keccak256 of typed data)
     * @param signature A 65-byte ECDSA signature: {r: 32 bytes} || {s: 32 bytes} || {v: 1 byte}
     *
     * @return recovered The recovered address (i.e., the signer). If invalid, returns address(0)
     * @return err An enum indicating what kind of failure occured (or NoError if successful)
     * @return errArg Extra data: for example, the invalid signature length or invalid `s` value
     */
    function tryRecover(
        bytes32 hash,
        bytes memory signature
    )
        internal
        pure
        returns (address recovered, RecoverError err, bytes32 errArg)
    {
        // Standard ECDSA signatures must be exactly 65 bytes: 32 bytes r, 33 bytes s, 1 byte v
        if (signature.length == 65) {
            bytes32 r; // ECDSA r-value (first 32 bytes)
            bytes32 s; // ECDSA s-value (next 32 bytes)
            uint8 v; // ECDSA v-value (final 1 byte)

            // Solidity does not provide native decoding of r, s, v from bytes,
            // so we use low-level `assembly` to manually extract them.
            //
            // - `add(signature, 0x20)` skips the first 32 bytes, which stores the length of the array
            // - `mload(...)` reads 32 bytes from memory starting at that offset
            // - `byte(0, mload(...))` reads just the first byte (for `v`) from the last word
            assembly ("memory-safe") {
                r := mload(add(signature, 0x20)) // r = bytes 0x20 to 0x3F
                s := mload(add(signature, 0x40)) // s = bytes 0x40 to 0x5F
                v := byte(0, mload(add(signature, 0x60))) // v = first byte of 0x60 to 0x7F
            }

            // Now that we have r, s, v - delegate to the main recovery function
            return tryRecover(hash, v, r, s);
        } else {
            // If the length isn't 65, it's an invalid ECDSA signature.
            // Return address(0) with a descriptive error enum and argument
            return (
                address(0),
                RecoverError.InvalidSignatureLength,
                bytes32(signature.length)
            );
        }
    }

    /**
     * @notice Recovers the signer address from a given message hash and signature.
     *
     * This is a convenience wrapper over `tryRecover`, and is used when you want a clean result without handling errors manually.
     *
     * Internally:
     * - Calls `tryRecover` to parse the signature and perform recovery.
     * - If any error is returned, it will revert with a specific custom error.
     * - Otherwise, it returns the recovered signer address.
     *
     * @param hash The hash of the signed message (should be result of a hash function).
     * It must be a digest (like `keccak256`) - signing raw message is insecure.
     *
     * @param signature The 65-byte signature (r, s, y) in standard ECDSA format.
     *
     * @return The address that produced the signature over this hash.
     *
     * SECURITY NOTE:
     * - Signature malleability is prevented by checking that `s` is in the lower half of the curve order.
     * - Only `v` values of 27 or 28 are allowed - preventing alternate forms like 0/1 or invalid bits.
     * - You should *never* call this with unhashed data - always hash the message first to prevent crafted collisions.
     */
    function recover(
        bytes32 hash,
        bytes memory signature
    ) internal pure returns (address) {
        // Attempt to recover the signer address and capture the result + error info
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(
            hash,
            signature
        );

        // If something went wrong (bad length, invalid `s`, etc), this will revert with a descriptive error
        _throwError(error, errorArg);

        // If no error occured, return the valid recovered address
        return recovered;
    }

    /**
     * @notice Attempts to recover the signer address from a message hash and a compact (short) ECDSA signature.
     *
     * This function supports the ERC-2098 signature format which reduces signature size from 65 bytes to 64 bytes
     * by "compressing" the `v` and `s` values into a single 32-byte `vs` value.
     *
     * - `r`: first 32 bytes of the signature (same as in standard format)
     * - `vs`: packed 32-byte field combining the `s` value (lower 255 bits) and the `v` value (stored in highest bit).
     *
     * How it works:
     * - Extracts the real `s` by masking of the highest bit.
     * - Extracts `v` by shifting the highest bit of `vs` into position and adjusting it to be 27 or 28.
     * - Then delegates to the full `tryRecover(hash, v, r, s)` functions.
     * @param hash The hashed message that was signed.
     * @param r The `r` value from the signature.
     * @param vs The combined `v || s` value as per ERC-2098 format.
     *
     * @return recovered The recovered address (or zero address if invalid)
     * @return err Error type (none, bad length, invalid s, etc)
     * @return errArg Additional argument (like the bad `s` or bad length for debugging)
     */
    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    )
        internal
        pure
        returns (address recovered, RecoverError err, bytes32 errArg)
    {
        unchecked {
            // Extract the `s` value by masking out the highest bit (bit 255 = v flag)
            bytes32 s = vs &
                bytes32(
                    0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
                );

            // Extract the `v` value from the highest bit of `vs`
            // This bit is 0 or 1 -> so add 27 to get proper ECDSA `v` (27 or 28)
            uint8 v = uint8((uint256(vs) >> 255) + 27);

            // Call the main tryReciver with expanded signature (r, s, v)
            return tryRecover(hash, v, r, s);
        }
    }

    /**
     * @notice Recovers the address that signed a hashed message (`hash`) using a **short (64-byte)** ECDSA signature.
     *
     * This function is a wrapper around the `tryRecover()` variant that accepts the **compact** `(r, vs)` format
     * as defined in [EIP-2098].
     *
     * Internally calls `tryRecover(hash, r, vs)` to attempt recovery and capture any signature errors.
     * - Uses `_throwError()` to revert with a descriptive custom error if the recovery fails.
     *
     * @param hash The message hash that was originally signed (should be properly prefixed via EIP-191/EIP-712).
     * @param r The first 32 bytes of the signature (unchanged from standard ECDSA).
     * @param vs The packed value combining `v` and `s` into a single 32-byte word:
     * - lower 255 bits: the `s` value (must be in the lower half-order)
     * - highest bit (bit 255): encodes the recovery id `v` (0 or 1 -> maps to 27 or 28)
     *
     * @return The address that produced the signature.
     *
     * @dev This is the signature format used by ERC-2612 permits to save 1 byte in calldata.
     * If the signature is invalid or malleable, this function will revert with a clear error.
     */
    function recover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address) {
        // Attempt to recover the signer address from the signature (r, vs)
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(
            hash,
            r,
            vs
        );

        // If recovery failed, revert with a specific error
        _throwError(error, errorArg);

        // Otherwise, return the recovered address
        return recovered;
    }

    /**
     * @notice Attempts to recover the signer address from the signature components:
     *         `v`, `r`, and `s` — the standard ECDSA fields used in Ethereum signatures.
     *
     * @param hash The hashed message that was originally signed.
     * @param v Recovery ID: usually 27 or 28 (sometimes encoded as 0 or 1 by some tools).
     * @param r First 32 bytes of the signature.
     * @param s Second 32 bytes of the signature.
     *
     * @return recovered The recovered signer address.
     * @return err The type of recovery error (if any).
     * @return errArg Additional error info (like the invalid `s` value).
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        internal
        pure
        returns (address recovered, RecoverError err, bytes32 errArg)
    {
        // --- Signature Malleability Check (EIP-2 Compliant) ---

        // ECDSA signatures are not always unique:
        // A signature (r, s) and (r, -s mod n) are both valid for the same message.
        // To prevent this, we require `s` to be in the lower half of the curve order.
        //
        // This cutoff value (aka "secp256k1n + 2") ensures:
        // - Uniqueness of signatures
        // - Compatibility with EIP-2 standard

        if (
            uint256(s) >
            0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
        ) {
            // If `s` is in the upper range, reject the signature as malleable
            return (address(0), RecoverError.InvalidSignatureS, s);
        }

        // --- Perform Actual Recovery ---

        // Uses the native `ecrecover()` opcode to extract the signer address
        // If `v` is not 27 or 28, or if inputs are malformed, this returns address(0)
        address signer = ecrecover(hash, v, r, s);

        // If the recovered address is address(0), something failed in `ecrecover`
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature, bytes32(0));
        }

        // Otherwise all checks passed - return the valid signer address
        return (signer, RecoverError.NoError, bytes32(0));
    }

    /**
     * @notice Recovers the signer address from the given ECDSA signature components:
     *         `v`, `r`, and `s`. This is a convenience wrapper around `tryRecover`.
     *
     * @dev - This is a high-level version of `tryRecover` that **automatically reverts**
     *         if signature recovery fails (i.e., it's unsafe or invalid).
     *
     *      - It uses the internal `_throwError` function to decode and revert with
     *        a descriptive custom error (like `ECDSAInvalidSignatureS` or `ECDSAInvalidSignatureLength`).
     *
     *      - Use this when you want to **strictly enforce** signature validity
     *        without manually handling errors.
     *
     * @param hash The message hash that was signed (e.g., `keccak256`, EIP-712, or toEthSignedMessageHash).
     * @param v The recovery identifier (must be 27 or 28).
     * @param r The first 32 bytes of the signature.
     * @param s The second 32 bytes of the signature.
     *
     * @return The address that signed the `hash` using the private key.
     *         This address should match the expected signer in verification logic.
     *
     * Reverts with custom Solidity errors from `_throwError` if the signature is malformed or malleable.
     */
    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(
            hash,
            v,
            r,
            s
        );
        _throwError(error, errorArg);
        return recovered;
    }

    /**
     * @notice Internal helper to handle signature recovery errors.
     *
     * @dev This function takes an enum `RecoverError` and an optional extra argument `errorArg`
     *      and either does nothing (if no error), or reverts with a descriptive custom Solidity error.
     *
     *      It's used by `recover()` to translate `tryRecover()` failures into clean, typed reverts.
     *
     * @param error The type of signature error that occurred (e.g., invalid length, malleable `s` value, etc.).
     * @param errorArg Additional context for the error (e.g., signature length or the invalid `s` value).
     */
    function _throwError(RecoverError error, bytes32 errorArg) private pure {
        // If there's no error, do nothing and return normally
        if (error == RecoverError.NoError) {
            return;
        }
        // If the signature failed to recover a valid signer address (generic failure)
        else if (error == RecoverError.InvalidSignature) {
            revert ECDSAInvalidSignature(); // Revert with custom error for invalid signature
        }
        // If the signature length is incorrect (not 65 bytes)
        else if (error == RecoverError.InvalidSignatureLength) {
            // Cast `errorArg` (which holds the actual length) back to uint for error reporting
            revert ECDSAInvalidSignatureLength(uint256(errorArg));
        }
        // If the signature's `s` value is not in the lower half of the curve order (malleable)
        else if (error == RecoverError.InvalidSignatureS) {
            revert ECDSAInvalidSignatureS(errorArg); // Provide invalid `s` value for debugging
        }
    }
}
