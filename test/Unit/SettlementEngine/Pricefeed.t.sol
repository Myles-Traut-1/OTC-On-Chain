// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestSetup} from "../../TestSetup.t.sol";
import {SettlementEngine} from "../../../src/contracts/SettlementEngine.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "@chainlink/src/v0.8/tests/MockV3Aggregator.sol";

contract PricefeedTest is TestSetup {
    function test_Pricefeed_StaleRevert() public {
        vm.warp(block.timestamp + 1 hours + 1); // Move time forward to make pricefeed stale

        vm.expectRevert(
            abi.encodeWithSelector(
                SettlementEngine.SettlementEngine__PriceFeedStale.selector
            )
        );
        settlementEngine.getAmountOut(
            address(offeredToken),
            address(requestedToken),
            1e18
        );
    }
}
