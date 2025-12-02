// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestSetup} from "../TestSetup.t.sol";
import {Orderbook} from "../../src/contracts/Orderbook.sol";

contract CreateTokenOfferTest is TestSetup {
    /*//////////////////////////////////////////////////////////////
                            STATE UPDATES
    //////////////////////////////////////////////////////////////*/

    function test_CreateTokenOffer_Success() public {
        uint256 initialMakerBalance = offeredToken.balanceOf(maker);
        uint256 initialEscrowBalance = offeredToken.balanceOf(address(escrow));

        assertEq(initialMakerBalance, INITIAL_MAKER_BALANCE);
        assertEq(initialEscrowBalance, 0);

        (
            Orderbook.TokenAmount memory offer,
            uint256 constraints
        ) = _generateOfferAmountsAndConstraints(
                address(offeredToken),
                OFFER_AMOUNT,
                MAX_SLIPPAGE_BPS,
                validFrom,
                validUntil
            );

        bytes32 expectedOfferId = keccak256(
            abi.encode(
                maker,
                orderbook.nonce(),
                address(offeredToken),
                OFFER_AMOUNT,
                address(requestedToken)
            )
        );

        vm.startPrank(maker);
        offeredToken.approve(address(orderbook), OFFER_AMOUNT);

        vm.expectEmit(true, true, true, true);
        emit Orderbook.OfferStatusUpdated(
            expectedOfferId,
            Orderbook.OfferStatus.Open
        );
        vm.expectEmit(true, true, true, true);
        emit Orderbook.OfferCreated(
            expectedOfferId,
            maker,
            offer,
            address(requestedToken),
            constraints
        );
        bytes32 offerId = orderbook.createTokenOffer(
            offer,
            address(requestedToken),
            constraints
        );
        vm.stopPrank();

        assertEq(
            offeredToken.balanceOf(maker),
            INITIAL_MAKER_BALANCE - OFFER_AMOUNT
        );
        assertEq(offeredToken.balanceOf(address(escrow)), OFFER_AMOUNT);

        (
            address maker_,
            Orderbook.TokenAmount memory offer_,
            address requestedToken_,
            uint256 constraints_,
            uint256 remainingAmount
        ) = orderbook.offers(offerId);

        assertEq(orderbook.nonce(), 2);

        assertEq(maker_, maker);
        assertEq(offer_.token, address(offeredToken));
        assertEq(offer_.amount, OFFER_AMOUNT);
        assertEq(requestedToken_, address(requestedToken));
        assertEq(constraints_, constraints);
        assertEq(remainingAmount, OFFER_AMOUNT);

        (
            uint64 validFrom_,
            uint64 validUntil_,
            uint128 maxSlippageBps_
        ) = orderbook.decodeConstraints(constraints_);

        assertEq(maxSlippageBps_, uint128(MAX_SLIPPAGE_BPS));
        assertEq(validFrom_, uint64(validFrom));
        assertEq(validUntil_, uint64(validUntil));

        Orderbook.OfferStatus offerStatus = orderbook.offerStatusById(offerId);

        assert(offerStatus == Orderbook.OfferStatus.Open);
    }

    /*//////////////////////////////////////////////////////////////
                            NEGATIVE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CreateTokenOffer_Reverts_ZeroAddress() public {
        (
            Orderbook.TokenAmount memory offer,
            uint256 constraints
        ) = _generateOfferAmountsAndConstraints(
                address(offeredToken),
                OFFER_AMOUNT,
                MAX_SLIPPAGE_BPS,
                validFrom,
                validUntil
            );

        vm.startPrank(maker);
        offeredToken.approve(address(orderbook), OFFER_AMOUNT);

        vm.expectRevert(Orderbook.Orderbook__ZeroAddress.selector);
        orderbook.createTokenOffer(offer, address(0), constraints);

        (offer, constraints) = _generateOfferAmountsAndConstraints(
            address(0),
            OFFER_AMOUNT,
            MAX_SLIPPAGE_BPS,
            validFrom,
            validUntil
        );

        vm.expectRevert(Orderbook.Orderbook__ZeroAddress.selector);
        orderbook.createTokenOffer(offer, address(requestedToken), constraints);
    }

    function test_CreateTokenOffer_Reverts_InvalidAmounts() public {
        (
            Orderbook.TokenAmount memory offer,
            uint256 constraints
        ) = _generateOfferAmountsAndConstraints(
                address(offeredToken),
                orderbook.MIN_OFFER_AMOUNT() - 1,
                MAX_SLIPPAGE_BPS,
                validFrom,
                validUntil
            );

        vm.startPrank(maker);
        offeredToken.approve(address(orderbook), OFFER_AMOUNT);

        vm.expectRevert(Orderbook.Orderbook__InvalidTokenAmount.selector);
        orderbook.createTokenOffer(offer, address(requestedToken), constraints);
        vm.stopPrank();
    }

    function test_CreateTokenOffer_Reverts_InvalidConstraints() public {
        vm.startPrank(maker);

        (
            Orderbook.TokenAmount memory offer,
            uint256 constraints
        ) = _generateOfferAmountsAndConstraints(
                address(offeredToken),
                OFFER_AMOUNT,
                0,
                validFrom,
                validUntil
            );

        vm.expectRevert(Orderbook.Orderbook__InvalidConstraints.selector);
        orderbook.createTokenOffer(offer, address(requestedToken), constraints);
        vm.stopPrank();

        (offer, constraints) = _generateOfferAmountsAndConstraints(
            address(offeredToken),
            OFFER_AMOUNT,
            MAX_SLIPPAGE_BPS,
            block.timestamp - 1,
            validUntil
        );

        vm.expectRevert(Orderbook.Orderbook__InvalidConstraints.selector);
        orderbook.createTokenOffer(offer, address(requestedToken), constraints);
        vm.stopPrank();

        (offer, constraints) = _generateOfferAmountsAndConstraints(
            address(offeredToken),
            OFFER_AMOUNT,
            MAX_SLIPPAGE_BPS,
            validFrom,
            block.timestamp
        );

        vm.expectRevert(Orderbook.Orderbook__InvalidConstraints.selector);
        orderbook.createTokenOffer(offer, address(requestedToken), constraints);
        vm.stopPrank();
    }
}
