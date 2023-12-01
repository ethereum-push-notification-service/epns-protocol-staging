pragma solidity ^0.8.20;

/**
 * EPNS Core is the main protocol that deals with the imperative
 * features and functionalities like Channel Creation, pushChannelAdmin etc.
 *
 * This protocol will be specifically deployed on Ethereum Blockchain while the Communicator
 * protocols can be deployed on Multiple Chains.
 * The EPNS Core is more inclined towards the storing and handling the Channel related
 * Functionalties.
 *
 */
import "./PushCoreStorageV1_5.sol";
import "./PushCoreStorageV2.sol";
import "../interfaces/IPUSH.sol";
import "../interfaces/IUniswapV2Router.sol";
import "../interfaces/IEPNSCommV1.sol";
import "../libraries/Errors.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { PausableUpgradeable, Initializable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract PushCoreV2_5 is Initializable, PushCoreStorageV1_5, PausableUpgradeable, PushCoreStorageV2 {
    using SafeERC20 for IERC20;

    /* ***************
        EVENTS
     *************** */
event UpdateChannel(address indexed channel, bytes identity, uint256 indexed amountDeposited);
    event RewardsClaimed(address indexed user, uint256 rewardAmount);
    event ChannelVerified(address indexed channel, address indexed verifier);
    event ChannelVerificationRevoked(address indexed channel, address indexed revoker);

    event DeactivateChannel(address indexed channel, uint256 indexed amountRefunded);
    event ReactivateChannel(address indexed channel, uint256 indexed amountDeposited);
    event ChannelBlocked(address indexed channel);
    event AddChannel(address indexed channel, ChannelType indexed channelType, bytes identity);
    event ChannelNotifcationSettingsAdded(
        address _channel, uint256 totalNotifOptions, string _notifSettings, string _notifDescription
    );
    event AddSubGraph(address indexed channel, bytes _subGraphData);
    event TimeBoundChannelDestroyed(address indexed channel, uint256 indexed amountRefunded);
    event ChannelOwnershipTransfer(address indexed channel, address indexed newOwner);
    event Staked(address indexed user, uint256 indexed amountStaked);
    event Unstaked(address indexed user, uint256 indexed amountUnstaked);
    event RewardsHarvested(address indexed user, uint256 indexed rewardAmount, uint256 fromEpoch, uint256 tillEpoch);
    event IncentivizeChatReqReceived(
        address requestSender,
        address requestReceiver,
        uint256 amountForReqReceiver,
        uint256 feePoolAmount,
        uint256 timestamp
    );
    event ChatIncentiveClaimed(address indexed user, uint256 indexed amountClaimed);

    /* ***************
        INITIALIZER
    *************** */

    function initialize(
        address _pushChannelAdmin,
        address _pushTokenAddress,
        address _wethAddress,
        address _uniswapRouterAddress,
        address _lendingPoolProviderAddress,
        address _daiAddress,
        address _aDaiAddress,
        uint256 _referralCode
    )
        public
        initializer
        returns (bool success)
    {
        // setup addresses
        pushChannelAdmin = _pushChannelAdmin;
        governance = _pushChannelAdmin; // Will be changed on-Chain governance Address later
        daiAddress = _daiAddress;
        aDaiAddress = _aDaiAddress;
        WETH_ADDRESS = _wethAddress;
        REFERRAL_CODE = _referralCode;
        PUSH_TOKEN_ADDRESS = _pushTokenAddress;
        UNISWAP_V2_ROUTER = _uniswapRouterAddress;
        lendingPoolProviderAddress = _lendingPoolProviderAddress;

        FEE_AMOUNT = 10 ether; // PUSH Amount that will be charged as Protocol Pool Fees
        MIN_POOL_CONTRIBUTION = 50 ether; // Channel's poolContribution should never go below MIN_POOL_CONTRIBUTION
        ADD_CHANNEL_MIN_FEES = 50 ether; // can never be below MIN_POOL_CONTRIBUTION

        ADJUST_FOR_FLOAT = 10 ** 7;
        groupLastUpdate = block.number;
        groupNormalizedWeight = ADJUST_FOR_FLOAT; // Always Starts with 1 * ADJUST FOR FLOAT

        // Create Channel
        success = true;
    }

    /* ***************

    SETTER & HELPER FUNCTIONS

    *************** */
    function onlyPushChannelAdmin() private view {
        if (msg.sender != pushChannelAdmin) {
            revert InvalidCaller();
        }
    }

    function onlyGovernance() private view {
        if (msg.sender != governance) {
            revert InvalidCaller();
        }
    }

    function onlyActivatedChannels(address _channel) private view {
        if (channels[_channel].channelState != 1) {
            revert InvalidChannel();
        }
    }

    function onlyChannelOwner(address _channel) private view {
        if (
            ((channels[_channel].channelState != 1 && msg.sender != _channel) ||
                (msg.sender != pushChannelAdmin && _channel != address(0x0)))
        ) {
            revert InvalidCaller();
        }
    }

    function addSubGraph(bytes calldata _subGraphData) external {
        onlyActivatedChannels(msg.sender);
        emit AddSubGraph(msg.sender, _subGraphData);
    }

    function setEpnsCommunicatorAddress(address _commAddress) external {
        onlyPushChannelAdmin();
        epnsCommunicator = _commAddress;
    }

    function setGovernanceAddress(address _governanceAddress) external {
        onlyPushChannelAdmin();
        governance = _governanceAddress;
    }

    function setFeeAmount(uint256 _newFees) external {
        onlyGovernance();
        if (_newFees <= 0 && _newFees > ADD_CHANNEL_MIN_FEES) {
            revert InvalidArgument("Invalid Argument");
        }
        FEE_AMOUNT = _newFees;
    }

    function setMinPoolContribution(uint256 _newAmount) external {
        onlyGovernance();
        if (_newAmount <= 0) {
            revert InvalidArgument("invalid Argument");
        }
        MIN_POOL_CONTRIBUTION = _newAmount;
    }

    function pauseContract() external {
        onlyGovernance();
        _pause();
    }

    function unPauseContract() external {
        onlyGovernance();
        _unpause();
    }

    /**
     * @notice Allows to set the Minimum amount threshold for Creating Channels
     *
     * @dev    Minimum required amount can never be below MIN_POOL_CONTRIBUTION
     *
     * @param _newFees new minimum fees required for Channel Creation
     *
     */
    function setMinChannelCreationFees(uint256 _newFees) external {
        onlyGovernance();
        if (_newFees < MIN_POOL_CONTRIBUTION) {
            revert InvalidArgument("Invalid Argument");
        }
        ADD_CHANNEL_MIN_FEES = _newFees;
    }

    function transferPushChannelAdminControl(address _newAdmin) external {
        onlyPushChannelAdmin();
        if (_newAdmin == address(0) || _newAdmin == pushChannelAdmin) {
            revert InvalidArgument("Invalid Argument");
        }
        pushChannelAdmin = _newAdmin;
    }

    /* ***********************************

        CHANNEL RELATED FUNCTIONALTIES

    **************************************/
    /**
     * @notice Allows Channel Owner to update their Channel's Details like Description, Name, Logo, etc by passing in a
     * new identity bytes hash
     *
     * @dev  Only accessible when contract is NOT Paused
     *       Only accessible when Caller is the Channel Owner itself
     *       If Channel Owner is updating the Channel Meta for the first time:
     *       Required Fees => 50 PUSH tokens
     *
     *       If Channel Owner is updating the Channel Meta for the N time:
     *       Required Fees => (50 * N) PUSH Tokens
     *
     *       Total fees goes to PROTOCOL_POOL_FEES
     *       Updates the channelUpdateCounter
     *       Updates the channelUpdateBlock
     *       Records the Block Number of the Block at which the Channel is being updated
     *       Emits an event with the new identity for the respective Channel Address
     *
     * @param _channel     address of the Channel
     * @param _newIdentity bytes Value for the New Identity of the Channel
     * @param _amount amount of PUSH Token required for updating channel details.
     *
     */
    function updateChannelMeta(address _channel, bytes calldata _newIdentity, uint256 _amount) external whenNotPaused {
        onlyChannelOwner(_channel);
        uint256 updateCounter = channelUpdateCounter[_channel] + 1;
        uint256 requiredFees = ADD_CHANNEL_MIN_FEES * updateCounter;

        if (_amount < requiredFees) {
            revert InvalidAmount();
        }

        PROTOCOL_POOL_FEES = PROTOCOL_POOL_FEES + _amount;
        channelUpdateCounter[_channel] = updateCounter;
        channels[_channel].channelUpdateBlock = block.number;

        IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(_channel, address(this), _amount);
        emit UpdateChannel(_channel, _newIdentity, _amount);
    }

    /**
     * @notice An external function that allows users to Create their Own Channels by depositing a valid amount of PUSH
     * @dev    Only allows users to Create One Channel for a specific address.
     *         Only allows a Valid Channel Type to be assigned for the Channel Being created.
     *         Validates and Transfers the amount of PUSH  from the Channel Creator to the EPNS Core Contract
     *
     * @param  _channelType the type of the Channel Being created
     * @param  _identity the bytes value of the identity of the Channel
     * @param  _amount Amount of PUSH  to be deposited before Creating the Channel
     * @param  _channelExpiryTime the expiry time for time bound channels
     *
     */
    function createChannelWithPUSH(
        ChannelType _channelType,
        bytes calldata _identity,
        uint256 _amount,
        uint256 _channelExpiryTime
    )
        external
        whenNotPaused
    {        if (_amount < ADD_CHANNEL_MIN_FEES) {
            revert InvalidAmount();
        }
        if (channels[msg.sender].channelState != 0) {
            revert InvalidChannel();
        }
        if (
            _channelType != ChannelType.InterestBearingOpen ||
            _channelType != ChannelType.InterestBearingMutual ||
            _channelType != ChannelType.TimeBound ||
            _channelType != ChannelType.TokenGaited
        ) {
            revert InvalidArgument("Invalid Channel Type");
        }

        emit AddChannel(msg.sender, _channelType, _identity);

        IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(msg.sender, address(this), _amount);
        _createChannel(msg.sender, _channelType, _amount, _channelExpiryTime);
    }

    /**
     * @notice Base Channel Creation Function that allows users to Create Their own Channels and Stores crucial details
     * about the Channel being created
     * @dev    -Initializes the Channel Struct
     *         -Subscribes the Channel's Owner to Imperative EPNS Channels as well as their Own Channels
     *         - Updates the CHANNEL_POOL_FUNDS and PROTOCOL_POOL_FEES in the contract.
     *
     * @param _channel         address of the channel being Created
     * @param _channelType     The type of the Channel
     * @param _amountDeposited The total amount being deposited while Channel Creation
     * @param _channelExpiryTime the expiry time for time bound channels
     *
     */
    function _createChannel(
        address _channel,
        ChannelType _channelType,
        uint256 _amountDeposited,
        uint256 _channelExpiryTime
    ) private {
        uint256 poolFeeAmount = FEE_AMOUNT;
        uint256 poolFundAmount = _amountDeposited - poolFeeAmount;
        //store funds in pool_funds & pool_fees
        CHANNEL_POOL_FUNDS = CHANNEL_POOL_FUNDS + poolFundAmount;
        PROTOCOL_POOL_FEES = PROTOCOL_POOL_FEES + poolFeeAmount;

        // Calculate channel weight
        uint256 _channelWeight = (poolFundAmount * ADJUST_FOR_FLOAT) / MIN_POOL_CONTRIBUTION;
        // Next create the channel and mark user as channellized
        channels[_channel].channelState = 1;
        channels[_channel].poolContribution = poolFundAmount;
        channels[_channel].channelType = _channelType;
        channels[_channel].channelStartBlock = block.number;
        channels[_channel].channelUpdateBlock = block.number;
        channels[_channel].channelWeight = _channelWeight;
        // Add to map of addresses and increment channel count
        uint256 _channelsCount = channelsCount;
        channelsCount = _channelsCount + 1;

        if (_channelType == ChannelType.TimeBound) {
            if (_channelExpiryTime <= block.timestamp) {
                revert InvalidArgument("Invalid channelExpiryTime");
            }
            channels[_channel].expiryTime = _channelExpiryTime;
        }

        // Subscribe them to their own channel as well
        address _epnsCommunicator = epnsCommunicator;
        if (_channel != pushChannelAdmin) {
            IEPNSCommV1(_epnsCommunicator).subscribeViaCore(_channel, _channel);
        }

        // All Channels are subscribed to EPNS Alerter as well, unless it's the EPNS Alerter channel iteself
        if (_channel != address(0x0)) {
            IEPNSCommV1(_epnsCommunicator).subscribeViaCore(address(0x0), _channel);
            IEPNSCommV1(_epnsCommunicator).subscribeViaCore(_channel, pushChannelAdmin);
        }
    }

    /**
     * @notice Function that allows Channel Owners to Destroy their Time-Bound Channels
     * @dev    - Can only be called the owner of the Channel or by the EPNS Governance/Admin.
     *         - EPNS Governance/Admin can only destory a channel after 14 Days of its expriation timestamp.
     *         - Can only be called if the Channel is of type - TimeBound
     *         - Can only be called after the Channel Expiry time is up.
     *         - If Channel Owner destroys the channel after expiration, he/she recieves back refundable amount &
     * CHANNEL_POOL_FUNDS decreases.
     *         - If Channel is destroyed by EPNS Governance/Admin, No refunds for channel owner. Refundable Push tokens
     * are added to PROTOCOL_POOL_FEES.
     *         - Deletes the Channel completely
     *         - It transfers back refundable tokenAmount back to the USER.
     *
     */

    function destroyTimeBoundChannel(address _channelAddress) external whenNotPaused {
        onlyActivatedChannels(_channelAddress);
        Channel memory channelData = channels[_channelAddress];

        if (channelData.channelType != ChannelType.TimeBound) {
            revert InvalidChannel();
        }
        if (
            (msg.sender != _channelAddress &&
                channelData.expiryTime >= block.timestamp) ||
            (msg.sender != pushChannelAdmin &&
                channelData.expiryTime + 14 days >= block.timestamp)
        ) {
            revert InvalidArgument("Invalid Caller or Channel Not Expired");
        }
        uint256 totalRefundableAmount = channelData.poolContribution;

        if (msg.sender != pushChannelAdmin) {
            CHANNEL_POOL_FUNDS = CHANNEL_POOL_FUNDS - totalRefundableAmount;
            IERC20(PUSH_TOKEN_ADDRESS).safeTransfer(msg.sender, totalRefundableAmount);
        } else {
            CHANNEL_POOL_FUNDS = CHANNEL_POOL_FUNDS - totalRefundableAmount;
            PROTOCOL_POOL_FEES = PROTOCOL_POOL_FEES + totalRefundableAmount;
        }
        // Unsubscribing from imperative Channels
        address _epnsCommunicator = epnsCommunicator;
        IEPNSCommV1(_epnsCommunicator).unSubscribeViaCore(address(0x0), _channelAddress);
        IEPNSCommV1(_epnsCommunicator).unSubscribeViaCore(_channelAddress, _channelAddress);
        IEPNSCommV1(_epnsCommunicator).unSubscribeViaCore(_channelAddress, pushChannelAdmin);
        // Decrement Channel Count and Delete Channel Completely
        channelsCount = channelsCount - 1;
        delete channels[_channelAddress];

        emit TimeBoundChannelDestroyed(msg.sender, totalRefundableAmount);
    }

    /**
     * @notice - Deliminated Notification Settings string contains -> Total Notif Options + Notification Settings
     * For instance: 5+1-0+2-50-20-100+1-1+2-78-10-150
     *  5 -> Total Notification Options provided by a Channel owner
     *
     *  For Boolean Type Notif Options
     *  1-0 -> 1 stands for BOOLEAN type - 0 stands for Default Boolean Type for that Notifcation(set by Channel Owner),
     * In this case FALSE.
     *  1-1 stands for BOOLEAN type - 1 stands for Default Boolean Type for that Notifcation(set by Channel Owner), In
     * this case TRUE.
     *
     *  For SLIDER TYPE Notif Options
     *   2-50-20-100 -> 2 stands for SLIDER TYPE - 50 stands for Default Value for that Option - 20 is the Start Range
     * of that SLIDER - 100 is the END Range of that SLIDER Option
     *  2-78-10-150 -> 2 stands for SLIDER TYPE - 78 stands for Default Value for that Option - 10 is the Start Range of
     * that SLIDER - 150 is the END Range of that SLIDER Option
     *
     *  @param _notifOptions - Total Notification options provided by the Channel Owner
     *  @param _notifSettings- Deliminated String of Notification Settings
     *  @param _notifDescription - Description of each Notification that depicts the Purpose of that Notification
     *  @param _amountDeposited - Fees required for setting up channel notification settings
     *
     */
    function createChannelSettings(
        uint256 _notifOptions,
        string calldata _notifSettings,
        string calldata _notifDescription,
        uint256 _amountDeposited
    )
        external
    {
        onlyActivatedChannels(msg.sender);
        if (_amountDeposited < ADD_CHANNEL_MIN_FEES) {
            revert InvalidAmount();
        }
        string memory notifSetting = string(abi.encodePacked(Strings.toString(_notifOptions), "+", _notifSettings));
        channelNotifSettings[msg.sender] = notifSetting;

        PROTOCOL_POOL_FEES = PROTOCOL_POOL_FEES + _amountDeposited;
        IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(msg.sender, address(this), _amountDeposited);
        emit ChannelNotifcationSettingsAdded(msg.sender, _notifOptions, notifSetting, _notifDescription);
    }

    /**
     * @notice Allows Channel Owner to Deactivate his/her Channel for any period of Time. Channels Deactivated can be
     * Activated again.
     * @dev    - Function can only be Called by Already Activated Channels
     *         - Calculates the totalRefundableAmount for the Channel Owner.
     *         - The function deducts MIN_POOL_CONTRIBUTION from refundAble amount to ensure that channel's weight &
     * poolContribution never becomes ZERO.
     *         - Updates the State of the Channel(channelState) and the New Channel Weight in the Channel's Struct
     *         - In case, the Channel Owner wishes to reactivate his/her channel, they need to Deposit at least the
     * Minimum required PUSH  while reactivating.
     *
     */

    function deactivateChannel() external whenNotPaused {
        onlyActivatedChannels(msg.sender);
        Channel storage channelData = channels[msg.sender];

        uint256 minPoolContribution = MIN_POOL_CONTRIBUTION;
        uint256 totalRefundableAmount = channelData.poolContribution - minPoolContribution;

        uint256 _newChannelWeight = (minPoolContribution * ADJUST_FOR_FLOAT) / minPoolContribution;

        channelData.channelState = 2;
        CHANNEL_POOL_FUNDS = CHANNEL_POOL_FUNDS - totalRefundableAmount;
        channelData.channelWeight = _newChannelWeight;
        channelData.poolContribution = minPoolContribution;

        IERC20(PUSH_TOKEN_ADDRESS).safeTransfer(msg.sender, totalRefundableAmount);

        emit DeactivateChannel(msg.sender, totalRefundableAmount);
    }

    /**
     * @notice Allows Channel Owner to Reactivate his/her Channel again.
     * @dev    - Function can only be called by previously Deactivated Channels
     *         - Channel Owner must Depost at least minimum amount of PUSH  to reactivate his/her channel.
     *         - Deposited PUSH amount is distributed between CHANNEL_POOL_FUNDS and PROTOCOL_POOL_FEES
     *         - Calculation of the new Channel Weight and poolContribution is performed and stored
     *         - Updates the State of the Channel(channelState) in the Channel's Struct.
     * @param _amount Amount of PUSH to be deposited
     *
     */

    function reactivateChannel(uint256 _amount) external whenNotPaused {
        if (
            _amount < ADD_CHANNEL_MIN_FEES ||
            channels[msg.sender].channelState != 2
        ) {
            revert InvalidArgument("Invalid Amount Or Channel Is Active");
        }

        IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(msg.sender, address(this), _amount);
        uint256 poolFeeAmount = FEE_AMOUNT;
        uint256 poolFundAmount = _amount - poolFeeAmount;
        //store funds in pool_funds & pool_fees
        CHANNEL_POOL_FUNDS = CHANNEL_POOL_FUNDS + poolFundAmount;
        PROTOCOL_POOL_FEES = PROTOCOL_POOL_FEES + poolFeeAmount;

        Channel storage channelData = channels[msg.sender];

        uint256 _newPoolContribution = channelData.poolContribution + poolFundAmount;
        uint256 _newChannelWeight = (_newPoolContribution * ADJUST_FOR_FLOAT) / MIN_POOL_CONTRIBUTION;

        channelData.channelState = 1;
        channelData.poolContribution = _newPoolContribution;
        channelData.channelWeight = _newChannelWeight;

        emit ReactivateChannel(msg.sender, _amount);
    }

    /**
     * @notice ALlows the pushChannelAdmin to Block any particular channel Completely.
     *
     * @dev    - Can only be called by pushChannelAdmin
     *         - Can only be Called for Activated Channels
     *         - Can only Be Called for NON-BLOCKED Channels
     *
     *         - Updates channel's state to BLOCKED ('3')
     *         - Decreases the Channel Count
     *         - Since there is no refund, the channel's poolContribution is added to PROTOCOL_POOL_FEES and Removed
     * from CHANNEL_POOL_FUNDS
     *         - Emit 'ChannelBlocked' Event
     * @param _channelAddress Address of the Channel to be blocked
     *
     */

    function blockChannel(address _channelAddress) external whenNotPaused {
        onlyPushChannelAdmin();
        if (
            ((channels[_channelAddress].channelState == 3) &&
                (channels[_channelAddress].channelState == 0))
        ) {
            revert InvalidChannel();
        }
        uint256 minPoolContribution = MIN_POOL_CONTRIBUTION;
        Channel storage channelData = channels[_channelAddress];
        // add channel's currentPoolContribution to PoolFees - (no refunds if Channel is blocked)
        // Decrease CHANNEL_POOL_FUNDS by currentPoolContribution
        uint256 currentPoolContribution = channelData.poolContribution - minPoolContribution;
        CHANNEL_POOL_FUNDS = CHANNEL_POOL_FUNDS - currentPoolContribution;
        PROTOCOL_POOL_FEES = PROTOCOL_POOL_FEES + currentPoolContribution;

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

    /**
     * @notice    Function is designed to tell if a channel is verified or not
     * @dev       Get if channel is verified or not
     * @param    _channel Address of the channel to be Verified
     * @return   verificationStatus  Returns 0 for not verified, 1 for primary verification, 2 for secondary
     * verification
     *
     */
    function getChannelVerfication(address _channel) public view returns (uint8 verificationStatus) {
        address verifiedBy = channels[_channel].verifiedBy;
        bool logicComplete = false;

        // Check if it's primary verification
        if (
            verifiedBy == pushChannelAdmin ||
            _channel == address(0x0) ||
            _channel == pushChannelAdmin
        ) {
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
                    verifiedBy = channels[verifiedBy].verifiedBy;
                }
            }
        }
    }

    function batchVerification(
        uint256 _startIndex,
        uint256 _endIndex,
        address[] calldata _channelList
    )
        external
        returns (bool)
    {
        onlyPushChannelAdmin();
        for (uint256 i = _startIndex; i < _endIndex; i++) {
            verifyChannel(_channelList[i]);
        }
        return true;
    }

    /**
     * @notice    Function is designed to verify a channel
     * @dev       Channel will be verified by primary or secondary verification, will fail or upgrade if already
     * verified
     * @param    _channel Address of the channel to be Verified
     *
     */
    function verifyChannel(address _channel) public {
        onlyActivatedChannels(_channel);
        // Check if caller is verified first
        uint8 callerVerified = getChannelVerfication(msg.sender);
        if (callerVerified <= 0) {
            revert InvalidCallerParam("Unverified Caller");
        }

        // Check if channel is verified
        uint8 channelVerified = getChannelVerfication(_channel);
        if (channelVerified != 0 || msg.sender != pushChannelAdmin) {
            revert InvalidChannel();
        }

        // Verify channel
        channels[_channel].verifiedBy = msg.sender;

        // Emit event
        emit ChannelVerified(_channel, msg.sender);
    }

    /**
     * @notice    Function is designed to unverify a channel
     * @dev       Channel who verified this channel or Push Channel Admin can only revoke
     * @param    _channel Address of the channel to be unverified
     *
     */
    function unverifyChannel(address _channel) public {
        if (
            channels[_channel].verifiedBy != msg.sender ||
            msg.sender != pushChannelAdmin
        ) {
            revert InvalidCaller();
        }

        // Unverify channel
        channels[_channel].verifiedBy = address(0x0);

        // Emit Event
        emit ChannelVerificationRevoked(_channel, msg.sender);
    }

    /**
     * Core-V2: Stake and Claim Functions **
     */

    function updateStakingAddress(address _stakingAddress) external {
        onlyPushChannelAdmin();
        feePoolStakingContract = _stakingAddress;
    }

    function sendFunds(address _user, uint256 _amount) external {
        if (msg.sender != feePoolStakingContract) {
            revert InvalidCaller();
        }
        IERC20(PUSH_TOKEN_ADDRESS).transfer(_user, _amount);
    }

    /**
     * Allows caller to add pool_fees at any given epoch
     *
     */
    function addPoolFees(uint256 _rewardAmount) external {
        IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(msg.sender, address(this), _rewardAmount);
        PROTOCOL_POOL_FEES = PROTOCOL_POOL_FEES + _rewardAmount;
    }
    /**
     * @notice Designed to handle the incoming Incentivized Chat Request Data and PUSH tokens.
     * @dev    This function currently handles the PUSH tokens that enters the contract due to any
     *         activation of incentivizied chat request from Communicator contract.
     *          - Can only be called by Communicator contract
     *          - Records and keeps track of Pool Funds and Pool Fees
     *          - Stores the PUSH tokens for the Celeb User, which can be claimed later only by that specific user.
     * @param  requestSender    Address that initiates the incentivized chat request
     * @param  requestReceiver  Address of the target user for whom the request is activated.
     * @param  amount           Amount of PUSH tokens deposited for activating the chat request
     */

    function handleChatRequestData(address requestSender, address requestReceiver, uint256 amount) external {
          if (msg.sender != epnsCommunicator) {
            revert InvalidCaller();
        }
        uint256 poolFeeAmount = FEE_AMOUNT;
        uint256 requestReceiverAmount = amount - poolFeeAmount;

        celebUserFunds[requestReceiver] += requestReceiverAmount;
        PROTOCOL_POOL_FEES = PROTOCOL_POOL_FEES + poolFeeAmount;

        emit IncentivizeChatReqReceived(
            requestSender, requestReceiver, requestReceiverAmount, poolFeeAmount, block.timestamp
        );
    }

    /**
     * @notice Allows the Celeb User(for whom chat requests were triggered) to claim their PUSH token earings.
     * @dev    Only accessible if a particular user has a non-zero PUSH token earnings in contract.
     * @param  _amount Amount of PUSH tokens to be claimed
     */
    function claimChatIncentives(uint256 _amount) external {
        if (celebUserFunds[msg.sender] < _amount) {
            revert InvalidAmount();
        }

        celebUserFunds[msg.sender] -= _amount;
        IERC20(PUSH_TOKEN_ADDRESS).safeTransfer(msg.sender, _amount);

        emit ChatIncentiveClaimed(msg.sender, _amount);
    }
}