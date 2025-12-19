// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IOrderbook {
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
    error Orderbook__OfferNotOpenOrInProgress();
    error Orderbook__InvalidOfferId();
    error Orderbook__InvalidContribution(uint256 amount);
    error Orderbook__SlippageExceeded();
    error Orderbook__UnsupportedToken(address token);
    error Orderbook__TokenAlreadyAdded(address token);
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
    event OfferContributed(
        bytes32 indexed orderId,
        address indexed taker,
        uint256 amountIn,
        uint256 amountOut
    );
    event OfferStatusUpdated(bytes32 indexed orderId, OfferStatus newStatus);
    event TokenAdded(address indexed token, address indexed dataFeed);
    event TokenRemoved(address indexed token);

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

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

    /// @dev Constraints are packed into a single uint256 for gas efficiency.
    /// @dev Constraintsts = uint64 validFrom | uint64 validUntil | uint128 maxSlippageBps
    struct Offer {
        address maker; // Maker address
        TokenAmount offer; // Asset/amount maker is giving
        address requestedToken; // Asset maker expects
        uint256 constraints; // Packed constraints
        uint256 remainingAmount; // Remaining amount to be filled
    }

    /// @notice Asset definition with amount semantics.
    struct TokenAmount {
        address token;
        uint256 amount;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// TODO Add Price Feed Validation to ensure feed matches token
    function addToken(address _token, address _dataFeed) external;

    function removeToken(address _token) external;

    function pause() external;

    function unpause() external;

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createTokenOffer(
        TokenAmount memory _offer,
        address _requestedToken,
        uint256 _constraints
    ) external returns (bytes32 offerId);

    function createEthOffer(
        TokenAmount memory _offer,
        address _requestedToken,
        uint256 _constraints
    ) external payable returns (bytes32 offerId);

    function cancelOffer(bytes32 _offerId) external;

    function updateConstraints(
        bytes32 _offerId,
        uint256 _newConstraints
    ) external;

    function contribute(
        bytes32 _offerId,
        uint256 _amount,
        uint256 _quote
    ) external payable returns (uint256 amountOut);

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getOffer(
        bytes32 _offerId
    ) external view returns (Offer memory offer, OfferStatus status);

    function encodeConstraints(
        uint64 _validFrom,
        uint64 _validUntil,
        uint128 _maxSlippageBps
    ) external pure returns (uint256);

    function decodeConstraints(
        uint256 _encodedConstraints
    )
        external
        pure
        returns (uint64 validFrom, uint64 validUntil, uint128 maxSlippageBps);
}
