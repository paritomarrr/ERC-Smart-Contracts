# ERC20 Deep Dive

## Inheritance
```solidity
abstract contract ERC20 is IERC20, IERC20Metadata, Context, IERC20Errors
```

Purpose:
- Implements ERC20 behavior (`IERC20`)
- Adds token name/symbol/decimals (`IERC20Metadata`)
- Inherits `_msgSender()` via `Context` for meta-tx support
- Custom errors (`IERC20Errors`) insteads of strings -- saves gas

## State Variables

1. `string private _name;`
2. `string private _symbol`

Purpose:
These represent ERC20 metadata, such as
- `_name`: Full name of the token
- `_symbol`: Abbreviation 

Defined by:
- IERC20Metadata -- an optional extension of ERC20

Notes:
- used only for off-chain display purposes (wallets, UIs)
- Not used in any on-chain logic or calculations
- Stored as `string` -> expensive in gas if modified, but only set once (in constructor)

3. `uint256 private _totalSupply`

Purpose:
Tracks the current circulating supply of the token.

Mechanics:
- Incremented during `_mint`
- Decremented during `_burn`

Invariants:
- Cannot overflow (uses Solidity 0.8+ with checked math)
- Always equal to the sum of all balances

Notes:
- `totalSupply()` is a `view` getter
- Used by third-party tools to display market cap, circulating supply

4. `mapping(address => uint256) private _balances;`

Purpose:
Keeps track of individual token holdings

Structure:
```solidity
_balances[address] = uint256
```

Access Pattern:
- Directly read via `balanceOf()`
- Updated via:
> `_transfer(from, to, amount)`
> `_mint(to, amount)`
> `_burn(from, amount)`

Storage Notes:
- Each address gets a new storage slot, which costs 20k gas on first write, 5k on update
- Deleting a balance (setting to zero) refunds 15k gas

Security
- Always checked against `>= amount` in transfer flows to prevent underflow
- Never accepts transfer to/from `address(0)`

5. `mapping(address => mapping(address => uint256)) private _allowances;`

Purpose:
Tracks delegated spending power--how much a `spender` is allowed to transfer from an `owner`.

Structure:
```solidity
_allowances[owner][spender] = uint256;
```

Usage:
- Read via `allowance(owner, spender)`
- Set via `approve(spender, amount)`
- Decreased in `transferFrom` via `_spendAllowance`

Infinite Approval Optimization:
```solidity
if (allowanxe == type(uint256).max) {
    // skip updating - treated as infinite
}
```

This is a gas-saving optimization that mimics "infinite approval" 

Risks:
- Approval front-running vulnerability if `approve()` is called with a new amount while the old one is still active and usable. 

## Constructor
```solidity
constructor(string memory name_, string memory symbol_) {
    _name = name_;
    _symbol = symbol_;
}
```

Purpose: 
- Initializes the metadata of the ERC20 token:
> `_name`: Human readable name
> `_symbol`: Ticker symbol

Key Points:
1. No minting here
- This base contract does not mint any tokens during construction.
- Minting is intentionally left to child contracts, using the internal `_mint()` function.
- This keeps the ERC20 contract modular and reusable. 

```solidity
contract MyToken is ERC20 {
    constructor() ERC20("MyToken", "MTK") {
        _mint(msg.sender, 1000 * 10 ** decimals());
    }
}
```

2. Immutability by convention

```solidity
string private _name;
string private _symbol;
```
- These are not explicitly declared `immutable`, but they behave effectively immutable because:
> They are only set in the constructor
> There are no setter functions to change them later
- `immutable` would reduce storage cost (keeps it in bytecode), but `string` types can't be immutable -- only value types (e.g. `uint`, `address`) can.

3. Constructor Arguments are memory variables
- Solidity requires dynamic types like `string` to be passed in memory.
- `name_` and `symbol_` are standard underscore-prefixed names to distinguish them from state vars.

4. Gas Considerations
- Since `_name` and `_symbol` are `string`, they use dynamic storage (keccak256 slot), which is more expensive than fixed-size types.
- But since these are only set once, and never updated, the gas impact is acceptable.

## Metadata Functions
```solidity
function name() public view virtual returns (string memory) {
    return _name;
}

function symbol() public view virtual returns (string memory) {
    return _symbol;
}

function decimals() public view virtual returns (uint8) {
    return 18;
}

```

Purpose:
These fnuctions expose token identity and formatting metadata to frontends, wallets and explorers. 
They have no effect on the token's accounting or logic, but they are crucial for user experience. 

### Function by function Breakdown
1. `name()`
What it does:
Returns the full descriptive name of the token

Usage:
- Displayed in wallets 
- Used in UIs alongside balances

Security
- Returns `_name`, which is set only once in the constructor
- No risk of manipulation unless the contract is upgradeable

2. `symbol()`
What it does:
Returns the short ticker symbol

Usage:
- Appears on explorers, exchanges, dashboards
- Helps with visual clarity and quick recognition

Security:
- Same as `name()` -- read-only, constructor-initialized

3. `decimals()`
What it does:
Returns the number of decimal places used to format the token's units
- 18 decimals -> `1000000000000000000` = `1.0 token`

Convention:
- 18 decimals is the de facto Ethereum standard, imitating ETH/Wei
- USDC uses 6 demails -- important for DeFi integrations

Notes:
- `decimals()` is only for display purposes
- It does not affect internal logic or token math
- You must still perform math using raw integers

Why these are `view`?
Because no state mutation

Why these are `virtual`?
Allow overriding in custom token setups

Example override:
```solidity
function decimals() public pure override returns (uint8) {
    return 6; // USDC style
}
```

Storage Access
- `name()` - string [dynamic]
- `symbol()` - string [dynamic]
- `decimals()` - constant [in practice]

## Read Functions
1. `totalSupply()`
```solidity
function totalSupply() public view virtual returns (uint256) {
    return _totalSupply;
}
```

Purpose:
Returns the total number of tokens currently in circulation.

Internals:
- `totalSupply()` is updated only via `_mint()` and `_burn()`:
> `_mint()` -> adds to supply
> `_burn()` -> subtracts from supply

Real-world usage:
- Used by explorers, DeFi dashboards to show "market cap" or circulating supply

Security:
- Uses solidity 0.8+, so overflow/underflow are checked
- Cannot become negative (uint256)
- Not modifiable externally (no setter)

2. `balanceOf(address account)`
```solidity
function balanceOf (address account) public view virtual returns (uint256) {
    return _balances[account];
}
```

Purpose:
Returns the current token balance of a given address.

Internals:
`balances` is updated by `_transfer`,`_mint`and `_burn`

Security
- Cannot overflow or underflow
- If no tokens ever received, the mapping defaults to 0 (safe)
- Read-only, no access control needed

3. `allowance(address owner, address spender)`
```solidity
function allowance(address owner, address spender) public view virtual returns (uint256) {
    return _allowances[owner][spender];
}
```

Purpose:
Returns the remaining number of tokens that `spender` is allowed to spend on behalf of `owner`.

Internals:
- `_allowances` is modified by:
> `approve()` -> sets value
> `transferFrom()` -> spends value via `_spendAllowance`
- Also readable by:
> dApps and DeFi protocols (e.g., Uniswap)
> Explorers (e.g., "Approved to: X contract")

Security
- Fully view-only
- Defaults to 0 if never approved
- Infinite approval (type(uint256).max) optimization handled in _spendAllowance

