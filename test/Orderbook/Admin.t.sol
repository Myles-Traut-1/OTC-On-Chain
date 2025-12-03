// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestSetup} from "../TestSetup.t.sol";
import {Orderbook} from "../../src/contracts/Orderbook.sol";
import {Escrow} from "../../src/contracts/Escrow.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

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
        bool isSupported = orderbook.supportedTokens(address(newToken));
        assertFalse(
            isSupported,
            "Token should not be supported before being added"
        );

        vm.startPrank(owner);
        vm.expectEmit(true, false, false, false);
        emit Orderbook.TokenAdded(address(newToken));
        orderbook.addToken(address(newToken));
        vm.stopPrank();

        isSupported = orderbook.supportedTokens(address(newToken));
        assertTrue(isSupported, "Token should be supported after being added");
    }

    /*//////////////////////////////////////////////////////////////
                              REMOVE TOKEN
    //////////////////////////////////////////////////////////////*/

    function test_RemoveToken() public {
        // First, add the token to ensure it is supported
        vm.startPrank(owner);
        orderbook.addToken(address(newToken));
        vm.stopPrank();

        bool isSupported = orderbook.supportedTokens(address(newToken));
        assertTrue(isSupported, "Token should be supported after being added");

        vm.startPrank(owner);
        vm.expectEmit(true, false, false, false);
        emit Orderbook.TokenRemoved(address(newToken));
        orderbook.removeToken(address(newToken));
        vm.stopPrank();

        isSupported = orderbook.supportedTokens(address(newToken));
        assertFalse(
            isSupported,
            "Token should not be supported after being removed"
        );
    }
}
