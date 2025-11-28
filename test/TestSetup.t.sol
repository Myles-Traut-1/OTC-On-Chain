// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {Orderbook} from "../src/contracts/Orderbook.sol";
import {Escrow} from "../src/contracts/Escrow.sol";
import {SettlementEngine} from "../src/contracts/SettlementEngine.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract TestSetup is Test {
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

    function setUp() public virtual {
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

        escrow.setOrderbook(address(orderbook));
        vm.stopPrank();

        deal(maker, INITIAL_MAKER_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    function _generateOfferAmountsAndConstraints(
        address _offeredToken,
        uint256 _amount,
        uint256 _minFillAmount,
        uint256 _maxSlippageBps,
        uint256 _validFrom,
        uint256 _validUntil
    )
        internal
        pure
        returns (
            Orderbook.TokenAmount memory offer,
            Orderbook.Constraints memory constraints
        )
    {
        offer = Orderbook.TokenAmount({token: _offeredToken, amount: _amount});

        constraints = Orderbook.Constraints({
            minFillAmount: _minFillAmount,
            maxSlippageBps: _maxSlippageBps,
            validFrom: uint64(_validFrom),
            validUntil: uint64(_validUntil)
        });

        return (offer, constraints);
    }

    function _createAndReturnOffer(
        address _offeredToken
    ) internal returns (bytes32 orderId) {
        Orderbook.TokenAmount memory offer;
        Orderbook.Constraints memory constraints;

        if (_offeredToken == orderbook.ETH_ADDRESS()) {
            (offer, constraints) = _generateOfferAmountsAndConstraints(
                orderbook.ETH_ADDRESS(),
                OFFER_AMOUNT,
                MIN_FILL_AMOUNT,
                MAX_SLIPPAGE_BPS,
                validFrom,
                validUntil
            );

            vm.startPrank(maker);
            orderId = orderbook.createEthOffer{value: OFFER_AMOUNT}(
                offer,
                address(requestedToken),
                constraints
            );
            vm.stopPrank();
        } else {
            (offer, constraints) = _generateOfferAmountsAndConstraints(
                address(offeredToken),
                OFFER_AMOUNT,
                MIN_FILL_AMOUNT,
                MAX_SLIPPAGE_BPS,
                validFrom,
                validUntil
            );

            vm.startPrank(maker);
            offeredToken.approve(address(orderbook), OFFER_AMOUNT);
            orderId = orderbook.createTokenOffer(
                offer,
                address(requestedToken),
                constraints
            );
            vm.stopPrank();
        }
    }
}
