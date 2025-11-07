// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/// @notice Orderbook data model shared across the OTC desk suite.
/// @dev Execution logic lives in dedicated settlement/escrow contracts; 
///      this contract focuses on the canonical order schema, identifiers and status tracking so that other modules can integrate without duplicating definitions.

contract Orderbook {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error Orderbook__OrderAlreadyExists(bytes32 orderId);
    error Orderbook__ZeroAddress();
    error Orderbook__InsufficientBalance();
    error Orderbook__InvalidTokenType();
    error Orderbook__InvalidTokenAmount();
    error Orderbook__InvalidConstraints();

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Taker instructions regarding how the order may be filled.
    enum FillInstruction {
        Default,       // Standard behaviour with partial fills allowed
        FillOrKill,    // Must be completely filled in a single transaction
        ImmediateOrCancel // Fill any amount immediately; cancel remainder
    }

    /// @notice Lifecycle states tracked on-chain to prevent replays.
    enum OrderStatus {
        None,
        Open,
        Filled,
        Cancelled,
        Expired
    }

    enum TokenType {
        ERC20,
        ERC721,
        ERC1155
    }

    /// @notice Party configuration for maker and (optionally) taker.
    struct Party {
        address wallet;         // Primary signing / settlement address
        address settlement;     // Target address for asset delivery (can differ from wallet, address(0) for msg.sender)
    }

    /// @notice Asset definition with amount semantics.
    struct TokenAmount {
        address token;  // ERC-20 / ERC-721 / ERC-1155 wrapper handled by adapters
        uint256 amount; // Quantity (ERC-721 uses amount = tokenId)
        TokenType tokenType;
    }

    /// @notice Time and risk controls applied to an order.
    struct Constraints {
        FillInstruction instruction; // Taker fill preference
        uint256 minFillAmount;       // Minimum base asset fill (offer side)
        uint256 maxSlippageBps;      // Max basis point deviation allowed by settlement engine
        uint64 validFrom;            // Optional start timestamp (0 = immediately active)
        uint64 validUntil;           // Expiration timestamp
    }

    /// @notice Canonical order payload hashed for EIP-712 signatures.
    struct Order {
        bytes32 orderId;             // Unique identifier
        Party maker;                 // Maker configuration
        TokenAmount offer;           // Asset/amount maker is giving
        address requestedToken;      // Asset maker expects
        Constraints constraints;     // Fill and timing controls
    }

    /// @notice Tracks the current status of an order hash to prevent replays.
    mapping(bytes32 orderId => OrderStatus status) public orderStatusById;

    mapping (bytes32 orderId => Order order) public orders;

    uint256 public nonce;

    address public settlementEngine;
    address public escrow;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event SettlementEngineSet(address indexed settlementEngine);
    event EscrowSet(address indexed escrow);

    event OrderCreated(
        bytes32 indexed orderId, 
        address indexed maker, 
        address settlement, 
        TokenAmount offer, 
        address requestedToken, 
        Constraints constraints
    );

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier checkZeroAddress(address _address) {
        if(_address == address(0)) {
            revert Orderbook__ZeroAddress();
        }
        _;
    }

    modifier validateTokenAmounts(TokenAmount memory _offer) {
        if (_offer.tokenType != TokenType.ERC20 && _offer.tokenType != TokenType.ERC721 && _offer.tokenType != TokenType.ERC1155) {
            revert Orderbook__InvalidTokenType();
        }
        if (_offer.amount == 0) {
            revert Orderbook__InvalidTokenAmount();
        }
        if (_offer.token == address(0)) {
            revert Orderbook__ZeroAddress();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _settlementEngine, address _escrow) checkZeroAddress(_settlementEngine) checkZeroAddress(_escrow) {
        settlementEngine = _settlementEngine;
        escrow = _escrow;
        nonce = 1;

        emit SettlementEngineSet(settlementEngine);
        emit EscrowSet(escrow);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUINCTIONS
    //////////////////////////////////////////////////////////////*/

    function createOrder(
        address _settlementAddress, 
        TokenAmount memory _offer, 
        address _requestedToken, 
        Constraints memory _constraints
    ) external checkZeroAddress(_requestedToken) validateTokenAmounts(_offer) {
        bytes32 _orderId = keccak256(abi.encode(msg.sender, nonce, _offer.token, _offer.amount, _requestedToken));
        if(orderStatusById[_orderId]!= OrderStatus.None) {
            revert Orderbook__OrderAlreadyExists(_orderId);
        }

        _validateConstraints(_constraints);

        _transferTokens(_offer);

        orders[_orderId] = Order ({
            orderId: _orderId,
            maker : Party ({
                wallet: msg.sender,
                settlement: _settlementAddress
            }),
            offer: _offer,
            requestedToken: _requestedToken,
            constraints: _constraints
        });

        orderStatusById[_orderId] = OrderStatus.Open;
        nonce ++;

        emit OrderCreated(_orderId, msg.sender, _settlementAddress, _offer, _requestedToken, _constraints);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _transferTokens(TokenAmount memory _tokenAmount) internal returns (bool success) {
       
        if (_tokenAmount.tokenType == TokenType.ERC20) {
            IERC20(_tokenAmount.token).safeTransferFrom(msg.sender, escrow, _tokenAmount.amount);
            success = true;
        } else if (_tokenAmount.tokenType == TokenType.ERC721) {
            IERC721(_tokenAmount.token).safeTransferFrom(msg.sender, escrow, _tokenAmount.amount);
            success = true;
        } else if (_tokenAmount.tokenType == TokenType.ERC1155) {
            IERC1155 token = IERC1155(_tokenAmount.token);
            uint256 balance = token.balanceOf(msg.sender, _tokenAmount.amount);
            if (balance < _tokenAmount.amount) {
                revert Orderbook__InsufficientBalance();
            }
            token.safeTransferFrom(msg.sender, escrow, _tokenAmount.amount, balance, "");
            success = true;
        }
    }

    function _validateConstraints(Constraints memory _constraints) internal view {
        if (_constraints.minFillAmount == 0 || _constraints.maxSlippageBps == 0 || _constraints.validFrom < block.timestamp || _constraints.validUntil < block.timestamp) {
            revert Orderbook__InvalidConstraints();
        }
    }
}