// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestSetup} from "../../TestSetup.t.sol";
import {Escrow} from "../../../src/contracts/Escrow.sol";
import {UUPSProxy} from "../../../src/contracts/UUPSProxy.sol";

contract EscrowHarness is Escrow {
    function exposedDecreaseBalance(address _token, uint256 _amount) external {
        _decreaseBalance(_token, _amount);
    }
}

contract DecreaseBalanceTest is TestSetup {
    EscrowHarness public escrowHarness;
    EscrowHarness public escrowHarnessImplementation;
    UUPSProxy public escrowHarnessProxy;

    function setUp() public override {
        super.setUp();

        vm.startPrank(owner);
        escrowHarness = _deployHarness();
        escrowHarness.setOrderbook(address(orderbook));
        vm.stopPrank();

        // First, increase the escrow balance for the offered token and ETH
        deal(address(escrowHarness), OFFER_AMOUNT);
        offeredToken.mint(address(escrowHarness), OFFER_AMOUNT);

        vm.startPrank(address(orderbook));
        escrowHarness.increaseBalance(ETH, OFFER_AMOUNT);
        escrowHarness.increaseBalance(address(offeredToken), OFFER_AMOUNT);
        vm.stopPrank();

        assertEq(address(escrowHarness).balance, OFFER_AMOUNT);
        assertEq(offeredToken.balanceOf(address(escrowHarness)), OFFER_AMOUNT);
        uint256 initialEscrowBalance = escrowHarness.getTokenBalance(ETH);
        uint256 initialTokenBalance = escrowHarness.getTokenBalance(
            address(offeredToken)
        );

        assertEq(initialEscrowBalance, OFFER_AMOUNT);
        assertEq(initialTokenBalance, OFFER_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                        DECREASE BALANCE
    //////////////////////////////////////////////////////////////*/

    function test_DecreaseBalance_Success_Eth() public {
        uint256 initialEscrowBalance = escrowHarness.getTokenBalance(ETH);
        assertEq(initialEscrowBalance, OFFER_AMOUNT);

        vm.prank(address(orderbook));
        escrowHarness.exposedDecreaseBalance(ETH, OFFER_AMOUNT);

        uint256 finalEscrowBalance = escrowHarness.getTokenBalance(ETH);
        assertEq(finalEscrowBalance, 0);
    }

    function test_DecreaseBalance_Success_Token() public {
        uint256 initialEscrowBalance = escrowHarness.getTokenBalance(
            address(offeredToken)
        );
        assertEq(initialEscrowBalance, OFFER_AMOUNT);

        vm.prank(address(orderbook));
        escrowHarness.exposedDecreaseBalance(
            address(offeredToken),
            OFFER_AMOUNT
        );

        uint256 finalEscrowBalance = escrowHarness.getTokenBalance(
            address(offeredToken)
        );
        assertEq(finalEscrowBalance, 0);
    }

    /*//////////////////////////////////////////////////////////////
                              INTEGRATION
    //////////////////////////////////////////////////////////////*/

    function test_CancelOffer_DecreasesEscrowBalance_Eth() public {
        // This tests ETH sent to the escrow and not the escrowHarness contract
        bytes32 offerId = _createAndReturnOffer(ETH, address(requestedToken));

        uint256 initialEscrowBalance = escrow.getTokenBalance(ETH);
        assertEq(initialEscrowBalance, OFFER_AMOUNT);
        assertEq(maker.balance, INITIAL_MAKER_BALANCE - OFFER_AMOUNT);

        vm.prank(maker);
        orderbook.cancelOffer(offerId);

        uint256 finalEscrowBalance = escrow.getTokenBalance(ETH);
        assertEq(finalEscrowBalance, 0);
        assertEq(maker.balance, INITIAL_MAKER_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _deployHarness() internal returns (EscrowHarness) {
        escrowHarnessImplementation = new EscrowHarness();
        escrowHarnessProxy = new UUPSProxy(
            address(escrowHarnessImplementation),
            ""
        );
        EscrowHarness escrowHarness = EscrowHarness(
            payable(address(escrowHarnessProxy))
        );
        escrowHarness.initialize();
        return escrowHarness;
    }
}
