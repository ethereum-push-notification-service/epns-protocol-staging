pragma solidity ^0.8.20;
// SPDX-License-Identifier: MIT

/**
 * @title PushComm V3
 * @author Push Protocol
 * @notice Push Communicator, as the name suggests, is more of a Communictation Layer
 *         between END USERS and Push Core Protocol.
 *         The Communicator Protocol is comparatively much simpler & involves basic
 *         details, specifically about the USERS of the Protocols
 *
 * @dev   Some imperative functionalities that the Push Communicator Protocol allows
 *        are Subscribing to a particular channel, Unsubscribing a channel, Sending
 *        Notifications to a particular recipient or all subscribers of a Channel etc.
 * @Custom:security-contact https://immunefi.com/bug-bounty/pushprotocol/information/
 */
import { PushCommStorageV2 } from "./PushCommStorageV2.sol";
import { Errors } from "../libraries/Errors.sol";
import { IPushCommV3 } from "../interfaces/IPushCommV3.sol";
import { BaseHelper } from "../libraries/BaseHelper.sol";
import { CommTypes, CrossChainRequestTypes } from "../libraries/DataTypes.sol";
import { IERC1271 } from "../interfaces/signatures/IERC1271.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import {
    PausableUpgradeable, Initializable
} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "../interfaces/wormhole/INttManager.sol";
import "../interfaces/wormhole/IWormholeTransceiver.sol";
import "../interfaces/wormhole/IWormholeRelayer.sol";
import "../libraries/wormhole-lib/TransceiverStructs.sol";

