// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestSetup} from "../../TestSetup.t.sol";
import {IEscrow} from "../../../src/interfaces/IEscrow.sol";

contract TransferFundsTest is TestSetup {
    address public recipient = makeAddr("recipient");
    address public noEthReceiver;

    function setUp() public override {
        super.setUp();

        // First, mint ETH and offered tokens to the escrow contract
        deal(address(escrow), OFFER_AMOUNT);
        offeredToken.mint(address(escrow), OFFER_AMOUNT);

        // Then increase the escrow internal balance for the offered token and ETH
        vm.startPrank(address(orderbook));
        escrow.increaseBalance(ETH, OFFER_AMOUNT);
        escrow.increaseBalance(address(offeredToken), OFFER_AMOUNT);
        vm.stopPrank();

        assertEq(address(escrow).balance, OFFER_AMOUNT);
        assertEq(offeredToken.balanceOf(address(escrow)), OFFER_AMOUNT);

        uint256 initialEscrowBalance = escrow.getTokenBalance(ETH);
        uint256 initialTokenBalance = escrow.getTokenBalance(
            address(offeredToken)
        );

        assertEq(initialEscrowBalance, OFFER_AMOUNT);
        assertEq(initialTokenBalance, OFFER_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                          TRANSFER FUNDS
    //////////////////////////////////////////////////////////////*/

    function test_TransferFunds_Success_Eth_DecreasesTokenBalance() public {
        assertEq(maker.balance, INITIAL_MAKER_BALANCE);
        vm.prank(address(orderbook));
        vm.expectEmit(true, true, false, true);
        emit IEscrow.FundsTransferred(ETH, maker, OFFER_AMOUNT);
        escrow.transferFunds(ETH, maker, OFFER_AMOUNT);
        assertEq(maker.balance, INITIAL_MAKER_BALANCE + OFFER_AMOUNT);
        assertEq(escrow.getTokenBalance(ETH), 0);
    }

    function test_TransferFunds_Success_Token_DecreasesTokenBalance() public {
        assertEq(offeredToken.balanceOf(maker), INITIAL_MAKER_BALANCE);
        vm.prank(address(orderbook));
        vm.expectEmit(true, true, false, true);
        emit IEscrow.FundsTransferred(
            address(offeredToken),
            maker,
            OFFER_AMOUNT
        );
        escrow.transferFunds(address(offeredToken), maker, OFFER_AMOUNT);
        assertEq(
            offeredToken.balanceOf(maker),
            INITIAL_MAKER_BALANCE + OFFER_AMOUNT
        );
        assertEq(escrow.getTokenBalance(address(offeredToken)), 0);
    }

    /*//////////////////////////////////////////////////////////////
                             NEGATIVE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_reverts_TransferFunds_OnlyOrderbook() public {
        vm.expectRevert(
            abi.encodeWithSelector(IEscrow.Escrow__Unauthorized.selector)
        );
        escrow.transferFunds(ETH, recipient, OFFER_AMOUNT);
    }

    function test_TransferFunds_FailsToSendEth() public {
        // Deploy a contract that cannot receive ETH
        noEthReceiver = address(new NoEthReceiver());

        vm.prank(address(orderbook));
        vm.expectRevert(
            abi.encodeWithSelector(IEscrow.Escrow__EthTransferFailed.selector)
        );
        escrow.transferFunds(ETH, noEthReceiver, OFFER_AMOUNT);
    }
}

contract NoEthReceiver {
    receive() external payable {
        revert("Cannot receive ETH");
    }
}
