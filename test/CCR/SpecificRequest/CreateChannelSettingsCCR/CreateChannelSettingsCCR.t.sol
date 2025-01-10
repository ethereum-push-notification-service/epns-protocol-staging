// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseCCRTest } from "../../BaseCCR.t.sol";
import {CrossChainRequestTypes } from "contracts/libraries/DataTypes.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { console } from "forge-std/console.sol";
import { BaseHelper } from "contracts/libraries/BaseHelper.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract CreateChannelSettingsCCR is BaseCCRTest {
    uint256 amount = ADD_CHANNEL_MIN_FEES;
    uint256 notifOptions = 2;
    string notifSettings = "1-0+2-50-20-100";
    string notifDescription = "description";

    function setUp() public override {
        BaseCCRTest.setUp();
        sourceAddress = toWormholeFormat(address(commProxy));
        (_payload, requestPayload) = getSpecificPayload(
            CrossChainRequestTypes.CrossChainFunction.CreateChannelSettings,
            BaseHelper.addressToBytes32(address(0)),
            amount,
            0,
            percentage,
            notifOptions,
            notifSettings,
            notifDescription,
            BaseHelper.addressToBytes32(actor.charlie_channel_owner)
        );
    }

    modifier whenCreateChannelSettingsIsCalled() {
        _;
    }

    function test_WhenContractIsPaused() external whenCreateChannelSettingsIsCalled {
        // it should Revert

        changePrank(actor.admin);
        commProxy.pauseContract();
        vm.expectRevert("Pausable: paused");
        changePrank(actor.charlie_channel_owner);
        commProxy.createCrossChainRequest(
            CrossChainRequestTypes.CrossChainFunction.CreateChannelSettings, _payload, amount, GasLimit
        );
    }

    function test_RevertWhen_AmountIsLessThanMinimumFees() external whenCreateChannelSettingsIsCalled {
        // it should revert
        amount = 49e18;
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidArg_LessThanExpected.selector, ADD_CHANNEL_MIN_FEES, amount)
        );
        changePrank(actor.charlie_channel_owner);
        commProxy.createCrossChainRequest(
            CrossChainRequestTypes.CrossChainFunction.CreateChannelSettings, _payload, amount, GasLimit
        );
    }

    function test_RevertWhen_EtherPassedIsLess() external whenCreateChannelSettingsIsCalled {
        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientFunds.selector));
        changePrank(actor.charlie_channel_owner);
        commProxy.createCrossChainRequest(
            CrossChainRequestTypes.CrossChainFunction.CreateChannelSettings, _payload, amount, GasLimit
        );
    }

    function test_WhenAllChecksPasses() public whenCreateChannelSettingsIsCalled {
        // it should successfully create the CCR

        vm.expectEmit(true, false, false, false);
        emit LogMessagePublished(SourceChain.WORMHOLE_RELAYER_SOURCE, 2105, 0, requestPayload, 15);
        changePrank(actor.charlie_channel_owner);
        commProxy.createCrossChainRequest{ value: 1e18 }(
            CrossChainRequestTypes.CrossChainFunction.CreateChannelSettings, _payload, amount, GasLimit
        );
    }

    modifier whenReceiveFunctionIsCalledInCore() {
        test_WhenAllChecksPasses();

        setUpDestChain();
        _;
    }

    function test_WhenSenderIsNotRegistered() external whenReceiveFunctionIsCalledInCore {
        // it should Revert

        //set sender to zero address
        coreProxy.setRegisteredSender(SourceChain.SourceChainId, toWormholeFormat(address(0)));

        vm.expectRevert("Not registered sender");
        receiveWormholeMessage(requestPayload);
    }

    function test_WhenSenderIsNotRelayer() external whenReceiveFunctionIsCalledInCore {
        // it should Revert

        coreProxy.setWormholeRelayer(address(0));
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotAdmin.selector));
        receiveWormholeMessage(requestPayload);
    }

    function test_WhenDeliveryHashIsUsedAlreadyw() external whenReceiveFunctionIsCalledInCore {
        // it should Revert

        receiveWormholeMessage(requestPayload);
        vm.expectRevert(abi.encodeWithSelector(Errors.Payload_Duplicacy_Error.selector));
        receiveWormholeMessage(requestPayload);
    }

    function test_whenReceiveChecksPass() public whenReceiveFunctionIsCalledInCore {

        uint256 HOLDER_FEE_POOL = coreProxy.HOLDER_FEE_POOL();
        uint256 WALLET_FEE_POOL = coreProxy.WALLET_FEE_POOL();
        changePrank(DestChain.WORMHOLE_RELAYER_DEST);

        string memory notifSettingRes = string(abi.encodePacked(Strings.toString(notifOptions), "+", notifSettings));

        vm.expectEmit(true, true, false, true);
        emit ChannelNotifcationSettingsAdded(BaseHelper.addressToBytes32(actor.charlie_channel_owner), notifOptions, notifSettingRes, notifDescription);

        coreProxy.receiveWormholeMessages(
            requestPayload, additionalVaas, sourceAddress, SourceChain.SourceChainId, deliveryHash
        );
        // Update states based on Fee Percentage calculation
        assertEq(coreProxy.HOLDER_FEE_POOL(), HOLDER_FEE_POOL + BaseHelper.calcPercentage(amount , HOLDER_SPLIT));
        assertEq(coreProxy.WALLET_FEE_POOL(), WALLET_FEE_POOL + amount - BaseHelper.calcPercentage(amount , HOLDER_SPLIT));            
}

    function test_whenTokensAreTransferred() external {
        vm.recordLogs();
        test_whenReceiveChecksPass();

        (address sourceNttManager, bytes32 recipient, uint256 _amount, uint16 recipientChain) =
            getMessagefromLog(vm.getRecordedLogs());

        bytes[] memory a;
        (bytes memory transceiverMessage, bytes32 hash) =
            getRequestPayload(_amount, recipient, recipientChain, sourceNttManager);

        uint balanceCoreBefore = pushToken.balanceOf(address(coreProxy));

        changePrank(DestChain.WORMHOLE_RELAYER_DEST);
        DestChain.wormholeTransceiverChain2.receiveWormholeMessages(
            transceiverMessage, // Verified
            a, // Should be zero
            bytes32(uint256(uint160(address(SourceChain.wormholeTransceiverChain1)))), // Must be a wormhole peers
            10_003, // ChainID from the call
            hash // Hash of the VAA being used
        );

        assertEq(pushToken.balanceOf(address(coreProxy)), balanceCoreBefore + amount, "Tokens in Core");
    }
}
