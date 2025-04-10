// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

// ERC20 Interface
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address recipient) external view returns (uint256);
    function transfer(address recipient, uint256 value) external view returns (bool);
    function transferFrom(address sender, address recipient, uint256 value) external view returns (uint256);
    function approve(address sender, address recipient, uint256 value) external view returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

// ERC20 Contract
contract ERC20 {

}