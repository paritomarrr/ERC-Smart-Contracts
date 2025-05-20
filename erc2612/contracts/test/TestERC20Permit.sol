// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20Permit} from "../ERC20Permit.sol";
import {ERC20} from "../../../erc20/contracts/ERC20.sol";

contract TestERC20Permit is ERC20Permit {
    constructor(string memory name, string memory symbol)
        ERC20(name, symbol)
        ERC20Permit(name) {}

        function $_mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}