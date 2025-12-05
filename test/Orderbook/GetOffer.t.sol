// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestSetup} from "../TestSetup.t.sol";
import {Orderbook} from "../../src/contracts/Orderbook.sol";

contract Orderbook_GetOffer is TestSetup {
    function test_GetOfferReturnsOfferAndStatus() public {
        bytes32 offerId = _createAndReturnOffer(
            address(offeredToken),
            address(requestedToken)
        );

        (Orderbook.Offer memory offer, Orderbook.OfferStatus status) = orderbook
            .getOffer(offerId);

        assertEq(offer.maker, maker);
        assertEq(offer.offer.token, address(offeredToken));
        assertEq(offer.offer.amount, OFFER_AMOUNT);
        assertEq(offer.requestedToken, address(requestedToken));
        assert(status == Orderbook.OfferStatus.Open);

        (
            uint64 validFrom,
            uint64 validUntil,
            uint128 maxSlippageBps
        ) = orderbook.decodeConstraints(offer.constraints);

        assertEq(maxSlippageBps, MAX_SLIPPAGE_BPS);
        assertEq(validFrom, uint64(validFrom));
        assertEq(validUntil, uint64(validUntil));

        bytes32 etherOfferId = _createAndReturnOffer(
            address(ETH),
            address(requestedToken)
        );

        (offer, status) = orderbook.getOffer(etherOfferId);

        assertEq(offer.maker, maker);
        assertEq(offer.offer.token, address(ETH));
        assertEq(offer.offer.amount, OFFER_AMOUNT);
        assertEq(offer.requestedToken, address(requestedToken));
        assert(status == Orderbook.OfferStatus.Open);

        (validFrom, validUntil, maxSlippageBps) = orderbook.decodeConstraints(
            offer.constraints
        );
        assertEq(maxSlippageBps, MAX_SLIPPAGE_BPS);
        assertEq(validFrom, uint64(validFrom));
        assertEq(validUntil, uint64(validUntil));
    }

    /*//////////////////////////////////////////////////////////////
                             NEGATIVE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_InvalidOfferId() public {
        bytes32 invalidOfferId = keccak256(abi.encode("invalid offer id"));

        vm.expectRevert(Orderbook.Orderbook__InvalidOfferId.selector);
        orderbook.getOffer(invalidOfferId);
    }
}
