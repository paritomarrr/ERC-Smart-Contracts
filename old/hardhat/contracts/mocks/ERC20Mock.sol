// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "../token/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor() ERC20("ERC20Mock", "E20M", 18) {}

}