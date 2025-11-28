// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestSetup} from "../TestSetup.t.sol";
import {Orderbook} from "../../src/contracts/Orderbook.sol";
import {Escrow} from "../../src/contracts/Escrow.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CancelOfferTest is TestSetup {
    function setUp() public override {
        super.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                            STATE UPDATES
    //////////////////////////////////////////////////////////////*/

    function test_CancelOfferWithToken_Success() public {
        (bytes32 offerId) = _createOffer(address(offeredToken));

        vm.startPrank(maker);

        uint256 escrowBalanceBefore = offeredToken.balanceOf(address(escrow));
        uint256 makerBalanceBefore = offeredToken.balanceOf(maker);
        assertEq(escrowBalanceBefore, OFFER_AMOUNT);
        assertEq(makerBalanceBefore, INITIAL_MAKER_BALANCE - OFFER_AMOUNT);

        (, , , , , uint256 remainingAmount) = orderbook.orders(offerId);
        assertEq(remainingAmount, OFFER_AMOUNT);

        vm.expectEmit(true, true, true, true);
        emit Orderbook.OfferCancelled(offerId, maker);
        orderbook.cancelOffer(offerId);
        vm.stopPrank();

        uint256 escrowBalanceAfter = offeredToken.balanceOf(address(escrow));
        uint256 makerBalanceAfter = offeredToken.balanceOf(maker);

        assertEq(escrowBalanceAfter, 0);
        assertEq(makerBalanceAfter, INITIAL_MAKER_BALANCE);

        Orderbook.OrderStatus orderStatus = orderbook.orderStatusById(offerId);
        assert(orderStatus == Orderbook.OrderStatus.Cancelled);

        (, , , , , remainingAmount) = orderbook.orders(offerId);
        assertEq(remainingAmount, 0);
    }

    function test_CancelOfferWithEth_Success() public {
        (bytes32 offerId) = _createOffer(orderbook.ETH_ADDRESS());

        vm.startPrank(maker);

        uint256 escrowBalanceBefore = address(escrow).balance;
        uint256 makerBalanceBefore = maker.balance;
        assertEq(escrowBalanceBefore, OFFER_AMOUNT);
        assertEq(makerBalanceBefore, INITIAL_MAKER_BALANCE - OFFER_AMOUNT);

        (, , , , , uint256 remainingAmount) = orderbook.orders(offerId);
        assertEq(remainingAmount, OFFER_AMOUNT);

        vm.expectEmit(true, true, true, true);
        emit Orderbook.OfferCancelled(offerId, maker);
        orderbook.cancelOffer(offerId);
        vm.stopPrank();

        uint256 escrowBalanceAfter = address(escrow).balance;
        uint256 makerBalanceAfter = maker.balance;

        assertEq(escrowBalanceAfter, 0);
        assertEq(makerBalanceAfter, INITIAL_MAKER_BALANCE);

        Orderbook.OrderStatus orderStatus = orderbook.orderStatusById(offerId);
        assert(orderStatus == Orderbook.OrderStatus.Cancelled);

        (, , , , , remainingAmount) = orderbook.orders(offerId);
        assertEq(remainingAmount, 0);
    }

    /*//////////////////////////////////////////////////////////////
                             NEGATIVE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CancelOffer_Reverts_NotCreator() public {
        (bytes32 offerId) = _createOffer(address(offeredToken));

        vm.startPrank(taker1);
        vm.expectRevert(Orderbook.Orderbook__NotOfferCreator.selector);
        orderbook.cancelOffer(offerId);
        vm.stopPrank();

        bytes32 invalidId = keccak256(abi.encodePacked("invalid"));
        vm.startPrank(maker);
        vm.expectRevert(Orderbook.Orderbook__NotOfferCreator.selector);
        orderbook.cancelOffer(invalidId);
        vm.stopPrank();
    }

    function test_CancelOffer_Reverts_NotOpen() public {
        (bytes32 offerId) = _createOffer(orderbook.ETH_ADDRESS());

        vm.startPrank(maker);
        orderbook.cancelOffer(offerId);
        vm.stopPrank();

        vm.startPrank(maker);
        vm.expectRevert(Orderbook.Orderbook__OrderNotOpen.selector);
        orderbook.cancelOffer(offerId);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _createOffer(address _token) internal returns (bytes32 offerId) {
        (
            Orderbook.TokenAmount memory offer,
            Orderbook.Constraints memory constraints
        ) = _generateOfferAmountsAndConstraints(
                _token,
                OFFER_AMOUNT,
                MIN_FILL_AMOUNT,
                MAX_SLIPPAGE_BPS,
                validFrom,
                validUntil
            );

        vm.startPrank(maker);
        if (_token == orderbook.ETH_ADDRESS()) {
            deal(maker, INITIAL_MAKER_BALANCE);
            offerId = orderbook.createEthOffer{value: OFFER_AMOUNT}(
                offer,
                address(requestedToken),
                constraints
            );
        } else {
            IERC20(_token).approve(address(orderbook), OFFER_AMOUNT);
            offerId = orderbook.createTokenOffer(
                offer,
                address(requestedToken),
                constraints
            );
        }
        vm.stopPrank();
    }
}
