pragma solidity ^0.8.20;

/**
 * @title  PushCore V3
 * @author Push Protocol
 * @notice Push Core is the main protocol that deals with the imperative
 *         features and functionalities like Channel Creation, pushChannelAdmin etc.
 *
 * @dev This protocol will be specifically deployed on Ethereum Blockchain while the Communicator
 *      protocols can be deployed on Multiple Chains.
 *      The Push Core is more inclined towards the storing and handling the Channel related functionalties.
 * @Custom:security-contact https://immunefi.com/bug-bounty/pushprotocol/information/
 */
import { PushCoreStorageV1_5 } from "./PushCoreStorageV1_5.sol";
import { PushCoreStorageV2 } from "./PushCoreStorageV2.sol";
import "../interfaces/IPUSH.sol";
import { IPushCoreV3 } from "../interfaces/IPushCoreV3.sol";
import { BaseHelper } from "../libraries/BaseHelper.sol";
import { Errors } from "../libraries/Errors.sol";
import { CoreTypes, CrossChainRequestTypes, GenericTypes } from "../libraries/DataTypes.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    PausableUpgradeable, Initializable
} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "../interfaces/wormhole/IWormholeReceiver.sol";

contract PushCoreV3 is
    Initializable,
    PushCoreStorageV1_5,
    PausableUpgradeable,
    PushCoreStorageV2,
    IPushCoreV3,
    IWormholeReceiver
{
    using SafeERC20 for IERC20;

    /* ***************
        INITIALIZER
    *************** */
    /**
     * @notice Initializer has been removed to save contract space.
     * However, for readability, initialized values have been mentioned below:
     *   FEE_AMOUNT            = 10 ether;
     *   MIN_POOL_CONTRIBUTION = 1 ether;
     *   ADD_CHANNEL_MIN_FEES  = 50 ether;
     *   ADJUST_FOR_FLOAT      = 10 ** 7;
     * --------------------------------------------------------------------------
     */

    /* ***************

    SETTER & HELPER FUNCTIONS

    *************** */
    function onlyPushChannelAdmin() private view {
        if (msg.sender != pushChannelAdmin) {
            revert Errors.CallerNotAdmin();
        }
    }

    function onlyGovernance() private view {
        if (msg.sender != governance) {
            revert Errors.CallerNotGovernance();
        }
    }

    function onlyActivatedChannels(bytes32 _channel) private view {

        if (channelInfo[_channel].channelState != 1) {
            revert Errors.Core_InvalidChannel();
        }
    }

    function addSubGraph(bytes calldata _subGraphData) external {
        onlyActivatedChannels(BaseHelper.addressToBytes32(msg.sender));
        emit AddSubGraph(BaseHelper.addressToBytes32(msg.sender), _subGraphData);
    }

    function setPushCommunicatorAddress(address _commAddress) external {
        onlyPushChannelAdmin();
        pushCommunicator = _commAddress;
    }

    function setGovernanceAddress(address _governanceAddress) external {
        onlyPushChannelAdmin();
        governance = _governanceAddress;
    }
    /**
     * @notice Allows admin to set the Fee Amount of core contract
     *
     * @dev    _newFees must not be more than (or equal to) the ADD_CHANNEL_MIN_FEES
     *
     * @param _newFees new minimum fees required for FEE_AMOUNT
     */

    function setFeeAmount(uint256 _newFees) external {
        onlyGovernance();
        if (_newFees == 0) {
            revert Errors.InvalidArg_LessThanExpected(1, _newFees);
        }
        if (_newFees >= ADD_CHANNEL_MIN_FEES) {
            revert Errors.InvalidArg_MoreThanExpected(ADD_CHANNEL_MIN_FEES, _newFees);
        }
        FEE_AMOUNT = _newFees;
    }

    function setMinPoolContribution(uint256 _newAmount) external {
        onlyGovernance();
        if (_newAmount == 0) {
            revert Errors.InvalidArg_LessThanExpected(1, _newAmount);
        }
        MIN_POOL_CONTRIBUTION = _newAmount;
    }

    function pauseContract() external {
        onlyPushChannelAdmin();
        _pause();
    }

    function unPauseContract() external {
        onlyPushChannelAdmin();
        _unpause();
    }
    /**
     * @notice Allows to set the Minimum amount threshold for Creating Channels
     *
     * @dev    Minimum required amount can never be below the sum of MIN_POOL_CONTRIBUTION and FEE_AMOUNT
     *
     * @param _newFees new minimum fees required for Channel Creation
     *
     */

    function setMinChannelCreationFees(uint256 _newFees) external {
        onlyGovernance();
        uint256 minFeeRequired = MIN_POOL_CONTRIBUTION + FEE_AMOUNT;
        if (_newFees < minFeeRequired) {
            revert Errors.InvalidArg_LessThanExpected(minFeeRequired, _newFees);
        }
        ADD_CHANNEL_MIN_FEES = _newFees;
    }

    function transferPushChannelAdminControl(address _newAdmin) external {
        onlyPushChannelAdmin();
        if (_newAdmin == address(0) || _newAdmin == pushChannelAdmin) {
            revert Errors.InvalidArgument_WrongAddress(_newAdmin);
        }
        pushChannelAdmin = _newAdmin;
    }

    /* ***********************************

        CHANNEL RELATED FUNCTIONALTIES

    **************************************/
    ///@inheritdoc IPushCoreV3
    function updateChannelMeta(bytes calldata _newIdentity, uint256 _amount) external whenNotPaused {
        bytes32 _channel = BaseHelper.addressToBytes32(msg.sender);

        IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(msg.sender, address(this), _amount);
        _updateChannelMeta(_channel, _newIdentity, _amount);
    }

    function _updateChannelMeta(bytes32 _channel, bytes memory _newIdentity, uint256 _amount) internal {
        onlyActivatedChannels(_channel);
        uint256 updateCounter = channelUpdateCounter[_channel] + 1;
        uint256 requiredFees = ADD_CHANNEL_MIN_FEES * updateCounter;

        if (_amount < requiredFees) {
            revert Errors.InvalidArg_LessThanExpected(requiredFees, _amount);
        }

        distributeFees(_amount);

        channelUpdateCounter[_channel] = updateCounter;

        channelInfo[_channel].channelUpdateBlock = block.number;

        emit UpdateChannel(_channel, _newIdentity, _amount);
    }

    /// @inheritdoc IPushCoreV3
    function createChannelWithPUSH(
        CoreTypes.ChannelType _channelType,
        bytes calldata _identity,
        uint256 _amount,
        uint256 _channelExpiryTime
    )
        external
        whenNotPaused
    {
        if (_amount < ADD_CHANNEL_MIN_FEES) {
            revert Errors.InvalidArg_LessThanExpected(ADD_CHANNEL_MIN_FEES, _amount);
        }
        bytes32 _channelBytesID = BaseHelper.addressToBytes32(msg.sender);

        IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(msg.sender, address(this), _amount);

        emit ChannelCreated(_channelBytesID, _channelType, _identity);
        _createChannel(_channelBytesID, _channelType, _amount, _channelExpiryTime);
    }

    /**
     * @notice Base Channel Creation Function that allows users to Create Their own Channels and Stores crucial details
     * about the Channel being created
     * @dev    -Initializes the Channel Struct
     *         -Subscribes the Channel's Owner to Imperative Push Channels as well as their Own Channels
     *         - Updates the CHANNEL_POOL_FUNDS and POOL_FEES in the contract.
     *
     * @param _channel         address of the channel being Created
     * @param _channelType     The type of the Channel
     * @param _amountDeposited The total amount being deposited while Channel Creation
     * @param _channelExpiryTime the expiry time for time bound channels
     *
     */
    function _createChannel(
        bytes32 _channel,
        CoreTypes.ChannelType _channelType,
        uint256 _amountDeposited,
        uint256 _channelExpiryTime
    )
        private
    {
        if (channelInfo[_channel].channelState != 0) {
            revert Errors.Core_InvalidChannel();
        }

        if (uint8(_channelType) < 2) {
            revert Errors.Core_InvalidChannelType();
        }

        if (_channelType == CoreTypes.ChannelType.TimeBound) {
            if (_channelExpiryTime <= block.timestamp) {
                revert Errors.Core_InvalidExpiryTime();
            }
            channelInfo[_channel].expiryTime = _channelExpiryTime;
        }

        uint256 poolFeeAmount = FEE_AMOUNT;
        uint256 poolFundAmount = _amountDeposited - poolFeeAmount;
        //store funds in pool_funds & pool_fees
        CHANNEL_POOL_FUNDS = CHANNEL_POOL_FUNDS + poolFundAmount;
        distributeFees(poolFeeAmount);

        // Calculate channel weight
        uint256 _channelWeight = (poolFundAmount * ADJUST_FOR_FLOAT) / MIN_POOL_CONTRIBUTION;
        // Next create the channel and mark user as channellized
        channelInfo[_channel].channelState = 1;
        channelInfo[_channel].poolContribution = poolFundAmount;
        channelInfo[_channel].channelType = _channelType;
        channelInfo[_channel].channelStartBlock = block.number;
        channelInfo[_channel].channelUpdateBlock = block.number;
        channelInfo[_channel].channelWeight = _channelWeight;
        // Add to map of addresses and increment channel count
        channelsCount = channelsCount + 1;
    }

    /// @inheritdoc IPushCoreV3
    function createChannelSettings(
        uint256 _notifOptions,
        string calldata _notifSettings,
        string calldata _notifDescription,
        uint256 _amountDeposited
    )
        external
    {
        onlyActivatedChannels(BaseHelper.addressToBytes32(msg.sender));
        if (_amountDeposited < ADD_CHANNEL_MIN_FEES) {
            revert Errors.InvalidArg_LessThanExpected(ADD_CHANNEL_MIN_FEES, _amountDeposited);
        }
        
        IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(msg.sender, address(this), _amountDeposited);

        bytes32 _channelBytesID = BaseHelper.addressToBytes32(msg.sender);
        _createSettings(_channelBytesID, _notifOptions, _amountDeposited, _notifSettings, _notifDescription);
    }

    function _createSettings(
        bytes32 _channel,
        uint256 _notifOptions,
        uint256 _amountDeposited,
        string memory _notifSettings,
        string memory _notifDescription
    )
        private
    {
        distributeFees(_amountDeposited);

        string memory notifSetting = string(abi.encodePacked(Strings.toString(_notifOptions), "+", _notifSettings));

        emit ChannelNotifcationSettingsAdded(_channel, _notifOptions, notifSetting, _notifDescription);
    }

    /// @inheritdoc IPushCoreV3
    function updateChannelState(uint256 _amount) external whenNotPaused {
        // Check channel's current state
        bytes32 _channelBytesID = BaseHelper.addressToBytes32(msg.sender);

           if(channelInfo[_channelBytesID].channelState == 2) {
                IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(msg.sender, address(this), _amount);
                _reactivateChannel( _channelBytesID, _amount);
           }else {
              _deactivateChannel( _channelBytesID, msg.sender);
            }     
    }

    function _deactivateChannel(bytes32 _channelBytesID, address recipient) internal {
    
        CoreTypes.Channel storage channelData = channelInfo[_channelBytesID];
        uint8 channelCurrentState = channelData.channelState;
        // Prevent INACTIVE or BLOCKED Channels
        if (channelCurrentState != 1) {
            revert Errors.Core_InvalidChannel();
        }

        uint256 minPoolContribution = MIN_POOL_CONTRIBUTION;
        // If Active State , Enter the Time-Bound Deletion/Deactivate Channel Phase
            uint256 totalRefundableAmount;
            if (!(channelData.channelType == CoreTypes.ChannelType.TimeBound)) {
                // DEACTIVATION PHASE
                totalRefundableAmount = channelData.poolContribution - minPoolContribution;

                uint256 _newChannelWeight = (minPoolContribution * ADJUST_FOR_FLOAT) / minPoolContribution;
                channelData.channelState = 2;
                channelData.channelWeight = _newChannelWeight;
                channelData.poolContribution = minPoolContribution;
            } else {
                // TIME-BOUND CHANNEL DELETION PHASE
                if (channelData.expiryTime >= block.timestamp) {
                    revert Errors.Core_InvalidChannel();
                }
                totalRefundableAmount = channelData.poolContribution;
                channelsCount = channelsCount - 1;
                delete channelInfo[_channelBytesID];
            }
            emit ChannelStateUpdate(_channelBytesID, totalRefundableAmount, 0);
            CHANNEL_POOL_FUNDS = CHANNEL_POOL_FUNDS - totalRefundableAmount;
            IERC20(PUSH_TOKEN_ADDRESS).safeTransfer(recipient, totalRefundableAmount);
    }

    function _reactivateChannel(bytes32 _channelBytesID, uint256 _amount) internal {
        if (_amount < ADD_CHANNEL_MIN_FEES) {
            revert Errors.InvalidArg_LessThanExpected(ADD_CHANNEL_MIN_FEES, _amount);
        }
        CoreTypes.Channel storage channelData = channelInfo[_channelBytesID];
        uint256 poolFeeAmount = FEE_AMOUNT;
        uint256 poolFundAmount = _amount - poolFeeAmount;
        //store funds in pool_funds & pool_fees
        CHANNEL_POOL_FUNDS = CHANNEL_POOL_FUNDS + poolFundAmount;

        distributeFees(poolFeeAmount);

        uint256 _newPoolContribution = channelData.poolContribution + poolFundAmount;
        uint256 _newChannelWeight = (_newPoolContribution * ADJUST_FOR_FLOAT) / MIN_POOL_CONTRIBUTION;

        channelData.channelState = 1;
        channelData.poolContribution = _newPoolContribution;
        channelData.channelWeight = _newChannelWeight;
        emit ChannelStateUpdate(_channelBytesID, 0, _amount);
    }

    /// @inheritdoc IPushCoreV3
    function blockChannel(bytes32 _channelAddress) external whenNotPaused {
        onlyGovernance();
        if (((channelInfo[_channelAddress].channelState == 3) || (channelInfo[_channelAddress].channelState == 0))) {
            revert Errors.Core_InvalidChannel();
        }
        uint256 minPoolContribution = MIN_POOL_CONTRIBUTION;
        CoreTypes.Channel storage channelData = channelInfo[_channelAddress];
        // add channel's currentPoolContribution to PoolFees - (no refunds if Channel is blocked)
        // Decrease CHANNEL_POOL_FUNDS by currentPoolContribution
        uint256 currentPoolContribution = channelData.poolContribution - minPoolContribution;
        CHANNEL_POOL_FUNDS = CHANNEL_POOL_FUNDS - currentPoolContribution;

        distributeFees(currentPoolContribution);

        uint256 _newChannelWeight = (minPoolContribution * ADJUST_FOR_FLOAT) / minPoolContribution;

        channelsCount = channelsCount - 1;
        channelData.channelState = 3;
        channelData.channelWeight = _newChannelWeight;
        channelData.channelUpdateBlock = block.number;
        channelData.poolContribution = minPoolContribution;

        emit ChannelBlocked(_channelAddress);
    }

    /* **************
    => CHANNEL VERIFICATION FUNCTIONALTIES <=
    *************** */

    /// @inheritdoc IPushCoreV3
    function getChannelVerfication(bytes32 _channel) public view returns (uint8 verificationStatus) {

        address verifiedBy = channelInfo[_channel].verifiedBy;
        bool logicComplete = false;

        // Check if it's primary verification
        if (verifiedBy == pushChannelAdmin || _channel == BaseHelper.addressToBytes32(pushChannelAdmin)) {
            // primary verification, mark and exit
            verificationStatus = 1;
        } else {
            // can be secondary verification or not verified, dig deeper
            while (!logicComplete) {
                if (verifiedBy == address(0x0)) {
                    verificationStatus = 0;
                    logicComplete = true;
                } else if (verifiedBy == pushChannelAdmin) {
                    verificationStatus = 2;
                    logicComplete = true;
                } else {
                    // Upper drill exists, go up
                    bytes32 verifiedByChannel = BaseHelper.addressToBytes32(verifiedBy);
                    verifiedBy = channelInfo[verifiedByChannel].verifiedBy;
                }
            }
        }
    }

    function batchVerification(
        uint256 _startIndex,
        uint256 _endIndex,
        bytes32[] calldata _channelList
    )
        external
        returns (bool)
    {
        onlyPushChannelAdmin();
        for (uint256 i = _startIndex; i < _endIndex;) {
            verifyChannel(_channelList[i]);

            unchecked {
                i++;
            }
        }
        return true;
    }

    /// @inheritdoc IPushCoreV3
    function verifyChannel(bytes32 _channel) public {
        onlyActivatedChannels(_channel);
        // Check if caller is verified first
        uint8 callerVerified = getChannelVerfication(BaseHelper.addressToBytes32(msg.sender));
        if (callerVerified == 0) {
            revert Errors.UnauthorizedCaller(msg.sender);
        }

        // Check if channel is verified
        uint8 channelVerified = getChannelVerfication(_channel);
        if (!(channelVerified == 0 || msg.sender == pushChannelAdmin)) {
            revert Errors.Core_InvalidChannel();
        }

        // Verify channel
        channelInfo[_channel].verifiedBy = msg.sender;

        // Emit event
        emit ChannelVerified(_channel, BaseHelper.addressToBytes32(msg.sender));
    }

    /// @inheritdoc IPushCoreV3
    function unverifyChannel(bytes32 _channel) public {
        if (!(channelInfo[_channel].verifiedBy == msg.sender || msg.sender == pushChannelAdmin)) {
            revert Errors.CallerNotAdmin();
        }

        // Unverify channel
        channelInfo[_channel].verifiedBy = address(0x0);

        // Emit Event
        emit ChannelVerificationRevoked(_channel, BaseHelper.addressToBytes32(msg.sender));
    }

    /**
     * Core-V3: Stake and Claim Functions
     */
    function updateStakingAddress(address _stakingAddress) external {
        onlyPushChannelAdmin();
        STAKING_CONTRACT = _stakingAddress;
        IPUSH(PUSH_TOKEN_ADDRESS).setHolderDelegation(_stakingAddress,true);
    }

    function sendFunds(address _user, uint256 _amount) external {
        if (msg.sender != STAKING_CONTRACT) {
            revert Errors.UnauthorizedCaller(msg.sender);
        }
        IERC20(PUSH_TOKEN_ADDRESS).transfer(_user, _amount);
    }

    /**
     * Allows caller to add pool_fees at any given epoch
     *
     */
    function addPoolFees(uint256 _rewardAmount) external {
        IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(msg.sender, address(this), _rewardAmount);
        distributeFees(_rewardAmount);
    }

    function splitFeePool(GenericTypes.Percentage memory holderSplit) external {
        onlyGovernance();
        SPLIT_PERCENTAGE_FOR_HOLDER = holderSplit;
    }

    function distributeFees(uint256 _fees) internal{
        uint holderFee = BaseHelper.calcPercentage(_fees, SPLIT_PERCENTAGE_FOR_HOLDER);
        HOLDER_FEE_POOL += holderFee;
        WALLET_FEE_POOL += _fees - holderFee;
    }

    function getTotalFeePool() external view returns (uint256) {
        return HOLDER_FEE_POOL + WALLET_FEE_POOL;
    }

    /// @inheritdoc IPushCoreV3
    function createIncentivizedChatRequest(address requestReceiver, uint256 amount) external {
        if (amount < FEE_AMOUNT) {
            revert Errors.InvalidArg_LessThanExpected(FEE_AMOUNT, amount);
        }
        
        if (requestReceiver == address(0)) {
            revert Errors.InvalidArgument_WrongAddress(requestReceiver);
        }

        // Transfer tokens from the caller to the contract
        IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(msg.sender, address(this), amount);

        // Process the incentivized chat request
        _handleIncentivizedChat(BaseHelper.addressToBytes32(msg.sender), requestReceiver, amount);
    }

    /**
     * @notice Handles the incentivized chat request between a sender and a receiver.
     * @dev Transfers the specified amount, deducting a protocol fee, to the receiver's funds and updates the protocol
     * fee pool.
     * @param requestSender The address of the sender initiating the chat request.
     * @param requestReceiver The address of the receiver who is the target of the chat request.
     * @param amount The total amount sent by the sender for the incentivized chat.
     */
    function _handleIncentivizedChat(bytes32 requestSender, address requestReceiver, uint256 amount) private {
        uint256 poolFeeAmount = FEE_AMOUNT;
        uint256 requestReceiverAmount = amount - poolFeeAmount;

        celebUserFunds[requestReceiver] += requestReceiverAmount;

        distributeFees(poolFeeAmount);

        emit IncentivizedChatReqReceived(
            requestSender, BaseHelper.addressToBytes32(requestReceiver), requestReceiverAmount, poolFeeAmount, block.timestamp
        );
    }

    /// @inheritdoc IPushCoreV3
    function claimChatIncentives(uint256 _amount) external {
        if (celebUserFunds[msg.sender] < _amount) {
            revert Errors.InvalidArg_MoreThanExpected(celebUserFunds[msg.sender], _amount);
        }

        celebUserFunds[msg.sender] -= _amount;
        IERC20(PUSH_TOKEN_ADDRESS).safeTransfer(msg.sender, _amount);

        emit ChatIncentiveClaimed(BaseHelper.addressToBytes32(msg.sender), _amount);
    }

    /* *****************************
         WORMHOLE CROSS-CHAIN Functions
    ***************************** */
    modifier isRegisteredSender(uint16 sourceChain, bytes32 sourceAddress) {
        require(registeredSenders[sourceChain] == sourceAddress, "Not registered sender");
        _;
    }

    /**
     * Sets the registered address for 'sourceChain' to 'sourceAddress'
     * So that for messages from 'sourceChain', only ones from 'sourceAddress' are valid
     *
     * Assumes only one sender per chain is valid
     * Sender is the address that called 'send' on the Wormhole Relayer contract on the source chain)
     */
    function setRegisteredSender(uint16 sourceChain, bytes32 sourceAddress) external {
        onlyPushChannelAdmin();
        registeredSenders[sourceChain] = sourceAddress;
    }

    function setWormholeRelayer(address _wormholeRelayer) external {
        onlyPushChannelAdmin();
        wormholeRelayer = _wormholeRelayer;
    }

    function onlyWormholeRelayer() private view {
        if (msg.sender != wormholeRelayer) {
            revert Errors.CallerNotAdmin();
        }
    }

    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory, // additionalVaas
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 deliveryHash
    )
        public
        payable
        override
        isRegisteredSender(sourceChain, sourceAddress)
    {
        onlyWormholeRelayer();
        if (processedMessages[deliveryHash]) {
            revert Errors.Payload_Duplicacy_Error();
        }

        (
            CrossChainRequestTypes.CrossChainFunction functionType,
            bytes memory structPayload,
            uint256 amount,
            bytes32 sender
        ) = abi.decode(payload, (CrossChainRequestTypes.CrossChainFunction, bytes, uint256, bytes32));

        if (functionType == CrossChainRequestTypes.CrossChainFunction.AddChannel) {
            // Specific Request: Add Channel
            (CoreTypes.ChannelType channelType, bytes memory channelIdentity, uint256 channelExpiry) =
                abi.decode(structPayload, (CoreTypes.ChannelType, bytes, uint256));
            emit ChannelCreated(sender, channelType, channelIdentity);
            _createChannel(sender, channelType, amount, channelExpiry);
        } else if (functionType == CrossChainRequestTypes.CrossChainFunction.IncentivizedChat) {
            // Specific Request: Incentivized Chat
            (bytes32 amountRecipient) = abi.decode(structPayload, (bytes32));
            _handleIncentivizedChat(
                sender, BaseHelper.bytes32ToAddress(amountRecipient), amount
            );
        } else if (functionType == CrossChainRequestTypes.CrossChainFunction.CreateChannelSettings) {
            (uint256 _notifOptions, string memory _notifSettings,  string memory _notifDescription) =
                abi.decode(structPayload, (uint256, string, string));
            _createSettings(sender, _notifOptions, amount, _notifSettings, _notifDescription);
        } else if (functionType == CrossChainRequestTypes.CrossChainFunction.UpdateChannelMeta) {
            (bytes memory _newIdentity) = abi.decode(structPayload, (bytes));
            _updateChannelMeta(sender, _newIdentity, amount);
        } else if (functionType == CrossChainRequestTypes.CrossChainFunction.DeactivateChannel) {
            // Specific Request: Deactivating or Deleting Channel
            (address recipient) = abi.decode(structPayload, (address));
            _deactivateChannel(sender, recipient);
        } else if (functionType == CrossChainRequestTypes.CrossChainFunction.ReactivateChannel) {
            // Specific Request: Deactivating or Deleting Channel
            _reactivateChannel(sender, amount);
        } else if (functionType == CrossChainRequestTypes.CrossChainFunction.ArbitraryRequest) {
            // Arbitrary Request
            (uint8 feeId, GenericTypes.Percentage memory feePercentage, bytes32 amountRecipient) =
                abi.decode(structPayload, (uint8, GenericTypes.Percentage, bytes32));

            _handleArbitraryRequest(sender, feeId, feePercentage, BaseHelper.bytes32ToAddress(amountRecipient), amount);
        } else if (functionType == CrossChainRequestTypes.CrossChainFunction.AdminRequest_AddPoolFee) {
            // Admin Request
            distributeFees(amount);
        } else {
            revert("Invalid Function Type");
        }

        processedMessages[deliveryHash] = true;
    }

    /// @inheritdoc IPushCoreV3
    function handleArbitraryRequestData(
        uint8 feeId,
        GenericTypes.Percentage calldata feePercentage,
        address amountRecipient,
        uint256 amount
    )
        external
    {
        if (amount == 0) {
            revert Errors.InvalidArg_LessThanExpected(1, amount);
        }
        // Transfer tokens from the caller to the contract
        IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(msg.sender, address(this), amount);

        // Call the private function to process the arbitrary request
        _handleArbitraryRequest(BaseHelper.addressToBytes32(msg.sender), feeId, feePercentage, amountRecipient, amount);
    }

    /**
     * @notice Handles the arbitrary request.
     * @dev Calculates the fee, updates the state variables, and emits an event.
     * @param sender The address of the sender initiating the arbitrary request.
     * @param feeId The fee ID associated with the request.
     * @param feePercentage The fee percentage to be deducted.
     * @param amountRecipient The address of the recipient.
     * @param amount The total amount sent by the sender for the arbitrary request.
     */
    function _handleArbitraryRequest(
        bytes32 sender,
        uint8 feeId,
        GenericTypes.Percentage memory feePercentage,
        address amountRecipient,
        uint256 amount
    )
        private
    {
        // Calculate the fee amount
        uint256 feeAmount = BaseHelper.calcPercentage(amount, feePercentage);

        // Update states based on Fee Percentage calculation
        distributeFees(feeAmount);

        arbitraryReqFees[amountRecipient] += amount - feeAmount;

        // Emit an event for the arbitrary request
        emit ArbitraryRequest(sender, BaseHelper.addressToBytes32(amountRecipient), amount, feePercentage, feeId);
    }

    /**
     * @notice Allows a user to claim a specified amount of arbitrary request fees.
     * @dev Reverts if the user tries to claim more than their available balance.
     * @param _amount The amount of arbitrary request fees to claim.
     * @custom:requires The caller's balance of arbitrary request fees must be greater than or equal to `_amount`.
     * @custom:reverts Errors.InvalidArg_MoreThanExpected if `_amount` exceeds the caller's available arbitrary request
     * fees.
     * @custom:emits An {ArbitraryRequestFeesClaimed} event.
     */
    function claimArbitraryRequestFees(uint256 _amount) external {
        uint256 userFeesBalance = arbitraryReqFees[msg.sender];

        if (userFeesBalance < _amount) {
            revert Errors.InvalidArg_MoreThanExpected(userFeesBalance, _amount);
        }

        arbitraryReqFees[msg.sender] = userFeesBalance - _amount;
        IERC20(PUSH_TOKEN_ADDRESS).safeTransfer(msg.sender, _amount);

        emit ArbitraryRequestFeesClaimed(BaseHelper.addressToBytes32(msg.sender), _amount);
    }

    function migrateAddressToBytes32(address[] calldata _channels) external whenPaused {
        onlyPushChannelAdmin();
        for (uint256 i; i < _channels.length; ++i) {
            CoreTypes.Channel memory _channelData = channels[_channels[i]];
            bytes32 _channelBytesID = BaseHelper.addressToBytes32(_channels[i]);
            channelInfo[_channelBytesID] = _channelData;
            channelUpdateCounter[_channelBytesID] = oldChannelUpdateCounter[_channels[i]];
            delete channels[_channels[i]];
            delete oldChannelUpdateCounter[_channels[i]];
        }
    }
}
