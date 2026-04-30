# ERC-8232: On-Chain Agency Execution (Restricted Proxy)

[![Vyper](https://img.shields.io/badge/language-Vyper-yellow)](https://docs.vyperlang.org)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**The Mechanical Safety Switch for Autonomous AI Agents**

A Vyper implementation of ERC-8232 with optional RAMS integration. This standard enables secure on-chain execution constraints for autonomous agents through a bitmask-to-selector mapping architecture.

## Table of Contents

- [Abstract](#abstract)
- [The Problem](#the-problem-the-hallucination-drain)
- [The Solution](#the-solution-restricted-agency)
- [Architecture](#architecture)
- [Installation](#installation)
- [Quick Start](#quick-start-poc)
- [Contributing](#contributing)
- [License](#license)

## Abstract

As AI agents move toward autonomy in RWA and DeFi environments, the industry faces an **Execution Gap**. Current delegation standards (ERC-1271, ERC-4337) focus on identity (Who is the agent?), but they fail to provide granular constraint (What bytes can the agent send?).

ERC-8232 introduces a proxy-factory architecture that enforces a **bitmask-to-selector mapping**. It provides a hardware-level firewall that physically prevents agents from executing unauthorized function calls, regardless of their legal mandate or AI logic.

## The Problem: "The Hallucination Drain"

Autonomous agents are prone to:

- **Logic Hallucinations:** AI sends a `burn()` or `withdraw()` command when it intended to `rebalance()`.
- **Key Compromise:** An attacker steals an agent's API key and attempts a `transferAll()`.
- **Mandate Drift:** An agent authorized for treasury management attempts to interact with unapproved high-risk protocols.

## The Solution: Restricted Agency

ERC-8232 shifts the security model from **"Trust the Agent"** to **"Constraint the Hand."**

### 1. Calldata Slicing

The ERC-8232 proxy implementation slices the first 4 bytes of every incoming payload.

```python
actual_selector: bytes4 = extract32(slice(call_data, 0, 4), 0, output_type=bytes4)
```

### 2. Bitmask Enforcement

Every action type bit is mapped to a specific function selector.

- **Bit 1 (Rebalance):** Mapped to `0xa9059cbb` (`transfer`) on a specific RWA token.
- **Bit 2 (Vote):** Mapped to `0xc9d27afe` (`vote`).

If an agent attempts to call a function not mapped to their active bits, the transaction reverts at the execution layer.

## Architecture

- **`SettledFactory.vy`:** Deploys individual, immutable proxies for users.
- **`SettledProxy.vy`:** The enforcement engine that holds assets and validates agent calldata.
- **`MCP Server`:** The bridge that allows AI agents to "cook" valid calldata and submit it to the proxy.

### Directory Structure

```
erc-8232/
├── contracts/           # Core ERC-8232 implementation
│   └── ERC_8232.vy
|   ├── 8232Factory.vy
|   └── Agency.vy
|
├── implementation/      # Registry and vault contracts
│   ├── registry/
│   │   └── ERC_8232.vy
│   └── vault/
│       ├── 8232Factory.vy
|       ├── proxy_spec.md
│       └── Agency.vy
├── tests/              # Test suite
├── scripts/            # Deployment and utility scripts
├── spec/               # Specification documents
└── ape-config.yaml     # Ape framework configuration
```

## Installation

### Prerequisites

- [Python](https://www.python.org/) 3.8 or higher
- [Vyper](https://docs.vyperlang.org/en/latest/installing-vyper.html)
- [Ape](https://docs.apeworx.io/) framework

### Setup

1. Clone the repository:
```bash
git clone https://github.com/neonmercenary/erc-8232.git
cd erc-8232
```

2. Create a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt // uv sync
```

## Quick Start (POC)

### Step 1: Deploy Proxy

```python
deploy_settled_proxy()  # On the Factory
```

### Step 2: Map Selector

```python
mapSelector(1, 0xa9059cbb)  # Lock Bit 1 to Transfer
```

### Step 3: Grant Permission

```python
setAgentPermission(agent_addr, rwa_addr, 2)
```

### Step 4: Execute

```python
performAgencyAction()  # Agent calls this
```

## Testing

Run the test suite:

```bash
ape test
```

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Security

This is experimental software. Use at your own risk. For security concerns, please reach out to the maintainers privately.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Related Links

- [ERC-8232 Specification](spec/erc-8232.md)
- [Proxy Specification](contracts/proxy_spec.md)
- [Vyper Documentation](https://docs.vyperlang.org)
- [Ape Framework](https://docs.apeworx.io/)

## Disclaimer

This is a proof of concept. Before using in production, conduct thorough security audits and testing.