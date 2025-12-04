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
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier checkZeroAddress(address _addr) {
        if (_addr == address(0)) {
            revert Escrow__AddressZero();
        }
        _;
    }

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

    mapping(address token => uint256 balance) private tokenBalances; // Internal accounting to prevent donation attacks

    receive() external payable {}

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

    function increaseBalance(
        address _token,
        uint256 _amount
    ) external onlyOrderbook {
        _increaseBalance(_token, _amount);
    }

    function transferFunds(
        address _token,
        address _to,
        uint256 _amount
    ) external onlyOrderbook {
        _decreaseBalance(_token, _amount);

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

    /*//////////////////////////////////////////////////////////////
                           PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _increaseBalance(address _token, uint256 _amount) internal {
        tokenBalances[_token] += _amount;
    }

    function _decreaseBalance(address _token, uint256 _amount) private {
        tokenBalances[_token] -= _amount;
    }
}
