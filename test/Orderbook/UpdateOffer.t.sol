 // // SPDX-License-Identifier: MIT
// pragma solidity 0.8.25;

// import {TestSetup} from "../TestSetup.t.sol";
// import {Orderbook} from "../../src/contracts/Orderbook.sol";

// contract UpdateOfferTest is TestSetup {
//     uint256 public newOfferAmount = OFFER_AMOUNT / 2;
//     uint256 public newMinFillAmount = MIN_FILL_AMOUNT / 2;
//     uint256 public newMaxSlippageBps = MAX_SLIPPAGE_BPS / 2;
//     uint256 public newValidFrom = validFrom + 100;
//     uint256 public newValidUntil = validUntil + 100;

//     address public newRequestedToken = makeAddr("newRequestedToken");

//     /*//////////////////////////////////////////////////////////////
//                             STATE UPDATES
//     //////////////////////////////////////////////////////////////*/

//     function test_UpdateOffer_SameRequestedToken_Success() public {
//         bytes32 offerId = _createAndReturnOffer(address(requestedToken));

//         (
//             address maker_,
//             Orderbook.TokenAmount memory offer_,
//             address requestedToken_,
//             Orderbook.Constraints memory constraints_,
//             uint256 remainingAmount
//         ) = orderbook.offers(offerId);

//         assertEq(maker_, maker);
//         assertEq(offer_.token, address(offeredToken));
//         assertEq(offer_.amount, OFFER_AMOUNT);
//         assertEq(requestedToken_, address(requestedToken));
//         assertEq(constraints_.minFillAmount, MIN_FILL_AMOUNT);
//         assertEq(constraints_.maxSlippageBps, MAX_SLIPPAGE_BPS);
//         assertEq(constraints_.validFrom, validFrom);
//         assertEq(constraints_.validUntil, validUntil);
//         assertEq(remainingAmount, OFFER_AMOUNT);

//         (
//             Orderbook.TokenAmount memory newOffer,
//             Orderbook.Constraints memory newConstraints
//         ) = _generateOfferAmountsAndConstraints(
//                 address(offeredToken),
//                 newOfferAmount,
//                 newMinFillAmount,
//                 newMaxSlippageBps,
//                 newValidFrom,
//                 newValidUntil
//             );

//         vm.startPrank(maker);

//         vm.expectEmit(true, true, true, true);
//         emit Orderbook.OfferUpdated(
//             offerId,
//             maker,
//             newOffer,
//             address(requestedToken),
//             newConstraints
//         );

//         orderbook.updateOffer(
//             offerId,
//             newOffer,
//             newConstraints,
//             address(requestedToken)
//         );
//         vm.stopPrank();

//         (
//             maker_,
//             offer_,
//             requestedToken_,
//             constraints_,
//             remainingAmount
//         ) = orderbook.offers(offerId);

//         assertEq(offer_.token, address(offeredToken));
//         assertEq(offer_.amount, newOfferAmount);
//         assertEq(constraints_.minFillAmount, newMinFillAmount);
//         assertEq(constraints_.maxSlippageBps, newMaxSlippageBps);
//         assertEq(constraints_.validFrom, newValidFrom);
//         assertEq(constraints_.validUntil, newValidUntil);
//         assertEq(remainingAmount, OFFER_AMOUNT);
//         assertEq(requestedToken_, address(requestedToken));
//         assertEq(maker_, maker);
//     }

//     function test_UpdateOffer_DifferentRequestedToken_Success() public {
//         bytes32 offerId = _createAndReturnOffer(address(requestedToken));

//         (
//             address maker_,
//             Orderbook.TokenAmount memory offer_,
//             address requestedToken_,
//             Orderbook.Constraints memory constraints_,
//             uint256 remainingAmount
//         ) = orderbook.offers(offerId);

//         assertEq(maker_, maker);
//         assertEq(offer_.token, address(offeredToken));
//         assertEq(offer_.amount, OFFER_AMOUNT);
//         assertEq(requestedToken_, address(requestedToken));
//         assertEq(constraints_.minFillAmount, MIN_FILL_AMOUNT);
//         assertEq(constraints_.maxSlippageBps, MAX_SLIPPAGE_BPS);
//         assertEq(constraints_.validFrom, validFrom);
//         assertEq(constraints_.validUntil, validUntil);
//         assertEq(remainingAmount, OFFER_AMOUNT);

