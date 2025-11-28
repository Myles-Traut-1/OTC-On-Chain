// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestSetup} from "../TestSetup.t.sol";
import {Orderbook} from "../../src/contracts/Orderbook.sol";

contract Orderbook_GetOffer is TestSetup {
    function test_GetOfferReturnsOderAndStatus() public {
        bytes32 orderId = _createAndReturnOffer(address(offeredToken));

        (Orderbook.Order memory order, Orderbook.OrderStatus status) = orderbook
            .getOffer(orderId);

        assertEq(order.orderId, orderId);
        assertEq(order.maker, maker);
        assertEq(order.offer.token, address(offeredToken));
        assertEq(order.offer.amount, OFFER_AMOUNT);
        assertEq(order.requestedToken, address(requestedToken));
        assertEq(order.constraints.minFillAmount, MIN_FILL_AMOUNT);
        assertEq(order.constraints.maxSlippageBps, MAX_SLIPPAGE_BPS);
        assertEq(order.constraints.validFrom, uint64(validFrom));
        assertEq(order.constraints.validUntil, uint64(validUntil));
        assert(status == Orderbook.OrderStatus.Open);

        bytes32 etherOrderId = _createAndReturnOffer(
            address(orderbook.ETH_ADDRESS())
        );

        (order, status) = orderbook.getOffer(etherOrderId);

        assertEq(order.orderId, etherOrderId);
        assertEq(order.maker, maker);
        assertEq(order.offer.token, address(orderbook.ETH_ADDRESS()));
        assertEq(order.offer.amount, OFFER_AMOUNT);
        assertEq(order.requestedToken, address(requestedToken));
        assertEq(order.constraints.minFillAmount, MIN_FILL_AMOUNT);
        assertEq(order.constraints.maxSlippageBps, MAX_SLIPPAGE_BPS);
        assertEq(order.constraints.validFrom, uint64(validFrom));
        assertEq(order.constraints.validUntil, uint64(validUntil));
        assert(status == Orderbook.OrderStatus.Open);
    }

    /*//////////////////////////////////////////////////////////////
                             NEGATIVE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_InvalidOrderId() public {
        bytes32 invalidOrderId = keccak256(abi.encode("invalid order id"));

        vm.expectRevert(Orderbook.Orderbook__InvalidOrderId.selector);
        orderbook.getOffer(invalidOrderId);
    }
}
