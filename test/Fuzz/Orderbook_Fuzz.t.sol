// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestSetup} from "../TestSetup.t.sol";
import {Orderbook} from "../../src/contracts/Orderbook.sol";
import {Escrow} from "../../src/contracts/Escrow.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract OrderbookFuzzTest is TestSetup {
    function test_Fuzz_createTokenOffer(
        uint256 _offeredAmount,
        uint64 _validFrom,
        uint64 _validUntil,
        uint128 _maxSlippageBps
    ) public {
        uint256 minOfferAmount = orderbook.MIN_OFFER_AMOUNT();
        uint256 maxSlippageBps = orderbook.MAX_SLIPPAGE();
        uint256 minSlippageBps = orderbook.MIN_SLIPPAGE();

        _offeredAmount = bound(
            _offeredAmount,
            minOfferAmount,
            INITIAL_MAKER_BALANCE
        );

        _validFrom = uint64(
            bound(
                _validFrom,
                uint64(block.timestamp),
                uint64(block.timestamp + 7 days)
            )
        );

        _validUntil = uint64(
            bound(_validUntil, _validFrom + 1, _validFrom + 30 days)
        );

        _maxSlippageBps = uint128(
            bound(_maxSlippageBps, minSlippageBps, maxSlippageBps)
        ); // 0.5% - 2%
    }
}