//         (
//             Orderbook.TokenAmount memory newOffer,
//             Orderbook.Constraints memory newConstraints
//         ) = _generateOfferAmountsAndConstraints(
//                 address(offeredToken),
//                 newOfferAmount,
//                 newMinFillAmount,
//                 newMaxSlippageBps,
//                 newValidFrom,
//                 newValidUntil
//             );

//         vm.startPrank(maker);

//         vm.expectEmit(true, true, true, true);
//         emit Orderbook.OfferUpdated(
//             offerId,
//             maker,
//             newOffer,
//             address(newRequestedToken),
//             newConstraints
//         );

//         orderbook.updateOffer(
//             offerId,
//             newOffer,
//             newConstraints,
//             address(newRequestedToken)
//         );
//         vm.stopPrank();

//         (
//             maker_,
//             offer_,
//             requestedToken_,
//             constraints_,
//             remainingAmount
//         ) = orderbook.offers(offerId);

//         assertEq(offer_.token, address(offeredToken));
//         assertEq(offer_.amount, newOfferAmount);
//         assertEq(constraints_.minFillAmount, newMinFillAmount);
//         assertEq(constraints_.maxSlippageBps, newMaxSlippageBps);
//         assertEq(constraints_.validFrom, newValidFrom);
//         assertEq(constraints_.validUntil, newValidUntil);
//         assertEq(remainingAmount, OFFER_AMOUNT);
//         assertEq(requestedToken_, address(newRequestedToken));
//         assertEq(maker_, maker);
//     }

//     /*//////////////////////////////////////////////////////////////
//                              NEGATIVE TESTS
//     //////////////////////////////////////////////////////////////*/

//     function test_UpdateOffer_Reverts_NotOfferCreator() public {
//         address invalidCaller = makeAddr("invalidCaller");
//         bytes32 offerId = _createAndReturnOffer(address(requestedToken));

//         (
//             Orderbook.TokenAmount memory newOffer,
//             Orderbook.Constraints memory newConstraints
//         ) = _generateOfferAmountsAndConstraints(
//                 address(offeredToken),
//                 newOfferAmount,
//                 newMinFillAmount,
//                 newMaxSlippageBps,
//                 newValidFrom,
//                 newValidUntil
//             );

//         vm.startPrank(invalidCaller);

//         vm.expectRevert(Orderbook.Orderbook__NotOfferCreator.selector);
//         orderbook.updateOffer(
//             offerId,
//             newOffer,
//             newConstraints,
//             address(requestedToken)
//         );
//     }

//     function test_UpdateOffer_RevertsOnZeroAddress() public {
//         bytes32 offerId = _createAndReturnOffer(address(requestedToken));

//         (
//             Orderbook.TokenAmount memory newOffer,
//             Orderbook.Constraints memory newConstraints
//         ) = _generateOfferAmountsAndConstraints(
//                 address(offeredToken),
//                 newOfferAmount,
//                 newMinFillAmount,
//                 newMaxSlippageBps,
//                 newValidFrom,
//                 newValidUntil
//             );

//         vm.startPrank(maker);

//         vm.expectRevert(Orderbook.Orderbook__ZeroAddress.selector);
//         orderbook.updateOffer(offerId, newOffer, newConstraints, address(0));
//         vm.stopPrank();
//     }

//     function test_UpdateOffer_RevertsIfStatusNotOpen() public {
//         bytes32 offerId = _createAndReturnOffer(address(requestedToken));

//         // Simulate that the offer is in progress
//         orderbook.contribute(offerId);

//         (
//             Orderbook.TokenAmount memory newOffer,
//             Orderbook.Constraints memory newConstraints
//         ) = _generateOfferAmountsAndConstraints(
//                 address(offeredToken),
//                 newOfferAmount,
//                 newMinFillAmount,
//                 newMaxSlippageBps,
//                 newValidFrom,
//                 newValidUntil
//             );

