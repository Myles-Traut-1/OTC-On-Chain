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

    /// @dev Always returns in the _offeredToken's Decimals
    function getAmountOut(
        address _offeredToken,
        address _requestedToken,
        uint256 _amountIn,
        uint256 _offerAmount
    ) external view returns (uint256 amountOut) {
        // handle case for ETH as offered token

        //Get Price of 1 _offeredToken in _requestedToken
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
            uint256 priceFeedDecimals = requestedTokenFeed.decimals();

            console.log("Requested Token Decimals:", requestedTokenDecimals);

            // Get price of requested token for 1 ETH
            (, int256 requestedTokenPrice, , , ) = requestedTokenFeed
                .latestRoundData();

            // Adjust requestedTokenPrice to 18 decimals
            uint256 adjustedRequestedTokenPrice = (
                (uint256(requestedTokenPrice) * 10 ** (18 - priceFeedDecimals))
            );

            console.log(
                "Adjusted Requested Token Price:",
                adjustedRequestedTokenPrice
            );

            // return in 18 decimals because ETH has 18 decimals
            amountOut =
                (((_amountIn * PRECISION) / adjustedRequestedTokenPrice) *
                    _offerAmount) /
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

            // Get price of offered token for 1 ETH
            (, int256 offeredTokenPrice, , , ) = offeredTokenFeed
                .latestRoundData();

            uint256 offeredTokenDecimals = IERC20Metadata(_offeredToken)
                .decimals();
            uint256 priceFeedDecimals = offeredTokenFeed.decimals();

            console.log("Offered Token Decimals:", offeredTokenDecimals);

            // Adjust offeredTokenPrice to 18 decimals
            uint256 adjustedOfferedTokenPrice = (
                (uint256(offeredTokenPrice) * 10 ** (18 - priceFeedDecimals))
            );

            console.log(
                "Adjusted Offered Token Price:",
                adjustedOfferedTokenPrice
            );

            uint256 scaledAmountOut = ((_amountIn * adjustedOfferedTokenPrice) /
                _offerAmount);

            uint256 decimalsDifference = 18 - offeredTokenDecimals;

            /// @notice return in offeredToken's decimals
            amountOut = scaledAmountOut / (10 ** decimalsDifference);
        }

        // Handle case for ERC20 to ERC20 swap via ETH
        else {
            // Get price feeds for both tokens
            (address requestedTokenFeedAddress, ) = orderbook.tokenInfo(
                _requestedToken
            );
            (address offeredTokenFeedAddress, ) = orderbook.tokenInfo(
                _offeredToken
            );

            AggregatorV3Interface requestedTokenFeed = AggregatorV3Interface(
                requestedTokenFeedAddress
            );
            AggregatorV3Interface offeredTokenFeed = AggregatorV3Interface(
                offeredTokenFeedAddress
            );

            (, int256 requestedTokenPrice, , , ) = requestedTokenFeed
                .latestRoundData();
            (, int256 offeredTokenPrice, , , ) = offeredTokenFeed
                .latestRoundData();

            uint256 requestedTokenDecimals = IERC20Metadata(_requestedToken)
                .decimals();
            uint256 offeredTokenDecimals = IERC20Metadata(_offeredToken)
                .decimals();

            uint256 priceFeedDecimalsRequested = requestedTokenFeed.decimals();
            uint256 priceFeedDecimalsOffered = offeredTokenFeed.decimals();

            //Adjust prices to 18 decimals
            uint256 adjustedRequestedTokenPrice = (
                (uint256(requestedTokenPrice) *
                    10 ** (18 - priceFeedDecimalsRequested))
            );
            uint256 adjustedOfferedTokenPrice = (
                (uint256(offeredTokenPrice) *
                    10 ** (18 - priceFeedDecimalsOffered))
            );
            // Calculate OfferAmount
            uint256 totalOffer = _offerAmount * adjustedOfferedTokenPrice;
            uint256 totalRequest = _amountIn * adjustedRequestedTokenPrice;

            uint256 scaledAmountOut = (totalOffer * PRECISION) / totalRequest;

            // Calculate amountOut and adjust for tokenOut decimals, then divide by PRECISION
            amountOut = scaledAmountOut / (10 ** (18 - offeredTokenDecimals));
        }
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _checkZeroAddress(address _addr) internal pure {
        if (_addr == address(0)) {
            revert SettlementEngine__AddressZero();
        }
    }
}
