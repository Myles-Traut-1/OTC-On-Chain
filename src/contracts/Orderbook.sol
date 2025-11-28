// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {
    SafeERC20,
    IERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {Escrow} from "./Escrow.sol";

/// @notice Orderbook data model shared across the OTC desk suite.
/// @dev Execution logic lives in dedicated settlement/escrow contracts;
///      this contract focuses on the canonical order schema, identifiers and status tracking so that other modules can integrate without duplicating definitions.

contract Orderbook is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error Orderbook__OrderAlreadyExists(bytes32 orderId);
    error Orderbook__ZeroAddress();
    error Orderbook__InsufficientBalance();
    error Orderbook__InvalidTokenAmount();
    error Orderbook__InvalidConstraints();
    error Orderbook__NotETH();
    error Orderbook__ETHTransferFailed();
    error Orderbook__NotOfferCreator();
    error Orderbook__OrderNotOpen();
    error Orderbook__InvalidOrderId();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event SettlementEngineSet(address indexed settlementEngine);
    event EscrowSet(address indexed escrow);
    event OfferCreated(
        bytes32 indexed orderId,
        address indexed maker,
        TokenAmount offer,
        address requestedToken,
        Constraints constraints
    );
    event OfferCancelled(bytes32 indexed orderId, address indexed maker);

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier checkZeroAddress(address _address) {
        _checkZeroAddress(_address);
        _;
    }

    modifier validateTokenAmounts(TokenAmount memory _offer) {
        _validateTokenAmounts(_offer);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    address public constant ETH_ADDRESS =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice Lifecycle states tracked on-chain to prevent replays.
    enum OrderStatus {
        None,
        Open,
        Filled,
        Cancelled,
        Expired
    }

    /// @notice Asset definition with amount semantics.
    struct TokenAmount {
        address token;
        uint256 amount;
    }

    /// @notice Time and risk controls applied to an order.
    struct Constraints {
        uint256 minFillAmount; // Minimum base asset fill (offer side)
        uint256 maxSlippageBps; // Max basis point deviation allowed by settlement engine
        uint64 validFrom;
        uint64 validUntil;
    }

    /// @notice Canonical order payload hashed for EIP-712 signatures.
    struct Order {
        bytes32 orderId; // Unique identifier
        address maker; // Maker configuration
        TokenAmount offer; // Asset/amount maker is giving
        address requestedToken; // Asset maker expects
        Constraints constraints;
        uint256 remainingAmount; // Fill and timing controls
    }

    /// @notice Tracks the current status of an order hash to prevent replays.
    mapping(bytes32 orderId => OrderStatus status) public orderStatusById;

    mapping(bytes32 orderId => Order order) public orders;

    uint256 public nonce;

    address public settlementEngine;
    Escrow public escrow;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _settlementEngine,
        address _escrow
    ) checkZeroAddress(_settlementEngine) checkZeroAddress(_escrow) {
        settlementEngine = _settlementEngine;
        escrow = Escrow(payable(_escrow));
        nonce = 1;

        emit SettlementEngineSet(settlementEngine);
        emit EscrowSet(address(escrow));
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createTokenOffer(
        TokenAmount memory _offer,
        address _requestedToken,
        Constraints memory _constraints
    )
        external
        checkZeroAddress(_requestedToken)
        validateTokenAmounts(_offer)
        nonReentrant
        returns (bytes32 _orderId)
    {
        _orderId = _generateOrderId(
            _offer.token,
            _offer.amount,
            _requestedToken
        );

        _validateConstraints(_constraints);

        IERC20(_offer.token).safeTransferFrom(
            msg.sender,
            address(escrow),
            _offer.amount
        );

        orders[_orderId] = Order({
            orderId: _orderId,
            maker: msg.sender,
            offer: _offer,
            requestedToken: _requestedToken,
            constraints: _constraints,
            remainingAmount: _offer.amount
        });

        orderStatusById[_orderId] = OrderStatus.Open;
        nonce++;

        emit OfferCreated(
            _orderId,
            msg.sender,
            _offer,
            _requestedToken,
            _constraints
        );
    }

    function createEthOffer(
        TokenAmount memory _offer,
        address _requestedToken,
        Constraints memory _constraints
    )
        external
        payable
        checkZeroAddress(_requestedToken)
        validateTokenAmounts(_offer)
        nonReentrant
        returns (bytes32 _orderId)
    {
        if (msg.value != _offer.amount) {
            revert Orderbook__InvalidTokenAmount();
        }

        if (_offer.token != ETH_ADDRESS) {
            revert Orderbook__NotETH();
        }

        _orderId = _generateOrderId(ETH_ADDRESS, msg.value, _requestedToken);

        _validateConstraints(_constraints);

        // Transfer ETH to escrow
        (bool success, ) = address(escrow).call{value: msg.value}("");

        if (!success) {
            revert Orderbook__ETHTransferFailed();
        }

        orders[_orderId] = Order({
            orderId: _orderId,
            maker: msg.sender,
            offer: TokenAmount({token: ETH_ADDRESS, amount: msg.value}),
            requestedToken: _requestedToken,
            constraints: _constraints,
            remainingAmount: msg.value
        });

        orderStatusById[_orderId] = OrderStatus.Open;
        nonce++;

        emit OfferCreated(
            _orderId,
            msg.sender,
            _offer,
            _requestedToken,
            _constraints
        );
    }

    function cancelOffer(bytes32 _offerId) external nonReentrant {
        Order storage order = orders[_offerId];

        if (order.maker != msg.sender) {
            revert Orderbook__NotOfferCreator();
        }

        if (orderStatusById[_offerId] != OrderStatus.Open) {
            revert Orderbook__OrderNotOpen();
        }

        orderStatusById[_offerId] = OrderStatus.Cancelled;

        uint256 remainingAmount = order.remainingAmount;
        order.remainingAmount = 0;

        // Return remaining offer amount to maker
        if (order.offer.token == ETH_ADDRESS) {
            escrow.transferFunds(ETH_ADDRESS, order.maker, remainingAmount);
        } else {
            escrow.transferFunds(
                order.offer.token,
                order.maker,
                remainingAmount
            );
        }

        emit OfferCancelled(_offerId, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _checkZeroAddress(address _address) internal pure {
        if (_address == address(0)) {
            revert Orderbook__ZeroAddress();
        }
    }

    function _validateTokenAmounts(TokenAmount memory _offer) internal pure {
        if (_offer.amount == 0) {
            revert Orderbook__InvalidTokenAmount();
        }
        if (_offer.token == address(0)) {
            revert Orderbook__ZeroAddress();
        }
    }

    function _validateConstraints(
        Constraints memory _constraints
    ) internal view {
        if (
            _constraints.minFillAmount == 0 ||
            _constraints.maxSlippageBps == 0 ||
            _constraints.validFrom < block.timestamp ||
            _constraints.validUntil <= _constraints.validFrom
        ) {
            revert Orderbook__InvalidConstraints();
        }
    }

    function _generateOrderId(
        address _offeredToken,
        uint256 _amount,
        address _requestedToken
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    msg.sender,
                    nonce,
                    _offeredToken,
                    _amount,
                    _requestedToken
                )
            );
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getOrder(
        bytes32 _orderId
    ) external view returns (Order memory order, OrderStatus status) {
        if (orders[_orderId].maker == address(0)) {
            revert Orderbook__InvalidOrderId();
        }
        order = orders[_orderId];
        status = orderStatusById[_orderId];
    }
}
