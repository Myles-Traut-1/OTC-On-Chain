// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {
    Ownable2Step,
    Ownable
} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {Orderbook} from "./Orderbook.sol";

import {
    SafeERC20,
    IERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Escrow is Ownable2Step {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

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
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOrderbook() {
        if (msg.sender != address(orderbook)) {
            revert Escrow__Unauthorized();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    Orderbook public orderbook;

    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() Ownable(msg.sender) {}

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setOrderbook(address _orderbook) external onlyOwner {
        orderbook = Orderbook(_orderbook);

        emit OrderbookSet(_orderbook);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function transferFunds(
        address _token,
        address _to,
        uint256 _amount
    ) external onlyOrderbook {
        if (_token == orderbook.ETH_ADDRESS()) {
            (bool success, ) = _to.call{value: _amount}("");
            if (!success) {
                revert Escrow__EthTransferFailed();
            }
        } else {
            IERC20(_token).safeTransfer(_to, _amount);
        }

        emit FundsTransferred(_token, _to, _amount);
    }
}
