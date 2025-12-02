// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestSetup} from "../TestSetup.t.sol";
import {Orderbook} from "../../src/contracts/Orderbook.sol";

contract UpdateConstraintsTest is TestSetup {
    uint256 public newMaxSlippageBps = MAX_SLIPPAGE_BPS / 2;
    uint256 public newValidFrom = validFrom + 100;
    uint256 public newValidUntil = validUntil + 100;

    /*//////////////////////////////////////////////////////////////
                            STATE UPDATES
    //////////////////////////////////////////////////////////////*/

    function test_UpdateConstraints() public {
        bytes32 offerId = _createAndReturnOffer(
            address(offeredToken),
            address(requestedToken)
        );

        (, , , Orderbook.Constraints memory constraints_, ) = orderbook.offers(
            offerId
        );

        assertEq(constraints_.maxSlippageBps, MAX_SLIPPAGE_BPS);
        assertEq(constraints_.validFrom, validFrom);
        assertEq(constraints_.validUntil, validUntil);

        (
            ,
            Orderbook.Constraints memory newConstraints
        ) = _generateOfferAmountsAndConstraints(
                address(offeredToken),
                OFFER_AMOUNT,
                newMaxSlippageBps,
                newValidFrom,
                newValidUntil
            );

        vm.startPrank(maker);

        vm.expectEmit(true, true, true, true);
        emit Orderbook.OfferConstraintsUpdated(offerId, maker, newConstraints);

        orderbook.updateConstraints(offerId, newConstraints);
        vm.stopPrank();

        (
            address _maker,
            Orderbook.TokenAmount memory tokenAmounts,
            address _requestedToken,
            Orderbook.Constraints memory updatedConstraints,
            uint256 remainingAmount
        ) = orderbook.offers(offerId);

        // Assert Constraints have updated. Other values remain the same.
        assertEq(updatedConstraints.maxSlippageBps, newMaxSlippageBps);
        assertEq(updatedConstraints.validFrom, newValidFrom);
        assertEq(updatedConstraints.validUntil, newValidUntil);

        assertEq(tokenAmounts.token, address(offeredToken));
        assertEq(tokenAmounts.amount, OFFER_AMOUNT);
        assertEq(remainingAmount, OFFER_AMOUNT);
        assertEq(_requestedToken, address(requestedToken));
        assertEq(_maker, maker);
    }

    /*//////////////////////////////////////////////////////////////
                                 NEGATIVE TESTS
        //////////////////////////////////////////////////////////////*/

    function test_UpdateConstraints_Reverts_NotOfferCreator() public {
        address invalidCaller = makeAddr("invalidCaller");
        bytes32 offerId = _createAndReturnOffer(
            address(offeredToken),
            address(requestedToken)
        );

        (
            ,
            Orderbook.Constraints memory newConstraints
        ) = _generateOfferAmountsAndConstraints(
                address(offeredToken),
                OFFER_AMOUNT,
                newMaxSlippageBps,
                newValidFrom,
                newValidUntil
            );

        vm.startPrank(invalidCaller);

        vm.expectRevert(Orderbook.Orderbook__NotOfferCreator.selector);
        orderbook.updateConstraints(offerId, newConstraints);
    }

    function test_UpdateConstraints_RevertsIfStatusNotOpen() public {
        bytes32 offerId = _createAndReturnOffer(
            address(offeredToken),
            address(requestedToken)
        );

        // Simulate that the offer is in progress
        orderbook.contribute(offerId);

        (
            ,
            Orderbook.Constraints memory newConstraints
        ) = _generateOfferAmountsAndConstraints(
                address(offeredToken),
                OFFER_AMOUNT,
                newMaxSlippageBps,
                newValidFrom,
                newValidUntil
            );

        vm.startPrank(maker);

        vm.expectRevert(Orderbook.Orderbook__OfferNotOpen.selector);
        orderbook.updateConstraints(offerId, newConstraints);
        vm.stopPrank();
    }

    function test_UpdateConstraints_RevertsOnInvalidConstraints() public {
        bytes32 offerId = _createAndReturnOffer(
            address(offeredToken),
            address(requestedToken)
        );

        vm.startPrank(maker);

        vm.expectRevert(Orderbook.Orderbook__InvalidConstraints.selector);
        orderbook.updateConstraints(
            offerId,
            Orderbook.Constraints({
                maxSlippageBps: 0,
                validFrom: uint64(newValidFrom),
                validUntil: uint64(newValidUntil)
            })
        );

        vm.expectRevert(Orderbook.Orderbook__InvalidConstraints.selector);
        orderbook.updateConstraints(
            offerId,
            Orderbook.Constraints({
                maxSlippageBps: uint128(newMaxSlippageBps),
                validFrom: 0,
                validUntil: uint64(newValidUntil)
            })
        );

        vm.expectRevert(Orderbook.Orderbook__InvalidConstraints.selector);
        orderbook.updateConstraints(
            offerId,
            Orderbook.Constraints({
                maxSlippageBps: uint128(newMaxSlippageBps),
                validFrom: uint64(newValidFrom),
                validUntil: uint64(newValidFrom)
            })
        );
    }
}
