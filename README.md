# OTC Exchange Architecture Overview

## Overview

This application aims to build a set of smart contracts that make up an On-Chain OTC Desk. It is understood that OTC desks require KYC. The implementation of that is out of scope of this project.

## Core Modules

Phase 1:

- `OrderBook` Makers post a bond to deter spam, and takers submit contributions for atomic fills.
- `Escrow` custodializes assets during order execution.
- `Settlement Engine` is responsible for amount calculations

Phase 2:
- Smart Contract Wallet integration via EIP-7702 with Paymaster for free contributions

## Order Lifecycle

1. Maker registers an offer defining a token pair, total offer amount and settlement window.
2. Funds move into escrow for immediate settlement.
3. Takers contribute requested tokens to offers until fulfilment
5. Contributions and Creations emit events for accounting and tracking via subgraph.

## Governance & Upgradeability

- Core modules run behind a  UUPS proxy pattern with timelocked governance.
- A governance DAO should manage parameter updates, whitelist and blacklist entries.
- A circuit breaker allows emergency pause via multisig authorization followed by DAO ratification.