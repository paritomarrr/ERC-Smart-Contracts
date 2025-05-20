// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library MessageHashUtils {
    /**
     * @dev Returns the keccak256 digest of an EIP-712 typed data
     *
     * This function constructs the final message hash that a wallet or relayer signs using EIP-712.
     *
     * It takes 2 inputs:
     * - `domainSeparator`: Identifies the signing domain (e.g. dApp name, version, chainId, contract address)
     * - `structHash`: The keccak256 hash of the actual typed data (struct) to be signed
     *
     * The final digest is:
     * keccak256("\x19\x01" || domainSeparator || structHash)
     *
     * This is compliant with the EIP-712 standard [version 4], and is what metamask and other wallets
     * use when calling `eth_signTypedData`
     *
     * This hash is later used in ECDSA.recover() to verify who signed the data.
     */
    function toTypedDataHash(
        bytes32 domainSeparator,
        bytes32 structHash
    ) internal pure returns (bytes32 digest) {
        assembly {
            // Step 1: Load the free memory pointer into `ptr`
            let ptr := mload(0x40)

            // Step 2: Store the EIP-712 version prefix at the beginning of memory
            // \x19\x01 is the fixed prefix defined in EIP-712 for typed data
            mstore(ptr, hex"19_01")

            // Step 3: Store the domain separator right after the prefix (starts at ptr + 2)
            mstore(add(ptr, 0x02), domainSeparator)

            // Step 4: Store the struct hash after the domain separator (starts at ptr + 2 + 32 = ptr + 34 = 0x22)
            mstore(add(ptr, 0x22), structHash)

            // Step 5: Compute the keccak256 hash of the entire 66 bytes:
            // - 2 bytes: "\x19\x01"
            // - 32 bytes: domainSeparator
            // - 32 bytes: structHash
            // Total: 2 + 32 + 32 = 66 = 0x42
            digest := keccak256(ptr, 0x42)
        }
    }
}
