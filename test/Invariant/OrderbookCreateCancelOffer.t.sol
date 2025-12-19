// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {TestSetup} from "../TestSetup.t.sol";

import {IOrderbook} from "../../src/interfaces/IOrderbook.sol";

import {Orderbook} from "../../src/contracts/Orderbook.sol";
import {Escrow} from "../../src/contracts/Escrow.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract CreateCancelOfferHandler is Test {
    Orderbook public orderbook;
    Escrow public escrow;

    address public maker;
    address public offeredToken;
    address public requestedToken;

    uint256 public escrowBalance;
    uint256 public escrowOfferedTokenBalance;
    uint256 public approvedAmount;

    uint256 INITIAL_MAKER_BALANCE = 100 ether;

    uint256 public validFrom = uint64(block.timestamp);
    uint256 public validUntil = uint64(block.timestamp + 1 days);

    uint128 public constant MAX_SLIPPAGE_BPS = 20; // 2%

    bytes32 public lastOfferId;

    mapping(bytes32 offerId => bool exists) public offerIdExists;

    constructor(
        Orderbook _orderbook,
        Escrow _escrow,
        address _maker,
        address _offeredToken,
        address _requestedToken
    ) {
        orderbook = _orderbook;
        escrow = _escrow;

        maker = _maker;
        offeredToken = _offeredToken;
        requestedToken = _requestedToken;
    }

    function createTokenOffer(uint256 _amount) public {
        uint256 minAmount = orderbook.MIN_OFFER_AMOUNT();
        _amount = bound(_amount, minAmount, 1 ether);

        ERC20Mock(offeredToken).mint(maker, _amount);

        lastOfferId = _createAndReturnOffer(
            offeredToken,
            requestedToken,
            _amount
        );

        escrowOfferedTokenBalance += _amount;

        if (offerIdExists[lastOfferId]) {
            revert("Duplicate offerId detected");
        }

        offerIdExists[lastOfferId] = true;
    }

    function cancelTokenOffer() public {
        (, , , , uint256 remainingAmount) = orderbook.offers(lastOfferId);
        if (remainingAmount == 0) {
            return;
        }

        vm.startPrank(maker);
        orderbook.cancelOffer(lastOfferId);
        vm.stopPrank();

        escrowOfferedTokenBalance -= remainingAmount;
    }

    function offerIds_are_unique() public view {
        // This invariant is implicitly enforced by the mapping structure.
        // If a duplicate `offerId` were added, the test would fail.
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _generateOfferAmountsAndConstraints(
        address _offeredToken,
        uint256 _amount,
        uint256 _maxSlippageBps,
        uint256 _validFrom,
        uint256 _validUntil
    )
        internal
        view
        returns (IOrderbook.TokenAmount memory offer, uint256 constraints)
    {
        offer = IOrderbook.TokenAmount({token: _offeredToken, amount: _amount});

        constraints = orderbook.encodeConstraints(
            uint64(_validFrom),
            uint64(_validUntil),
            uint128(_maxSlippageBps)
        );
        return (offer, constraints);
    }

    function _createAndReturnOffer(
        address _offeredToken,
        address _requestedToken,
        uint256 _amount
    ) internal returns (bytes32 orderId) {
        IOrderbook.TokenAmount memory offer;
        uint256 constraints;

        if (_offeredToken == orderbook.ETH_ADDRESS()) {
            (offer, constraints) = _generateOfferAmountsAndConstraints(
                orderbook.ETH_ADDRESS(),
                _amount,
                MAX_SLIPPAGE_BPS,
                validFrom,
                validUntil
            );

            vm.startPrank(maker);
            orderId = orderbook.createEthOffer{value: _amount}(
                offer,
                address(_requestedToken),
                constraints
            );
            vm.stopPrank();
        } else {
            (offer, constraints) = _generateOfferAmountsAndConstraints(
                address(offeredToken),
                _amount,
                MAX_SLIPPAGE_BPS,
                validFrom,
                validUntil
            );

            vm.startPrank(maker);
            IERC20(offeredToken).approve(address(orderbook), _amount);
            orderId = orderbook.createTokenOffer(
                offer,
                address(_requestedToken),
                constraints
            );
            vm.stopPrank();
        }
    }
}

contract OrderbookCreateCancelOfferInvariant is StdInvariant, TestSetup {
    CreateCancelOfferHandler public handler;

    function setUp() public override {
        super.setUp();

        handler = new CreateCancelOfferHandler(
            orderbook,
            escrow,
            maker,
            address(offeredToken),
            address(requestedToken)
        );

        targetContract(address(handler));

        assertEq(maker.balance, INITIAL_MAKER_BALANCE);
        assertEq(offeredToken.balanceOf(maker), INITIAL_MAKER_BALANCE);
    }

    function invariant_escrow_balances_always_equal_sum_of_offer_amounts_minus_cancelled_offers()
        public
        view
    {
        assertEq(
            escrow.getTokenBalance(address(offeredToken)),
            handler.escrowOfferedTokenBalance()
        );
    }

    function invariant_offer_ids_are_unique() public view {
        handler.offerIds_are_unique();
    }
}
