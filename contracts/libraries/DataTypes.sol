pragma solidity ^0.8.20;

library CoreTypes {
    /* ***************

    ENUMS AND CONSTANTS

    *************** */

    //For Message Type
    enum ChannelType {
        ProtocolNonInterest,
        ProtocolPromotion,
        InterestBearingOpen,
        InterestBearingMutual,
        TimeBound,
        TokenGated
    }

    enum ChannelAction {
        ChannelRemoved,
        ChannelAdded,
        ChannelUpdated
    }

    /**
     * @notice Channel Struct that includes imperative details about a specific Channel.
     *
     */
    struct Channel {
        /// @custom:channelType Denotes the Channel Type
        ChannelType channelType;
        /**
         * @notice Symbolizes Channel's State:
         * 0 -> INACTIVE,
         * 1 -> ACTIVATED
         * 2 -> DeActivated By Channel Owner,
         * 3 -> BLOCKED by pushChannelAdmin/Governance
         *
         */
        uint8 channelState;
        /// @notice denotes the address of the verifier of the Channel
        address verifiedBy;
        /// @notice Total Amount of PUSH deposited during Channel Creation
        uint256 poolContribution;
        /// @notice Represents the Historical Constant
        uint256 channelHistoricalZ;
        /// @notice Represents the FS Count
        uint256 channelFairShareCount;
        /// @notice The last update block number, used to calculate fair share
        uint256 channelLastUpdate;
        /// @notice Helps in defining when channel started for pool and profit calculation
        uint256 channelStartBlock;
        /// @notice Helps in outlining when channel was updated
        uint256 channelUpdateBlock;
        /// @notice The individual weight to be applied as per pool contribution
        uint256 channelWeight;
        /// @notice The Expiry TimeStamp in case of TimeBound Channel Types
        uint256 expiryTime;
    }
}

library CommTypes {
    /**
     * @notice User Struct that involves imperative details about
     * a specific User.
     *
     */
    struct User {
        /// @notice Indicates whether or not a user is ACTIVE
        bool userActivated;
        /// @notice Will be false until public key is emitted
        bool publicKeyRegistered;
        /// @notice Events should not be polled before this block as user doesn't exist
        uint256 userStartBlock;
        /// @notice Keep track of subscribers
        uint256 subscribedCount;
        /**
         * @notice Indicates if User subscribed to a Specific Channel Address
         * 1 -> User is Subscribed
         * 0 -> User is NOT SUBSCRIBED
         */
        mapping(address => uint8) isSubscribed;
        ///@notice Keeps track of all subscribed channels
        mapping(address => uint256) subscribed;
        ///@notice Maps ID to the Channel
        mapping(uint256 => address) mapAddressSubscribed;
    }
}

library StakingTypes {
    /// @dev: Stores all user's staking details
    struct UserFeesInfo {
        ///@notice Total amount staked by a user at any given time
        uint256 stakedAmount;
        ///@notice weight of PUSH tokens staked by user
        uint256 stakedWeight;
        ///@notice The last block when user staked
        uint256 lastStakedBlock;
        ///@notice The last block when user claimed rewards
        uint256 lastClaimedBlock;
        ///@notice Weight of staked amount of a user w.r.t total staked in a single epoch
        mapping(uint256 => uint256) epochToUserStakedWeight;
    }

    struct WalletShareInfo {
        ///@notice Total amount staked by a user at any given time
        uint256 walletShare;
        ///@notice The last block when user staked
        uint256 lastStakedBlock;
        ///@notice The last block when user claimed rewards
        uint256 lastClaimedBlock;
        ///@notice Weight of staked amount of a user w.r.t total staked in a single epoch
        mapping(uint256 => uint256) epochToWalletShares;
    }
}

library CrossChainRequestTypes {
    // Payload
    enum CrossChainFunction {
        AddChannel,
        CreateChannelSettings,
        ReactivateChannel,
        IncentivizedChat,
        ArbitraryRequest,
        AdminRequest_AddPoolFee,
        DeactivateChannel,
        UpdateChannelMeta
    }
}

library GenericTypes {
    struct Percentage {
        uint256 percentageNumber;
        uint256 decimalPlaces;
    }
}
