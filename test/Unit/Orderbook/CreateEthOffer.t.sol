// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestSetup} from "../../TestSetup.t.sol";
import {Orderbook} from "../../../src/contracts/Orderbook.sol";

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract CreateEthOfferTest is TestSetup {
    /*//////////////////////////////////////////////////////////////
                            STATE UPDATES
    //////////////////////////////////////////////////////////////*/

    function test_CreateEthOffer_Success() public {
        uint256 initialMakerBalance = maker.balance;
        uint256 initialEscrowBalance = address(escrow).balance;

        assertEq(initialMakerBalance, INITIAL_MAKER_BALANCE);
        assertEq(initialEscrowBalance, 0);

        assertEq(orderbook.nonce(), 1);

        (
            Orderbook.TokenAmount memory offer,
            uint256 constraints
        ) = _generateOfferAmountsAndConstraints(
                ETH,
                OFFER_AMOUNT,
                MAX_SLIPPAGE_BPS,
                validFrom,
                validUntil
            );

        bytes32 expectedOfferId = keccak256(
            abi.encode(
                maker,
                orderbook.nonce(),
                ETH,
                OFFER_AMOUNT,
                address(requestedToken)
            )
        );

        vm.startPrank(maker);

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
        bytes32 offerId = orderbook.createEthOffer{value: OFFER_AMOUNT}(
            offer,
            address(requestedToken),
            constraints
        );

        assertEq(maker.balance, initialMakerBalance - OFFER_AMOUNT);
        assertEq(address(escrow).balance, initialEscrowBalance + OFFER_AMOUNT);

        (
            address maker_,
            Orderbook.TokenAmount memory offer_,
            address requestedToken_,
            uint256 constraints_,
            uint256 remainingAmount
        ) = orderbook.offers(offerId);

        assertEq(orderbook.nonce(), 2);

        assertEq(maker_, maker);
        assertEq(offer_.token, ETH);
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

    function test_CreateEthOffer_RevertsSameTokens() public {
        (
            Orderbook.TokenAmount memory offer,
            uint256 constraints
        ) = _generateOfferAmountsAndConstraints(
                ETH,
                OFFER_AMOUNT,
                MAX_SLIPPAGE_BPS,
                validFrom,
                validUntil
            );

        vm.startPrank(maker);

        vm.expectRevert(Orderbook.Orderbook__SameTokens.selector);
        orderbook.createEthOffer{value: OFFER_AMOUNT}(offer, ETH, constraints);

        vm.stopPrank();
    }

    function test_CreateEthOfferRevertsForUnsupportedRequestedToken() public {
        vm.startPrank(owner);
        orderbook.removeToken(address(requestedToken));
        vm.stopPrank();

        (, bool isSupported) = orderbook.tokenInfo(address(requestedToken));

        assertFalse(isSupported);

        (
            Orderbook.TokenAmount memory offer,
            uint256 constraints
        ) = _generateOfferAmountsAndConstraints(
                ETH,
                OFFER_AMOUNT,
                MAX_SLIPPAGE_BPS,
                validFrom,
                validUntil
            );

        vm.startPrank(maker);
        vm.expectRevert(
            abi.encodeWithSelector(
                Orderbook.Orderbook__UnsupportedToken.selector,
                address(requestedToken)
            )
        );
        orderbook.createEthOffer{value: OFFER_AMOUNT}(
            offer,
            address(requestedToken),
            constraints
        );
        vm.stopPrank();
    }

    function test_CreateEthOfferRevertsForUnsupportedOfferedToken() public {
        vm.startPrank(owner);
        orderbook.removeToken(ETH);
        vm.stopPrank();

        (
            Orderbook.TokenAmount memory offer,
            uint256 constraints
        ) = _generateOfferAmountsAndConstraints(
                ETH,
                OFFER_AMOUNT,
                MAX_SLIPPAGE_BPS,
                validFrom,
                validUntil
            );

        vm.startPrank(maker);
        vm.expectRevert(
            abi.encodeWithSelector(
                Orderbook.Orderbook__UnsupportedToken.selector,
                ETH
            )
        );
        orderbook.createEthOffer{value: OFFER_AMOUNT}(
            offer,
            address(requestedToken),
            constraints
        );
        vm.stopPrank();
    }

    function test_CreateEthOffer_Reverts_ZeroAddress() public {
        (
            Orderbook.TokenAmount memory offer,
            uint256 constraints
        ) = _generateOfferAmountsAndConstraints(
                ETH,
                OFFER_AMOUNT,
                MAX_SLIPPAGE_BPS,
                validFrom,
                validUntil
            );

        vm.startPrank(maker);

        vm.expectRevert(
            abi.encodeWithSelector(
                Orderbook.Orderbook__UnsupportedToken.selector,
                address(0)
            )
        );
        orderbook.createEthOffer{value: OFFER_AMOUNT}(
            offer,
            address(0),
            constraints
        );

        vm.stopPrank();
    }

    function test_CreateEthOffer_Reverts_NotETH() public {
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

        vm.expectRevert(Orderbook.Orderbook__NotETH.selector);
        orderbook.createEthOffer{value: OFFER_AMOUNT}(
            offer,
            address(requestedToken),
            constraints
        );

        vm.stopPrank();
    }

    function testCreateEthOffer_TransferFails() public {
        // Arrange
        (
            Orderbook.TokenAmount memory offer,
            uint256 constraints
        ) = _generateOfferAmountsAndConstraints(
                ETH,
                OFFER_AMOUNT,
                MAX_SLIPPAGE_BPS,
                validFrom,
                validUntil
            );

        vm.startPrank(owner);

        // Mock escrow to fail
        address mockEscrow = address(new MockEscrow());
        Orderbook newOrderbook = new Orderbook(
            address(settlementEngine),
            mockEscrow
        );
        newOrderbook.addToken(
            address(requestedToken),
            address(requestedTokenEthFeed)
        );
        newOrderbook.addToken(newOrderbook.ETH_ADDRESS(), address(0));
        vm.stopPrank();

        // Assert escrow address
        assertEq(
            address(newOrderbook.escrow()),
            mockEscrow,
            "Escrow address mismatch"
        );

        // Act & Assert
        vm.startPrank(maker); // Simulate maker's call
        vm.expectRevert(Orderbook.Orderbook__ETHTransferFailed.selector);
        newOrderbook.createEthOffer{value: offer.amount}(
            offer,
            address(requestedToken),
            constraints
        );
    }

    function test_CreateEthOffer_Reverts_InvalidAmounts() public {
        (
            Orderbook.TokenAmount memory offer,
            uint256 constraints
        ) = _generateOfferAmountsAndConstraints(
                ETH,
                orderbook.MIN_OFFER_AMOUNT() - 1,
                MAX_SLIPPAGE_BPS,
                validFrom,
                validUntil
            );

        vm.startPrank(maker);

        vm.expectRevert(Orderbook.Orderbook__InvalidOfferAmount.selector);
        orderbook.createEthOffer{value: 0}(
            offer,
            address(requestedToken),
            constraints
        );

        vm.stopPrank();
    }

    function test_CreateEthOffer_Reverts_InvalidConstraints() public {
        vm.startPrank(maker);
        (
            Orderbook.TokenAmount memory offer,
            uint256 constraints
        ) = _generateOfferAmountsAndConstraints(
                ETH,
                OFFER_AMOUNT,
                MAX_SLIPPAGE_BPS,
                block.timestamp - 1,
                validUntil
            );

        vm.expectRevert(
            abi.encodeWithSelector(
                Orderbook.Orderbook__InvalidConstraints.selector,
                "VALID_FROM"
            )
        );
        orderbook.createEthOffer{value: OFFER_AMOUNT}(
            offer,
            address(requestedToken),
            constraints
        );

        (offer, constraints) = _generateOfferAmountsAndConstraints(
            ETH,
            OFFER_AMOUNT,
            MAX_SLIPPAGE_BPS,
            validFrom,
            block.timestamp
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                Orderbook.Orderbook__InvalidConstraints.selector,
                "VALID_UNTIL"
            )
        );
        orderbook.createEthOffer{value: OFFER_AMOUNT}(
            offer,
            address(requestedToken),
            constraints
        );
        vm.stopPrank();
    }

    function test_CreateEthOffer_RevertsWhenPaused() public {
        vm.startPrank(owner);
        orderbook.pause();
        vm.stopPrank();

        (
            Orderbook.TokenAmount memory offer,
            uint256 constraints
        ) = _generateOfferAmountsAndConstraints(
                ETH,
                OFFER_AMOUNT,
                MAX_SLIPPAGE_BPS,
                validFrom,
                validUntil
            );

        vm.startPrank(maker);

        vm.expectRevert(
            abi.encodeWithSelector(Pausable.EnforcedPause.selector)
        );
        orderbook.createEthOffer{value: OFFER_AMOUNT}(
            offer,
            address(requestedToken),
            constraints
        );

        vm.stopPrank();
    }
}

contract MockEscrow {
    mapping(address => uint256) private tokenBalances;

    receive() external payable {
        revert("MockEscrow: ETH transfer failed");
    }
    function increaseBalance(address _token, uint256 _amount) external {
        tokenBalances[_token] += _amount;
    }
}
