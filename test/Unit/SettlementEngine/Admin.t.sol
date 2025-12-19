// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestSetup} from "../../TestSetup.t.sol";

import {ISettlementEngine} from "../../../src/interfaces/ISettlementEngine.sol";
import {SettlementEngine} from "../../../src/contracts/SettlementEngine.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract AdminPrivilegesTest is TestSetup {
    address newOrderbook = makeAddr("newOrderbook");
    address nonOwner = makeAddr("nonOwner");

    /*//////////////////////////////////////////////////////////////
                             SET ORDERBOOK
    //////////////////////////////////////////////////////////////*/

    function test_SetOrderBook() public {
        assertEq(address(settlementEngine.orderbook()), address(orderbook));

        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit ISettlementEngine.OrderbookSet(newOrderbook);
        settlementEngine.setOrderbook(newOrderbook);

        assertEq(address(settlementEngine.orderbook()), newOrderbook);
    }

    /******* NEGATIVE TESTS ********/

    function test_SetOrderBook_AddressZero() public {
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISettlementEngine.SettlementEngine__AddressZero.selector
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
                    SET STALENESS THRESHOLD
    //////////////////////////////////////////////////////////////*/

    function test_SetStalenessThreshold() public {
        uint256 newThreshold = 2 hours; // 2 hours
        assertEq(
            settlementEngine.stalenessThreshold(),
            1 hours,
            "Initial staleness threshold should be 1 hour"
        );

        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit ISettlementEngine.StalenessThresholdSet(1 hours, newThreshold);
        settlementEngine.setStalenessThreshold(newThreshold);
        vm.stopPrank();

        assertEq(
            settlementEngine.stalenessThreshold(),
            newThreshold,
            "Staleness threshold should be updated"
        );
    }

    /******* NEGATIVE TESTS ********/

    function test_SetStalenessThreshold_Reverts_WhenZero() public {
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISettlementEngine.SettlementEngine__ThresholdZero.selector
            )
        );
        settlementEngine.setStalenessThreshold(0);
        vm.stopPrank();
    }

    function test_SetStalenessThreshold_Reverts_NonOwner() public {
        vm.startPrank(maker);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                maker
            )
        );
        settlementEngine.setStalenessThreshold(2 hours);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                 PAUSE
    //////////////////////////////////////////////////////////////*/

    function test_PauseAndUnpause() public {
        assertFalse(escrow.paused(), "Contract should not be paused initially");

        vm.prank(owner);
        escrow.pause();
        assertTrue(escrow.paused(), "Contract should be paused after pausing");

        vm.prank(owner);
        escrow.unpause();
        assertFalse(
            escrow.paused(),
            "Contract should not be paused after unpausing"
        );
    }

    /******* NEGATIVE TESTS ********/

    function test_pauseReverts_NonOwner() public {
        vm.prank(maker);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                maker
            )
        );
        settlementEngine.pause();
    }

    function test_unPauseReverts_NonOwner() public {
        vm.prank(owner);
        settlementEngine.pause();

        vm.prank(maker);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                maker
            )
        );
        settlementEngine.unpause();
    }

    /*//////////////////////////////////////////////////////////////
                                UPGRADE
    //////////////////////////////////////////////////////////////*/

    function test_UpgradeSettlementEngine() public pauseContract {
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

    function test_UpgradeReverts_NonOwner() public pauseContract {
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

    function test_UpgradeReverts_ZeroAddress() public pauseContract {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISettlementEngine.SettlementEngine__AddressZero.selector
            )
        );
        settlementEngine.upgradeToAndCall(address(0), "");
    }

    function test_Upgrade_Reverts_WhenNotPaused() public {
        SettlementEngineV2 newImplementation = new SettlementEngineV2();

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(Pausable.ExpectedPause.selector)
        );
        settlementEngine.upgradeToAndCall(address(newImplementation), "");
    }

    modifier pauseContract() {
        vm.prank(owner);
        settlementEngine.pause();
        _;
    }
}

contract SettlementEngineV2 is SettlementEngine {
    function version() external pure returns (string memory) {
        return "v2";
    }
}
