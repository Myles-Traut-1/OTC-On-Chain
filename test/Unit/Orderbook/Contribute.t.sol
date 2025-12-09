// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestSetup} from "../../TestSetup.t.sol";
import {Orderbook} from "../../../src/contracts/Orderbook.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ContributeTests is TestSetup {
    uint256 public constant CONTRIBUTE_AMOUNT = OFFER_AMOUNT / 2; // 0.5 ether

    bytes32 public tokenOfferId;
    bytes32 public ethOfferId;

    function setUp() public override {
        super.setUp();

        requestedToken.mint(taker1, CONTRIBUTE_AMOUNT);

        tokenOfferId = _createAndReturnOffer(
            address(offeredToken),
            address(requestedToken)
        );

        ethOfferId = _createAndReturnOffer(
            address(ETH),
            address(requestedToken)
        );
    }

    function test_ContributeTokenToTokenOffer_Success() public {
        uint256 escrowOfferedTokenBalanceBefore = offeredToken.balanceOf(
            address(escrow)
        );

        uint256 takerRequestedTokenBalanceBefore = requestedToken.balanceOf(
            taker1
        );
        uint256 takerOfferedTokenBalanceBefore = offeredToken.balanceOf(taker1);

        uint256 makerRequestedTokenBalanceBefore = requestedToken.balanceOf(
            maker
        );

        assertEq(escrowOfferedTokenBalanceBefore, OFFER_AMOUNT);

        assertEq(takerRequestedTokenBalanceBefore, CONTRIBUTE_AMOUNT);
        assertEq(takerOfferedTokenBalanceBefore, 0);

        assertEq(makerRequestedTokenBalanceBefore, 0);

        uint256 expectedAmountOut = settlementEngine.getAmountOut(
            address(offeredToken),
            address(requestedToken),
            CONTRIBUTE_AMOUNT,
            OFFER_AMOUNT
        );

        vm.startPrank(taker1);
        requestedToken.approve(address(orderbook), CONTRIBUTE_AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit Orderbook.OfferContributed(
            tokenOfferId,
            taker1,
            CONTRIBUTE_AMOUNT,
            expectedAmountOut
        );
        uint256 amountOut = orderbook.contribute(
            tokenOfferId,
            CONTRIBUTE_AMOUNT
        );
        vm.stopPrank();

        assertEq(
            offeredToken.balanceOf(address(escrow)),
            escrowOfferedTokenBalanceBefore - amountOut
        );
        assertEq(
            escrow.getTokenBalance(address(offeredToken)),
            escrowOfferedTokenBalanceBefore - amountOut
        );
        assertEq(
            requestedToken.balanceOf(taker1),
            takerRequestedTokenBalanceBefore - CONTRIBUTE_AMOUNT
        );
        assertEq(
            offeredToken.balanceOf(taker1),
            takerOfferedTokenBalanceBefore + amountOut
        );
        assertEq(
            requestedToken.balanceOf(maker),
            makerRequestedTokenBalanceBefore + CONTRIBUTE_AMOUNT
        );
    }

    function test_ContributeTokenToETHOffer_Success() public {
        uint256 escrowEthBalanceBefore = escrow.getTokenBalance(ETH);

        uint256 takerRequestedTokenBalanceBefore = requestedToken.balanceOf(
            taker1
        );
        uint256 takerEthBalanceBefore = taker1.balance;

        uint256 makerRequestedTokenBalanceBefore = requestedToken.balanceOf(
            maker
        );

        assertEq(escrowEthBalanceBefore, OFFER_AMOUNT);

        assertEq(takerRequestedTokenBalanceBefore, CONTRIBUTE_AMOUNT);
        assertEq(takerEthBalanceBefore, 0);

        assertEq(makerRequestedTokenBalanceBefore, 0);

        uint256 expectedAmountOut = settlementEngine.getAmountOut(
            address(ETH),
            address(requestedToken),
            CONTRIBUTE_AMOUNT,
            OFFER_AMOUNT
        );

        vm.startPrank(taker1);
        requestedToken.approve(address(orderbook), CONTRIBUTE_AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit Orderbook.OfferContributed(
            ethOfferId,
            taker1,
            CONTRIBUTE_AMOUNT,
            expectedAmountOut
        );
        uint256 amountOut = orderbook.contribute(ethOfferId, CONTRIBUTE_AMOUNT);
        vm.stopPrank();

        assertEq(
            escrow.getTokenBalance(address(ETH)),
            escrowEthBalanceBefore - amountOut
        );
        assertEq(
            requestedToken.balanceOf(taker1),
            takerRequestedTokenBalanceBefore - CONTRIBUTE_AMOUNT
        );
        assertEq(taker1.balance, takerEthBalanceBefore + amountOut);
        assertEq(
            requestedToken.balanceOf(maker),
            makerRequestedTokenBalanceBefore + CONTRIBUTE_AMOUNT
        );
    }

    function test_ContributeUpdatesState() public {
        (, , , , uint256 remainingAmountBefore) = orderbook.offers(
            tokenOfferId
        );
        Orderbook.OfferStatus statusBefore = orderbook.offerStatusById(
            tokenOfferId
        );
        assertEq(remainingAmountBefore, OFFER_AMOUNT);
        assert(statusBefore == Orderbook.OfferStatus.Open);

        vm.startPrank(taker1);
        requestedToken.approve(address(orderbook), CONTRIBUTE_AMOUNT);
        orderbook.contribute(tokenOfferId, CONTRIBUTE_AMOUNT);
        vm.stopPrank();

        (, , , , uint256 remainingAmountAfter) = orderbook.offers(tokenOfferId);
        assertEq(remainingAmountAfter, OFFER_AMOUNT - CONTRIBUTE_AMOUNT);

        Orderbook.OfferStatus statusAfter = orderbook.offerStatusById(
            tokenOfferId
        );
        assert(statusAfter == Orderbook.OfferStatus.InProgress);
    }

    /*//////////////////////////////////////////////////////////////
                             NEGATIVE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_contribute_RevertsOfferNotOpen() public {
        bytes32 invalidOfferId = bytes32("invalidOfferId");

        vm.startPrank(taker1);
        vm.expectRevert(Orderbook.Orderbook__OfferNotOpen.selector);
        orderbook.contribute(invalidOfferId, CONTRIBUTE_AMOUNT);
        vm.stopPrank();
    }

    function test_contribute_RevertsAmountZero() public {
        vm.startPrank(taker1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Orderbook.Orderbook__InvalidContribution.selector,
                0
            )
        );
        orderbook.contribute(tokenOfferId, 0);
        vm.stopPrank();
    }

    function test_contribute_RevertsBeforeValidFrom() public {
        bytes32 offerId = _createAndReturnOfferWithConstraints(
            address(offeredToken),
            address(requestedToken),
            OFFER_AMOUNT,
            MAX_SLIPPAGE_BPS,
            block.timestamp + 1 days,
            block.timestamp + 10 days
        );

        vm.startPrank(taker1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Orderbook.Orderbook__InvalidConstraints.selector,
                "OFFER_EXPIRED_OR_NOT_STARTED"
            )
        );
        orderbook.contribute(offerId, CONTRIBUTE_AMOUNT);
    }

    function test_contribute_RevertsAfterValidUntil() public {
        bytes32 offerId = _createAndReturnOfferWithConstraints(
            address(offeredToken),
            address(requestedToken),
            OFFER_AMOUNT,
            MAX_SLIPPAGE_BPS,
            block.timestamp,
            block.timestamp + 10 days
        );

        vm.warp(block.timestamp + 10 days + 1);

        vm.startPrank(taker1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Orderbook.Orderbook__InvalidConstraints.selector,
                "OFFER_EXPIRED_OR_NOT_STARTED"
            )
        );
        orderbook.contribute(offerId, CONTRIBUTE_AMOUNT);
    }
}
