# 🧠 ERC Smart Contracts Test Suite

A rigorous and modular smart contract testing repository focused on **real-world ERC standard implementations** using both **Foundry** and **Hardhat**.

---

## ✅ What's Included

### 🧪 Full ERC20 Test Suite
- Unit tests
- Fuzzing tests
- Invariant tests
- Internal hook testing
- Hardhat + Foundry parity
- Gas checks, revert checks, and event logs
- Bug reproduction edge cases

### 📂 Organized by Folder
- `contracts/`: Core implementations
- `interfaces/`: Standard interface definitions
- `utils/`: Shared helpers and base modules
- `test-foundry/`: Foundry test suite (unit + invariants)
- `test-hardhat/`: Hardhat test suite
- `notes.md`: Conceptual + developer notes
- `security.md`: Known attack vectors and mitigation

---

## 🧰 Scripts

| Command | Description |
|--------|-------------|
| `npm run test:foundry` | Run all Foundry tests |
| `npm run test:foundry:unit` | Run unit tests for ERC20 via Foundry |
| `npm run test:foundry:invariant` | Run invariant tests for ERC20 via Foundry |
| `npm run test:hardhat` | Run all Hardhat tests for ERC20 |
| `npm run build:hardhat` | Compile contracts using Hardhat |
| `npm run clean:hardhat` | Clean Hardhat cache/artifacts |

> No need to `cd` into any folders — top-level `package.json` handles everything.

---

## 📦 Covered So Far
- ✅ ERC-20 (with full coverage including edge cases, invariants, fuzzing, and both Hardhat & Foundry)
- 🧾 Extensive notes (`notes.md`) and security vectors (`security.md`) included

---

## 🚧 Upcoming Coverage (Work In Progress)
- ERC-2612 (Permit)
- ERC-777
- ERC-721
- ERC-721A
- ERC-1155
- ERC-4626
- Ownable / AccessControl / Pausable / ReentrancyGuard
- ERC-165 / 1967 / 1167 / 2535 (Diamond) / 2981
- Meta-transactions & Signatures: ERC-2771 / 1271 / 4337 / 1820 / EIP-712
- Address checksums & blobs: EIP-55 / EIP-4844

---

## 🛡️ Focus on Security
Every standard we test is evaluated for:
- Known vulnerabilities
- Compliance with spec
- Revert behavior
- Total supply consistency
- Unexpected edge conditions

---

## 🧱 Goal
Build a reusable, extensible testbed for **all critical Ethereum token standards** in one place — deeply verified, security-aware, and ready for production.

