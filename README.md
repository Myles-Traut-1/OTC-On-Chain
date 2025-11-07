# OTC Exchange Architecture Overview

## Overview

This application aims to build a set of smart contracts that make up an On-Chain OTC Desk. It is understood that OTC desks require KYC. The implementation of that is out of scope of this project.

## Core Modules

Phase 1:

- `OrderBook` stores EIP-712 signed orders. Makers post a bond to deter spam, and takers submit signatures for atomic fills.
- `Escrow` custodializes assets during order execution. It supports ERC-20, ERC-721, and ERC-1155 tokens through shared interface adapters.
- `Settlement` performs atomic trade settlement, enforcing escrow transfers, slippage bounds, and optional partial fills.

Phase 2:
- Pricing oracles (e.g., Chainlink, Pyth) can validate final prices for fully on-chain matching when required.

## Order Lifecycle

1. Maker registers an instrument template defining token pair, settlement window, and collateral requirements.
2. Maker signs an off-chain order payload that includes price, size, expiration, allowlist or denylist preferences.
3. Taker submits the signed order on-chain; contracts validate signatures, parameters, and compliance hooks.
4. Funds move into escrow for immediate settlement.
5. Settlement emits events for accounting push order identifiers to a subgraph.

## Collateral & Risk Controls

- Both parties post margin with configurable haircuts, retained in escrow until settlement completes.
- Liquidation triggers when collateral value falls below maintenance ratios, using oracle price feeds.
- Tokenized real-world assets are supported through whitelist.

## Governance & Upgradeability

- Core modules run behind a  UUPS proxy pattern with timelocked governance.
- A governance DAO should manage parameter updates, whitelist and blacklist entries, and fee schedules.
- A circuit breaker allows emergency pause via multisig authorization followed by DAO ratification.

## Fees & Incentives

- Protocol settlement fees route to the treasury.
- Maker bonding fees refund post-expiration for unfilled orders and penalize cancellations after taker commitment.
- A staking module rewards liquidity providers with rebates and governance participation rights.

## Deployment & Operations

- Deploy core contracts on Ethereum L1 for security, extending to L2 rollups (Arbitrum, Base) through shared governance when lower fees are needed.
- Use Chainlink CCIP or LayerZero for cross-chain settlement while keeping escrow logic anchored on the primary chain.
- Monitor activity with OpenZeppelin Defender, Forta, and custom alerts for abnormal fills or collateral drawdowns.