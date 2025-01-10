// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;
import { GenericTypes } from "contracts/libraries/DataTypes.sol";
abstract contract Constants {
    // General Constant Values of All Contracts
    uint256 internal constant DEC_27_2021 = 1_640_605_391;
    bytes constant _testChannelIdentity = bytes("test-channel-hello-world");

    // Specific Constant Values for Staking-Related Contracts
    // uint256 public genesisEpoch = 17_821_509;
    // uint256 public lastEpochInitialized = 5;
    // uint256 public lastTotalStakeEpochInitialized = 0;
    // uint256 public totalStakedAmount = 6_654_086 ether;
    // uint256 public previouslySetEpochRewards = 60_000 ether;
    uint256 public constant epochDuration = 21 * 7156; // 21 * number of blocks per day(7156) ~ 20 day approx

    uint256 public genesisEpoch = block.number;
    uint256 public lastEpochInitialized = genesisEpoch;
    uint256 public lastTotalStakeEpochInitialized = 0;
    uint256 public totalStakedAmount = 0 ether;
    uint256 public previouslySetEpochRewards = 0 ether;

    uint256 ADD_CHANNEL_MIN_FEES = 50 ether;
    uint256 ADD_CHANNEL_MAX_POOL_CONTRIBUTION = 250 ether;
    uint256 FEE_AMOUNT = 10 ether;
    uint256 MIN_POOL_CONTRIBUTION = 1 ether;
    uint256 ADJUST_FOR_FLOAT = 10 ** 7;
    GenericTypes.Percentage HOLDER_SPLIT = GenericTypes.Percentage({ percentageNumber: 55, decimalPlaces: 1 });
    uint256 WALLET_TOTAL_SHARES = 100_000 * 1e18;

    //Comm Constants used for meta transaction
    string public constant name = "Push COMM V1";
    bytes32 public constant NAME_HASH = keccak256(bytes(name));
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
    bytes32 public constant SUBSCRIBE_TYPEHASH =
        keccak256("Subscribe(address channel,address subscriber,uint256 nonce,uint256 expiry)");
    bytes32 public constant UNSUBSCRIBE_TYPEHASH =
        keccak256("Unsubscribe(address channel,address subscriber,uint256 nonce,uint256 expiry)");
    bytes32 public constant SEND_NOTIFICATION_TYPEHASH =
        keccak256("SendNotification(address channel,address recipient,bytes identity,uint256 nonce,uint256 expiry)");
}