contract PushCommV3 is Initializable, PushCommStorageV2, IPushCommV3, PausableUpgradeable {
    using SafeERC20 for IERC20;

    /* *****************************

        MODIFIERS

    ***************************** */

    modifier onlyPushChannelAdmin() {
        if (msg.sender != pushChannelAdmin) {
            revert Errors.CallerNotAdmin();
        }
        _;
    }

    modifier onlyPushGovernance() {
        if (msg.sender != governance) {
            revert Errors.CallerNotGovernance();
        }
        _;
    }

    modifier onlyPushCore() {
        if (msg.sender != PushCoreAddress) {
            revert Errors.UnauthorizedCaller(msg.sender);
        }
        _;
    }

    /* *****************************

        INITIALIZER

    ***************************** */
    function initialize(address _pushChannelAdmin, string memory _chainName) public initializer returns (bool) {
        pushChannelAdmin = _pushChannelAdmin;
        governance = _pushChannelAdmin;
        chainName = _chainName;
        chainID = block.chainid;
        return true;
    }

    /* *****************************

        SETTER FUNCTIONS

    ***************************** */

    function verifyChannelAlias(string memory _channelAddress) external {
        emit ChannelAlias(chainName, block.chainid, msg.sender, _channelAddress);
    }


    function setPushCoreAddress(address _coreAddress) external onlyPushChannelAdmin {
        PushCoreAddress = _coreAddress;
    }

    function setGovernanceAddress(address _governanceAddress) external onlyPushChannelAdmin {
        governance = _governanceAddress;
    }

    function setPushTokenAddress(address _tokenAddress) external onlyPushChannelAdmin {
        PUSH_NTT = IERC20(_tokenAddress);
    }

    function transferPushChannelAdminControl(address _newAdmin) external onlyPushChannelAdmin {
        if (_newAdmin == address(0) || _newAdmin == pushChannelAdmin) {
            revert Errors.InvalidArgument_WrongAddress(_newAdmin);
        }
        pushChannelAdmin = _newAdmin;
    }

    function pauseContract() external onlyPushChannelAdmin {
        _pause();
    }

    function unPauseContract() external onlyPushChannelAdmin {
        _unpause();
    }

    /* *****************************

         SUBSCRIBE FUNCTIONS

    ***************************** */

    /// @inheritdoc IPushCommV3
    function isUserSubscribed(address _channel, address _user) public view returns (bool) {
        CommTypes.User storage user = users[_user];
        if (user.isSubscribed[_channel] == 1) {
            return true;
        }
    }

    /// @inheritdoc IPushCommV3
    function subscribe(address _channel) external {
        _subscribe(_channel, msg.sender);
    }

    /// @inheritdoc IPushCommV3
    function batchSubscribe(address[] calldata _channelList) external {
        uint256 channelListLength = _channelList.length;
        for (uint256 i = 0; i < channelListLength;) {
            _subscribe(_channelList[i], msg.sender);
            unchecked {
                i++;
            }
        }
    }

    /**
     * @notice Base Subscribe Function that allows users to Subscribe to a Particular Channel
     *
     * @dev Initializes the User Struct with crucial details about the Channel Subscription
     *      Addes the caller as a an Activated User of the protocol. (Only if the user hasn't been added already)
     *
     * @param _channel address of the channel that the user is subscribing to
     * @param _user    address of the Subscriber
     *
     */
    function _subscribe(address _channel, address _user) private {
        if (!isUserSubscribed(_channel, _user)) {
            _addUser(_user);

            CommTypes.User storage user = users[_user];

            uint256 _subscribedCount = user.subscribedCount;

            user.isSubscribed[_channel] = 1;
            // treat the count as index and update user struct
            user.subscribed[_channel] = _subscribedCount;
            user.mapAddressSubscribed[_subscribedCount] = _channel;
            user.subscribedCount = _subscribedCount + 1; // Finally increment the subscribed count
            // Emit it
            emit Subscribe(_channel, _user);
        }
    }

    /// @inheritdoc IPushCommV3
    function subscribeBySig(
        address channel,
        address subscriber,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
    {
        // EIP-712
        if (subscriber == address(0)) {
            revert Errors.InvalidArgument_WrongAddress(subscriber);
        }
        if (nonce != nonces[subscriber]++) {
            revert Errors.Comm_InvalidNonce();
        }
        if (block.timestamp > expiry) {
            revert Errors.Comm_TimeExpired(expiry, block.timestamp);
        }

        bytes32 domainSeparator = keccak256(abi.encode(DOMAIN_TYPEHASH, NAME_HASH, block.chainid, address(this)));
        bytes32 structHash = keccak256(abi.encode(SUBSCRIBE_TYPEHASH, channel, subscriber, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        if (BaseHelper.isContract(subscriber)) {
            // use EIP-1271
            bytes4 result = IERC1271(subscriber).isValidSignature(digest, abi.encodePacked(r, s, v));
            if (result != 0x1626ba7e) {
                revert Errors.Comm_InvalidSignature_FromContract();
            }
        } else {
            // validate with in contract
            address signatory = ecrecover(digest, v, r, s);
            if (signatory != subscriber) {
                revert Errors.Comm_InvalidSignature_FromEOA();
            }
        }

        _subscribe(channel, subscriber);
    }

    /// @inheritdoc IPushCommV3
    function subscribeViaCore(address _channel, address _user) external onlyPushCore {
        _subscribe(_channel, _user);
    }

    /* *****************************

         UNSUBSCRIBE FUNCTIONS

    ***************************** */

    /// @inheritdoc IPushCommV3
    function unsubscribe(address _channel) external {
        // Call actual unsubscribe
        _unsubscribe(_channel, msg.sender);
    }

    /// @inheritdoc IPushCommV3
    function batchUnsubscribe(address[] calldata _channelList) external {
        uint256 channelListLength = _channelList.length;
        for (uint256 i = 0; i < channelListLength;) {
            _unsubscribe(_channelList[i], msg.sender);
            unchecked {
                i++;
            }
        }
    }

    /**
     * @notice Base Usubscribe Function that allows users to UNSUBSCRIBE from a Particular Channel
     * @dev Modifies the User Struct with crucial details about the Channel Unsubscription
     * @param _channel address of the channel that the user is unsubscribing from
     * @param _user address of the unsubscriber
     *
     */
    function _unsubscribe(address _channel, address _user) private {
        if (isUserSubscribed(_channel, _user)) {
            CommTypes.User storage user = users[_user];

            uint256 _subscribedCount = user.subscribedCount - 1;

            user.isSubscribed[_channel] = 0;
            user.subscribed[user.mapAddressSubscribed[_subscribedCount]] = user.subscribed[_channel];
            user.mapAddressSubscribed[user.subscribed[_channel]] = user.mapAddressSubscribed[_subscribedCount];

            // delete the last one and substract
            delete (user.subscribed[_channel]);
            delete (user.mapAddressSubscribed[_subscribedCount]);
            user.subscribedCount = _subscribedCount;

            // Emit it
            emit Unsubscribe(_channel, _user);
        }
    }

    /// @inheritdoc IPushCommV3
    function unsubscribeBySig(
        address channel,
        address subscriber,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
    {
        if (subscriber == address(0)) {
            revert Errors.InvalidArgument_WrongAddress(subscriber);
        }
        if (nonce != nonces[subscriber]++) {
            revert Errors.Comm_InvalidNonce();
        }
        if (block.timestamp > expiry) {
            revert Errors.Comm_TimeExpired(expiry, block.timestamp);
        }

        // EIP-712
        bytes32 domainSeparator = keccak256(abi.encode(DOMAIN_TYPEHASH, NAME_HASH, block.chainid, address(this)));
        bytes32 structHash = keccak256(abi.encode(UNSUBSCRIBE_TYPEHASH, channel, subscriber, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        if (BaseHelper.isContract(subscriber)) {
            // use EIP-1271
            bytes4 result = IERC1271(subscriber).isValidSignature(digest, abi.encodePacked(r, s, v));
            if (result != 0x1626ba7e) {
                revert Errors.Comm_InvalidSignature_FromContract();
            }
        } else {
            // validate with in contract
            address signatory = ecrecover(digest, v, r, s);
            if (signatory != subscriber) {
                revert Errors.Comm_InvalidSignature_FromEOA();
            }
        }
        _unsubscribe(channel, subscriber);
    }

    /// @inheritdoc IPushCommV3
    function unSubscribeViaCore(address _channel, address _user) external onlyPushCore {
        _unsubscribe(_channel, _user);
    }

    /**
     * @notice Activates/Adds a particular User's Address in the Protocol.
     *         Keeps track of the Total User Count
     * @dev   Executes its main actions only if the User is not activated yet.
     *        Does nothing if an address has already been added.
     *
     * @param _user address of the user
     */
    function _addUser(address _user) private {
        if (!users[_user].userActivated) {
            // Activates the user
            users[_user].userStartBlock = block.number;
            users[_user].userActivated = true;
            mapAddressUsers[usersCount] = _user;

            usersCount = usersCount + 1;
        }
    }

    /* *****************************

         SEND NOTIFICATOINS FUNCTIONS

    ***************************** */

    /// @inheritdoc IPushCommV3
    function addDelegate(address _delegate) external {
        if(delegatedNotificationSenders[msg.sender][_delegate] == false){
            delegatedNotificationSenders[msg.sender][_delegate] = true;
            _subscribe(msg.sender, _delegate);
            emit AddDelegate(msg.sender, _delegate);
        }
    }

    /// @inheritdoc IPushCommV3
    function removeDelegate(address _delegate) external {
        if(delegatedNotificationSenders[msg.sender][_delegate] == true){
            delegatedNotificationSenders[msg.sender][_delegate] = false;
            _unsubscribe(msg.sender, _delegate);
            emit RemoveDelegate(msg.sender, _delegate);
        }
    }

    /**
     *
     * @notice Two main CALLERS for this function-
     *          1. Channel Owner sends Notif to all Subscribers / Subset of Subscribers / Individual Subscriber
     *          2. Delegatee of Channel sends Notif to Recipients
     *
     * @dev    When a CHANNEL OWNER Calls the Function and sends a Notif:
     *          -> We ensure -> "Channel Owner Must be Valid" && "Channel Owner is the Caller"
     *          -> NOTE - Validation of wether or not an address is a CHANNEL, is done via PUSH NODES
     *
     * @dev     When a Delegatee wants to send Notif to Recipient:
     *          -> We ensure "Delegate is the Caller" && "Delegatee is Approved by Chnnel Owner"
     *
     */
    function _checkNotifReq(address _channel, address _recipient) private view returns (bool) {
        if ((_channel == msg.sender) || (delegatedNotificationSenders[_channel][msg.sender])) {
            return true;
        }

        return false;
    }

    /// @inheritdoc IPushCommV3
    function sendNotification(address _channel, address _recipient, bytes memory _identity) external returns (bool) {
        bool success = _checkNotifReq(_channel, _recipient);
        if (success) {
            // Emit the message out
            emit SendNotification(_channel, _recipient, _identity);
            return true;
        }

        return false;
    }

    /**
     * @notice Base Notification Function that Allows a Channel Owners, Delegates as well as Users to send Notifications
     *
     * @dev   Specifically designed to be called via the EIP 712 send notif function.
     *        Takes into consideration the Signatory address to perform all the imperative checks
     *
     * @param _channel address of the Channel
     * @param _recipient address of the reciever of the Notification
     * @param _signatory address of the SIGNER of the Send Notif Function call transaction
     * @param _identity Info about the Notification
     *
     */
    function _sendNotification(
        address _channel,
        address _recipient,
        address _signatory,
        bytes calldata _identity
    )
        private
        returns (bool)
    {
        if (_channel == _signatory || delegatedNotificationSenders[_channel][_signatory]) {
            // Emit the message out
            emit SendNotification(_channel, _recipient, _identity);
            return true;
        }

        return false;
    }

    /// @inheritdoc IPushCommV3
    function sendNotifBySig(
        address _channel,
        address _recipient,
        address _signer,
        bytes calldata _identity,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
        returns (bool)
    {
        if (_signer == address(0) || nonce != nonces[_signer] || block.timestamp > expiry) {
            return false;
        }

        bytes32 domainSeparator = keccak256(abi.encode(DOMAIN_TYPEHASH, NAME_HASH, block.chainid, address(this)));
        bytes32 structHash =
            keccak256(abi.encode(SEND_NOTIFICATION_TYPEHASH, _channel, _recipient, keccak256(_identity), nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        if (BaseHelper.isContract(_signer)) {
            // use EIP-1271 signature check
            bytes4 result = IERC1271(_signer).isValidSignature(digest, abi.encodePacked(r, s, v));
            if (result != 0x1626ba7e) return false;
        } else {
            address signatory = ecrecover(digest, v, r, s);
            if (signatory != _signer) return false;
        }

        // check sender & emit event
        bool success = _sendNotification(_channel, _recipient, _signer, _identity);

        // update nonce if signature valid
        nonces[_signer] = nonce + 1;

        return success;
    }

    /// @inheritdoc IPushCommV3
    function changeUserChannelSettings(address _channel, uint256 _notifID, string calldata _notifSettings) external {
        if (!isUserSubscribed(_channel, msg.sender)) {
            revert Errors.Comm_InvalidSubscriber();
        }
        string memory notifSetting = string(abi.encodePacked(Strings.toString(_notifID), "+", _notifSettings));
        userToChannelNotifs[msg.sender][_channel] = notifSetting;
        emit UserNotifcationSettingsAdded(_channel, msg.sender, _notifID, notifSetting);
    }

    /* *****************************

         WORMHOLE CROSS-CHAIN Functions

    ***************************** */

    /**
     * @notice Sets the configuration for the bridge
     * @dev This function can only be called by the Push Channel Admin
     * @param _pushNTT The address of the PUSH NTT token
     * @param _nttManager The address of the NTT Manager contract
     * @param _wormholeTransceiver The Wormhole Transceiver contract interface
     * @param _wormholeRelayerAddress The Wormhole Relayer contract interface
     * @param _recipientChain The recipient chain ID for the Wormhole
     */
    function setBridgeConfig(
        address _pushNTT,
        address _nttManager,
        IWormholeTransceiver _wormholeTransceiver,
        IWormholeRelayer _wormholeRelayerAddress,
        uint16 _recipientChain
    )
        external
        onlyPushChannelAdmin
    {
        PUSH_NTT = IERC20(_pushNTT);
        NTT_MANAGER = INttManager(_nttManager);
        WORMHOLE_TRANSCEIVER = IWormholeTransceiver(_wormholeTransceiver);
        WORMHOLE_RELAYER = IWormholeRelayer(_wormholeRelayerAddress);
        WORMHOLE_RECIPIENT_CHAIN = _recipientChain;
    }

    /**
     * @notice Sets the configuration for core fees
     * @dev Can only be called by the Push Channel Admin
     * @param _minChannelCreationFee The minimum fee for creating a channel
     * @param _feeAmount The amount of the fee
     */
    function setCoreFeeConfig(
        uint256 _minChannelCreationFee,
        uint256 _feeAmount,
        uint256 _minPoolContribution
    )
        external
        onlyPushChannelAdmin
    {
        if (_minPoolContribution == 0 || _feeAmount == 0) {
            revert Errors.InvalidArg_LessThanExpected(1, _minPoolContribution);
        }
        if (_minChannelCreationFee < _feeAmount + _minPoolContribution) {
            revert Errors.InvalidArg_LessThanExpected(_feeAmount + _minPoolContribution, _minChannelCreationFee);
        }
        MIN_POOL_CONTRIBUTION = _minPoolContribution;
        ADD_CHANNEL_MIN_FEES = _minChannelCreationFee;
        FEE_AMOUNT = _feeAmount;
    }

    /**
     * @notice Quotes the cost of bridging tokens to the recipient chain
     * @dev Calls the Wormhole Transceiver to get the delivery price
     * @return cost The cost of bridging tokens
     */
    function quoteTokenBridgingCost() public view returns (uint256 cost) {
        TransceiverStructs.TransceiverInstruction memory transceiverInstruction =
            TransceiverStructs.TransceiverInstruction({ index: 0, payload: abi.encodePacked(false) });
        cost = WORMHOLE_TRANSCEIVER.quoteDeliveryPrice(WORMHOLE_RECIPIENT_CHAIN, transceiverInstruction);
    }

    /**
     * @notice Quotes the cost of relaying a message to the target chain with the specified gas limit
     * @dev Calls the Wormhole Relayer to get the EVM delivery price
     * @param targetChain The chain to which the message is being relayed
     * @param gasLimit The gas limit for the message relay
     * @return cost The cost of relaying the message
     */
    function quoteMsgRelayCost(uint16 targetChain, uint256 gasLimit) public view returns (uint256 cost) {
        (cost,) = WORMHOLE_RELAYER.quoteEVMDeliveryPrice(targetChain, 0, gasLimit);
    }

    /**
     * @notice Creates a cross-chain request based on the specified function type and payload
     * @dev Implements restrictions and calls the internal function to create the cross-chain request
     * @param functionType The type of cross-chain function to execute
     * @param payload The payload data for the cross-chain request
     * @param amount The amount of tokens to be transferred
     * @param gasLimit The gas limit for the cross-chain request
     */
    function createCrossChainRequest(
        CrossChainRequestTypes.CrossChainFunction functionType,
        bytes calldata payload,
        uint256 amount,
        uint256 gasLimit
    )
        external
        payable
        whenNotPaused
    {
        // Implement restrictions based on functionType

        if (functionType == CrossChainRequestTypes.CrossChainFunction.AddChannel || 
            functionType == CrossChainRequestTypes.CrossChainFunction.CreateChannelSettings ||
            functionType == CrossChainRequestTypes.CrossChainFunction.ReactivateChannel ) {
            if (amount < ADD_CHANNEL_MIN_FEES) {
                revert Errors.InvalidArg_LessThanExpected(ADD_CHANNEL_MIN_FEES, amount);
            }
        } else if (functionType == CrossChainRequestTypes.CrossChainFunction.IncentivizedChat) {
            if (amount < FEE_AMOUNT) {
                revert Errors.InvalidArg_LessThanExpected(FEE_AMOUNT, amount);
            }
        } else if (functionType == CrossChainRequestTypes.CrossChainFunction.ArbitraryRequest) {
            if (amount == 0) {
                revert Errors.InvalidArg_LessThanExpected(1, amount);
            }
        }
        bytes memory requestPayload = abi.encode(functionType, payload, amount, msg.sender);

        // Call the internal function to create the cross-chain request
        _createCrossChainRequest(requestPayload, amount, gasLimit);
    }

    /**
     * @notice Internal function to create a cross-chain request
     * @dev Calculates the message bridge cost and token bridge cost, transfers tokens, and sends the payload
     * @param requestPayload The encoded payload for the cross-chain request
     * @param amount The amount of tokens to be transferred
     * @param gasLimit The gas limit for the cross-chain request
     */
    function _createCrossChainRequest(bytes memory requestPayload, uint256 amount, uint256 gasLimit) internal {
        // Calculate MSG bridge cost and Token Bridge cost
        uint16 recipientChain = WORMHOLE_RECIPIENT_CHAIN;

        uint256 messageBridgeCost = quoteMsgRelayCost(recipientChain, gasLimit);
        uint256 tokenBridgeCost = quoteTokenBridgingCost();
        address coreAddress = PushCoreAddress;
        if (amount != 0) {
            if (msg.value < (messageBridgeCost + tokenBridgeCost)) {
                revert Errors.InsufficientFunds();
            }
            IERC20 PushNtt = PUSH_NTT;
            INttManager NttManager = NTT_MANAGER;

            PushNtt.transferFrom(msg.sender, address(this), amount);
            PushNtt.approve(address(NttManager), amount);
            NttManager.transfer{ value: tokenBridgeCost }(
                amount,
                recipientChain,
                BaseHelper.addressToBytes32(coreAddress),
                BaseHelper.addressToBytes32(msg.sender),
                false,
                new bytes(1)
            );
        } else if (msg.value < (messageBridgeCost)) {
            revert Errors.InsufficientFunds();
        }

        // Relay the RequestData Payload
        WORMHOLE_RELAYER.sendPayloadToEvm{ value: messageBridgeCost }(
            recipientChain,
            coreAddress,
            requestPayload,
            0, // no receiver value needed since we're just passing a message
            gasLimit,
            recipientChain,
            msg.sender // Refund address is of the sender
        );
    }

    /**
     * @notice Function to allow the Push Channel Admin to bridge PROTOCOL_POOL_FEES from Comm to Core
     * @dev    Can only be called by the Push Channel Admin
     * @param  amount Amount to be bridged
     */
    // Should be only admin
    // Should only bridge NTT TOKENS FROM COMM TO CORE on ethereum
    function transferFeePoolToCore(uint256 amount, uint256 gasLimit) external payable onlyPushChannelAdmin {
        uint256 protocolPoolFee = PROTOCOL_POOL_FEE;
        if (protocolPoolFee < amount) {
            revert Errors.InsufficientFunds();
        }
        address coreAddress = PushCoreAddress;
        uint16 recipientChain = WORMHOLE_RECIPIENT_CHAIN;
        uint256 messageBridgeCost = quoteMsgRelayCost(recipientChain, gasLimit);
        uint256 tokenBridgeCost = quoteTokenBridgingCost();

        if (msg.value < (messageBridgeCost + tokenBridgeCost)) {
            revert Errors.InsufficientFunds();
        }

        protocolPoolFee = protocolPoolFee - amount;
        PROTOCOL_POOL_FEE = protocolPoolFee;

        INttManager NttManager = NTT_MANAGER;

        PUSH_NTT.approve(address(NttManager), amount);
        NttManager.transfer{ value: tokenBridgeCost }(
            amount,
            recipientChain,
            BaseHelper.addressToBytes32(coreAddress),
            BaseHelper.addressToBytes32(msg.sender),
            false,
            new bytes(1)
        );

        bytes memory requestPayload =
            abi.encode(CrossChainRequestTypes.CrossChainFunction.AdminRequest_AddPoolFee, bytes(""), amount, msg.sender);

        // Relay the RequestData Payload
        WORMHOLE_RELAYER.sendPayloadToEvm{ value: messageBridgeCost }(
            recipientChain,
            coreAddress,
            requestPayload,
            0, // no receiver value needed since we're just passing a message
            gasLimit,
            recipientChain,
            msg.sender // Refund address is of the sender
        );
    }
    ///@notice Wallet PGP attach code starts here

    /* *****************************

         USER PGP Registry Functions

    ***************************** */

    function registerUserPGP(bytes calldata _caipData, string calldata _pgp, bool _isNFT) external {
        uint256 fee = FEE_AMOUNT;
        PROTOCOL_POOL_FEE += fee;
        PUSH_NTT.safeTransferFrom(msg.sender, address(this), fee);

        bytes32 caipHash = keccak256(_caipData);

        if (!_isNFT) {
            (, uint256 _chainId, address _wallet) = abi.decode(_caipData, (string, uint256, address));

            if (bytes(walletToPGP[caipHash]).length != 0 || _wallet != msg.sender) {
                revert Errors.Comm_InvalidArguments();
            }
            emit UserPGPRegistered(_pgp, _wallet, chainName, chainID);
        } else {
            (,,, address _nft, uint256 _id,) =
                abi.decode(_caipData, (string, string, uint256, address, uint256, uint256));
            require(IERC721(_nft).ownerOf(_id) == msg.sender, "NFT not owned");

            if (bytes(walletToPGP[caipHash]).length != 0) {
                string memory _previousPgp = walletToPGP[caipHash];
                emit UserPGPRemoved(_previousPgp, _nft, _id, chainName, chainID);
            }
            emit UserPGPRegistered(_pgp, _nft, _id, chainName, chainID);
        }
        walletToPGP[caipHash] = _pgp;
    }

    function removeWalletFromUser(bytes calldata _caipData, bool _isNFT) public {
        bytes32 caipHash = keccak256(_caipData);
        if (bytes(walletToPGP[caipHash]).length == 0) {
            revert("Invalid Call");
        }

        uint256 fee = FEE_AMOUNT;
        PROTOCOL_POOL_FEE += fee;
        PUSH_NTT.safeTransferFrom(msg.sender, address(this), fee);

        string memory pgp = walletToPGP[caipHash];

        if (!_isNFT) {
            (, uint256 _chainId, address _wallet) = abi.decode(_caipData, (string, uint256, address));

            if (_wallet != msg.sender) {
                revert Errors.Comm_InvalidArguments();
            }
            emit UserPGPRemoved(pgp, _wallet, chainName, chainID);
        } else {
            (,,, address _nft, uint256 _id,) =
                abi.decode(_caipData, (string, string, uint256, address, uint256, uint256));

            require(IERC721(_nft).ownerOf(_id) == msg.sender, "NFT not owned");
            emit UserPGPRemoved(pgp, _nft, _id, chainName, chainID);
        }
        delete walletToPGP[caipHash];
    }
}
