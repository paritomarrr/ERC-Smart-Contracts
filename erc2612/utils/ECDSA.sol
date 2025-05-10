// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations. 
 * 
 * These functions can be used to verify that a message was signed by the holder of the private keys of a given address.
 */
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS
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

    
}