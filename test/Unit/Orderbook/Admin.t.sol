// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestSetup} from "../../TestSetup.t.sol";
import {Orderbook} from "../../../src/contracts/Orderbook.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract AdminPrivilegesTest is TestSetup {
    ERC20Mock public newToken;

    function setUp() public override {
        super.setUp();
        newToken = new ERC20Mock();
    }

    /*//////////////////////////////////////////////////////////////
                               ADD TOKEN
    //////////////////////////////////////////////////////////////*/

    function test_AddToken() public {
        (address priceFeed, bool isSupported) = orderbook.tokenInfo(
            address(newToken)
        );
        assertFalse(
            isSupported,
            "Token should not be supported before being added"
        );
        assertEq(
            priceFeed,
            address(0),
            "Data feed should be address zero before being added"
        );

        vm.startPrank(owner);
        vm.expectEmit(true, false, false, false);
        emit Orderbook.TokenAdded(
            address(newToken),
            address(offeredTokenEthFeed)
        );
        orderbook.addToken(address(newToken), address(offeredTokenEthFeed));
        vm.stopPrank();

        (priceFeed, isSupported) = orderbook.tokenInfo(address(newToken));
        assertTrue(isSupported, "Token should be supported after being added");
        assertEq(
            priceFeed,
            address(offeredTokenEthFeed),
            "Data feed should be set correctly after being added"
        );
    }

    /******* NEGATIVE TESTS ********/

    function test_AddToken_Reverts_NonOwner() public {
        vm.prank(maker);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                maker
            )
        );
        orderbook.addToken(address(newToken), address(offeredTokenEthFeed));
    }

    function test_AddToken_RevertsOnZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(Orderbook.Orderbook__ZeroAddress.selector)
        );
        orderbook.addToken(address(0), address(offeredTokenEthFeed));

        vm.expectRevert(
            abi.encodeWithSelector(Orderbook.Orderbook__ZeroAddress.selector)
        );
        orderbook.addToken(address(newToken), address(0));
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              REMOVE TOKEN
    //////////////////////////////////////////////////////////////*/

    function test_RemoveToken() public {
        // First, add the token to ensure it is supported
        vm.startPrank(owner);
        orderbook.addToken(address(newToken), address(offeredTokenEthFeed));
        vm.stopPrank();

        (, bool isSupported) = orderbook.tokenInfo(address(newToken));
        assertTrue(isSupported, "Token should be supported after being added");

        vm.startPrank(owner);
        vm.expectEmit(true, false, false, false);
        emit Orderbook.TokenRemoved(address(newToken));
        orderbook.removeToken(address(newToken));
        vm.stopPrank();

        (, isSupported) = orderbook.tokenInfo(address(newToken));
        assertFalse(
            isSupported,
            "Token should not be supported after being removed"
        );
    }

    /******* NEGATIVE TESTS ********/

    function test_RemoveToken_Reverts_NonOwner() public {
        vm.prank(maker);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                maker
            )
        );
        orderbook.removeToken(address(newToken));
    }

    function test_RemoveToken_RevertsOnZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                Orderbook.Orderbook__UnsupportedToken.selector,
                address(0)
            )
        );
        orderbook.removeToken(address(0));
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                 PAUSE
    //////////////////////////////////////////////////////////////*/

    function test_PauseAndUnpause() public {
        assertFalse(
            orderbook.paused(),
            "Contract should not be paused initially"
        );

        vm.prank(owner);
        orderbook.pause();
        assertTrue(
            orderbook.paused(),
            "Contract should be paused after pausing"
        );

        vm.prank(owner);
        orderbook.unpause();
        assertFalse(
            orderbook.paused(),
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
        orderbook.pause();
    }

    function test_unPauseReverts_NonOwner() public {
        vm.prank(owner);
        orderbook.pause();

        vm.prank(maker);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                maker
            )
        );
        orderbook.unpause();
    }

    /*//////////////////////////////////////////////////////////////
                                UPGRADE
    //////////////////////////////////////////////////////////////*/

    function test_UpgradeOrderbook() public {
        OrderbookV2 newImplementation = new OrderbookV2();

        vm.prank(owner);
        orderbook.upgradeToAndCall(address(newImplementation), "");

        assertEq(
            OrderbookV2(address(orderbook)).version(),
            "v2",
            "Contract should be upgraded to new implementation"
        );
    }

    /******* NEGATIVE TESTS ********/

    function test_UpgradeReverts_NonOwner() public {
        OrderbookV2 newImplementation = new OrderbookV2();

        vm.prank(maker);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                maker
            )
        );
        orderbook.upgradeToAndCall(address(newImplementation), "");
    }

    function test_UpgradeReverts_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(Orderbook.Orderbook__ZeroAddress.selector)
        );
        orderbook.upgradeToAndCall(address(0), "");
    }
}

contract OrderbookV2 is Orderbook {
    function version() external pure returns (string memory) {
        return "v2";
    }
}
