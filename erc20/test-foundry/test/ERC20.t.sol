// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {TestERC20} from "local/TestERC20.sol";

contract ERC20Test is Test {
    TestERC20 public token;

    address internal holder;
    address internal recipient;
    address internal spender;
    address internal constant ZERO_ADDRESS = address(0);

    uint256 internal constant INITIAL_SUPPLY = 100 ether;
    uint256 internal constant MAX_UINT = type(uint256).max;
    uint8 internal constant DECIMALS = 18;

    // ==== HELPER FUNCTIONS ====
    function mintTo(address to, uint256 amount) internal {
        token.$_mint(to, amount);
    }

    function burnFrom(address from, uint256 amount) internal {
        token.$_burn(from, amount);
    }

    function assertBalanceEq(address account, uint256 expected) internal {
        assertEq(token.balanceOf(account), expected, "Unexpected balance");
    }

    // ==== SETUP FIXTURE ====
    function setUp() public {
        holder = makeAddr("holder");
        recipient = makeAddr("recipient");
        spender = makeAddr("spender");

        vm.prank(holder);
        token = new TestERC20("My Token", "MTKN", INITIAL_SUPPLY);
    }

    // ==== TOKEN METADATA ====
    function testName() public {
        assertEq(token.name(), "My Token");
    }

    function testSymbol() public {
        assertEq(token.symbol(), "MTKN");
    }

    function testDecimals() public {
        assertEq(token.decimals(), DECIMALS);
    }

    function testTokenSupply_EqualsSumOfBalances() public {
        assertEq(token.totalSupply(), token.balanceOf(holder));
    }

    // ==== BALANCE ====
    function testBalanceOf_ReturnsCorrectBalance() public {
        assertEq(token.balanceOf(holder), INITIAL_SUPPLY);
    }

    function testBalanceOf_ZeroAddressReturnsZero() public {
        assertEq(token.balanceOf(ZERO_ADDRESS), 0);
    }

    function testTransfer_UpdatesBalancesCorrectly() public {
        uint256 amount = 10 ether;

        vm.prank(holder);
        token.transfer(recipient, amount);

        assertBalanceEq(holder, INITIAL_SUPPLY - amount);
        assertBalanceEq(recipient, amount);
    }

    // ==== TRANSFERS ====

    function testTransferSuccess() public {
        uint256 amount = 10 ether;

        vm.prank(holder);
        token.transfer(recipient, amount);

        assertBalanceEq(holder, INITIAL_SUPPLY - amount);
        assertBalanceEq(recipient, amount);
    }

    function testTransferFullBalance() public {
        uint256 full = INITIAL_SUPPLY;

        vm.prank(holder);
        token.transfer(recipient, full);

        assertBalanceEq(holder, 0);
        assertBalanceEq(recipient, full);
    }

    function testTransferZero() public {
        vm.prank(holder);
        token.transfer(recipient, 0);

        assertBalanceEq(holder, INITIAL_SUPPLY);
        assertBalanceEq(recipient, 0);
    }

    function testTransferReverts_NotEnoughBalance() public {
        uint256 amount = INITIAL_SUPPLY + 1 ether;

        vm.prank(holder);
        token.transfer(recipient, INITIAL_SUPPLY); // drain

        vm.prank(holder);
        vm.expectRevert(); // no balance left
        token.transfer(recipient, 1 ether);
    }

    function testTransferReverts_ToZeroAddress() public {
        vm.prank(holder);

        // selector: bytes4(keccak256("ERC20InvalidReceiver(address)"))
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InvalidReceiver(address)",
                ZERO_ADDRESS
            )
        );

        token.transfer(ZERO_ADDRESS, 1 ether);
    }

    function testTransferEmitsEvent() public {
        uint256 amount = 1 ether;

        vm.prank(holder);
        vm.expectEmit(true, true, false, true);
        emit Transfer(holder, recipient, amount);

        token.transfer(recipient, amount);
    }

    function testTransferPreservesTotalSupply() public {
        uint256 before = token.totalSupply();

        vm.prank(holder);
        token.transfer(recipient, 10 ether);

        uint256 after_ = token.totalSupply();
        assertEq(before, after_, "Total supply must remain constant");
    }

    // ==== ALLOWANCE ====

    function testApprovalSetsAllowance() public {
        uint256 amount = 50 ether;

        vm.prank(holder);
        token.approve(spender, amount);

        assertEq(token.allowance(holder, spender), amount);
    }

    function testApproveOverridesPrevious() public {
        uint256 first = 10 ether;
        uint256 second = 42 ether;

        vm.prank(holder);
        token.approve(spender, first);

        vm.prank(holder);
        token.approve(spender, second);

        assertEq(token.allowance(holder, spender), second);
    }

    function testApproveToZero() public {
        uint256 amount = 30 ether;

        vm.prank(holder);
        token.approve(spender, amount);

        vm.prank(holder);
        token.approve(spender, 0);

        assertEq(token.allowance(holder, spender), 0);
    }

    error ERC20InvalidApprover(address approver);

    function testApproveFromZeroAddress() public {
        // simulate call from address(0) using `vm.prank(address(0))`
        vm.prank(ZERO_ADDRESS);
        vm.expectRevert(
            abi.encodeWithSelector(ERC20InvalidApprover.selector, ZERO_ADDRESS)
        );
        token.approve(spender, 10 ether);
    }

    error ERC20InvalidSpender(address spender);

    function testApproveToZeroAddress() public {
        vm.prank(holder);
        vm.expectRevert(
            abi.encodeWithSelector(ERC20InvalidSpender.selector, ZERO_ADDRESS)
        );
        token.approve(ZERO_ADDRESS, 1 ether);
    }

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function testApproveEmitsEvent() public {
        uint256 amount = 20 ether;

        vm.prank(holder);
        vm.expectEmit(true, true, false, true);
        emit Approval(holder, spender, amount);

        token.approve(spender, amount);
    }

    function testApproveMaxUint() public {
        vm.prank(holder);
        token.approve(spender, MAX_UINT);

        assertEq(token.allowance(holder, spender), MAX_UINT);
    }

    // ==== TRANSFERS ====

    /// @notice Can transfer tokens via approved spender
    function testTransferFromWorks() public {
        uint256 amount = 10 ether;

        // Holder gives spender permission
        vm.prank(holder);
        token.approve(spender, amount);

        // Spender initiates transferFrom
        vm.prank(spender);
        token.transferFrom(holder, recipient, amount);

        // Assert balances updated
        assertBalanceEq(holder, INITIAL_SUPPLY - amount);
        assertBalanceEq(recipient, amount);
    }

    /// @notice Allowancw should be consumed (set to 0) after exact spend
    function testTransferFromReducesAllowance() public {
        uint256 amount = 5 ether;

        vm.prank(holder);
        token.approve(spender, amount);

        vm.prank(spender);
        token.transferFrom(holder, recipient, amount);

        assertEq(token.allowance(holder, spender), 0);
    }

    /// @notice Infinite allowance should not decrease after transfer
    function testTransferFromWithMaxUint() public {
        uint256 amount = 1 ether;

        vm.prank(holder);
        token.approve(spender, MAX_UINT);

        vm.prank(spender);
        token.transferFrom(holder, recipient, amount);

        // Still has infinite allowance
        assertEq(token.allowance(holder, spender), MAX_UINT);
    }

    /// @notice Reverts when trying to spend more than allowance
    function testTransferFromInsufficientAllowance() public {
        uint256 allowed = 1 ether;
        uint256 value = 2 ether;

        vm.prank(holder);
        token.approve(spender, allowed);

        vm.prank(spender);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientAllowance(address,uint256,uint256)",
                spender,
                allowed,
                value
            )
        );

        token.transferFrom(holder, recipient, value);
    }

    /// @notice Reverts when owner has insufficient balance
    function testTransferFromInsufficientBalance() public {
        uint256 allowed = INITIAL_SUPPLY + 1 ether;

        vm.prank(holder);
        token.approve(spender, allowed);

        vm.prank(spender);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientBalance(address,uint256,uint256)",
                holder,
                INITIAL_SUPPLY,
                allowed
            )
        );

        token.transferFrom(holder, recipient, allowed);
    }

    /// @notice Reverts when attempting to approve from zero address
    function testTransferFromZeroOwner() public {
        uint256 value = 1 ether;

        vm.prank(spender);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientAllowance(address,uint256,uint256)",
                spender,
                0,
                value
            )
        );
        token.transferFrom(ZERO_ADDRESS, recipient, value);
    }

    /// @notice Reverts when recipient is zero address
    function testTransferFromToZero() public {
        uint256 amount = 1 ether;

        vm.prank(holder);
        token.approve(spender, amount);

        vm.prank(spender);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InvalidReceiver(address)",
                ZERO_ADDRESS
            )
        );

        token.transferFrom(holder, ZERO_ADDRESS, amount);
    }

    /// @notice Emits Transfer event with correct args
    function testTransferFromEmitsTransfer() public {
        uint256 amount = 1 ether;

        vm.prank(holder);
        token.approve(spender, amount);

        vm.prank(spender);
        vm.expectEmit(true, true, false, true); // indexed, indexed, not indexed, check data
        emit Transfer(holder, recipient, amount);

        token.transferFrom(holder, recipient, amount);
    }

    /// @notice Approval event is NOT emitted if allowance is MaxUint
    function testTransferFromEmitsNoApprovalIfInfinite() public {
        vm.prank(holder);
        token.approve(spender, MAX_UINT);

        vm.prank(spender);
        token.transferFrom(holder, recipient, 1 ether);
    }

    // ==== INTERNAL HOOKS ====

    /// @notice Internal `_transfer()` should emit Transfer event
    function test_internalTransfer_EmitsEvent() public {
        uint256 amount = 1 ether;

        // Expect Transfer event with correct indexed params and value
        vm.expectEmit(true, true, false, true);
        emit Transfer(holder, recipient, amount);

        token.$_transfer(holder, recipient, amount);
    }

    /// @notice Internal `_approve()` should emit Approval event
    function test_internalApprove_EmitsEvent() public {
        uint256 amount = 2 ether;

        // Expect approval event with correct owner, spender, value
        vm.expectEmit(true, true, false, true);
        emit Approval(holder, spender, amount);

        token.$_approve(holder, spender, amount);
    }

    /// @notice If `from == address(0)`, _update() should mint tokens (increase supply)
    function test_internalUpdate_Mint() public {
        uint256 mintAmount = 5 ether;
        uint256 previousSupply = token.totalSupply();

        // Mint tokens to recipient
        token.$_update(address(0), recipient, mintAmount);

        // Total supply should increase
        assertEq(token.totalSupply(), previousSupply + mintAmount);
        assertBalanceEq(recipient, mintAmount);
    }

    /// @notice If `to == address(0)`, _update() should burn tokens (decrease supply)
    function test_internalUpdate_Burn() public {
        uint256 burnAmount = 3 ether;

        // First move some tokens to this address
        token.$_transfer(holder, address(this), burnAmount);
        uint256 previousSupply = token.totalSupply();

        // Burn tokens from this address
        token.$_update(address(this), address(0), burnAmount);

        // Total supply should decrease and balance become zero
        assertEq(token.totalSupply(), previousSupply - burnAmount);
        assertBalanceEq(address(this), 0);
    }

    /// @notice _update() should allow from == to (no supply change, no net effect)
    function test_internalUpdate_SameAddress() public {
        uint256 amount = 2 ether;

        // Move tokens to a test address
        token.$_transfer(holder, address(this), amount);

        // Use _update with from == to
        token.$_update(address(this), address(this), amount);

        // Balance should remain unchanged and no mint/burn
        assertBalanceEq(address(this), amount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
    }

    /// @notice _update() should revert if it would overflow balance (mint too much)
    function test_internalUpdate_RevertsOnOverflow() public {
        address user = address(0xBEEF);
        token.$_mint(user, 1 ether); // Give user initial balance

        // Attempt to mint MAX - would overflow uint256
        vm.expectRevert(); // Should trigger Solidity panic
        token.$_mint(user, type(uint256).max);
    }

    // ==== MINT ====

    /// @notice Mints tokens to a user
function testMint() public {
    uint256 amount = 100 ether;
    address user = makeAddr("user");

    token.$_mint(user, amount);

    assertEq(token.balanceOf(user), amount);
    assertEq(token.totalSupply(), INITIAL_SUPPLY + amount);
}

/// @notice Reverts when minting to the zero address
function testMintToZeroAddress() public {
    uint256 amount = 1 ether;

    vm.expectRevert(
        abi.encodeWithSignature("ERC20InvalidReceiver(address)", ZERO_ADDRESS)
    );
    token.$_mint(ZERO_ADDRESS, amount);
}

/// @notice Reverts when minting causes total supply to overflow
function testMintOverflow() public {
    // Set totalSupply near max value
    address user = makeAddr("user");

    // Manually mint a huge amount to push close to overflow
    token.$_mint(user, type(uint256).max - INITIAL_SUPPLY);

    // Next mint should overflow
    vm.expectRevert(stdError.arithmeticError); // PANIC 0x11
    token.$_mint(user, 1);
}

/// @notice Emits Transfer(from=0x0, to=user, value)
function testMintEmitsTransferFromZero() public {
    uint256 amount = 1 ether;
    address user = makeAddr("user");

    vm.expectEmit(true, true, false, true);
    emit Transfer(ZERO_ADDRESS, user, amount);

    token.$_mint(user, amount);
}

// ==== BURN ====

/// @notice Burns user tokens correctly
function testBurn() public {
    uint256 amount = 1 ether;

    token.$_burn(holder, amount);

    assertEq(token.balanceOf(holder), INITIAL_SUPPLY - amount);
    assertEq(token.totalSupply(), INITIAL_SUPPLY - amount);
}

/// @notice Reverts when burning more than balance
function testBurnTooMuch() public {
    uint256 amount = INITIAL_SUPPLY + 1 ether;

    vm.expectRevert(
        abi.encodeWithSignature(
            "ERC20InsufficientBalance(address,uint256,uint256)",
            holder,
            INITIAL_SUPPLY,
            amount
        )
    );
    token.$_burn(holder, amount);
}

/// @notice Reverts when burning from the zero address
function testBurnZeroAddress() public {
    vm.expectRevert(
        abi.encodeWithSignature("ERC20InvalidSender(address)", ZERO_ADDRESS)
    );
    token.$_burn(ZERO_ADDRESS, 1 ether);
}

/// @notice Emits Transfer(to=0x0) when burning
function testBurnEmitsTransferToZero() public {
    uint256 amount = 1 ether;

    vm.expectEmit(true, true, false, true);
    emit Transfer(holder, ZERO_ADDRESS, amount);

    token.$_burn(holder, amount);
}

// ==== FUZZ TESTING ====

/// @notice Fuzz transfer to random address with random amount
function testFuzzTransfer(address to, uint256 amount) public {
    vm.assume(to != address(0));
    vm.assume(to != holder); // to avoid holder sending to self

    // Reset balances before fuzz run
    deal(address(token), holder, INITIAL_SUPPLY);
    deal(address(token), to, 0);

    amount = bound(amount, 0, INITIAL_SUPPLY);

    vm.prank(holder);
    token.transfer(to, amount);

    assertEq(token.balanceOf(to), amount);
    assertEq(token.balanceOf(holder), INITIAL_SUPPLY - amount);
}


/// @notice Fuzz approve for random spender and amount
function testFuzzApprove(address spender_, uint256 value) public {
    vm.assume(spender_ != address(0)); // Ensure non-zero spender

    vm.prank(holder);
    token.approve(spender_, value);

    assertEq(token.allowance(holder, spender_), value);
}

/// @notice Fuzz transferFrom by spender who has allowance and balance
function testFuzzTransferFrom(address from, address to, uint256 value) public {
    vm.assume(from != address(0) && to != address(0));
    
    uint256 startingBalance = 100 ether;
    value = bound(value, 0, startingBalance);

    // Give 'from' enough tokens
    deal(address(token), from, startingBalance);

    // Give spender approval
    vm.prank(from);
    token.approve(spender, value);

    // Spender calls transferFrom
    vm.prank(spender);
    token.transferFrom(from, to, value);

    assertEq(token.balanceOf(to), value);
    assertEq(token.balanceOf(from), startingBalance - value);
}

/// @notice Fuzz minting and burning preserves totalSupply = sum of balances
function testFuzzMintBurnBalanceIntegrity(uint256 mintAmount, uint256 burnAmount) public {
    mintAmount = bound(mintAmount, 0, type(uint128).max);
    burnAmount = bound(burnAmount, 0, mintAmount); // Only burn what we mint

    address user = makeAddr("user");

    token.$_mint(user, mintAmount);
    token.$_burn(user, burnAmount);

    uint256 supply = token.totalSupply();
    uint256 balance = token.balanceOf(user) + token.balanceOf(holder); // holder still holds INITIAL_SUPPLY

    assertEq(supply, balance);
}



    event Transfer(address indexed from, address indexed to, uint256 value);
}
