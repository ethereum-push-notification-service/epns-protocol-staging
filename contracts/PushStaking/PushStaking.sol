// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./PushStakingStorage.sol";
import "../interfaces/IPUSH.sol";
import { IPushCoreStaking } from "../interfaces/IPushCoreStaking.sol";
import { Errors } from "../libraries/Errors.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { GenericTypes } from "../libraries/DataTypes.sol";
import { BaseHelper } from "../libraries/BaseHelper.sol";

contract PushStaking is Initializable, PushStakingStorage {
    using SafeERC20 for IERC20;

    event Staked(address indexed user, uint256 indexed amountStaked);
    event Unstaked(address indexed user, uint256 indexed amountUnstaked);
    event RewardsHarvested(address indexed user, uint256 indexed rewardAmount, uint256 fromEpoch, uint256 tillEpoch);
    event NewSharesIssued(address indexed wallet, uint256 indexed shares);
    event SharesRemoved(address indexed wallet, uint256 indexed shares);
    event SharesDecreased(address indexed Wallet, uint256 indexed oldShares, uint256 newShares);

    function initialize(address _pushChannelAdmin, address _core, address _pushToken) public initializer {
        pushChannelAdmin = _pushChannelAdmin;
        governance = _pushChannelAdmin;
        core = _core;
        PUSH_TOKEN_ADDRESS = _pushToken;
        FOUNDATION = _pushChannelAdmin;
    }

    modifier onlyPushChannelAdmin() {
        if (msg.sender != pushChannelAdmin) {
            revert Errors.CallerNotAdmin();
        }
        _;
    }

    modifier onlyGovernance() {
        if (msg.sender != governance) {
            revert Errors.CallerNotGovernance();
        }
        _;
    }

    function setGovernanceAddress(address _governanceAddress) external onlyPushChannelAdmin {
        governance = _governanceAddress;
    }

    function setPushChannelAdmin(address _newChannelAdmin) external onlyPushChannelAdmin{
        pushChannelAdmin = _newChannelAdmin;
    }

    function setFoundationAddress(address _foundation) external onlyGovernance{
        uint256 _tillEpoch = lastEpochRelative(genesisEpoch, block.number) - 1;
        uint256 _epoch_to_block_number = genesisEpoch + _tillEpoch * epochDuration;

        address oldFoundation = FOUNDATION;
        FOUNDATION = _foundation;
        walletShareInfo[_foundation].lastClaimedBlock = _epoch_to_block_number;

        removeWalletShare(oldFoundation);
    }

    function getEpochToWalletShare(address wallet, uint epoch) public view returns(uint){
        return walletShareInfo[wallet].epochToWalletShares[epoch];
    }

    function initializeStake(uint256 _walletTotalShares) external {
        require(genesisEpoch == 0, "PushCoreV2::initializeStake: Already Initialized");
        genesisEpoch = block.number;
        lastEpochInitialized = genesisEpoch;

        _stake(core, 1e18);

        WALLET_TOTAL_SHARES = _walletTotalShares;
        walletLastEpochInitialized = genesisEpoch;
        uint256 sharesToBeAllocated = _walletTotalShares;

        walletShareInfo[FOUNDATION].lastClaimedBlock = genesisEpoch;

        _adjustWalletAndTotalStake(FOUNDATION, sharesToBeAllocated, 0);
        emit NewSharesIssued(FOUNDATION, sharesToBeAllocated);
    }

    /**
     * @notice Calcultes the share amount based on requested shares and total shares 
     */
    function getSharesAmount(
        uint256 _totalShares,
        GenericTypes.Percentage memory _percentage
    )
        public
        pure
        returns (uint256 sharesToBeAllocated)
    {
        if (_percentage.percentageNumber / 10 ** _percentage.decimalPlaces >= 100 || _percentage.percentageNumber == 0) {
            revert Errors.InvalidArg_MoreThanExpected(99, _percentage.percentageNumber);
        }
        sharesToBeAllocated = (_percentage.percentageNumber * _totalShares)
            / ((100 * (10 ** _percentage.decimalPlaces)) - _percentage.percentageNumber);
    }
    /**
     * @notice allows Governance to add/increase wallet shares. 
     * @notice If a wallet has already has a share, then it acts as a "increase share" function, given that the percenatge passed
     * @notice should be greater than the already assigned percentge.
     * Emits NewSharesIssued
     */

    function addWalletShare(address _walletAddress, GenericTypes.Percentage memory _percentage) public onlyGovernance {
        if(_walletAddress == address(0)){
            revert Errors.InvalidArgument_WrongAddress(_walletAddress);
        }
        uint256 TotalShare = WALLET_TOTAL_SHARES;
        uint256 currentWalletShare = walletShareInfo[_walletAddress].walletShare;
        if (currentWalletShare != 0) {
            TotalShare -= currentWalletShare;
        }
        uint256 sharesToBeAllocated = getSharesAmount(TotalShare, _percentage);
        if (sharesToBeAllocated <= currentWalletShare) {
            revert Errors.InvalidArg_LessThanExpected(currentWalletShare, sharesToBeAllocated);
        }
        walletShareInfo[_walletAddress].lastClaimedBlock = walletShareInfo[_walletAddress].lastClaimedBlock == 0
            ? genesisEpoch
            : walletShareInfo[_walletAddress].lastClaimedBlock;
        _adjustWalletAndTotalStake(_walletAddress, sharesToBeAllocated, currentWalletShare);
        WALLET_TOTAL_SHARES = TotalShare + sharesToBeAllocated;
        emit NewSharesIssued(_walletAddress, sharesToBeAllocated);
    }

    /**
     * @notice allows Governance to remove wallet shares. 
     * @notice shares to be removed are given back to FOUNDATION
     * Emits SharesRemoved
     */

    function removeWalletShare(address _walletAddress) public onlyGovernance {
        if(_walletAddress == address(0) || _walletAddress == FOUNDATION) {
            revert Errors.InvalidArgument_WrongAddress(_walletAddress);
        }
        if (block.number <= walletShareInfo[_walletAddress].lastStakedBlock + epochDuration) {
            revert Errors.PushStaking_InvalidEpoch_LessThanExpected();
        }
        uint256 sharesToBeRemoved = walletShareInfo[_walletAddress].walletShare;
        _adjustWalletAndTotalStake(_walletAddress, 0, sharesToBeRemoved);
        _adjustWalletAndTotalStake(FOUNDATION, sharesToBeRemoved, 0);

        emit SharesRemoved(_walletAddress, sharesToBeRemoved);
    }

    function decreaseWalletShare(
            address _walletAddress,
            GenericTypes.Percentage memory _percentage
        )
            external
            onlyGovernance
        {
            if(_walletAddress == address(0) || _walletAddress == FOUNDATION) {
               revert Errors.InvalidArgument_WrongAddress(_walletAddress);
            }

            uint currentEpoch = lastEpochRelative(genesisEpoch,block.number);

            uint256 currentShares = walletShareInfo[_walletAddress].walletShare;
            uint256 sharesToBeAllocated = BaseHelper.calcPercentage(WALLET_TOTAL_SHARES, _percentage);

            if(sharesToBeAllocated >= currentShares){
                revert Errors.InvalidArg_MoreThanExpected(currentShares, sharesToBeAllocated);
            }
            uint256 sharesToBeRemoved = currentShares - sharesToBeAllocated;

            _adjustWalletAndTotalStake(_walletAddress, 0, sharesToBeRemoved);
            _adjustWalletAndTotalStake(FOUNDATION, sharesToBeRemoved, 0);
            
            emit SharesDecreased(_walletAddress, currentShares, sharesToBeAllocated);
       }

    /**
     * @notice calculates rewards for share holders, for any given epoch. 
     * @notice The rewards are calcluated based on -Their Wallet Share in that epoch, Total Wallet Shares in that epoch,
     * @notice Total Rewards available in that epoch
     * @dev Reward for a Given Wallet X in epoch i = ( Wallet Share of X in epoch i  * Rewards in epoch i) / WALLET_TOTAL_SHARES in epoch i
     */
    function calculateWalletRewards(address _wallet, uint256 _epochId) public view returns (uint256) {
        return (walletShareInfo[_wallet].epochToWalletShares[_epochId] * epochRewardsForWallets[_epochId])
            / epochToTotalShares[_epochId];
    }

    function claimShareRewards() external returns (uint256 rewards) {
        _adjustWalletAndTotalStake(msg.sender, 0, 0);

        uint256 currentEpoch = lastEpochRelative(genesisEpoch, block.number);
        uint256 nextFromEpoch = lastEpochRelative(genesisEpoch, walletShareInfo[msg.sender].lastClaimedBlock);

        uint256 _tillEpoch = currentEpoch - 1;

        for (uint256 i = nextFromEpoch; i <= _tillEpoch; i++) {
            uint256 claimableReward = calculateWalletRewards(msg.sender, i);
            rewards = rewards + claimableReward;
        }

        walletRewardsClaimed[msg.sender] = walletRewardsClaimed[msg.sender] + rewards;
        // set the lastClaimedBlock to blocknumer at the end of `_tillEpoch`
        uint256 _epoch_to_block_number = genesisEpoch + _tillEpoch * epochDuration;
        walletShareInfo[msg.sender].lastClaimedBlock = _epoch_to_block_number;
        IPushCoreStaking(core).sendFunds(msg.sender, rewards);

        emit RewardsHarvested(msg.sender, rewards, nextFromEpoch, _tillEpoch);
    }
    /**
     * @notice Function to return User's Push Holder weight based on amount being staked & current block number
     *
     */

    function _returnPushTokenWeight(
        address _account,
        uint256 _amount,
        uint256 _atBlock
    )
        internal
        view
        returns (uint256)
    {
        return _amount * (_atBlock - IPUSH(PUSH_TOKEN_ADDRESS).holderWeight(_account));
    }

    /**
     * @notice Returns the epoch ID based on the start and end block numbers passed as input
     *
     */
    function lastEpochRelative(uint256 _from, uint256 _to) public pure returns (uint256) {
        if (_to < _from) {
            revert Errors.InvalidArg_LessThanExpected(_from, _to);
        }
        return uint256((_to - _from) / epochDuration + 1);
    }

    /**
     * @notice Calculates and returns the claimable reward amount for a user at a given EPOCH ID.
     * @dev    Formulae for reward calculation:
     *         rewards = ( userStakedWeight at Epoch(n) * avalailable rewards at EPOCH(n) ) / totalStakedWeight at
     * EPOCH(n)
     *
     */
    function calculateEpochRewards(address _user, uint256 _epochId) public view returns (uint256 rewards) {
        rewards = (userFeesInfo[_user].epochToUserStakedWeight[_epochId] * epochRewardsForStakers[_epochId])
            / epochToTotalStakedWeight[_epochId];
    }

    /**
     * @notice Function to allow users to stake in the protocol
     * @dev    Records total Amount staked so far by a particular user
     *         Triggers weight adjustents functions
     * @param  _amount represents amount of tokens to be staked
     *
     */
    function stake(uint256 _amount) external {
        _stake(msg.sender, _amount);
        emit Staked(msg.sender, _amount);
    }

    function _stake(address _staker, uint256 _amount) private {
        uint256 currentEpoch = lastEpochRelative(genesisEpoch, block.number);
        uint256 blockNumberToConsider = genesisEpoch + (epochDuration * currentEpoch);
        uint256 userWeight = _returnPushTokenWeight(_staker, _amount, blockNumberToConsider);
        IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(msg.sender, core, _amount);

        userFeesInfo[_staker].stakedAmount = userFeesInfo[_staker].stakedAmount + _amount;
        userFeesInfo[_staker].lastClaimedBlock =
            userFeesInfo[_staker].lastClaimedBlock == 0 ? genesisEpoch : userFeesInfo[_staker].lastClaimedBlock;
        totalStakedAmount += _amount;
        // Adjust user and total rewards, piggyback method
        _adjustUserAndTotalStake(_staker, userWeight, false);
    }

    /**
     * @notice Function to allow users to Unstake from the protocol
     * @dev    Allows stakers to claim rewards before unstaking their tokens
     *         Triggers weight adjustents functions
     *         Allows users to unstake all amount at once
     *
     */
    function unstake() external {
        if (block.number <= userFeesInfo[msg.sender].lastStakedBlock + epochDuration) {
            revert Errors.PushStaking_InvalidEpoch_LessThanExpected();
        }
        if (userFeesInfo[msg.sender].stakedAmount == 0) {
            revert Errors.UnauthorizedCaller(msg.sender);
        }
        harvestAll();
        uint256 stakedAmount = userFeesInfo[msg.sender].stakedAmount;
        IPushCoreStaking(core).sendFunds(msg.sender, stakedAmount);

        // Adjust user and total rewards, piggyback method
        _adjustUserAndTotalStake(msg.sender, userFeesInfo[msg.sender].stakedWeight, true);

        userFeesInfo[msg.sender].stakedAmount = 0;
        userFeesInfo[msg.sender].stakedWeight = 0;
        totalStakedAmount -= stakedAmount;

        emit Unstaked(msg.sender, stakedAmount);
    }

    /**
     * @notice Allows users to harvest/claim their earned rewards from the protocol
     * @dev    Computes nextFromEpoch and currentEpoch and uses them as startEPoch and endEpoch respectively.
     *         Rewards are claculated from start epoch till endEpoch(currentEpoch - 1).
     *         Once calculated, user's total claimed rewards and nextFromEpoch details is updated.
     *
     */
    function harvestAll() public {
        uint256 currentEpoch = lastEpochRelative(genesisEpoch, block.number);

        uint256 rewards = harvest(msg.sender, currentEpoch - 1);
        IPushCoreStaking(core).sendFunds(msg.sender, rewards);
    }

    /**
     * @notice Allows paginated harvests for users between a particular number of epochs.
     * @param  _tillEpoch   - the end epoch number till which rewards shall be counted.
     * @dev    _tillEpoch should never be equal to currentEpoch.
     *         Transfers rewards to caller and updates user's details.
     *
     */
    function harvestPaginated(uint256 _tillEpoch) external {
        uint256 rewards = harvest(msg.sender, _tillEpoch);
        IPushCoreStaking(core).sendFunds(msg.sender, rewards);
    }

    /**
     * @notice Allows Push Governance to harvest/claim the earned rewards for its stake in the protocol
     * @param  _tillEpoch   - the end epoch number till which rewards shall be counted.
     * @dev    only accessible by Push Admin
     *         Unlike other harvest functions, this is designed to transfer rewards to Push Governance.
     *
     */
    function daoHarvestPaginated(uint256 _tillEpoch) external onlyGovernance {
        uint256 rewards = harvest(core, _tillEpoch);
        IPushCoreStaking(core).sendFunds(msg.sender, rewards);
    }

    /**
     * @notice Internal harvest function that is called for all types of harvest procedure.
     * @param  _user       - The user address for which the rewards will be calculated.
     * @param  _tillEpoch   - the end epoch number till which rewards shall be counted.
     * @dev    _tillEpoch should never be equal to currentEpoch.
     *         Transfers rewards to caller and updates user's details.
     */
    function harvest(address _user, uint256 _tillEpoch) internal returns (uint256 rewards) {
        IPUSH(PUSH_TOKEN_ADDRESS).resetHolderWeight(_user);
        _adjustUserAndTotalStake(_user, 0, false);

        uint256 currentEpoch = lastEpochRelative(genesisEpoch, block.number);
        uint256 nextFromEpoch = lastEpochRelative(genesisEpoch, userFeesInfo[_user].lastClaimedBlock);

        if (currentEpoch <= _tillEpoch) {
            revert Errors.PushStaking_InvalidEpoch_LessThanExpected();
        }
        if (_tillEpoch < nextFromEpoch) {
            revert Errors.InvalidArg_LessThanExpected(nextFromEpoch, _tillEpoch);
        }
        for (uint256 i = nextFromEpoch; i <= _tillEpoch; i++) {
            uint256 claimableReward = calculateEpochRewards(_user, i);
            rewards = rewards + claimableReward;
        }

        usersRewardsClaimed[_user] = usersRewardsClaimed[_user] + rewards;
        // set the lastClaimedBlock to blocknumer at the end of `_tillEpoch`
        uint256 _epoch_to_block_number = genesisEpoch + _tillEpoch * epochDuration;
        userFeesInfo[_user].lastClaimedBlock = _epoch_to_block_number;

        emit RewardsHarvested(_user, rewards, nextFromEpoch, _tillEpoch);
    }

    /**
     * @notice  This functions helps in adjustment of user's as well as totalWeigts, both of which are imperative for
     * reward calculation at a particular epoch.
     * @dev     Enables adjustments of user's stakedWeight, totalStakedWeight, epochToTotalStakedWeight as well as
     * epochToTotalStakedWeight.
     *          triggers _setupEpochsReward() to adjust rewards for every epoch till the current epoch
     *
     *          Includes 2 main cases of weight adjustments
     *          1st Case: User stakes for the very first time:
     *              - Simply update userFeesInfo, totalStakedWeight and epochToTotalStakedWeight of currentEpoch
     *
     *          2nd Case: User is NOT staking for first time - 2 Subcases
     *              2.1 Case: User stakes again but in Same Epoch
     *                  - Increase user's stake and totalStakedWeight
     *                  - Record the epochToUserStakedWeight for that epoch
     *                  - Record the epochToTotalStakedWeight of that epoch
     *
     *              2.2 Case: - User stakes again but in different Epoch
     *                  - Update the epochs between lastStakedEpoch & (currentEpoch - 1) with the old staked weight
     * amounts
     *                  - While updating epochs between lastStaked & current Epochs, if any epoch has zero value for
     * totalStakedWeight, update it with current totalStakedWeight value of the protocol
     *                  - For currentEpoch, initialize the epoch id with updated weight values for
     * epochToUserStakedWeight & epochToTotalStakedWeight
     */
    function _adjustUserAndTotalStake(address _user, uint256 _userWeight, bool isUnstake) internal {
        uint256 currentEpoch = lastEpochRelative(genesisEpoch, block.number);
        _setupEpochsRewardAndWeights(_userWeight, currentEpoch, isUnstake);
        uint256 userStakedWeight = userFeesInfo[_user].stakedWeight;

        // Initiating 1st Case: User stakes for first time
        if (userStakedWeight == 0) {
            userFeesInfo[_user].stakedWeight = _userWeight;
        } else {
            // Initiating 2.1 Case: User stakes again but in Same Epoch
            uint256 lastStakedEpoch = lastEpochRelative(genesisEpoch, userFeesInfo[_user].lastStakedBlock);
            if (currentEpoch == lastStakedEpoch) {
                userFeesInfo[_user].stakedWeight =
                    isUnstake ? userStakedWeight - _userWeight : userStakedWeight + _userWeight;
            } else {
                // Initiating 2.2 Case: User stakes again but in Different Epoch
                for (uint256 i = lastStakedEpoch; i <= currentEpoch; i++) {
                    if (i != currentEpoch) {
                        userFeesInfo[_user].epochToUserStakedWeight[i] = userStakedWeight;
                    } else {
                        userFeesInfo[_user].stakedWeight =
                            isUnstake ? userStakedWeight - _userWeight : userStakedWeight + _userWeight;
                        userFeesInfo[_user].epochToUserStakedWeight[i] = userFeesInfo[_user].stakedWeight;
                    }
                }
            }
        }

        if (_userWeight != 0) {
            userFeesInfo[_user].lastStakedBlock = block.number;
        }
    }

    /**
     * @notice Internal function that allows setting up the rewards for specific EPOCH IDs
     * @dev    Initializes (sets reward) for every epoch ID that falls between the lastEpochInitialized and currentEpoch
     *         Reward amount for specific EPOCH Ids depends on newly available Protocol_Pool_Fees.
     *             - If no new fees was accumulated, rewards for particular epoch ids can be zero
     *             - Records the Pool_Fees value used as rewards.
     *             - Records the last epoch id whose rewards were set.
     */
    function _setupEpochsRewardAndWeights(uint256 _userWeight, uint256 _currentEpoch, bool isUnstake) private {
        uint256 _lastEpochInitiliazed = lastEpochRelative(genesisEpoch, lastEpochInitialized);
        // Setting up Epoch Based Rewards
        if (_currentEpoch > _lastEpochInitiliazed || _currentEpoch == 1) {
            uint256 HOLDER_FEE_POOL = IPushCoreStaking(core).HOLDER_FEE_POOL();

            uint256 availableRewardsPerEpoch = (HOLDER_FEE_POOL - previouslySetEpochRewards);
            uint256 _epochGap = _currentEpoch - _lastEpochInitiliazed;

            if (_epochGap > 1) {
                epochRewardsForStakers[_currentEpoch - 1] += availableRewardsPerEpoch;
            } else {
                epochRewardsForStakers[_currentEpoch] += availableRewardsPerEpoch;
            }

            lastEpochInitialized = block.number;
            previouslySetEpochRewards = HOLDER_FEE_POOL;
        }
        // Setting up Epoch Based TotalWeight
        if (lastTotalStakeEpochInitialized == 0 || lastTotalStakeEpochInitialized == _currentEpoch) {
            epochToTotalStakedWeight[_currentEpoch] = isUnstake
                ? epochToTotalStakedWeight[_currentEpoch] - _userWeight
                : epochToTotalStakedWeight[_currentEpoch] + _userWeight;
        } else {
            for (uint256 i = lastTotalStakeEpochInitialized + 1; i <= _currentEpoch - 1; i++) {
                if (epochToTotalStakedWeight[i] == 0) {
                    epochToTotalStakedWeight[i] = epochToTotalStakedWeight[lastTotalStakeEpochInitialized];
                }
            }

            epochToTotalStakedWeight[_currentEpoch] = isUnstake
                ? epochToTotalStakedWeight[lastTotalStakeEpochInitialized] - _userWeight
                : epochToTotalStakedWeight[lastTotalStakeEpochInitialized] + _userWeight;
        }
        lastTotalStakeEpochInitialized = _currentEpoch;
    }

    function _adjustWalletAndTotalStake(address _wallet, uint256 _sharesToAdd, uint256 _sharesToRemove) internal {
        uint256 currentEpoch = lastEpochRelative(genesisEpoch, block.number);
        _setupEpochsRewardAndSharesForWallets(_sharesToAdd, currentEpoch, _sharesToRemove);

        uint256 _walletPrevShares = walletShareInfo[_wallet].walletShare;

        // Initiating 1st Case: User stakes for first time
        if (_walletPrevShares == 0) {
            walletShareInfo[_wallet].walletShare = _sharesToAdd;
        } else {
            // Initiating 2.1 Case: User stakes again but in Same Epoch
            uint256 lastStakedEpoch = lastEpochRelative(genesisEpoch, walletShareInfo[_wallet].lastStakedBlock);
            if (currentEpoch == lastStakedEpoch) {
                walletShareInfo[_wallet].walletShare = _walletPrevShares + _sharesToAdd - _sharesToRemove;
            } else {
                // Initiating 2.2 Case: User stakes again but in Different Epoch
                for (uint256 i = lastStakedEpoch; i <= currentEpoch; i++) {
                    if (i != currentEpoch) {
                        walletShareInfo[_wallet].epochToWalletShares[i] = _walletPrevShares;
                    } else {
                        walletShareInfo[_wallet].walletShare = _walletPrevShares + _sharesToAdd - _sharesToRemove;

                        walletShareInfo[_wallet].epochToWalletShares[i] = walletShareInfo[_wallet].walletShare;
                    }
                }
            }
        }

        if (_sharesToAdd != 0) {
            walletShareInfo[_wallet].lastStakedBlock = block.number;
        }
    }

    /**
     * @notice Internal function that allows setting up the rewards for specific EPOCH IDs
     * @dev    Initializes (sets reward) for every epoch ID that falls between the lastEpochInitialized and currentEpoch
     *         Reward amount for specific EPOCH Ids depends on newly available Protocol_Pool_Fees.
     *             - If no new fees was accumulated, rewards for particular epoch ids can be zero
     *             - Records the Pool_Fees value used as rewards.
     *             - Records the last epoch id whose rewards were set.
     */
    function _setupEpochsRewardAndSharesForWallets(
        uint256 _sharesToAdd,
        uint256 _currentEpoch,
        uint256 _sharesToRemove
    )
        private
    {
        uint256 _lastEpochInitiliazed = lastEpochRelative(genesisEpoch, walletLastEpochInitialized);
        // Setting up Epoch Based Rewards
        if (_currentEpoch > _lastEpochInitiliazed || _currentEpoch == 1) {
            uint256 WALLET_FEE_POOL = IPushCoreStaking(core).WALLET_FEE_POOL();
            uint256 availableRewardsPerEpoch = (WALLET_FEE_POOL - walletPreviouslySetEpochRewards);
            uint256 _epochGap = _currentEpoch - _lastEpochInitiliazed;

            if (_epochGap > 1) {
                epochRewardsForWallets[_currentEpoch - 1] += availableRewardsPerEpoch;
            } else {
                epochRewardsForWallets[_currentEpoch] += availableRewardsPerEpoch;
            }

            walletLastEpochInitialized = block.number;
            walletPreviouslySetEpochRewards = WALLET_FEE_POOL;
        }
        // Setting up Epoch Based TotalWeight
        if (walletLastTotalStakeEpochInitialized == 0 || walletLastTotalStakeEpochInitialized == _currentEpoch) {
            epochToTotalShares[_currentEpoch] = epochToTotalShares[_currentEpoch] + _sharesToAdd - _sharesToRemove;
        } else {
            for (uint256 i = walletLastTotalStakeEpochInitialized + 1; i <= _currentEpoch - 1; i++) {
                if (epochToTotalShares[i] == 0) {
                    epochToTotalShares[i] = epochToTotalShares[walletLastTotalStakeEpochInitialized];
                }
            }
            epochToTotalShares[_currentEpoch] = epochToTotalShares[_currentEpoch]
                + epochToTotalShares[walletLastTotalStakeEpochInitialized] + _sharesToAdd - _sharesToRemove;
        }
        walletLastTotalStakeEpochInitialized = _currentEpoch;
    }
}
