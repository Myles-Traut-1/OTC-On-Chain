// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {
    Ownable2Step,
    Ownable
} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {
    IERC20Metadata
} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {
    AggregatorV3Interface
} from "@chainlink/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {Orderbook} from "./Orderbook.sol";

/// TODO: Add redundant price feeds
/// TODO: Add PriceFeed staleness and deviation checks
/// TODO: Add support for TWAP oracles
/// TODO: Add pausable functionality
/// TODO: Add upgradeable functionality
/// TODO: Add emergencyWithdraw functionality with timelock
contract SettlementEngine is Ownable2Step {
    using Math for uint256;

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

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
            // Offer ETH need to get Requested Token / ETH price feed
            (address requestedTokenFeedAddress, ) = orderbook.tokenInfo(
                _requestedToken
            );

            (
                uint256 priceFeedDecimals,
                uint256 requestedTokenPrice
            ) = _getPriceFeedInfo(requestedTokenFeedAddress);

            // Adjust requestedTokenPrice to 18 decimals
            uint256 adjustedRequestedTokenPrice = (
                (uint256(requestedTokenPrice) * 10 ** (18 - priceFeedDecimals))
            );

            ///@dev round in favour of offer creator
            // return in 18 decimals
            amountOut = Math.mulDiv(
                _amountIn,
                _offerAmount,
                adjustedRequestedTokenPrice,
                Math.Rounding.Floor
            );
        }

        // handle case for ETH as requested token
        else if (_requestedToken == orderbook.ETH_ADDRESS()) {
            // Need to get Offered Token / ETH price feed
            (address offeredTokenFeedAddress, ) = orderbook.tokenInfo(
                _offeredToken
            );

            (
                uint256 priceFeedDecimals,
                uint256 offeredTokenPrice
            ) = _getPriceFeedInfo(offeredTokenFeedAddress);

            uint256 offeredTokenDecimals = IERC20Metadata(_offeredToken)
                .decimals();

            // Adjust offeredTokenPrice to 18 decimals
            uint256 adjustedOfferedTokenPrice = (
                (uint256(offeredTokenPrice) * 10 ** (18 - priceFeedDecimals))
            );

            // Calculate amountOut in 18 decimals
            uint256 scaledAmountOut = Math.mulDiv(
                _amountIn,
                adjustedOfferedTokenPrice,
                _offerAmount,
                Math.Rounding.Floor
            );

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

            (
                uint256 priceFeedDecimalsRequested,
                uint256 requestedTokenPrice
            ) = _getPriceFeedInfo(requestedTokenFeedAddress);
            (
                uint256 priceFeedDecimalsOffered,
                uint256 offeredTokenPrice
            ) = _getPriceFeedInfo(offeredTokenFeedAddress);

            uint256 offeredTokenDecimals = IERC20Metadata(_offeredToken)
                .decimals();

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

            // Calculate amountOut in 18 decimals
            uint256 scaledAmountOut = Math.mulDiv(
                totalOffer,
                PRECISION,
                totalRequest,
                Math.Rounding.Floor
            );

            // Adjust for receivedToken's decimals
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

    function _getPriceFeedInfo(
        address _priceFeed
    ) internal view returns (uint256, uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_priceFeed);

        uint256 priceFeedDecimals = priceFeed.decimals();

        // Get price of requested token for 1 ETH
        (, int256 price, , , ) = priceFeed.latestRoundData();

        return (priceFeedDecimals, uint256(price));
    }
}
