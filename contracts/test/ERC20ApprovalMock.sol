// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../erc20/contracts/ERC20.sol";

contract ERC20ApprovalMock is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount,
        bool
    ) internal virtual override {
        // This mock forces `approval` to always succeed
        super._approve(owner, spender, amount, true);
    }

    // ✅ Test-only helpers
    function $_mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function $_burn(address from, uint256 amount) public {
        _burn(from, amount);
    }

    function $_transfer(address from, address to, uint256 amount) public {
        _transfer(from, to, amount);
    }

    function $_approve(address owner, address spender, uint256 amount) public {
        _approve(owner, spender, amount);
    }

    function $_update(address from, address to, uint256 amount) public {
        _update(from, to, amount);
    }
}