pragma solidity ^0.8.20;

import { StakingTypes } from "../libraries/DataTypes.sol";

contract PushStakingStorage {
    //State variables for Stakers 
    uint256 public genesisEpoch; // Block number at which Stakig starts
    uint256 lastEpochInitialized; // The last EPOCH ID initialized with the respective epoch rewards
    uint256 lastTotalStakeEpochInitialized; // The last EPOCH ID initialized with the respective total staked weight
    uint256 public previouslySetEpochRewards; // Amount of rewards set in last initialized epoch
    uint256 public totalStakedAmount; // Total token weight staked in Protocol at any given time

    // State variables for Share holders 
    uint256 walletLastEpochInitialized; // todo new variable
    uint256 walletLastTotalStakeEpochInitialized;//todo new variable
    uint256 public walletPreviouslySetEpochRewards; //todo new variable
    uint256 public WALLET_TOTAL_SHARES; //Total Shares

    uint256 public constant epochDuration = 21 * 7156; // 21 * number of blocks per day(7156) ~ 20 day approx
    address public pushChannelAdmin;
    address public PUSH_TOKEN_ADDRESS;
    address public governance;
    address public core;
    address public FOUNDATION;

    //Mappings for Stakers
    ///@notice stores total rewards claimed by a user
    mapping(address => uint256) public usersRewardsClaimed;
    /// @notice Stores all the individual epoch rewards for stakers
    mapping(uint256 => uint256) public epochRewardsForStakers;
    /// @notice Stores User's Fees Details
    mapping(address => StakingTypes.UserFeesInfo) public userFeesInfo;
    /// @notice Stores the total staked weight at a specific epoch.
    mapping(uint256 => uint256) public epochToTotalStakedWeight;

    //Mappings for Share Holders
    ///@notice stores total reward claimed by a wallet
    mapping(address => uint256) public walletRewardsClaimed;
    /// @notice Stores all the individual epoch rewards for Wallet share holders
    mapping(uint256 => uint256) public epochRewardsForWallets;
    ///@notice stores Wallet share details for a given address
    mapping(address => StakingTypes.WalletShareInfo) public walletShareInfo;
    ///@notice stores the total shares in a specific epoch
    mapping(uint256 => uint256) public epochToTotalShares;
}
