// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {
    Ownable2StepUpgradeable,
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {
    UUPSUpgradeable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {
    IERC20Metadata
} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {
    AggregatorV3Interface
} from "@chainlink/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {Orderbook} from "./Orderbook.sol";

/// TODO: Add redundant price feeds
/// TODO: Add support for TWAP oracles
/// TODO: Add pausable functionality
contract SettlementEngine is Ownable2StepUpgradeable, UUPSUpgradeable {
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error SettlementEngine__AddressZero();
    error SettlementEngine__PriceFeedStale();

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
    uint256 public STALENESS_THRESHOLD = 1 hours;

    uint256[50] private __gap;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                                  INIT
    //////////////////////////////////////////////////////////////*/

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setOrderbook(
        address _orderbook
    ) external onlyOwner checkZeroAddress(_orderbook) {
        orderbook = Orderbook(_orderbook);

        emit OrderbookSet(_orderbook);
    }

    function _authorizeUpgrade(
        address _newImplementation
    ) internal override onlyOwner checkZeroAddress(_newImplementation) {}

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Always returns in the _offeredToken's Decimals
    function getAmountOut(
        address _offeredToken,
        address _requestedToken,
        uint256 _amountIn
    ) external view returns (uint256 amountOut) {
        // handle case for ETH as offered token
        if (_offeredToken == orderbook.ETH_ADDRESS()) {
            // Offer ETH need to get Requested Token / ETH price feed
            uint256 adjustedRequestedTokenPrice = _getAdjustedPrice(
                address(_requestedToken)
            );

            ///@dev round in favour of offer creator
            // return in 18 decimals
            amountOut = Math.mulDiv(
                _amountIn,
                PRECISION,
                adjustedRequestedTokenPrice,
                Math.Rounding.Floor
            );
        }

        // handle case for ETH as requested token
        else if (_requestedToken == orderbook.ETH_ADDRESS()) {
            // Need to get Offered Token / ETH price feed
            uint256 adjustedOfferedTokenPrice = _getAdjustedPrice(
                _offeredToken
            );

            // Calculate amountOut in 18 decimals
            uint256 scaledAmountOut = Math.mulDiv(
                _amountIn,
                adjustedOfferedTokenPrice,
                PRECISION,
                Math.Rounding.Floor
            );

            uint256 offeredTokenDecimals = IERC20Metadata(_offeredToken)
                .decimals();

            uint256 decimalsDifference = 18 - offeredTokenDecimals;

            /// @notice return in offeredToken's decimals
            amountOut = scaledAmountOut / (10 ** decimalsDifference);
        }

        // Handle case for ERC20 to ERC20 swap via ETH
        else {
            // Get price feeds for both tokens
            uint256 adjustedRequestedTokenPrice = _getAdjustedPrice(
                address(_requestedToken)
            );
            uint256 adjustedOfferedTokenPrice = _getAdjustedPrice(
                address(_offeredToken)
            );

            // Normalize totalRequest by dividing by PRECISION
            uint256 totalRequest = (_amountIn * adjustedRequestedTokenPrice) /
                PRECISION;

            // Use Math.mulDiv with PRECISION for precise division
            uint256 scaledAmountOut = Math.mulDiv(
                totalRequest,
                PRECISION,
                adjustedOfferedTokenPrice,
                Math.Rounding.Floor
            );

            uint256 offeredTokenDecimals = IERC20Metadata(_offeredToken)
                .decimals();

            uint256 decimalsDifference = 18 - offeredTokenDecimals;

            // Adjust for offeredToken's decimals
            amountOut = scaledAmountOut / (10 ** decimalsDifference);
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

    function _getAdjustedPrice(
        address _token
    ) internal view returns (uint256 adjustedPrice) {
        (address feedAddress, ) = orderbook.tokenInfo(_token);

        (uint256 decimals, uint256 tokenPrice) = _getPriceFeedInfo(feedAddress);

        // Adjust requestedTokenPrice to 18 decimals
        adjustedPrice = ((uint256(tokenPrice) * 10 ** (18 - decimals)));
    }

    function _getPriceFeedInfo(
        address _priceFeed
    ) internal view returns (uint256, uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_priceFeed);

        uint256 priceFeedDecimals = priceFeed.decimals();

        // Get price of requested token for 1 ETH
        (, int256 price, , uint256 updatedAt, ) = priceFeed.latestRoundData();
        _validatePriceFeedData(updatedAt);

        return (priceFeedDecimals, uint256(price));
    }

    /// TODO TEST!!
    function _validatePriceFeedData(uint256 _updatedAt) internal view {
        if (block.timestamp - _updatedAt > STALENESS_THRESHOLD) {
            revert SettlementEngine__PriceFeedStale();
        }
    }
}
