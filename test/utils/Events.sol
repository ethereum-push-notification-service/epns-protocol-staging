pragma solidity ^0.8.20;

import { CoreTypes, GenericTypes } from "../../contracts/libraries/DataTypes.sol";

abstract contract CoreEvents {
    event AddChannel(address indexed channel, CoreTypes.ChannelType indexed channelType, bytes identity);
    event ChannelCreated(bytes32 indexed channel, CoreTypes.ChannelType indexed channelType, bytes identity);
    event UpdateChannel(bytes32 indexed channel, bytes identity, uint256 indexed amountDeposited);
    event ReactivateChannel(address indexed channel, uint256 indexed amountDeposited);
    event DeactivateChannel(address indexed channel, uint256 indexed amountRefunded);
    event ChannelBlocked(bytes32 indexed channel);
    event TimeBoundChannelDestroyed(address indexed channel, uint256 indexed amountRefunded);
    event IncentivizedChatReqReceived(
        bytes32 requestSender,
        bytes32 requestReceiver,
        uint256 amountForReqReceiver,
        uint256 feePoolAmount,
        uint256 timestamp
    );
    event ChatIncentiveClaimed(address indexed user, uint256 indexed amountClaimed);
    event ChannelVerified(bytes32 indexed channel, bytes32 indexed verifier);
    event ChannelVerificationRevoked(bytes32 indexed channel, bytes32 indexed revoker);
    event ChannelStateUpdate(bytes32 indexed channel, uint256 amountRefunded, uint256 amountDeposited);
    event ArbitraryRequest(
        bytes32 indexed sender,
        bytes32 indexed receiver,
        uint256 amountDeposited,
        GenericTypes.Percentage feePercent,
        uint256 indexed feeId
    );
    event ArbitraryRequestFeesClaimed(address indexed user, uint256 indexed amountClaimed);
    event ChannelNotifcationSettingsAdded(bytes32 _channel, uint256 totalNotifOptions, string _notifSettings, string _notifDescription);
}

abstract contract CommEvents {
    event IncentivizeChatReqInitiated(
        address requestSender, address requestReceiver, uint256 amountDeposited, uint256 timestamp
    );
    event Subscribe(address indexed channel, address indexed user);
    event Unsubscribe(address indexed channel, address indexed user);
    ///@notice emits whenever a Wallet or NFT is linked OR unlinked to a PGP hash
    event UserPGPRegistered(string indexed PgpHash, address indexed wallet, string chainName, uint256 chainID);
    event UserPGPRegistered(
        string indexed PgpHash, address indexed nft, uint256 nftId, string chainName, uint256 chainID
    );

    event UserPGPRemoved(string indexed PgpHash, address indexed wallet, string chainName, uint256 chainID);
    event UserPGPRemoved(string indexed PgpHash, address indexed nft, uint256 nftId, string chainName, uint256 chainID);
    event LogMessagePublished(
        address indexed sender, uint64 sequence, uint32 nonce, bytes payload, uint8 consistencyLevel
    );
}

abstract contract ProxyEvents {
    event Paused(address account);
    event Unpaused(address account);
}

abstract contract MigrationEvents {
    event TokenMigrated(address indexed _tokenHolder, address indexed _tokenReceiver, uint256 _amountMigrated);
    event TokenUnmigrated(address indexed _tokenHolder, uint256 _amountUnmigrated);
}

abstract contract PushTokenEvents {
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event NewMinter(address indexed newMinter);
}

abstract contract WalletStakingEvents {
    event Staked(address indexed user, uint256 indexed amountStaked);
    event Unstaked(address indexed user, uint256 indexed amountUnstaked);
    event RewardsHarvested(address indexed user, uint256 indexed rewardAmount, uint256 fromEpoch, uint256 tillEpoch);
    event NewSharesIssued(address indexed Wallet, uint256 indexed Shares);
    event SharesRemoved(address indexed Wallet, uint256 indexed Shares);
    event SharesDecreased(address indexed Wallet, uint256 indexed oldShares, uint256 newShares);
}

abstract contract Events is CoreEvents, CommEvents, ProxyEvents, PushTokenEvents, MigrationEvents, WalletStakingEvents { }
