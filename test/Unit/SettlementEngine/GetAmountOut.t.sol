// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestSetup} from "../../TestSetup.t.sol";
import {SettlementEngine} from "../../../src/contracts/SettlementEngine.sol";

contract GetAmountOutTest is TestSetup {
    uint256 public constant AMOUNT_IN = 1 ether;
    /*//////////////////////////////////////////////////////////////
                           GET AMOUNT OUT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetAmountOut_OfferETH() public {
        // 1000 requestedToken = 1 ETH
        uint256 expectedAmountOut = 1e15; // 0.001 requestedToken

        uint256 amountOut = settlementEngine.getAmountOut(
            ETH,
            address(requestedToken),
            AMOUNT_IN
        );

        assertEq(amountOut, expectedAmountOut);
    }

    function test_GetAmountOut_RequestedETH() public {
        // 2000 offeredToken = 1 ETH
        uint256 expectedAmountOut = 2000e18;

        uint256 amountOut = settlementEngine.getAmountOut(
            address(offeredToken),
            ETH,
            AMOUNT_IN
        );

        assertEq(amountOut, expectedAmountOut);
    }

    function test_GetAmountOut_TokenToToken() public {
        // 2000 offeredToken = 1000 requestedToken -> 2:1 ratio

        uint256 expectedAmountOut = 2e18;

        uint256 amountOut = settlementEngine.getAmountOut(
            address(requestedToken),
            address(offeredToken),
            AMOUNT_IN
        );

        assertEq(amountOut, expectedAmountOut);

        expectedAmountOut = 0.5e18;

        amountOut = settlementEngine.getAmountOut(
            address(offeredToken),
            address(requestedToken),
            AMOUNT_IN
        );

        assertEq(amountOut, expectedAmountOut);
    }
}
