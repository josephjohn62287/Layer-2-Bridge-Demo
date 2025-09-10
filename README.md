# 🌉 Layer 2 Bridge Demo

A **Clarity smart contract** that simulates cross-chain token bridging functionality. This MVP demonstrates the core concepts of Layer 2 bridges and cross-chain token transfers.

## 🚀 Features

- 🔄 **Cross-Chain Deposits**: Deposit STX tokens to simulate bridging to Layer 2 chains
- 💸 **Withdrawal System**: Initiate and process withdrawals back to the main chain  
- 🛡️ **Multi-Chain Support**: Support for multiple target chains (Ethereum, Polygon, Arbitrum, Optimism)
- 👥 **Operator Management**: Bridge operators can process withdrawals
- ⏸️ **Emergency Controls**: Pause/unpause bridge functionality
- 💰 **Fee Management**: Configurable bridge fees
- 🔍 **Balance Tracking**: Track user balances across different chains

## 📋 Contract Functions

### Public Functions

| Function | Description |
|----------|-------------|
| `initialize-bridge` | Initialize the bridge with supported chains |
| `deposit-to-bridge` | Deposit STX to bridge to target chain |
| `initiate-withdrawal` | Start withdrawal process from Layer 2 |
| `process-withdrawal` | Process pending withdrawal (operators only) |
| `add-bridge-operator` | Add new bridge operator (owner only) |
| `pause-bridge` | Pause bridge operations (owner only) |
| `emergency-withdraw` | Emergency withdrawal (owner only) |

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-bridge-status` | Get current bridge status and settings |
| `get-user-balance-info` | Get user balance for specific chain |
| `get-withdrawal-info` | Get withdrawal details by nonce |
| `get-chain-info` | Get supported chain information |

## 🛠️ Usage

### Deploy and Initialize

```clarity
(contract-call? .layer-2-bridge-demo initialize-bridge)
```

### Deposit to Bridge

```clarity
(contract-call? .layer-2-bridge-demo deposit-to-bridge u10000000 u1)
```

### Check Balance

```clarity
(contract-call? .layer-2-bridge-demo get-user-balance-info 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM u1)
```

### Initiate Withdrawal

```clarity
(contract-call? .layer-2-bridge-demo initiate-withdrawal u5000000 u1)
```

### Process Withdrawal (Operators)

```clarity
(contract-call? .layer-2-bridge-demo process-withdrawal u0)
```

## 🔧 Configuration

- **Bridge Fee**: Default 1 STX (1000000 microSTX)
- **Supported Chains**: 
  - Chain ID 1: Ethereum
  - Chain ID 2: Polygon  
  - Chain ID 3: Arbitrum
  - Chain ID 4: Optimism

## 🎯 Learning Objectives

This demo teaches:
- Cross-chain token bridging concepts
- Withdrawal queue management
- Multi-signature operator patterns
- Emergency pause mechanisms
- Fee collection systems
- Balance tracking across chains

## ⚠️ Important Notes

- This is a **demo contract** for educational purposes
- Real bridge implementations require additional security measures
- Always test thoroughly before mainnet deployment
- Consider oracle integration for production bridges

## 🧪 Testing

Use Clarinet to test the contract:

```bash
clarinet test
```

## 📝 Error Codes

| Code | Description |
|------|-------------|
| u100 | Unauthorized access |
| u101 | Insufficient balance |
| u102 | Invalid amount |
| u103 | Bridge paused |
| u104 | Invalid chain |
| u105 | Withdrawal not found |
| u106 | Withdrawal already processed |

---

**Built with ❤️ using Clarity and Clarinet**
```

**Git Commit Message:**
```
feat: implement Layer 2 bridge demo with cross-chain token bridging simulation
```

**GitHub Pull Request Title:**
```
🌉 Add Layer 2 Bridge Demo Contract - Cross-Chain Token Bridging MVP
```

**GitHub Pull Request Description:**
```
## 🌉 Layer 2 Bridge Demo Implementation

This PR adds a complete Layer 2 bridge demonstration contract that simulates cross-chain token bridging functionality.

### ✨ Features Added
- Cross-chain deposit and withdrawal system
- Multi-chain support (Ethereum, Polygon, Arbitrum, Optimism)
- Bridge operator management with role-based access
- Emergency pause/unpause functionality
- Configurable bridge fees
- Withdrawal queue processing system
- Comprehensive balance tracking across chains

### 🎯 Educational Value
Perfect for learning cross-chain bridge concepts including:
- Token locking/unlocking mechanisms
- Withdrawal queue management
- Multi-signature operator patterns
- Emergency controls and safety measures

### 📁 Files Added
- `contracts/layer-2-bridge-demo.clar` - Main bridge contract (200+ lines)
- `README.md` - Comprehensive documentation with usage examples

Ready for testing and educational use! 🚀

