// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestSetup} from "../TestSetup.t.sol";
import {Orderbook} from "../../src/contracts/Orderbook.sol";

import {console} from "forge-std/console.sol";

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
        assertEq(offer.constraints.maxSlippageBps, MAX_SLIPPAGE_BPS);
        assertEq(offer.constraints.validFrom, uint64(validFrom));
        assertEq(offer.constraints.validUntil, uint64(validUntil));
        assert(status == Orderbook.OfferStatus.Open);

        bytes32 etherOfferId = _createAndReturnOffer(
            address(orderbook.ETH_ADDRESS()),
            address(requestedToken)
        );

        (offer, status) = orderbook.getOffer(etherOfferId);

        assertEq(offer.maker, maker);
        assertEq(offer.offer.token, address(orderbook.ETH_ADDRESS()));
        assertEq(offer.offer.amount, OFFER_AMOUNT);
        assertEq(offer.requestedToken, address(requestedToken));
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

    function test_pack() public {
        uint256 packed = orderbook.encodeConstraints(
            uint64(validFrom),
            uint64(validUntil),
            uint128(MAX_SLIPPAGE_BPS)
        );

        console.logUint(packed);

        (
            uint64 _validFromDecoded,
            uint64 _validUntilDecoded,
            uint128 _maxSlippageBpsDecoded
        ) = orderbook.decodeConstraints(packed);
        assertEq(_validFromDecoded, uint64(validFrom));
        assertEq(_validUntilDecoded, uint64(validUntil));
        assertEq(_maxSlippageBpsDecoded, uint128(MAX_SLIPPAGE_BPS));
    }
}
