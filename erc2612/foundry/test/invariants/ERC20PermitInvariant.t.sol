// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {MockERC20Permit} from "../../src/mock/TestERC20Permit.sol";

contract ERC20PermitInvariant is StdInvariant, Test {
    MockERC20Permit public token;
    address public owner;
    uint256 public ownerPk;
    uint256 internal lastNonce;

    function setUp () public {
        ownerPk = 0xA11CE;
        owner = vm.addr(ownerPk);
        token = new MockERC20Permit("My Token", "MTK");

        vm.prank(owner);
        token.$_mint(owner, 1000 ether);
    }

    // NONCE ONLY INCREASES
    function invariant_NonceDoesNotDecrease() public {
        uint256 currentNonce = token.nonces(owner);
        assertGe(currentNonce, 0); // just to be sure
        assertGe(currentNonce, lastNonce); // check it hasn't decrease
        lastNonce = currentNonce; // update for next call
    }
}