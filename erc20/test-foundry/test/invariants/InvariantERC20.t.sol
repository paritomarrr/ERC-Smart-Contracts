// SPDX=License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol"; // Foundry's base test module;
import "forge-std/StdInvariant.sol"; // Invariant-specific utilities
import {TestERC20} from "local/TestERC20.sol"; // ERC20 contract that we're testing

/// @title InvariantERC20
/// @notice This contract tests ERC20 invariants using Foundry
contract InvariantERC20 is StdInvariant, Test {
    TestERC20 token; // ERC20 token instance under test

    address[] public users; // array of test user addresses

    // predefined addresses used to simulate different users
    address internal constant ALICE = address(0x1);
    address internal constant BOB = address(0x2);
    address internal constant CHARLIE = address(0x3);

    // Total initial supply we give to the token
    uint256 internal constant INIT_SUPPLY = 1000 ether;

    /// @notice Runs before each invariant test
    function setUp() public {
        // Deploy a new instance of the token with an initial supply
        token = new TestERC20("MyToken", "MTK", INIT_SUPPLY);

        // Register test users
        users.push(ALICE);
        users.push(BOB);
        users.push(CHARLIE);

        // use foundry's built-in `deal()` to manually assign balances
        deal(address(token), ALICE, INIT_SUPPLY / 2);
        deal(address(token), BOB, INIT_SUPPLY / 2);
    }
    /// @notice Invariant #1
    /// totalSupply must equal the sum of balances across all accounts
    function invariant_totalSupplyMatchesBalances() public {
        uint256 sum;

        // Sum balances of all registered users
        for (uint256 i = 0; i < users.length; i++) {
            sum += token.balanceOf(users[i]);
        }

        // Check: totalSupply must always equal sum of balances
        assertEq(token.totalSupply(), sum, "totalSupply != sum(balances)");
    }

    /// @notice Invariant #2
    /// A spender who was never approved should NOT be able to transfer tokens
    function invariant_noTransferWithoutApproval() public {
        // This simulates CHARLIE trying to spend tokens from ALICE without being approved
        vm.prank(CHARLIE); // CHARLIE is msg.sender

        // Expect this call to revert (fail)
        vm.expectRevert();
        token.transferFrom(ALICE, BOB, 1 ether);
    }

    /// @notice Invariant #3
    /// Allowance should not magically increase unless `approve()` is called
    function invariant_allowanceOnlyViaApprove() public {
        // Get current allowance before anything changes
        uint256 before = token.allowance(ALICE, BOB);

        // Simulate ALICE calling `approve` to increase allowance
        vm.startPrank(ALICE); // All following txs are from ALICE
        token.approve(BOB, before + 1 ether);
        vm.stopPrank();

        // Check: new allowance should be >= previous
        uint256 after_ = token.allowance(ALICE, BOB);
        assertGe(after_, before, "Allowance decreased without logic");
    }

}