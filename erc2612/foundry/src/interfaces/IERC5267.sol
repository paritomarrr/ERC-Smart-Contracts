// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev This is an interface that defines a standard way
 *      for a contract to *describe its domain* for signing typed data (EIP-712).
 *      Think of it like a public "ID Card" for the contract's signature settings.
 */
interface IERC5267 {
    /**
     * @dev This event should be emitted *if* your contract changes its EIP-712 domain config.
     *      Why? Because wallets or apps might be caching that info. Emitting this tells them to refresh it.
     *      You don't have to emit it, but it's helpful.
     */
    event EIP712DomainChanged();

    function eip712Domain() external view returns (
        bytes1 fields, // A bitmap showing which values below are set. Helps clients parse the result.
        string memory name, // Name of the signing domain (like app or protocol name)
        string memory version, // Version of the domain (helps avoid collisions across upgrades)
        uint256 chainId, // Chain ID (prevents replay attacks across different networks)
        address verifyingContract, // The address that will use these values to verify signatures
        bytes32 salt, // Optional salt (adds randomness to domain hash if needed)
        uint256[] memory extensions // Optional extensions array (reversed for future specs or upgrades)
    );
}