# 🧠 ERC-2612 Permit Suite

ERC-2612 is a powerful extension to ERC-20 that enables **gasless approvals** using **off-chain signatures**. This suite provides a complete environment to **develop, test, break, and secure** EIP-2612-compatible smart contracts.

---

## 🌐 Connect With Me

[![](https://img.shields.io/badge/X-%40tomarpari90-blue?logo=twitter)](https://x.com/tomarpari90)  
[![](https://img.shields.io/badge/LinkedIn-PariTomar-blue?logo=linkedin)](https://www.linkedin.com/in/tomarpari90/)  
[![](https://img.shields.io/badge/Medium-%40tomarpari90-black?logo=medium)](https://medium.com/@tomarpari90)

---

## 🔍 What’s Inside

- ✅ Full ERC-2612 implementation with inline NatSpec + audit-style structure
- ✅ Hardhat test suite with signature generation, replay protection, and edge case coverage
- ✅ Foundry test suite with fuzzing, invariant checks, and replay attack simulations
- ✅ Documentation on real-world attack vectors (DAI-style deviation, silent failure risks)
- ✅ Signature utilities for `v`, `r`, `s` generation in Ethers.js and Foundry
- ✅ Security notes on nonce validation, domain separation, and unsafe integrations

---

## 🧪 Testing Guide

### 🛠️ Hardhat

```bash
cd hardhat
npm install
npx hardhat test
```

### 🛠️ Foundry
```bash
cd foundry
forge build
forge test -vvvv
```