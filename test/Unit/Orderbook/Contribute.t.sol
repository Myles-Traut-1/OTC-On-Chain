// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestSetup} from "../../TestSetup.t.sol";
import {Orderbook} from "../../../src/contracts/Orderbook.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract ContributeTests is TestSetup {
    bytes32 public tokenOfferId;
    bytes32 public ethOfferId;
    bytes32 public ethToTokenOfferId;

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
            CONTRIBUTE_AMOUNT
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
            CONTRIBUTE_AMOUNT,
            tokenQuote
        );
        vm.stopPrank();

        assertEq(amountOut, 2.5 ether);

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
            CONTRIBUTE_AMOUNT
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
        uint256 amountOut = orderbook.contribute(
            ethOfferId,
            CONTRIBUTE_AMOUNT,
            ethQuote
        );

        // 5e18 * 1e18 / 1000e18 = 5e15
        assertEq(amountOut, 5e15);
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

    function test_contribute_EthToToken() public {
        uint256 makerEthBalanceBefore = maker.balance;
        uint256 takerOfferedTokenBalanceBefore = offeredToken.balanceOf(taker1);

        ethToTokenOfferId = _createAndReturnOffer(address(offeredToken), ETH);

        uint256 quote = settlementEngine.getAmountOut(
            address(offeredToken),
            ETH,
            5e15
        );

        vm.startPrank(taker1);
        vm.deal(taker1, 5e15);

        // 5e15 * 2000e18 = 10e18
        uint256 amountOut = orderbook.contribute{value: 5e15}(
            ethToTokenOfferId,
            5e15,
            quote
        );
        vm.stopPrank();

        assertEq(amountOut, 10e18);

        uint256 makerEthBalanceAfter = maker.balance;
        uint256 takerOfferedTokenBalanceAfter = offeredToken.balanceOf(taker1);

        assertEq(makerEthBalanceAfter, makerEthBalanceBefore + 5e15);
        assertEq(
            takerOfferedTokenBalanceAfter,
            takerOfferedTokenBalanceBefore + amountOut
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
        uint256 amountOut = orderbook.contribute(
            tokenOfferId,
            CONTRIBUTE_AMOUNT,
            tokenQuote
        );
        vm.stopPrank();

        (, , , , uint256 remainingAmountAfter) = orderbook.offers(tokenOfferId);
        assertEq(remainingAmountAfter, OFFER_AMOUNT - amountOut);

        Orderbook.OfferStatus statusAfter = orderbook.offerStatusById(
            tokenOfferId
        );
        assert(statusAfter == Orderbook.OfferStatus.InProgress);
    }

    function test_contribute_MultipleContributions() public {
        (, , , , uint256 remainingAmountBefore) = orderbook.offers(
            tokenOfferId
        );
        assertEq(remainingAmountBefore, OFFER_AMOUNT);

        vm.startPrank(taker1);
        requestedToken.approve(address(orderbook), CONTRIBUTE_AMOUNT);
        uint256 amountOut = orderbook.contribute(
            tokenOfferId,
            CONTRIBUTE_AMOUNT,
            tokenQuote
        );
        vm.stopPrank();

        (, , , , uint256 remainingAmountAfter) = orderbook.offers(tokenOfferId);
        assertEq(remainingAmountAfter, OFFER_AMOUNT - amountOut);

        requestedToken.mint(taker1, CONTRIBUTE_AMOUNT);

        vm.startPrank(taker1);
        requestedToken.approve(address(orderbook), CONTRIBUTE_AMOUNT);
        amountOut = orderbook.contribute(
            tokenOfferId,
            CONTRIBUTE_AMOUNT,
            tokenQuote
        );
        vm.stopPrank();

        (, , , , remainingAmountAfter) = orderbook.offers(tokenOfferId);

        assertEq(remainingAmountAfter, OFFER_AMOUNT - amountOut - amountOut);
        assertEq(
            escrow.getTokenBalance(address(offeredToken)),
            remainingAmountAfter
        );
    }

    function test_contribute_GreaterThanRemainingAmount() public {
        uint256 excessiveContributeAmount = OFFER_AMOUNT * 4;
        requestedToken.mint(taker1, excessiveContributeAmount);

        uint256 escrowBalanceBefore = escrow.getTokenBalance(
            address(offeredToken)
        );

        uint256 takerRequestedTokenBalanceBefore = requestedToken.balanceOf(
            taker1
        );

        uint256 takerOfferedTokenBalanceBefore = offeredToken.balanceOf(taker1);

        uint256 makerRequestedTokenBalanceBefore = requestedToken.balanceOf(
            maker
        );
        assertEq(escrowBalanceBefore, OFFER_AMOUNT);
        assertEq(
            takerRequestedTokenBalanceBefore,
            OFFER_AMOUNT * 4 + CONTRIBUTE_AMOUNT
        );

        assertEq(takerOfferedTokenBalanceBefore, 0);
        assertEq(makerRequestedTokenBalanceBefore, 0);

        (, , , , uint256 remainingAmountBefore) = orderbook.offers(
            tokenOfferId
        );
        assertEq(remainingAmountBefore, OFFER_AMOUNT);

        vm.startPrank(taker1);
        requestedToken.approve(address(orderbook), excessiveContributeAmount);
        vm.expectEmit(false, false, false, true);
        emit Orderbook.OfferStatusUpdated(
            tokenOfferId,
            Orderbook.OfferStatus.Filled
        );
        vm.expectEmit(true, true, true, true);
        emit Orderbook.OfferContributed(
            tokenOfferId,
            taker1,
            excessiveContributeAmount / 2,
            OFFER_AMOUNT
        );
        uint256 amountOut = orderbook.contribute(
            tokenOfferId,
            excessiveContributeAmount,
            tokenQuote
        );
        vm.stopPrank();

        (, , , , uint256 remainingAmountAfter) = orderbook.offers(tokenOfferId);
        assertEq(remainingAmountAfter, 0);
        assertEq(amountOut, OFFER_AMOUNT);
        assertEq(
            escrow.getTokenBalance(address(offeredToken)),
            remainingAmountAfter
        );
        assertEq(
            requestedToken.balanceOf(taker1),
            takerRequestedTokenBalanceBefore - (OFFER_AMOUNT * 2)
        );
        assertEq(
            offeredToken.balanceOf(taker1),
            takerOfferedTokenBalanceBefore + OFFER_AMOUNT
        );
        assertEq(
            requestedToken.balanceOf(maker),
            makerRequestedTokenBalanceBefore + (OFFER_AMOUNT * 2)
        );

        Orderbook.OfferStatus statusAfter = orderbook.offerStatusById(
            tokenOfferId
        );
        assert(statusAfter == Orderbook.OfferStatus.Filled);
    }

    function test_contribute_SucceedsMaximumSlippage() public {
        bytes32 offerId = _createAndReturnOfferWithConstraints(
            address(offeredToken),
            address(requestedToken),
            OFFER_AMOUNT,
            10, // 1% max slippage
            block.timestamp,
            block.timestamp + 10 days
        );

        (, int256 requestedPriceToken, , , ) = requestedTokenEthFeed
            .latestRoundData();

        // Mock Price drop of 1% - 1
        vm.prank(owner);
        requestedTokenEthFeed.updateAnswer(int256((990e8))); // 1% worse -> should succeed

        (, int256 mockPriceDrop, , , ) = requestedTokenEthFeed
            .latestRoundData();

        uint256 onePercent = (uint256(requestedPriceToken) * 10) / 1000;

        assertEq(
            uint256(mockPriceDrop),
            (uint256(requestedPriceToken) - onePercent)
        );

        vm.startPrank(taker1);
        requestedToken.approve(address(orderbook), CONTRIBUTE_AMOUNT);
        uint256 amountOut = orderbook.contribute(
            offerId,
            CONTRIBUTE_AMOUNT,
            tokenQuote
        );
        vm.stopPrank();

        assertEq(amountOut, tokenQuote - ((tokenQuote * 10) / 1000)); // 1% slippage applied
    }

    function test_contribute_returnsExcessETH() public {
        deal(taker1, 1 ether);

        ethToTokenOfferId = _createAndReturnOffer(address(offeredToken), ETH);

        uint256 takerEthBalanceBefore = taker1.balance;

        uint256 quote = settlementEngine.getAmountOut(
            address(offeredToken),
            ETH,
            5e15
        );

        vm.startPrank(taker1);

        uint256 amountOut = orderbook.contribute{value: 10e15}(
            ethToTokenOfferId,
            10e15,
            quote
        );
        vm.stopPrank();

        assertEq(amountOut, 10e18);

        uint256 takerEthBalanceAfter = taker1.balance;

        // Taker sent 0.01 ETH, used 0.005 ETH, should get back 0.005 ETH
        assertEq(takerEthBalanceAfter, takerEthBalanceBefore - 5e15);
    }

    /*//////////////////////////////////////////////////////////////
                             NEGATIVE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_contribute_RevertsOfferNotOpen() public {
        bytes32 invalidOfferId = bytes32("invalidOfferId");

        vm.startPrank(taker1);
        vm.expectRevert(Orderbook.Orderbook__OfferNotOpenOrInProgress.selector);
        orderbook.contribute(invalidOfferId, CONTRIBUTE_AMOUNT, tokenQuote);
        vm.stopPrank();
    }

    function test_contribute_RevertsOfferNotInProgress() public {
        vm.startPrank(taker1);
        requestedToken.approve(address(orderbook), CONTRIBUTE_AMOUNT);
        orderbook.contribute(tokenOfferId, CONTRIBUTE_AMOUNT, tokenQuote);
        vm.stopPrank();

        assert(
            orderbook.offerStatusById(tokenOfferId) ==
                Orderbook.OfferStatus.InProgress
        );

        vm.prank(maker);
        orderbook.cancelOffer(tokenOfferId);

        assert(
            orderbook.offerStatusById(tokenOfferId) ==
                Orderbook.OfferStatus.Cancelled
        );

        vm.startPrank(taker1);
        vm.expectRevert(Orderbook.Orderbook__OfferNotOpenOrInProgress.selector);
        orderbook.contribute(tokenOfferId, CONTRIBUTE_AMOUNT, tokenQuote);
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
        orderbook.contribute(tokenOfferId, 0, tokenQuote);
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
        orderbook.contribute(offerId, CONTRIBUTE_AMOUNT, tokenQuote);
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
        orderbook.contribute(offerId, CONTRIBUTE_AMOUNT, tokenQuote);
    }

    function test_contributeReverts_SlippageExceeded() public {
        bytes32 offerId = _createAndReturnOfferWithConstraints(
            address(offeredToken),
            address(requestedToken),
            OFFER_AMOUNT,
            10, // 1% max slippage
            block.timestamp,
            block.timestamp + 10 days
        );

        (, int256 requestedPriceToken, , , ) = requestedTokenEthFeed
            .latestRoundData();

        // Mock Price drop of 1% - 1
        vm.prank(owner);
        requestedTokenEthFeed.updateAnswer(int256((990e8) - 1)); // 1% - 1 worse

        (, int256 mockPriceDrop, , , ) = requestedTokenEthFeed
            .latestRoundData();

        uint256 onePercent = (uint256(requestedPriceToken) * 10) / 1000;

        assertEq(
            uint256(mockPriceDrop),
            (uint256(requestedPriceToken) - onePercent) - 1
        );

        vm.startPrank(taker1);
        requestedToken.approve(address(orderbook), CONTRIBUTE_AMOUNT);
        vm.expectRevert(Orderbook.Orderbook__SlippageExceeded.selector);
        // Call with normal quote which is now invalid due to price drop
        orderbook.contribute(offerId, CONTRIBUTE_AMOUNT, tokenQuote);
        vm.stopPrank();
    }

    function test_contribute_RevertsInvalidContribution_ETH() public {
        deal(taker1, 1 ether);

        ethToTokenOfferId = _createAndReturnOffer(address(offeredToken), ETH);

        uint256 quote = settlementEngine.getAmountOut(
            address(offeredToken),
            ETH,
            5e15
        );

        vm.startPrank(taker1);

        vm.expectRevert(
            abi.encodeWithSelector(
                Orderbook.Orderbook__InvalidContribution.selector,
                5e14
            )
        );
        orderbook.contribute{value: 5e14}(ethToTokenOfferId, 5e15, quote);
        vm.stopPrank();
    }

    function test_contributeRevertsWhenPaused() public {
        vm.prank(owner);
        orderbook.pause();

        vm.startPrank(taker1);
        requestedToken.approve(address(orderbook), CONTRIBUTE_AMOUNT);
        vm.expectRevert(
            abi.encodeWithSelector(Pausable.EnforcedPause.selector)
        );
        orderbook.contribute(tokenOfferId, CONTRIBUTE_AMOUNT, tokenQuote);
        vm.stopPrank();
    }
}
