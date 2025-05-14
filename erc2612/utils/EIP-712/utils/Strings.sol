// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Math} from "./Math.sol";

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
