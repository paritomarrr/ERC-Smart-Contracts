// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Math} from "./Math.sol";

library StorageSlot {
    struct StringSlot {
        string value;
    }

    function getStringSlot(
        string storage store
    ) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }
}

library Strings {
    bytes16 private constant HEX_DIGITS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            // Step 1: Calculate how many decimal digits are in `value`.
            // Example: value = 12345 → log10(12345) = 4 → length = 5
            // This helps us know how much memory to allocate for the string.
            uint256 length = Math.log10(value) + 1;

            // Step 2: Create a new string of `length` characters.
            // Strings are stored as dynamic arrays with a 32-byte length prefix.
            string memory buffer = new string(length);

            // Step 3: Initialize a pointer to the end of the buffer where we will write digits from right to left.
            uint256 ptr;
            assembly ("memory-safe") {
                // Skip the first 32 bytes (length) and move to the end of the buffer.
                ptr := add(add(buffer, 0x20), length)
            }

            // Step 4: Extract digits and write them into memory one by one from right to left.
            while (true) {
                ptr--; // Move one byte left

                // Extract the last digit (0–9) of the number using modulus 10.
                // Then fetch the corresponding ASCII character from HEX_DIGITS.
                assembly ("memory-safe") {
                    mstore8(ptr, byte(mod(value, 10), HEX_DIGITS))
                }

                // Remove the last digit from `value`.
                value /= 10;

                // If value is 0, we’ve written all digits, so break the loop.
                if (value == 0) break;
            }

            // Step 5: Return the resulting string stored in `buffer`.
            return buffer;
        }
    }
}

// | string  | 0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA   |
// | length  | 0x                                                              BB |
type ShortString is bytes32;

library ShortStrings {
    error InvalidShortString();
    error StringTooLong(string str);
    // Used as an identifier for strings longer than 31 bytes.
    bytes32 private constant FALLBACK_SENTINEL =
        0x00000000000000000000000000000000000000000000000000000000000000FF;

    /**
     * @dev Encode a string of at most 31 chars into a `ShortString`.
     *
     * This will trigger a `StringTooLong` error is the input string is too long.
     */
    function toShortString(
        string memory str
    ) internal pure returns (ShortString) {
        bytes memory bstr = bytes(str);
        if (bstr.length > 31) {
            revert StringTooLong(str);
        }
        return ShortString.wrap(bytes32(uint256(bytes32(bstr)) | bstr.length));
    }

    /**
     * @dev Encode a string into a `ShortString`, or write it to storage if it is too long.
     */
    function toShortStringWithFallback(
        string memory value,
        string storage store
    ) internal returns (ShortString) {
        if (bytes(value).length < 32) {
            return toShortString(value);
        } else {
            StorageSlot.getStringSlot(store).value = value;
            return ShortString.wrap(FALLBACK_SENTINEL);
        }
    }

    function toStringWithFallback(
        ShortString value,
        string storage store
    ) internal pure returns (string memory) {
        if (ShortString.unwrap(value) != FALLBACK_SENTINEL) {
            return toString(value);
        } else {
            return store;
        }
    }

    /**
     * @dev Decode a `ShortString` back to a "normal" string.
     */
    function toString(ShortString sstr) internal pure returns (string memory) {
        uint256 len = byteLength(sstr);
        // using `new string(len)` would work locally but is not memory safe.
        string memory str = new string(32);
        assembly ("memory-safe") {
            mstore(str, len)
            mstore(add(str, 0x20), sstr)
        }
        return str;
    }

    /**
     * @dev Return the length of a `ShortString`.
     */
    function byteLength(ShortString sstr) internal pure returns (uint256) {
        uint256 result = uint256(ShortString.unwrap(sstr)) & 0xFF;
        if (result > 31) {
            revert InvalidShortString();
        }
        return result;
    }
}
