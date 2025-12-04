// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestSetup} from "../TestSetup.t.sol";
import {Orderbook} from "../../src/contracts/Orderbook.sol";
import {Escrow} from "../../src/contracts/Escrow.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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

        (address priceFeed, bool isSupported) = orderbook.tokenInfo(
            address(newToken)
        );
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
}
