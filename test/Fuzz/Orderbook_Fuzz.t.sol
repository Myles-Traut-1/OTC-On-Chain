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
        uint128 _slippageBps
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

        _slippageBps = uint128(
            bound(_slippageBps, minSlippageBps, maxSlippageBps)
        ); // 0.5% - 2%

        vm.startPrank(maker);
        Orderbook.TokenAmount memory _offer = Orderbook.TokenAmount({
            token: address(offeredToken),
            amount: _offeredAmount
        });

        uint256 constraints = orderbook.encodeConstraints(
            _validFrom,
            _validUntil,
            _slippageBps
        );

        IERC20(address(offeredToken)).approve(
            address(orderbook),
            _offeredAmount
        );
        bytes32 offerId = orderbook.createTokenOffer(
            _offer,
            address(requestedToken),
            constraints
        );
        vm.stopPrank();

        (Orderbook.Offer memory offer, Orderbook.OfferStatus status) = orderbook
            .getOffer(offerId);

        assertEq(offer.maker, maker);
        assertEq(offer.offer.token, address(offeredToken));
        assertEq(offer.offer.amount, _offeredAmount);
        assertEq(offer.constraints, constraints);
        assertEq(offer.requestedToken, address(requestedToken));
        assert(status == Orderbook.OfferStatus.Open);

        (uint64 validFrom, uint64 validUntil, uint128 slippageBps) = orderbook
            .decodeConstraints(offer.constraints);
        assertEq(slippageBps, _slippageBps);
        assertEq(validFrom, _validFrom);
        assertEq(validUntil, _validUntil);
    }
}
