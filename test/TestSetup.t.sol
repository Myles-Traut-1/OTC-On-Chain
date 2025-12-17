// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {Orderbook} from "../src/contracts/Orderbook.sol";
import {Escrow} from "../src/contracts/Escrow.sol";
import {SettlementEngine} from "../src/contracts/SettlementEngine.sol";

import {Deployer} from "../script/Deploy.s.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {MockV3Aggregator} from "@chainlink/src/v0.8/tests/MockV3Aggregator.sol";

/// TODO: Refactor helpers in seperate contract

contract TestSetup is Test {
    Deployer public deployer;

    MockV3Aggregator offeredTokenEthFeed;
    MockV3Aggregator requestedTokenEthFeed;

    Orderbook public orderbook;
    Escrow public escrow;
    SettlementEngine public settlementEngine;

    ERC20Mock public offeredToken;
    ERC20Mock public requestedToken;

    address public ETH;

    address public owner;
    address public maker;
    address public taker1;
    address public taker2;

    uint256 public constant INITIAL_MAKER_BALANCE = 100 ether;

    uint256 public constant OFFER_AMOUNT = 10 ether;
    uint256 public constant CONTRIBUTE_AMOUNT = OFFER_AMOUNT / 2; // 5 ether

    uint256 public validFrom = uint64(block.timestamp);
    uint256 public validUntil = uint64(block.timestamp + 1 days);

    // Quotes used to determine slippage.
    uint256 tokenQuote;
    uint256 ethQuote;

    uint128 public constant MAX_SLIPPAGE_BPS = 20; // 2%

    function setUp() public virtual {
        owner = makeAddr("owner");
        maker = makeAddr("maker");
        taker1 = makeAddr("taker1");
        taker2 = makeAddr("taker2");

        offeredTokenEthFeed = new MockV3Aggregator(8, 2000e8); // $2000 per ETH
        requestedTokenEthFeed = new MockV3Aggregator(8, 1000e8); // $1000 per ETH

        deployer = new Deployer();
        (orderbook, escrow, settlementEngine) = deployer.run(owner);

        offeredToken = new ERC20Mock();
        requestedToken = new ERC20Mock();

        offeredToken.mint(maker, INITIAL_MAKER_BALANCE);

        vm.startPrank(owner);

        escrow.setOrderbook(address(orderbook));
        settlementEngine.setOrderbook(address(orderbook));

        orderbook.addToken(address(offeredToken), address(offeredTokenEthFeed));
        orderbook.addToken(
            address(requestedToken),
            address(requestedTokenEthFeed)
        );
        orderbook.addToken(orderbook.ETH_ADDRESS(), address(0)); // ETH has no data feed
        vm.stopPrank();

        deal(maker, INITIAL_MAKER_BALANCE);

        ETH = orderbook.ETH_ADDRESS();

        tokenQuote = settlementEngine.getAmountOut(
            address(offeredToken),
            address(requestedToken),
            CONTRIBUTE_AMOUNT
        );
        ethQuote = settlementEngine.getAmountOut(
            address(ETH),
            address(requestedToken),
            CONTRIBUTE_AMOUNT
        );
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
        returns (Orderbook.TokenAmount memory offer, uint256 constraints)
    {
        offer = Orderbook.TokenAmount({token: _offeredToken, amount: _amount});

        constraints = orderbook.encodeConstraints(
            uint64(_validFrom),
            uint64(_validUntil),
            uint128(_maxSlippageBps)
        );
        return (offer, constraints);
    }

    function _createAndReturnOffer(
        address _offeredToken,
        address _requestedToken
    ) internal returns (bytes32 orderId) {
        Orderbook.TokenAmount memory offer;
        uint256 constraints;

        if (_offeredToken == orderbook.ETH_ADDRESS()) {
            (offer, constraints) = _generateOfferAmountsAndConstraints(
                orderbook.ETH_ADDRESS(),
                OFFER_AMOUNT,
                MAX_SLIPPAGE_BPS,
                validFrom,
                validUntil
            );

            vm.startPrank(maker);
            orderId = orderbook.createEthOffer{value: OFFER_AMOUNT}(
                offer,
                address(_requestedToken),
                constraints
            );
            vm.stopPrank();
        } else {
            (offer, constraints) = _generateOfferAmountsAndConstraints(
                address(offeredToken),
                OFFER_AMOUNT,
                MAX_SLIPPAGE_BPS,
                validFrom,
                validUntil
            );

            vm.startPrank(maker);
            offeredToken.approve(address(orderbook), OFFER_AMOUNT);
            orderId = orderbook.createTokenOffer(
                offer,
                address(_requestedToken),
                constraints
            );
            vm.stopPrank();
        }
    }

    function _createAndReturnOfferWithConstraints(
        address _offeredToken,
        address _requestedToken,
        uint256 _amount,
        uint256 _maxSlippageBps,
        uint256 _validFrom,
        uint256 _validUntil
    ) internal returns (bytes32 orderId) {
        Orderbook.TokenAmount memory offer;
        uint256 constraints;

        if (_offeredToken == orderbook.ETH_ADDRESS()) {
            (offer, constraints) = _generateOfferAmountsAndConstraints(
                orderbook.ETH_ADDRESS(),
                _amount,
                _maxSlippageBps,
                _validFrom,
                _validUntil
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
                _maxSlippageBps,
                _validFrom,
                _validUntil
            );

            vm.startPrank(maker);
            offeredToken.approve(address(orderbook), _amount);
            orderId = orderbook.createTokenOffer(
                offer,
                address(_requestedToken),
                constraints
            );
            vm.stopPrank();
        }
    }
}
