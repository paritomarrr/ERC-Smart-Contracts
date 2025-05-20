// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MockERC20Permit} from "../src/mock/TestERC20Permit.sol";

contract ERC20PermitTest is Test {
    MockERC20Permit token;

    address owner;
    address spender;
    uint256 ownerPk;

    function setUp() public {
        // Simulated private key for "Alice"
        ownerPk = 0xA11CE;
        // Simulated address derived from that key
        owner = vm.addr(ownerPk);
        // Generates a random address with a human-readable label
        spender = makeAddr("spender");

        token = new MockERC20Permit("My Token", "MTK");

        // Give owner some tokens
        vm.prank(owner);
        token.$_mint(owner, 1000 ether);
    }

    // tests
    function testPermitSuccess() public {
        uint256 value = 100 ether;
        uint256 nonce = token.nonces(owner);
        uint256 deadline = block.timestamp + 1 hours;

        // 1. Build the Permit struct hash
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                spender,
                value,
                nonce,
                deadline
            )
        );

        // 2. Get DOMAIN_SEPARATOR from contract
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();

        // 3. Build final EIP-712 digest
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                structHash
            )
        );

        // 4. Sign digest with owner's private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, digest);

        // 5. Call permit
        token.permit(owner, spender, value, deadline, v, r, s);

        // 6. Assert allowance and nonce updated
        assertEq(token.allowance(owner, spender), value, "Allowance not updated");
        assertEq(token.nonces(owner), 1, "Nonce not incremented");
    }

    function testReplayAttackFails () public {
        uint256 value = 100 ether;
        uint256 nonce = token.nonces(owner);
        uint256 deadline = block.timestamp + 1 hours;

        // Step 1: Build digest (same as before)
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                ),
                owner,
                spender,
                value,
                nonce,
                deadline
            )
        );

        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();

        bytes32 digest = keccak256(
        abi.encodePacked(
            "\x19\x01",
            domainSeparator,
            structHash
        )
    );

    // Step 2: Sign with owner
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, digest);

    // Step 3: Use the permit (first time should succeed)
    token.permit(owner, spender, value, deadline, v, r, s);

    // Step 4: Try to use the same permit again
    vm.expectRevert(); // Will revert due to nonce mismatch
    token.permit(owner, spender, value, deadline, v, r, s);
    }

}
