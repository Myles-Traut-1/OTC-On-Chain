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

    error Orderbook__OfferAlreadyExists(bytes32 orderId);
    error Orderbook__ZeroAddress();
    error Orderbook__InsufficientBalance();
    error Orderbook__InvalidTokenAmount();
    error Orderbook__InvalidConstraints();
    error Orderbook__NotETH();
    error Orderbook__ETHTransferFailed();
    error Orderbook__NotOfferCreator();
    error Orderbook__OfferNotOpen();
    error Orderbook__InvalidOfferId();

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
        uint256 constraints
    );
    event OfferCancelled(bytes32 indexed orderId, address indexed maker);
    event OfferConstraintsUpdated(
        bytes32 indexed orderId,
        address indexed maker,
        uint256 newConstraints
    );
    event OfferStatusUpdated(bytes32 indexed orderId, OfferStatus newStatus);

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

    uint256 public constant MIN_OFFER_AMOUNT = 1e6; //Prevent griefing with dust offers

    /// @notice Lifecycle states tracked on-chain to prevent replays.
    enum OfferStatus {
        None,
        Open,
        InProgress,
        Filled,
        Cancelled,
        Expired
    }

    /// @notice Asset definition with amount semantics.
    struct TokenAmount {
        address token;
        uint256 amount;
    }

    /// @notice Canonical order payload hashed for EIP-712 signatures.
    struct Offer {
        address maker; // Maker configuration
        TokenAmount offer; // Asset/amount maker is giving
        address requestedToken; // Asset maker expects
        uint256 constraints; // Packed constraints
        uint256 remainingAmount; // Fill and timing controls
    }

    /// @notice Tracks the current status of an offer hash to prevent replays.
    mapping(bytes32 offerId => OfferStatus status) public offerStatusById;

    mapping(bytes32 offerId => Offer offer) public offers;

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
        uint256 _constraints
    )
        external
        checkZeroAddress(_requestedToken)
        validateTokenAmounts(_offer)
        nonReentrant
        returns (bytes32 offerId)
    {
        _validateConstraints(_constraints);

        offerId = _generateOrderId(
            _offer.token,
            _offer.amount,
            _requestedToken
        );

        _createOfferAndUpdateStatus(
            offerId,
            _offer,
            _requestedToken,
            _constraints
        );

        IERC20(_offer.token).safeTransferFrom(
            msg.sender,
            address(escrow),
            _offer.amount
        );

        emit OfferCreated(
            offerId,
            msg.sender,
            _offer,
            _requestedToken,
            _constraints
        );
    }

    function createEthOffer(
        TokenAmount memory _offer,
        address _requestedToken,
        uint256 _constraints
    )
        external
        payable
        checkZeroAddress(_requestedToken)
        validateTokenAmounts(_offer)
        nonReentrant
        returns (bytes32 offerId)
    {
        if (msg.value != _offer.amount) {
            revert Orderbook__InvalidTokenAmount();
        }

        if (_offer.token != ETH_ADDRESS) {
            revert Orderbook__NotETH();
        }

        _validateConstraints(_constraints);

        offerId = _generateOrderId(ETH_ADDRESS, _offer.amount, _requestedToken);

        _createOfferAndUpdateStatus(
            offerId,
            _offer,
            _requestedToken,
            _constraints
        );

        // Transfer ETH to escrow
        (bool success, ) = address(escrow).call{value: _offer.amount}("");

        if (!success) {
            revert Orderbook__ETHTransferFailed();
        }

        emit OfferCreated(
            offerId,
            msg.sender,
            _offer,
            _requestedToken,
            _constraints
        );
    }

    function cancelOffer(bytes32 _offerId) external nonReentrant {
        Offer storage offer = offers[_offerId];

        if (offer.maker != msg.sender) {
            revert Orderbook__NotOfferCreator();
        }

        if (offerStatusById[_offerId] != OfferStatus.Open) {
            revert Orderbook__OfferNotOpen();
        }

        offerStatusById[_offerId] = OfferStatus.Cancelled;

        uint256 remainingAmount = offer.remainingAmount;
        offer.remainingAmount = 0;

        // Return remaining offer amount to maker
        if (offer.offer.token == ETH_ADDRESS) {
            escrow.transferFunds(ETH_ADDRESS, offer.maker, remainingAmount);
        } else {
            escrow.transferFunds(
                offer.offer.token,
                offer.maker,
                remainingAmount
            );
        }

        emit OfferStatusUpdated(_offerId, OfferStatus.Cancelled);
        emit OfferCancelled(_offerId, msg.sender);
    }

    function updateConstraints(
        bytes32 _offerId,
        uint256 _newConstraints
    ) external {
        (Offer memory offer, OfferStatus status) = _getOffer(_offerId);
        if (offer.maker != msg.sender) {
            revert Orderbook__NotOfferCreator();
        }
        if (status != OfferStatus.Open) {
            revert Orderbook__OfferNotOpen();
        }

        _validateConstraints(_newConstraints);

        offer.constraints = _newConstraints;

        offers[_offerId] = offer;

        emit OfferConstraintsUpdated(_offerId, msg.sender, _newConstraints);
    }

    function contribute(bytes32 _offerId) public {
        // Just here to update the OrderStatus
        offerStatusById[_offerId] = OfferStatus.InProgress;
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
        if (_offer.amount < MIN_OFFER_AMOUNT) {
            revert Orderbook__InvalidTokenAmount();
        }
        if (_offer.token == address(0)) {
            revert Orderbook__ZeroAddress();
        }
    }

    function _validateConstraints(uint256 _constraints) internal view {
        (
            uint64 validFrom,
            uint64 validUntil,
            uint128 maxSlippageBps
        ) = decodeConstraints(_constraints);
        if (
            maxSlippageBps == 0 ||
            validFrom < block.timestamp ||
            validUntil <= validFrom
        ) {
            revert Orderbook__InvalidConstraints();
        }
    }

    function _encodeConstraints(
        uint64 _validFrom,
        uint64 _validUntil,
        uint128 _maxSlippageBps
    ) private view returns (uint256 encodedConstraints) {
        // Shift '_validUntil' to the left by 64 bits, '_maxSlippageBps' to the left by 128 bits, and combine with '_validFrom' using bitwise OR
        encodedConstraints =
            (uint256(_maxSlippageBps) << 128) |
            (uint256(_validUntil) << 64) |
            uint256(_validFrom);
    }

    function _decodeConstraints(
        uint256 _encodedConstraints
    )
        private
        view
        returns (uint64 validFrom, uint64 validUntil, uint128 maxSlippageBps)
    {
        validFrom = uint64(_encodedConstraints & 0xFFFFFFFFFFFFFFFF); // Mask for the lower 64 bits
        validUntil = uint64(_encodedConstraints >> 64);
        maxSlippageBps = uint128(_encodedConstraints >> 128);
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

    function _createOfferAndUpdateStatus(
        bytes32 _offerId,
        TokenAmount memory _offer,
        address _requestedToken,
        uint256 _constraints
    ) internal {
        offers[_offerId] = Offer({
            maker: msg.sender,
            offer: _offer,
            requestedToken: _requestedToken,
            constraints: _constraints,
            remainingAmount: _offer.amount
        });

        offerStatusById[_offerId] = OfferStatus.Open;
        nonce++;

        emit OfferStatusUpdated(_offerId, OfferStatus.Open);
    }

    function _getOffer(
        bytes32 _offerId
    ) internal view returns (Offer memory offer, OfferStatus status) {
        if (offers[_offerId].maker == address(0)) {
            revert Orderbook__InvalidOfferId();
        }
        offer = offers[_offerId];
        status = offerStatusById[_offerId];
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getOffer(
        bytes32 _offerId
    ) external view returns (Offer memory offer, OfferStatus status) {
        return _getOffer(_offerId);
    }

    function encodeConstraints(
        uint64 _validFrom,
        uint64 _validUntil,
        uint128 _maxSlippageBps
    ) public view returns (uint256) {
        return _encodeConstraints(_validFrom, _validUntil, _maxSlippageBps);
    }

    function decodeConstraints(
        uint256 _encodedConstraints
    )
        public
        view
        returns (uint64 validFrom, uint64 validUntil, uint128 maxSlippageBps)
    {
        return _decodeConstraints(_encodedConstraints);
    }
}