//         vm.startPrank(maker);

//         vm.expectRevert(Orderbook.Orderbook__OfferNotOpen.selector);
//         orderbook.updateOffer(
//             offerId,
//             newOffer,
//             newConstraints,
//             address(requestedToken)
//         );
//         vm.stopPrank();
//     }

//     function test_UpdateOffer_RevertsOnInvalidTokenAmounts() public {
//         bytes32 offerId = _createAndReturnOffer(address(requestedToken));

//         (
//             Orderbook.TokenAmount memory newOffer,
//             Orderbook.Constraints memory newConstraints
//         ) = _generateOfferAmountsAndConstraints(
//                 address(offeredToken),
//                 0,
//                 newMinFillAmount,
//                 newMaxSlippageBps,
//                 newValidFrom,
//                 newValidUntil
//             );

//         vm.startPrank(maker);

//         vm.expectRevert(Orderbook.Orderbook__InvalidTokenAmount.selector);
//         orderbook.updateOffer(
//             offerId,
//             newOffer,
//             newConstraints,
//             address(requestedToken)
//         );
//         vm.stopPrank();

//         (newOffer, newConstraints) = _generateOfferAmountsAndConstraints(
//             address(0),
//             newOfferAmount,
//             newMinFillAmount,
//             newMaxSlippageBps,
//             newValidFrom,
//             newValidUntil
//         );

//         vm.startPrank(maker);

//         vm.expectRevert(Orderbook.Orderbook__ZeroAddress.selector);
//         orderbook.updateOffer(
//             offerId,
//             newOffer,
//             newConstraints,
//             address(requestedToken)
//         );
//         vm.stopPrank();
//     }

//     function test_UpdateOffer_RevertsOnInvalidConstraints() public {
//         bytes32 offerId = _createAndReturnOffer(address(requestedToken));

//         // Invalid minFillAmount

//         (
//             Orderbook.TokenAmount memory newOffer,
//             Orderbook.Constraints memory newConstraints
//         ) = _generateOfferAmountsAndConstraints(
//                 address(offeredToken),
//                 newOfferAmount,
//                 0,
//                 newMaxSlippageBps,
//                 newValidFrom,
//                 newValidUntil
//             );

//         vm.startPrank(maker);

//         vm.expectRevert(Orderbook.Orderbook__InvalidConstraints.selector);
//         orderbook.updateOffer(
//             offerId,
//             newOffer,
//             newConstraints,
//             address(requestedToken)
//         );

//         // Invalid maxSlippageBps

//         (newOffer, newConstraints) = _generateOfferAmountsAndConstraints(
//             address(offeredToken),
//             newOfferAmount,
//             newMinFillAmount,
//             0,
//             newValidFrom,
//             newValidUntil
//         );

//         // invalid validFrom and validUntil

//         vm.expectRevert(Orderbook.Orderbook__InvalidConstraints.selector);
//         orderbook.updateOffer(
//             offerId,
//             newOffer,
//             newConstraints,
//             address(requestedToken)
//         );

//         (newOffer, newConstraints) = _generateOfferAmountsAndConstraints(
//             address(offeredToken),
//             newOfferAmount,
//             newMinFillAmount,
//             newMaxSlippageBps,
//             block.timestamp - 1,
//             newValidUntil
//         );

//         vm.expectRevert(Orderbook.Orderbook__InvalidConstraints.selector);
//         orderbook.updateOffer(
//             offerId,
//             newOffer,
//             newConstraints,
//             address(requestedToken)
//         );

//         (newOffer, newConstraints) = _generateOfferAmountsAndConstraints(
//             address(offeredToken),
//             newOfferAmount,
//             newMinFillAmount,
//             newMaxSlippageBps,
//             newValidFrom,
//             newValidFrom
//         );

//         vm.expectRevert(Orderbook.Orderbook__InvalidConstraints.selector);
//         orderbook.updateOffer(
//             offerId,
//             newOffer,
//             newConstraints,
//             address(requestedToken)
//         );
//         vm.stopPrank();
//     }
// }
