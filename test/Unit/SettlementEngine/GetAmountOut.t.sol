// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestSetup} from "../../TestSetup.t.sol";
import {SettlementEngine} from "../../../src/contracts/SettlementEngine.sol";

import {console} from "forge-std/console.sol";

contract GetAmountOutTest is TestSetup {
    /*//////////////////////////////////////////////////////////////
                           GET AMOUNT OUT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetAmountOut_OfferETH() public {
        // 1000 requestedToken = 1 ETH
        uint256 amountOut = settlementEngine.getAmountOut(
            ETH,
            address(requestedToken),
            1000e18
        );

        console.log("Requested Token Amount Out:", amountOut);

        assertEq(amountOut, 1e18);
    }

    function test_GetAmountOut_RequestedETH() public {
        // 2000 offeredToken = 1 ETH
        uint256 amountOut = settlementEngine.getAmountOut(
            address(offeredToken),
            ETH,
            1e18
        );

        console.log("Requested Token Amount Out:", amountOut);

        assertEq(amountOut, 2000e18);
    }
}
