// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestSetup} from "../TestSetup.t.sol";
import {Orderbook} from "../../src/contracts/Orderbook.sol";

contract CreateEthOfferTest is TestSetup {
    /*//////////////////////////////////////////////////////////////
                            STATE UPDATES
    //////////////////////////////////////////////////////////////*/

    function test_CreateEthOffer_Success() public {
        deal(maker, OFFER_AMOUNT);
        uint256 initialMakerBalance = maker.balance;
        uint256 initialEscrowBalance = address(escrow).balance;

        assertEq(initialMakerBalance, OFFER_AMOUNT);
        assertEq(initialEscrowBalance, 0);

        (
            Orderbook.TokenAmount memory offer,
            Orderbook.Constraints memory constraints
        ) = _generateOfferAmountsAndConstraints(
                orderbook.ETH_ADDRESS(),
                OFFER_AMOUNT,
                MIN_FILL_AMOUNT,
                MAX_SLIPPAGE_BPS,
                validFrom,
                validUntil
            );

        bytes32 expectedOrderId = keccak256(
            abi.encode(
                maker,
                orderbook.nonce(),
                orderbook.ETH_ADDRESS(),
                OFFER_AMOUNT,
                address(requestedToken)
            )
        );

        vm.startPrank(maker);

        vm.expectEmit(true, true, true, true);
        emit Orderbook.OfferCreated(
            expectedOrderId,
            maker,
            offer,
            address(requestedToken),
            constraints
        );
        orderbook.createEthOffer{value: OFFER_AMOUNT}(
            offer,
            address(requestedToken),
            constraints
        );

        assertEq(maker.balance, initialMakerBalance - OFFER_AMOUNT);
        assertEq(address(escrow).balance, initialEscrowBalance + OFFER_AMOUNT);
    }
}
