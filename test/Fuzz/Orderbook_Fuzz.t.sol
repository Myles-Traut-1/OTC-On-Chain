// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestSetup} from "../TestSetup.t.sol";
import {Orderbook} from "../../src/contracts/Orderbook.sol";
import {Escrow} from "../../src/contracts/Escrow.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract OrderbookFuzzTest is TestSetup {
    function test_Fuzz_createTokenOffer(
        uint256 _offeredAmount,
        uint64 _validFrom,
        uint64 _validUntil,
        uint128 _maxSlippageBps
    ) public {
        _offeredAmount = bound(_offeredAmount, 1, INITIAL_MAKER_BALANCE);
    }
}
