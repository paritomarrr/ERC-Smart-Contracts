// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {ERC20} from "contracts/ERC20.sol";

contract TestERC20 is ERC20 {
    
        constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }

    // public wrappers for internal functions to test edge cases
    function $_mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    function $_burn(address account, uint256 amount) public {
        _burn(account, amount);
    }

    function $_transfer(address from, address to, uint256 amount) public {
        _transfer(from, to, amount);
    }

    function $_approve(address owner, address spender, uint256 amount) public {
        _approve(owner, spender, amount);
    }

    function $_update(address from, address to, uint256 amount) public {
        super._update(from, to, amount);
    }
}
