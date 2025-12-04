// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestSetup} from "../../TestSetup.t.sol";
import {Escrow} from "../../../src/contracts/Escrow.sol";

import {console} from "forge-std/console.sol";

contract IncreaseBalanceTest is TestSetup {
    /*//////////////////////////////////////////////////////////////
                        INCREASE BALANCE
    //////////////////////////////////////////////////////////////*/

    function test_IncreaseBalance_Success_Eth() public {
        uint256 initialEscrowBalance = escrow.getTokenBalance(ETH);
        assertEq(initialEscrowBalance, 0);

        vm.prank(address(orderbook));
        escrow.increaseBalance(ETH, OFFER_AMOUNT);

        uint256 finalEscrowBalance = escrow.getTokenBalance(ETH);
        assertEq(finalEscrowBalance, OFFER_AMOUNT);
    }

    function test_IncreaseBalance_Success_Token() public {
        uint256 initialEscrowBalance = escrow.getTokenBalance(
            address(offeredToken)
        );
        assertEq(initialEscrowBalance, 0);

        vm.prank(address(orderbook));
        escrow.increaseBalance(address(offeredToken), OFFER_AMOUNT);

        uint256 finalEscrowBalance = escrow.getTokenBalance(
            address(offeredToken)
        );
        assertEq(finalEscrowBalance, OFFER_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                             NEGATIVE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Reverts_IncreaseBalance_OnlyOrderbook() public {
        vm.expectRevert(
            abi.encodeWithSelector(Escrow.Escrow__Unauthorized.selector)
        );
        escrow.increaseBalance(ETH, OFFER_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                              INTEGRATION
    //////////////////////////////////////////////////////////////*/

    function test_CreateOffer_IncreasesEscrowBalance_Eth() public {
        uint256 initialEscrowBalance = escrow.getTokenBalance(ETH);
        uint256 ethbalance = address(escrow).balance;
        assertEq(ethbalance, 0);
        assertEq(initialEscrowBalance, 0);

        _createAndReturnOffer(ETH, address(requestedToken));

        ethbalance = address(escrow).balance;
        assertEq(ethbalance, OFFER_AMOUNT);

        uint256 finalEscrowBalance = escrow.getTokenBalance(ETH);
        assertEq(finalEscrowBalance, OFFER_AMOUNT);
    }

    function test_CreateOffer_IncreasesEscrowBalance_Token() public {
        uint256 initialEscrowBalance = escrow.getTokenBalance(
            address(offeredToken)
        );
        uint256 tokenbalance = offeredToken.balanceOf(address(escrow));

        assertEq(initialEscrowBalance, 0);
        assertEq(tokenbalance, 0);

        _createAndReturnOffer(address(offeredToken), address(requestedToken));

        tokenbalance = offeredToken.balanceOf(address(escrow));
        assertEq(tokenbalance, OFFER_AMOUNT);

        uint256 finalEscrowBalance = escrow.getTokenBalance(
            address(offeredToken)
        );
        assertEq(finalEscrowBalance, OFFER_AMOUNT);
    }
}
