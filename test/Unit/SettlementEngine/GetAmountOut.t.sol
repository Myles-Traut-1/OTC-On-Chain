// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestSetup} from "../../TestSetup.t.sol";
import {SettlementEngine} from "../../../src/contracts/SettlementEngine.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "@chainlink/src/v0.8/tests/MockV3Aggregator.sol";

contract GetAmountOutTest is TestSetup {
    MockUSDC public usdc;
    MockV3Aggregator public usdcEthFeed;

    uint256 public constant AMOUNT_IN = 1 ether;

    function setUp() public override {
        super.setUp();

        usdc = new MockUSDC();
        usdcEthFeed = new MockV3Aggregator(8, 2000e8); // $1 per USDC

        vm.startPrank(owner);
        orderbook.addToken(address(usdc), address(usdcEthFeed));
        vm.stopPrank();
    }
    /*//////////////////////////////////////////////////////////////
                           GET AMOUNT OUT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetAmountOut_OfferETH() public view {
        // 1000 requestedToken = 1 ETH
        uint256 expectedAmountOut = 1e18; // 0.001 requestedToken

        uint256 amountOut = settlementEngine.getAmountOut(
            ETH,
            address(requestedToken),
            1000e18
        );

        assertEq(amountOut, expectedAmountOut);
    }

    function test_GetAmountOut_RequestedETH() public view {
        // 1 ETH = 2000 offeredToken
        uint256 expectedAmountOut = 2000e18;

        uint256 amountOut = settlementEngine.getAmountOut(
            address(offeredToken),
            ETH,
            AMOUNT_IN
        );

        assertEq(amountOut, expectedAmountOut);
    }

    function test_GetAmountOut_TokenToToken() public view {
        // 2000 offeredToken = 1 ETH
        // 1000 requestedToken = 1 ETH
        // Ratio = 2 offeredToken : 1 requestedToken

        uint256 expectedAmountOut = 1e18;

        uint256 amountOut = settlementEngine.getAmountOut(
            address(requestedToken),
            address(offeredToken),
            AMOUNT_IN / 2
        );

        assertEq(amountOut, expectedAmountOut);

        expectedAmountOut = 0.5e18;

        amountOut = settlementEngine.getAmountOut(
            address(offeredToken),
            address(requestedToken),
            AMOUNT_IN
        );

        assertEq(amountOut, expectedAmountOut);

        expectedAmountOut = 1e18;

        amountOut = settlementEngine.getAmountOut(
            address(offeredToken),
            address(usdc),
            AMOUNT_IN
        );

        assertEq(amountOut, expectedAmountOut);

        expectedAmountOut = 0.5e6;

        amountOut = settlementEngine.getAmountOut(
            address(usdc),
            address(requestedToken),
            AMOUNT_IN
        );

        assertEq(amountOut, expectedAmountOut);
    }

    function test_GetAmountOut_VariableDecimals_OfferETH() public view {
        // Offer ETH request USDC
        // 2000 USDC = 1 ETH

        uint256 amountOut = settlementEngine.getAmountOut(
            ETH,
            address(usdc),
            2000e18
        );

        assertEq(amountOut, 1e18);
    }

    function test_GetAmountOut_VariableDecimals_OfferUSDC() public view {
        // Offer ETH request USDC
        // 2000 USDC = 1 ETH

        uint256 amountOut = settlementEngine.getAmountOut(
            address(usdc),
            ETH,
            AMOUNT_IN
        );

        assertEq(amountOut, 2000e6);
    }
}

contract MockUSDC is ERC20Mock {
    constructor() {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}
