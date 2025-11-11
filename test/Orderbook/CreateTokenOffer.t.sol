// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {Orderbook} from "../../src/contracts/Orderbook.sol";
import {Escrow} from "../../src/contracts/Escrow.sol";
import {SettlementEngine} from "../../src/contracts/SettlementEngine.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract CreateTokenOfferTest is Test {
    Orderbook public orderbook;
    Escrow public escrow;
    SettlementEngine public settlementEngine;

    ERC20Mock public offeredToken;
    ERC20Mock public requestedToken;

    address public owner;
    address public maker;
    address public taker1;
    address public taker2;

    uint256 public constant INITIAL_MAKER_BALANCE = 100 ether;

    uint256 public constant OFFER_AMOUNT = 10 ether;
    uint256 public constant MIN_FILL_AMOUNT = 1 ether;
    uint256 public constant MAX_SLIPPAGE_BPS = 100;
    uint256 public validFrom = uint64(block.timestamp);
    uint256 public validUntil = uint64(block.timestamp + 1 days);

    function setUp() public {
        owner = makeAddr("owner");
        maker = makeAddr("maker");
        taker1 = makeAddr("taker1");
        taker2 = makeAddr("taker2");

        offeredToken = new ERC20Mock();
        requestedToken = new ERC20Mock();

        offeredToken.mint(maker, INITIAL_MAKER_BALANCE);

        vm.startPrank(owner);
        settlementEngine = new SettlementEngine();
        escrow = new Escrow();
        orderbook = new Orderbook(address(settlementEngine), address(escrow));
        vm.stopPrank();
    }

    function test_CreateTokenOffer_Success() public {
        uint256 initialMakerBalance = offeredToken.balanceOf(maker);
        uint256 initialEscrowBalance = offeredToken.balanceOf(address(escrow));

        assertEq(initialMakerBalance, INITIAL_MAKER_BALANCE);
        assertEq(initialEscrowBalance, 0);

        (Orderbook.TokenAmount memory offer, Orderbook.Constraints memory constraints) = _generateOfferAmountsAndConstraints(
            address(offeredToken), OFFER_AMOUNT, MIN_FILL_AMOUNT, MAX_SLIPPAGE_BPS, validFrom, validUntil
        );

        bytes32 expectedOrderId = keccak256(
            abi.encode(maker, orderbook.nonce(), address(offeredToken), OFFER_AMOUNT, address(requestedToken))
        );

        vm.startPrank(maker);
        offeredToken.approve(address(orderbook), OFFER_AMOUNT);

        vm.expectEmit(true, true, true, true);
        emit Orderbook.OrderCreated(
            expectedOrderId, maker, address(escrow), offer, address(requestedToken), constraints
        );
        bytes32 orderId = orderbook.createTokenOrder(address(escrow), offer, address(requestedToken), constraints);
        vm.stopPrank();

        assertEq(offeredToken.balanceOf(maker), INITIAL_MAKER_BALANCE - OFFER_AMOUNT);
        assertEq(offeredToken.balanceOf(address(escrow)), OFFER_AMOUNT);

        (
            bytes32 orderId_,
            address maker_,
            Orderbook.TokenAmount memory offer_,
            address requestedToken_,
            Orderbook.Constraints memory constraints_,
            uint256 remainingAmount
        ) = orderbook.orders(orderId);

        assertEq(orderbook.nonce(), 2);

        assertEq(orderId_, orderId);
        assertEq(maker_, maker);
        assertEq(offer_.token, address(offeredToken));
        assertEq(offer_.amount, OFFER_AMOUNT);
        assertEq(requestedToken_, address(requestedToken));
        assertEq(constraints_.minFillAmount, MIN_FILL_AMOUNT);
        assertEq(constraints_.maxSlippageBps, MAX_SLIPPAGE_BPS);
        assertEq(constraints_.validFrom, uint64(validFrom));
        assertEq(constraints_.validUntil, uint64(validUntil));
        assertEq(remainingAmount, OFFER_AMOUNT);

        Orderbook.OrderStatus orderStatus = orderbook.orderStatusById(orderId);

        assert(orderStatus == Orderbook.OrderStatus.Open);
    }

    function _generateOfferAmountsAndConstraints(
        address _offeredToken,
        uint256 _amount,
        uint256 _minFillAmount,
        uint256 _maxSlippageBps,
        uint256 _validFrom,
        uint256 _validUntil
    ) internal pure returns (Orderbook.TokenAmount memory offer, Orderbook.Constraints memory constraints) {
        offer = Orderbook.TokenAmount({token: _offeredToken, amount: _amount});

        constraints = Orderbook.Constraints({
            minFillAmount: _minFillAmount,
            maxSlippageBps: _maxSlippageBps,
            validFrom: uint64(_validFrom),
            validUntil: uint64(_validUntil)
        });

        return (offer, constraints);
    }
}
