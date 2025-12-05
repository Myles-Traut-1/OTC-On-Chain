// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {
    SafeERC20,
    IERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {
    Ownable2Step,
    Ownable
} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {Escrow} from "./Escrow.sol";

/// @notice Orderbook data model shared across the OTC desk suite.
/// @dev Execution logic lives in dedicated settlement/escrow contracts;
///      this contract focuses on the canonical order schema, identifiers and status tracking so that other modules can integrate without duplicating definitions.

contract Orderbook is ReentrancyGuard, Ownable2Step {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error Orderbook__OfferAlreadyExists(bytes32 orderId);
    error Orderbook__ZeroAddress();
    error Orderbook__InsufficientBalance();
    error Orderbook__InvalidOfferAmount();
    error Orderbook__InvalidConstraints(string reason);
    error Orderbook__NotETH();
    error Orderbook__ETHTransferFailed();
    error Orderbook__NotOfferCreator();
    error Orderbook__OfferNotOpen();
    error Orderbook__InvalidOfferId();
    error Orderbook__UnsupportedToken(address token);
    error Orderbook__SameTokens();

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
    event TokenAdded(address indexed token, address indexed dataFeed);
    event TokenRemoved(address indexed token);

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier checkZeroAddress(address _address) {
        _checkZeroAddress(_address);
        _;
    }

    modifier validateOffer(
        TokenAmount memory _offer,
        address _requestedToken,
        uint256 _constraints
    ) {
        _validateOffer(_offer, _requestedToken, _constraints);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    address public constant ETH_ADDRESS =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    uint256 public constant MIN_OFFER_AMOUNT = 1e6; //Prevent griefing with dust offers
    uint256 public constant MIN_SLIPPAGE = 5; // 0.5% (scaled by 1000)
    uint256 public constant MAX_SLIPPAGE = 20; // Representing 2% (scaled by 1000)
    uint256 public constant SCALE = 1e3; // Scale factor for basis points calculations

    /// @notice Lifecycle states tracked on-chain to prevent replays.
    enum OfferStatus {
        None,
        Open,
        InProgress,
        Filled,
        Cancelled,
        Expired
    }

    struct Token {
        address dataFeed;
        bool isSupported;
    }

    /// @notice Asset definition with amount semantics.
    struct TokenAmount {
        address token;
        uint256 amount;
    }

    /// @notice Canonical order payload hashed for EIP-712 signatures.
    /// @dev Constraints are packed into a single uint256 for gas efficiency.
    /// @dev Constraintsts = uint64 validFrom | uint64 validUntil | uint128 maxSlippageBps
    struct Offer {
        address maker; // Maker configuration
        TokenAmount offer; // Asset/amount maker is giving
        address requestedToken; // Asset maker expects
        uint256 constraints; // Packed constraints
        uint256 remainingAmount; // Fill and timing controls
    }

    /// @notice Offer Tracking.
    mapping(bytes32 offerId => OfferStatus status) public offerStatusById;
    mapping(bytes32 offerId => Offer offer) public offers;

    /// @notice token tracking
    mapping(address token => Token) public tokenInfo;

    uint256 public nonce;

    address public settlementEngine;
    Escrow public escrow;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _settlementEngine,
        address _escrow
    )
        Ownable(msg.sender)
        checkZeroAddress(_settlementEngine)
        checkZeroAddress(_escrow)
    {
        settlementEngine = _settlementEngine;
        escrow = Escrow(payable(_escrow));
        nonce = 1;

        emit SettlementEngineSet(settlementEngine);
        emit EscrowSet(address(escrow));
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function addToken(
        address _token,
        address _dataFeed
    ) external onlyOwner checkZeroAddress(_token) {
        if (_token == ETH_ADDRESS) {
            tokenInfo[_token] = Token({
                dataFeed: address(0),
                isSupported: true
            });
        } else {
            _checkZeroAddress(_dataFeed);
        }

        tokenInfo[_token] = Token({dataFeed: _dataFeed, isSupported: true});
        emit TokenAdded(_token, _dataFeed);
    }

    function removeToken(address _token) external onlyOwner {
        if (!tokenInfo[_token].isSupported) {
            revert Orderbook__UnsupportedToken(_token);
        }
        tokenInfo[_token].isSupported = false;
        emit TokenRemoved(_token);
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
        validateOffer(_offer, _requestedToken, _constraints)
        nonReentrant
        returns (bytes32 offerId)
    {
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

        _transferToEscrow(_offer.token, _offer.amount);

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
        validateOffer(_offer, _requestedToken, _constraints)
        nonReentrant
        returns (bytes32 offerId)
    {
        if (msg.value != _offer.amount) {
            revert Orderbook__InvalidOfferAmount();
        }

        if (_offer.token != ETH_ADDRESS) {
            revert Orderbook__NotETH();
        }

        offerId = _generateOrderId(ETH_ADDRESS, _offer.amount, _requestedToken);

        _createOfferAndUpdateStatus(
            offerId,
            _offer,
            _requestedToken,
            _constraints
        );

        _transferToEscrow(ETH_ADDRESS, _offer.amount);

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

    function _validateOffer(
        TokenAmount memory _offer,
        address _requestedToken,
        uint256 _constraints
    ) internal view {
        address _offeredToken = _offer.token;
        uint256 _offerAmount = _offer.amount;

        if (!tokenInfo[_offeredToken].isSupported) {
            revert Orderbook__UnsupportedToken(_offeredToken);
        }

        if (!tokenInfo[_requestedToken].isSupported) {
            revert Orderbook__UnsupportedToken(_requestedToken);
        }

        if (_offeredToken == _requestedToken) {
            revert Orderbook__SameTokens();
        }

        if (_offerAmount < MIN_OFFER_AMOUNT) {
            revert Orderbook__InvalidOfferAmount();
        }

        _validateConstraints(_constraints);
    }

    function _validateConstraints(uint256 _constraints) internal view {
        (
            uint64 validFrom,
            uint64 validUntil,
            uint128 slippageBps
        ) = decodeConstraints(_constraints);
        if (slippageBps > MAX_SLIPPAGE) {
            revert Orderbook__InvalidConstraints("MAX_SLIPPAGE");
        } else if (slippageBps < MIN_SLIPPAGE) {
            revert Orderbook__InvalidConstraints("MIN_SLIPPAGE");
        } else if (validFrom < block.timestamp) {
            revert Orderbook__InvalidConstraints("VALID_FROM");
        } else if (validUntil <= validFrom) {
            revert Orderbook__InvalidConstraints("VALID_UNTIL");
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

    /*//////////////////////////////////////////////////////////////
                           PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _encodeConstraints(
        uint64 _validFrom,
        uint64 _validUntil,
        uint128 _maxSlippageBps
    ) private pure returns (uint256 encodedConstraints) {
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
        pure
        returns (uint64 validFrom, uint64 validUntil, uint128 maxSlippageBps)
    {
        validFrom = uint64(_encodedConstraints & 0xFFFFFFFFFFFFFFFF); // Mask for the lower 64 bits
        validUntil = uint64(_encodedConstraints >> 64);
        maxSlippageBps = uint128(_encodedConstraints >> 128);
    }

    function _transferToEscrow(address _token, uint256 _amount) private {
        if (_token == ETH_ADDRESS) {
            escrow.increaseBalance(ETH_ADDRESS, _amount);

            (bool success, ) = address(escrow).call{value: _amount}("");

            if (!success) {
                revert Orderbook__ETHTransferFailed();
            }
        } else {
            escrow.increaseBalance(_token, _amount);
            IERC20(_token).safeTransferFrom(
                msg.sender,
                address(escrow),
                _amount
            );
        }
    }
}
