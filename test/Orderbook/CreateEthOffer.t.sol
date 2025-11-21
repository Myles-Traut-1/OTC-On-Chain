// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestSetup} from "../TestSetup.t.sol";
import {Orderbook} from "../../src/contracts/Orderbook.sol";

contract CreateEthOfferTest is TestSetup {
    function setUp() public override {
        super.setUp();

        deal(maker, OFFER_AMOUNT);
    }
    /*//////////////////////////////////////////////////////////////
                            STATE UPDATES
    //////////////////////////////////////////////////////////////*/

    function test_CreateEthOffer_Success() public {
        uint256 initialMakerBalance = maker.balance;
        uint256 initialEscrowBalance = address(escrow).balance;

        assertEq(initialMakerBalance, OFFER_AMOUNT);
        assertEq(initialEscrowBalance, 0);

        (
            Orderbook.TokenAmount memory offer,
            Orderbook.Constraints memory constraints
        ) = _generateOfferAmountsAndConstraints(
                orderbook.ETH_ADDRESS(),
                OFFER_AMOUNT,
                MIN_FILL_AMOUNT,
                MAX_SLIPPAGE_BPS,
                validFrom,
                validUntil
            );

        bytes32 expectedOrderId = keccak256(
            abi.encode(
                maker,
                orderbook.nonce(),
                orderbook.ETH_ADDRESS(),
                OFFER_AMOUNT,
                address(requestedToken)
            )
        );

        vm.startPrank(maker);

        vm.expectEmit(true, true, true, true);
        emit Orderbook.OfferCreated(
            expectedOrderId,
            maker,
            offer,
            address(requestedToken),
            constraints
        );
        orderbook.createEthOffer{value: OFFER_AMOUNT}(
            offer,
            address(requestedToken),
            constraints
        );

        assertEq(maker.balance, initialMakerBalance - OFFER_AMOUNT);
        assertEq(address(escrow).balance, initialEscrowBalance + OFFER_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                            NEGATIVE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CreateEthOffer_Reverts_ZeroAddress() public {
        (
            Orderbook.TokenAmount memory offer,
            Orderbook.Constraints memory constraints
        ) = _generateOfferAmountsAndConstraints(
                orderbook.ETH_ADDRESS(),
                OFFER_AMOUNT,
                MIN_FILL_AMOUNT,
                MAX_SLIPPAGE_BPS,
                validFrom,
                validUntil
            );

        vm.startPrank(maker);

        vm.expectRevert(Orderbook.Orderbook__ZeroAddress.selector);
        orderbook.createEthOffer{value: OFFER_AMOUNT}(
            offer,
            address(0),
            constraints
        );

        vm.stopPrank();
    }

    function test_CreateEthOffer_Reverts_InvalidAmounts() public {
        (
            Orderbook.TokenAmount memory offer,
            Orderbook.Constraints memory constraints
        ) = _generateOfferAmountsAndConstraints(
                orderbook.ETH_ADDRESS(),
                0,
                MIN_FILL_AMOUNT,
                MAX_SLIPPAGE_BPS,
                validFrom,
                validUntil
            );

        vm.startPrank(maker);

        vm.expectRevert(Orderbook.Orderbook__InvalidTokenAmount.selector);
        orderbook.createEthOffer{value: 0}(
            offer,
            address(requestedToken),
            constraints
        );

        vm.stopPrank();
    }

    function test_CreateEthOffer_Reverts_InvalidConstraints() public {
        (
            Orderbook.TokenAmount memory offer,
            Orderbook.Constraints memory constraints
        ) = _generateOfferAmountsAndConstraints(
                orderbook.ETH_ADDRESS(),
                OFFER_AMOUNT,
                0,
                MAX_SLIPPAGE_BPS,
                validFrom,
                validUntil
            );

        vm.startPrank(maker);

        vm.expectRevert(Orderbook.Orderbook__InvalidConstraints.selector);
        orderbook.createEthOffer{value: OFFER_AMOUNT}(
            offer,
            address(requestedToken),
            constraints
        );
        vm.stopPrank();

        (offer, constraints) = _generateOfferAmountsAndConstraints(
            orderbook.ETH_ADDRESS(),
            OFFER_AMOUNT,
            MIN_FILL_AMOUNT,
            0,
            validFrom,
            validUntil
        );

        vm.expectRevert(Orderbook.Orderbook__InvalidConstraints.selector);
        orderbook.createEthOffer{value: OFFER_AMOUNT}(
            offer,
            address(requestedToken),
            constraints
        );
        vm.stopPrank();

        (offer, constraints) = _generateOfferAmountsAndConstraints(
            orderbook.ETH_ADDRESS(),
            OFFER_AMOUNT,
            MIN_FILL_AMOUNT,
            MAX_SLIPPAGE_BPS,
            block.timestamp - 1,
            validUntil
        );

        vm.expectRevert(Orderbook.Orderbook__InvalidConstraints.selector);
        orderbook.createEthOffer{value: OFFER_AMOUNT}(
            offer,
            address(requestedToken),
            constraints
        );
        vm.stopPrank();

        (offer, constraints) = _generateOfferAmountsAndConstraints(
            orderbook.ETH_ADDRESS(),
            OFFER_AMOUNT,
            MIN_FILL_AMOUNT,
            MAX_SLIPPAGE_BPS,
            validFrom,
            block.timestamp
        );

        vm.expectRevert(Orderbook.Orderbook__InvalidConstraints.selector);
        orderbook.createEthOffer{value: OFFER_AMOUNT}(
            offer,
            address(requestedToken),
            constraints
        );
        vm.stopPrank();
    }
}
