// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.26;

/// @title A Simple ERC-20 Token Implementation
/// @author Pari Tomar
/// @notice This contract implements a basic ERC-20 token with mint and burn functionality
/// @dev Does not include access control; mint and burn can be called by anyone

interface IERC20 {
    /// @notice Returns the total token supply
    function totalSupply() external view returns (uint256);

    /// @notice Transfers tokens from the caller to a specified address
    function transfer(address, uint256) external returns (bool);

    /// @notice Transfers tokens from one address to another using allowance mechanism
    function transferFrom(address to, uint256 amount) external returns (bool);

    /// @notice Approves a spender to spend a specified amount of tokens
    function approve(address spender, uint256 amount) external returns (bool);

    /// @notice Returns the token balance of a given address
    function balanceOf(address user) external view returns (uint256);

    /// @notice Returns the remaining number of tokens a spender is allowed to spend
    function allowance(address owner, address spender) external view returns (uint256); 
}

contract ERC20 {
    /// @notice Name of the token
    string public name;

    /// @notice Symbol of the token
    string public symbol;

    /// @notice Number of decimals used to get user representation
    uint8 public decimals;

    /// @notice Total supply of tokens in existence
    uint256 public totalSupply;

    /// @notice Maps addresses to their balances
    mapping(address => uint256) public balanceOf;

    /// @notice Allowances: owner => spender => amount
    mapping(address => mapping(address => uint256)) public allowance;

    /// @notice Emitted when tokens are transferred
    event Transfer(address indexed from, address indexed to, uint256 amount);

    /// @notice Emitted when an approval is set
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /// @notice Contract constructor sets the token details
    /// @param _name Name of the token
    /// @param _symbol Symbol of the token
    /// @param _decimals Number of decimals
    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    /// @notice Transfers tokens from the caller to a recipient
    /// @param to The recipient address
    /// @param amount Amount of tokens to send
    /// @return success Boolean indicating if transfer succeeded
    function transfer(address to, uint256 amount) public returns (bool success) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    /// @notice Transfers tokens on behalf of another address using allowance
    /// @param from The address to transfer tokens from
    /// @param to The address to transfer tokens to
    /// @param amount The amount of tokens to transfer
    /// @return success Boolean indicating if transfer succeeded
    function transferFrom(address from, address to, uint256 amount) public returns (bool success) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    /// @notice Approves a spender to spend tokens on behalf of the caller
    /// @param spender The address authorized to spend
    /// @param amount The max amount they are allowed to spend
    /// @return success Boolean indicating if approval succeeded
    function approve(address spender, uint256 amount) public returns (bool success) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /// @notice Public function to mint new tokens to an address
    /// @param receiver The address to receive the minted tokens
    /// @param amount The amount of tokens to mint
    function mint(address receiver, uint256 amount) external {
        _mint(receiver, amount);
    }

    /// @notice Public function to burn tokens from an address
    /// @param spender The address whose tokens will be burned
    /// @param amount The amount of tokens to burn
    function burn(address spender, uint256 amount) external {
        _burn(spender, amount);
    }

    /// @dev Internal function to mint tokens
    /// @param receiver The address receiving tokens
    /// @param amount The amount of tokens to mint
    function _mint(address receiver, uint256 amount) internal {
        balanceOf[receiver] += amount;
        totalSupply += amount;
        emit Transfer(address(0), receiver, amount);
    }

    /// @dev Internal function to burn tokens
    /// @param spender The address whose tokens will be destroyed
    /// @param amount The amount of tokens to burn
    function _burn(address spender, uint256 amount) internal {
        balanceOf[spender] -= amount;
        totalSupply -= amount;
        emit Transfer(spender, address(0), amount);
    }
}
