// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface ISettlementEngine {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error SettlementEngine__AddressZero();
    error SettlementEngine__PriceFeedStale();
    error SettlementEngine__ThresholdZero();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event OrderbookSet(address indexed orderbook);
    event StalenessThresholdSet(
        uint256 previousThreshold,
        uint256 newThreshold
    );

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setOrderbook(address _orderbook) external;
    function setStalenessThreshold(uint256 _stalenessThreshold) external;
    function pause() external;
    function unpause() external;

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getAmountOut(
        address _offeredToken,
        address _requestedToken,
        uint256 _amountIn
    ) external view returns (uint256 amountOut);
}
