// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IEscrow {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Escrow__AddressZero();
    error Escrow__EthTransferFailed();
    error Escrow__Unauthorized();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event OrderbookSet(address indexed orderbook);
    event FundsTransferred(
        address indexed token,
        address indexed to,
        uint256 amount
    );

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setOrderbook(address _orderbook) external;

    function pause() external;

    function unpause() external;

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function increaseBalance(address _token, uint256 _amount) external;

    function transferFunds(
        address _token,
        address _to,
        uint256 _amount
    ) external;
}
