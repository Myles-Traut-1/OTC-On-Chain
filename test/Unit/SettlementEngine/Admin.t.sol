// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestSetup} from "../../TestSetup.t.sol";
import {SettlementEngine} from "../../../src/contracts/SettlementEngine.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract AdminPrivalgesTest is TestSetup {
    address newOrderbook = makeAddr("newOrderbook");
    address nonOwner = makeAddr("nonOwner");

    /*//////////////////////////////////////////////////////////////
                             SET ORDERBOOK
    //////////////////////////////////////////////////////////////*/

    function test_SetOrderBook() public {
        assertEq(address(settlementEngine.orderbook()), address(orderbook));

        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit SettlementEngine.OrderbookSet(newOrderbook);
        settlementEngine.setOrderbook(newOrderbook);

        assertEq(address(settlementEngine.orderbook()), newOrderbook);
    }

    /******* NEGATIVE TESTS ********/

    function test_SetOrderBook_AddressZero() public {
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                SettlementEngine.SettlementEngine__AddressZero.selector
            )
        );
        settlementEngine.setOrderbook(address(0));
    }

    function test_SetOrderBook_OnlyOwner() public {
        vm.startPrank(nonOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                nonOwner
            )
        );
        settlementEngine.setOrderbook(newOrderbook);
    }

    /*//////////////////////////////////////////////////////////////
                                UPGRADE
    //////////////////////////////////////////////////////////////*/

    function test_UpgradeSettlementEngine() public {
        SettlementEngineV2 newImplementation = new SettlementEngineV2();

        vm.prank(owner);
        settlementEngine.upgradeToAndCall(address(newImplementation), "");
        assertEq(
            SettlementEngineV2(address(settlementEngine)).version(),
            "v2",
            "Contract should be upgraded to new implementation"
        );
    }

    /******* NEGATIVE TESTS ********/

    function test_UpgradeReverts_NonOwner() public {
        SettlementEngineV2 newImplementation = new SettlementEngineV2();

        vm.prank(maker);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                maker
            )
        );
        settlementEngine.upgradeToAndCall(address(newImplementation), "");
    }

    function test_UpgradeReverts_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                SettlementEngine.SettlementEngine__AddressZero.selector
            )
        );
        settlementEngine.upgradeToAndCall(address(0), "");
    }
}

contract SettlementEngineV2 is SettlementEngine {
    function version() external pure returns (string memory) {
        return "v2";
    }
}
