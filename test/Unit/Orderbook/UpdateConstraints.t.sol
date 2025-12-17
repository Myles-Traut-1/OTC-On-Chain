// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestSetup} from "../../TestSetup.t.sol";
import {Orderbook} from "../../../src/contracts/Orderbook.sol";

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

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

        (, , , uint256 constraints_, ) = orderbook.offers(offerId);

        (
            uint64 validFrom,
            uint64 validUntil,
            uint128 maxSlippageBps
        ) = orderbook.decodeConstraints(constraints_);

        assertEq(maxSlippageBps, MAX_SLIPPAGE_BPS);
        assertEq(validFrom, validFrom);
        assertEq(validUntil, validUntil);

        (, uint256 newConstraints) = _generateOfferAmountsAndConstraints(
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
            uint256 updatedConstraints,
            uint256 remainingAmount
        ) = orderbook.offers(offerId);

        (
            uint64 updatedValidFrom,
            uint64 updatedValidUntil,
            uint128 updatedMaxSlippageBps
        ) = orderbook.decodeConstraints(updatedConstraints);

        // Assert Constraints have updated. Other values remain the same.
        assertEq(updatedMaxSlippageBps, newMaxSlippageBps);
        assertEq(updatedValidFrom, newValidFrom);
        assertEq(updatedValidUntil, newValidUntil);

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

        (, uint256 newConstraints) = _generateOfferAmountsAndConstraints(
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
        uint256 contributedAmount = OFFER_AMOUNT / 2;

        requestedToken.mint(taker1, contributedAmount);
        requestedToken.approve(address(orderbook), contributedAmount);

        bytes32 offerId = _createAndReturnOffer(
            address(offeredToken),
            address(requestedToken)
        );

        // Simulate that the offer is in progress
        vm.startPrank(taker1);
        requestedToken.approve(address(orderbook), contributedAmount);
        orderbook.contribute(offerId, contributedAmount, tokenQuote);
        vm.stopPrank();

        (, uint256 newConstraints) = _generateOfferAmountsAndConstraints(
            address(offeredToken),
            OFFER_AMOUNT,
            newMaxSlippageBps,
            newValidFrom,
            newValidUntil
        );

        vm.startPrank(maker);

        vm.expectRevert(Orderbook.Orderbook__OfferNotOpenOrInProgress.selector);
        orderbook.updateConstraints(offerId, newConstraints);
        vm.stopPrank();
    }

    function test_UpdateConstraints_RevertsOnInvalidConstraints() public {
        bytes32 offerId = _createAndReturnOffer(
            address(offeredToken),
            address(requestedToken)
        );

        vm.startPrank(maker);

        uint256 invalidConstraints = orderbook.encodeConstraints(
            0,
            uint64(newValidUntil),
            uint128(newMaxSlippageBps)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                Orderbook.Orderbook__InvalidConstraints.selector,
                "VALID_FROM"
            )
        );
        orderbook.updateConstraints(offerId, invalidConstraints);

        invalidConstraints = orderbook.encodeConstraints(
            uint64(newValidFrom),
            uint64(newValidFrom),
            uint128(newMaxSlippageBps)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                Orderbook.Orderbook__InvalidConstraints.selector,
                "VALID_UNTIL"
            )
        );
        orderbook.updateConstraints(offerId, invalidConstraints);
    }

    function test_UpdateConstraintsRevertsWhenPaused() public {
        bytes32 offerId = _createAndReturnOffer(
            address(offeredToken),
            address(requestedToken)
        );

        (, uint256 newConstraints) = _generateOfferAmountsAndConstraints(
            address(offeredToken),
            OFFER_AMOUNT,
            newMaxSlippageBps,
            newValidFrom,
            newValidUntil
        );

        vm.prank(owner);
        orderbook.pause();

        vm.startPrank(maker);

        vm.expectRevert(
            abi.encodeWithSelector(Pausable.EnforcedPause.selector)
        );
        orderbook.updateConstraints(offerId, newConstraints);
    }
}
