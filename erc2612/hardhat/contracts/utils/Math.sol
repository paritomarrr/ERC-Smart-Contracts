// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Math {
    /**
     * @dev Returns the floor of the base-10 logarithm of a postive `value`.
     *
     * In simple terms, it tells how many decimal digits are needed to represent `value`.
     *
     * For Example:
     *
     * - log10(1)       = 0
     * - log10(9)       = 0
     * - log10(10)      = 1
     * - log10(999)     = 2
     * - log10(1000)    = 3
     *
     * This is used in Strings.toString() to determine how much memory to allocate for the decimal string representation of a number.
     */

    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;

        unchecked {
            // Check if the number is atleast 10^64
            // If yes, divide it and add 64 to the result - skipping 64 digits at once
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }

            // Check if the remaining value is at least 10^32
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }

            // Check if it's at least 10^16
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }

            // Now check if it's at least 10^8
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }

            // Then 10^4
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }

            // Then 10^2
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }

            // Finally check if value is at least 10
            if (value >= 10 ** 1) {
                result += 1;
            }
        }

        // Return the total number of times we were able to divide the value by powers of 10
        // This corresponds to the number of digits - 1 (i.e. floor(log10(value)))
        return result;
    }
}
