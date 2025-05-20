# 🧠 ERC20 Smart Contract Suite

Welcome to the **ERC20 Development and Security Learning Suite** — a comprehensive, dual-environment (Hardhat + Foundry) boilerplate designed to:

- 📦 **Develop and test** production-ready ERC20 contracts  
- 🔬 **Document & explain** the internals of ERC20 and ERC20Permit  
- 🛡️ **Explore attack vectors** and write security notes  
- 📚 Serve as a reference repo for Solidity learners & professionals  

---

## 🌐 Connect With Me

[![](https://img.shields.io/badge/X-%40tomarpari90-blue?logo=twitter)](https://x.com/tomarpari90)  
[![](https://img.shields.io/badge/LinkedIn-PariTomar-blue?logo=linkedin)](https://www.linkedin.com/in/tomarpari90/)  
[![](https://img.shields.io/badge/Medium-%40tomarpari90-black?logo=medium)](https://medium.com/@tomarpari90)

---

## 🧩 Folder Structure Overview

```bash
ERC-20/
├── foundry/              # For Foundry-based testing & learning
│   ├── src/              # Contracts (ERC20, Permit, etc.)
│   ├── test/             # Forge-based test cases
│   ├── lib/              # forge-std for cheatcodes and utils
│   ├── remappings.txt    # Remapping paths
│   └── foundry.toml      # Forge config
│
├── hardhat/              # Hardhat-based development & testing
│   ├── contracts/        # Contracts for deployment
│   ├── test/             # Mocha/Chai test cases
│   ├── hardhat.config.js # Configuration file
│   └── package.json      # Dependencies and scripts
│
├── notes.md              # Deep dive into ERC20 specs and logic
├── security.md           # Audit & attack vectors documented
```

## 🧪 How to Run Tests

### Hardhat (JavaScript Testing)
```bash
cd hardhat
npm install
npx hardhat test
```

### Foundry (Forge Testing)
```bash
cd foundry
forge install       # If needed, install dependencies like forge-std
forge build
forge test
```

## 🔍 What's Inside

### 📘 `notes.md`
- Thorough breakdown of `ERC20`  
- EIP references & contract behaviors explained line-by-line  
- Common pitfalls & internal design rationale  
- Notes to help you *understand every line*, not just use it

### 🔐 `security.md`
- Real-world attack vectors and security insights including:
  - Integer overflow/underflow (pre-Solidity 0.8)
  - `approve()` race condition (double-spend attacks)
  - Transfer event mismatches or missing validations
- Based on learnings from audits and DeFi exploits

---

