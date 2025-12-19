// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {
    SafeERC20,
    IERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {
    Ownable2StepUpgradeable,
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {
    PausableUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {
    UUPSUpgradeable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {Orderbook} from "./Orderbook.sol";

/// TODO: Add emergencyWithdraw functionality with timelock
contract Escrow is
    Ownable2StepUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
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
        _checkZeroAddress(_addr);
        _;
    }

    modifier onlyOrderbook() {
        _onlyOrderbook();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    Orderbook public orderbook;

    /// @dev receive is here to be able to receive ETH.
    /// @notice mapping used for internal accounting to prevent donation attacks.
    mapping(address token => uint256 balance) private tokenBalances;

    uint256[50] private __gap;

    /*//////////////////////////////////////////////////////////////
                                RECEIVE
    //////////////////////////////////////////////////////////////*/

    receive() external payable {}

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
        __Pausable_init();
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

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _authorizeUpgrade(
        address _newImplementation
    )
        internal
        override
        onlyOwner
        checkZeroAddress(_newImplementation)
        whenPaused
    {}

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
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _checkZeroAddress(address _addr) internal pure {
        if (_addr == address(0)) {
            revert Escrow__AddressZero();
        }
    }

    function _onlyOrderbook() internal view {
        if (msg.sender != address(orderbook)) {
            revert Escrow__Unauthorized();
        }
    }

    /*//////////////////////////////////////////////////////////////
                           PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _increaseBalance(address _token, uint256 _amount) internal {
        tokenBalances[_token] += _amount;
    }

    function _decreaseBalance(address _token, uint256 _amount) internal {
        tokenBalances[_token] -= _amount;
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getTokenBalance(address _token) external view returns (uint256) {
        return tokenBalances[_token];
    }
}
