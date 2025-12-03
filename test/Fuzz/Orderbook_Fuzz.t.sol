// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestSetup} from "../TestSetup.t.sol";
import {Orderbook} from "../../src/contracts/Orderbook.sol";
import {Escrow} from "../../src/contracts/Escrow.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {console} from "forge-std/console.sol";

contract OrderbookFuzzTest is TestSetup {
    uint256 public minOfferAmount;
    uint256 public maxSlippageBps;
    uint256 public minSlippageBps;

    uint256 public initialEscrowEthBalance;
    uint256 public initialEscrowTokenBalance;

    function setUp() public override {
        super.setUp();

        minOfferAmount = orderbook.MIN_OFFER_AMOUNT();
        maxSlippageBps = orderbook.MAX_SLIPPAGE();
        minSlippageBps = orderbook.MIN_SLIPPAGE();

        initialEscrowEthBalance = address(escrow).balance;
        initialEscrowTokenBalance = offeredToken.balanceOf(address(escrow));
    }

    function test_Fuzz_createTokenOffer(
        uint256 _offeredAmount,
        uint64 _validFrom,
        uint64 _validUntil,
        uint128 _slippageBps
    ) public {
        _offeredAmount = bound(
            _offeredAmount,
            minOfferAmount,
            INITIAL_MAKER_BALANCE
        );

        _validFrom = uint64(
            bound(
                _validFrom,
                uint64(block.timestamp),
                uint64(block.timestamp + 7 days)
            )
        );

        _validUntil = uint64(
            bound(_validUntil, _validFrom + 1, _validFrom + 30 days)
        );

        _slippageBps = uint128(
            bound(_slippageBps, minSlippageBps, maxSlippageBps)
        ); // 0.5% - 2%

        vm.startPrank(maker);

        Orderbook.TokenAmount memory _offer = Orderbook.TokenAmount({
            token: address(offeredToken),
            amount: _offeredAmount
        });

        uint256 constraints = orderbook.encodeConstraints(
            _validFrom,
            _validUntil,
            _slippageBps
        );

        IERC20(address(offeredToken)).approve(
            address(orderbook),
            _offeredAmount
        );

        bytes32 offerId = orderbook.createTokenOffer(
            _offer,
            address(requestedToken),
            constraints
        );

        (Orderbook.Offer memory offer, Orderbook.OfferStatus status) = orderbook
            .getOffer(offerId);

        assertEq(
            offeredToken.balanceOf(maker),
            INITIAL_MAKER_BALANCE - _offeredAmount
        );

        assertEq(
            offeredToken.balanceOf(address(escrow)),
            initialEscrowTokenBalance + _offeredAmount
        );

        assertEq(offer.maker, maker);
        assertEq(offer.offer.token, address(offeredToken));
        assertEq(offer.offer.amount, _offeredAmount);
        assertEq(offer.constraints, constraints);
        assertEq(offer.requestedToken, address(requestedToken));
        assert(status == Orderbook.OfferStatus.Open);

        _assertConstraints(
            offer.constraints,
            _validFrom,
            _validUntil,
            _slippageBps
        );
    }

    function test_Fuzz_createEthOffer(
        uint256 _offeredAmount,
        uint64 _validFrom,
        uint64 _validUntil,
        uint128 _slippageBps
    ) public {
        _offeredAmount = bound(
            _offeredAmount,
            minOfferAmount,
            INITIAL_MAKER_BALANCE
        );

        _validFrom = uint64(
            bound(
                _validFrom,
                uint64(block.timestamp),
                uint64(block.timestamp + 7 days)
            )
        );

        _validUntil = uint64(
            bound(_validUntil, _validFrom + 1, _validFrom + 30 days)
        );

        _slippageBps = uint128(
            bound(_slippageBps, minSlippageBps, maxSlippageBps)
        ); // 0.5% - 2%

        vm.startPrank(maker);
        Orderbook.TokenAmount memory _offer = Orderbook.TokenAmount({
            token: address(orderbook.ETH_ADDRESS()),
            amount: _offeredAmount
        });

        uint256 constraints = orderbook.encodeConstraints(
            _validFrom,
            _validUntil,
            _slippageBps
        );

        bytes32 offerId = orderbook.createEthOffer{value: _offeredAmount}(
            _offer,
            address(requestedToken),
            constraints
        );
        vm.stopPrank();

        (Orderbook.Offer memory offer, Orderbook.OfferStatus status) = orderbook
            .getOffer(offerId);

        assertEq(maker.balance, INITIAL_MAKER_BALANCE - _offeredAmount);
        assertEq(
            address(escrow).balance,
            initialEscrowEthBalance + _offeredAmount
        );

        assertEq(offer.maker, maker);
        assertEq(offer.offer.token, address(orderbook.ETH_ADDRESS()));
        assertEq(offer.offer.amount, _offeredAmount);
        assertEq(offer.constraints, constraints);
        assertEq(offer.requestedToken, address(requestedToken));
        assert(status == Orderbook.OfferStatus.Open);

        _assertConstraints(constraints, _validFrom, _validUntil, _slippageBps);
    }

    function test_Fuzz_CancelEthOffer(uint256 _offeredAmount) public {
        _offeredAmount = bound(
            _offeredAmount,
            minOfferAmount,
            INITIAL_MAKER_BALANCE
        );

        Orderbook.TokenAmount memory _offer = Orderbook.TokenAmount({
            token: address(orderbook.ETH_ADDRESS()),
            amount: _offeredAmount
        });

        uint256 constraints = orderbook.encodeConstraints(
            uint64(validFrom),
            uint64(validUntil),
            uint128(MAX_SLIPPAGE_BPS)
        );

        vm.startPrank(maker);

        bytes32 offerId = orderbook.createEthOffer{value: _offeredAmount}(
            _offer,
            address(requestedToken),
            constraints
        );

        (Orderbook.Offer memory offer, Orderbook.OfferStatus status) = orderbook
            .getOffer(offerId);

        assertEq(
            address(escrow).balance,
            initialEscrowEthBalance + _offeredAmount
        );

        console.log("Escrow balance before cancel:", address(escrow).balance);

        assertEq(maker.balance, INITIAL_MAKER_BALANCE - _offeredAmount);

        assertEq(offer.maker, maker);
        assertEq(offer.offer.token, address(orderbook.ETH_ADDRESS()));
        assertEq(offer.offer.amount, _offeredAmount);
        assertEq(offer.constraints, constraints);
        assertEq(offer.requestedToken, address(requestedToken));
        assert(status == Orderbook.OfferStatus.Open);

        orderbook.cancelOffer(offerId);

        (, Orderbook.OfferStatus updatedStatus) = orderbook.getOffer(offerId);

        vm.stopPrank();

        assert(updatedStatus == Orderbook.OfferStatus.Cancelled);
        assertEq(maker.balance, INITIAL_MAKER_BALANCE);
    }

    function test_Fuzz_CancelTokenOffer(uint256 _offeredAmount) public {
        _offeredAmount = bound(
            _offeredAmount,
            minOfferAmount,
            INITIAL_MAKER_BALANCE
        );

        Orderbook.TokenAmount memory _offer = Orderbook.TokenAmount({
            token: address(offeredToken),
            amount: _offeredAmount
        });

        uint256 constraints = orderbook.encodeConstraints(
            uint64(validFrom),
            uint64(validUntil),
            uint128(MAX_SLIPPAGE_BPS)
        );

        vm.startPrank(maker);

        offeredToken.approve(address(orderbook), _offeredAmount);

        bytes32 offerId = orderbook.createTokenOffer(
            _offer,
            address(requestedToken),
            constraints
        );

        (Orderbook.Offer memory offer, Orderbook.OfferStatus status) = orderbook
            .getOffer(offerId);

        assertEq(
            offeredToken.balanceOf(address(escrow)),
            initialEscrowTokenBalance + _offeredAmount
        );

        assertEq(
            offeredToken.balanceOf(maker),
            INITIAL_MAKER_BALANCE - _offeredAmount
        );

        assert(status == Orderbook.OfferStatus.Open);

        orderbook.cancelOffer(offerId);

        (, Orderbook.OfferStatus updatedStatus) = orderbook.getOffer(offerId);

        vm.stopPrank();

        assert(updatedStatus == Orderbook.OfferStatus.Cancelled);
        assertEq(offeredToken.balanceOf(maker), INITIAL_MAKER_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _assertConstraints(
        uint256 _constraints,
        uint64 _validFrom,
        uint64 _validUntil,
        uint128 _slippageBps
    ) internal {
        (uint64 validFrom, uint64 validUntil, uint128 slippageBps) = orderbook
            .decodeConstraints(_constraints);
        assertEq(slippageBps, _slippageBps);
        assertEq(validFrom, _validFrom);
        assertEq(validUntil, _validUntil);
    }
}
