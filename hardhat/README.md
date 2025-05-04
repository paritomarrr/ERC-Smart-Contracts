<details>
<summary>ERC-20</summary>
<br>
<h1>ERC-20 or Ethereum Request for Comment 20</h1>
It is a technical standard used to define the rules and functionality of tokens on the Ethereum blockchain. 
<br>
It ensures all ERC-20 tokens will have consistent set of guidelines, allowing them to interact with DEXes and dApps within the Ethereum exosystem. 
<br>
It simplifies token development and interaction between tokens and platforms.


<h2>Why we need it?</h2>
It addresses fragmented and unpredictable behavior of the tokens across the blockchain.
<br>
Before the introduction of ERC-20, creating tokens on Ethereum was inconsistent and fragmented. <br>
This inconsistency made it difficult to develop interoperable systems, as tokens often behaved unpredictably when integrated into different platforms. 

<h2>Solution</h2>
ERC-20 introduced a universal set of rules for creating tokens on Ethereum, making it easier for developers to ensure their tokens could work seamlessly with wallets, exchanges, and other applications.

<h2>How does it work?</h2>
The ERC-20 standard provides a unified set of functions and events that all Ethereum-based tokens must implement to ensure consistency. 

<h3>Core Functions</h3>

`1. transfer(address _to, address _value)`
Transfer `_value` amount of tokens to address`_to` and triggers the `Transfer` event. If the sender’s balance is insufficient, the transaction is reverted.
<br>
Note: Transfers of zero value are considered valid and must trigger the Transfer event.

```
function transfer(address _to, uint256 _value) public view returns (bool success)
```

`2. approve(address _spender, uint256 _value)`
This function authorises _spender to withdraw up to _value token from your account. 

```
function approve(address _spender, uint256 _value) public view returns (bool success)
```

`3. allowance(address _owner, address _spender)`  
Returns the amount `_spender` is still allowed to withdraw from `_owner`’s account.  
Useful for verifying the remaining allowance in delegated transfers.

```
function allowance(address _owner, address _spender) public view returns (uint256 remaining)
```


`4. transferFrom(address _from, address _to, uint256 _value)`  
Allows `_spender` to transfer `_value` tokens from `_from` to `_to`, provided they have enough allowance.  
This is commonly used in scenarios like automated payments or decentralized exchange contracts.

```
function transferFrom(address _from, address _to, uint256 _value) public returns (bool success)
```


`5. totalSupply()`  
Returns the total supply of the token currently in circulation.

```
function totalSupply() public view returns (uint256)
```

`6. balanceOf(address _owner)`  
Returns the current token balance of the given address.  
<br>
This function is read-only and helps display token balances in wallets and dApps.

```
function balanceOf(address _owner) public view returns (uint256 balance)
```



<h3>Events</h3>

`event Transfer(address indexed _from, address indexed _to, uint256 _value)`  
Triggered when tokens are transferred from one address to another.  
<br>
This includes both direct transfers and those done via `transferFrom`.

<br><br>

`event Approval(address indexed _owner, address indexed _spender, uint256 _value)`  
Emitted when `approve()` is called successfully.  
<br>
Signals that `_spender` is allowed to spend up to `_value` tokens on behalf of `_owner`.

<br>

<h2>Impact of ERC-20</h2>
The ERC-20 standard made it significantly easier to launch and interact with fungible tokens on Ethereum.  
<br>
It led to the massive ICO boom in 2017 and remains the most used token standard for fungible assets like:
<ul>
  <li>Stablecoins (e.g., USDC, USDT)</li>
  <li>Governance tokens (e.g., UNI, AAVE)</li>
  <li>DeFi tokens (e.g., COMP, SNX)</li>
</ul>

ERC-20 tokens are now essential components of the Ethereum DeFi stack and have enabled millions of dollars worth of liquidity and innovation.

<h2>Popular Implementations</h2>

<ul>
  <li><strong>OpenZeppelin:</strong> Secure, extensible, community-vetted contracts with support for minting, burning, and access control.</li>
  <li><strong>Solmate:</strong> Lightweight, gas-efficient library used in performance-sensitive applications.</li>
  <li><strong>ConsenSys:</strong> Straightforward, educational implementation suitable for learning and quick deployment.</li>
</ul>


</details>