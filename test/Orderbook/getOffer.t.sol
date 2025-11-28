// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestSetup} from "../TestSetup.t.sol";
import {Orderbook} from "../../src/contracts/Orderbook.sol";

contract Orderbook_GetOffer is TestSetup {
    function test_GetOfferReturnsOfferAndStatus() public {
        bytes32 offerId = _createAndReturnOffer(address(offeredToken));

        (Orderbook.Offer memory offer, Orderbook.OfferStatus status) = orderbook
            .getOffer(offerId);

        assertEq(offer.maker, maker);
        assertEq(offer.offer.token, address(offeredToken));
        assertEq(offer.offer.amount, OFFER_AMOUNT);
        assertEq(offer.requestedToken, address(requestedToken));
        assertEq(offer.constraints.minFillAmount, MIN_FILL_AMOUNT);
        assertEq(offer.constraints.maxSlippageBps, MAX_SLIPPAGE_BPS);
        assertEq(offer.constraints.validFrom, uint64(validFrom));
        assertEq(offer.constraints.validUntil, uint64(validUntil));
        assert(status == Orderbook.OfferStatus.Open);

        bytes32 etherOfferId = _createAndReturnOffer(
            address(orderbook.ETH_ADDRESS())
        );

        (offer, status) = orderbook.getOffer(etherOfferId);

        assertEq(offer.maker, maker);
        assertEq(offer.offer.token, address(orderbook.ETH_ADDRESS()));
        assertEq(offer.offer.amount, OFFER_AMOUNT);
        assertEq(offer.requestedToken, address(requestedToken));
        assertEq(offer.constraints.minFillAmount, MIN_FILL_AMOUNT);
        assertEq(offer.constraints.maxSlippageBps, MAX_SLIPPAGE_BPS);
        assertEq(offer.constraints.validFrom, uint64(validFrom));
        assertEq(offer.constraints.validUntil, uint64(validUntil));
        assert(status == Orderbook.OfferStatus.Open);
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
