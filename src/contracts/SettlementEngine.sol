// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {
    Ownable2Step,
    Ownable
} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {
    IERC20Metadata
} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {
    AggregatorV3Interface
} from "@chainlink/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {Orderbook} from "./Orderbook.sol";

import {console} from "forge-std/console.sol";

contract SettlementEngine is Ownable2Step {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error SettlementEngine__AddressZero();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event OrderbookSet(address indexed orderbook);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier checkZeroAddress(address _addr) {
        _checkZeroAddress(_addr);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    Orderbook public orderbook;

    uint256 public constant PRECISION = 1e18;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() Ownable(msg.sender) {}

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setOrderbook(
        address _orderbook
    ) external onlyOwner checkZeroAddress(_orderbook) {
        orderbook = Orderbook(_orderbook);

        emit OrderbookSet(_orderbook);
    }

    function getAmountOut(
        address _offeredToken,
        address _requestedToken,
        uint256 _amountIn
    ) external view returns (uint256 amountOut) {
        // handle case for ETH as offered token
        if (_offeredToken == orderbook.ETH_ADDRESS()) {
            // Requested Token -> ETH feed address
            // Offer ETH need to get Requested Token / ETH price feed
            (address requestedTokenFeedAddress, ) = orderbook.tokenInfo(
                _requestedToken
            );
            AggregatorV3Interface requestedTokenFeed = AggregatorV3Interface(
                requestedTokenFeedAddress
            );

            uint256 requestedTokenDecimals = IERC20Metadata(_requestedToken)
                .decimals();

            // Get price of requested token for 1 ETH
            (, int256 requestedTokenPrice, , , ) = requestedTokenFeed
                .latestRoundData();

            // Adjust requestedTokenPrice to 18 decimals
            uint256 adjustedRequestedTokenPrice = (
                (uint256(requestedTokenPrice) * 10 ** 10)
            );

            // Amount out of ETH to return for requested amount in of requested token
            uint256 ajustedAmountIn = _amountIn * PRECISION;

            amountOut =
                ((ajustedAmountIn * (10 ** requestedTokenDecimals)) /
                    adjustedRequestedTokenPrice) /
                PRECISION;
        }

        // handle case for ETH as requested token
        else if (_requestedToken == orderbook.ETH_ADDRESS()) {
            // Offered Token -> ETH feed address
            // Offering Token need to get Offered Token / ETH price feed
            (address offeredTokenFeedAddress, ) = orderbook.tokenInfo(
                _offeredToken
            );
            AggregatorV3Interface offeredTokenFeed = AggregatorV3Interface(
                offeredTokenFeedAddress
            );

            uint256 offeredTokenDecimals = IERC20Metadata(_offeredToken)
                .decimals();

            // Get price of offered token for 1 ETH
            (, int256 offeredTokenPrice, , , ) = offeredTokenFeed
                .latestRoundData();

            console.log("Offered Token Price:", offeredTokenPrice);

            // Adjust offeredTokenPrice to 18 decimals
            uint256 adjustedOfferedTokenPrice = (
                (uint256(offeredTokenPrice) * 10 ** 10)
            );

            console.log(
                "Ajusted Offered Token Price:",
                adjustedOfferedTokenPrice
            );

            // Amount out of offered to return for requested amount of ETH

            amountOut = (_amountIn * adjustedOfferedTokenPrice) / PRECISION;

            console.log("Amount Out:", amountOut);
        }

        // (address requestedTokenFeedAddress, ) = orderbook.tokenInfo(
        //     _requestedToken
        // );
        // (address offeredTokenFeedAddress, ) = orderbook.tokenInfo(
        //     _offeredToken
        // );

        // AggregatorV3Interface requestedTokenFeed = AggregatorV3Interface(
        //     requestedTokenFeedAddress
        // );
        // AggregatorV3Interface offeredTokenFeed = AggregatorV3Interface(
        //     offeredTokenFeedAddress
        // );

        // (, int256 requestedTokenPrice, , , ) = requestedTokenFeed
        //     .latestRoundData();
        // (, int256 offeredTokenPrice, , , ) = offeredTokenFeed.latestRoundData();

        // uint8 decimalsIn = requestedTokenFeed.decimals();
        // uint8 decimalsOut = offeredTokenFeed.decimals();

        // uint256 tokinInDecimals = IERC20Metadata(_requestedToken).decimals();
        // uint256 tokinOutDecimals = IERC20Metadata(_offeredToken).decimals();

        // // Adjust amountIn to 18 decimals then adjust by PRECISION
        // uint256 adjustedAmountIn = ((_amountIn * uint256(requestedTokenPrice)) /
        //     (10 ** tokinInDecimals)) * PRECISION;

        // // Calculate amountOut and adjust for tokenOut decimals, then divide by PRECISION
        // amountOut =
        //     ((adjustedAmountIn * (10 ** decimalsOut)) /
        //         uint256(offeredTokenPrice)) /
        //     PRECISION;
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _checkZeroAddress(address _addr) internal {
        if (_addr == address(0)) {
            revert SettlementEngine__AddressZero();
        }
    }
}
