// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestSetup} from "../TestSetup.t.sol";
import {Orderbook} from "../../src/contracts/Orderbook.sol";

contract UpdateConstraintsTest is TestSetup {
    function test_EncodeDecodeConstraints() public {
        uint256 packed = orderbook.encodeConstraints(
            uint64(validFrom),
            uint64(validUntil),
            uint128(MAX_SLIPPAGE_BPS)
        );

        (
            uint64 _validFromDecoded,
            uint64 _validUntilDecoded,
            uint128 _maxSlippageBpsDecoded
        ) = orderbook.decodeConstraints(packed);

        assertEq(_validFromDecoded, uint64(validFrom));
        assertEq(_validUntilDecoded, uint64(validUntil));
        assertEq(_maxSlippageBpsDecoded, uint128(MAX_SLIPPAGE_BPS));
    }
}
