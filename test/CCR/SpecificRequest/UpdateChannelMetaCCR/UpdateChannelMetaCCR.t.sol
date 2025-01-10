// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseCCRTest } from "../../BaseCCR.t.sol";
import { Errors } from ".././../../../contracts/libraries/Errors.sol";

import { CrossChainRequestTypes } from "../../../../contracts/libraries/DataTypes.sol";
import { BaseHelper } from "contracts/libraries/BaseHelper.sol";

contract UpdateChannelCCR is BaseCCRTest {
    uint256 amount;

    function setUp() public override {
        BaseCCRTest.setUp();
        amount = (coreProxy.channelUpdateCounter(toWormholeFormat(actor.bob_channel_owner)) + 1) * ADD_CHANNEL_MIN_FEES;
        sourceAddress = toWormholeFormat(address(commProxy));
        (_payload, requestPayload) = getSpecificPayload(
            CrossChainRequestTypes.CrossChainFunction.UpdateChannelMeta,
            BaseHelper.addressToBytes32(address(0)),
            amount,
            0,
            percentage,
            0,
            "",
            "",
            BaseHelper.addressToBytes32(actor.bob_channel_owner)
        );
    }

    modifier whencreateCrossChainReqIsCalled() {
        _;
    }

    function test_WhenContractIsPaused() external whencreateCrossChainReqIsCalled {
        // it should Revert

        changePrank(actor.admin);
        commProxy.pauseContract();
        vm.expectRevert("Pausable: paused");
        changePrank(actor.bob_channel_owner);
        commProxy.createCrossChainRequest(
            CrossChainRequestTypes.CrossChainFunction.UpdateChannelMeta, _payload, amount, GasLimit
        );
    }

    function test_RevertWhen_EtherPassedIsLess() external whencreateCrossChainReqIsCalled {
        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientFunds.selector));
        changePrank(actor.bob_channel_owner);
        commProxy.createCrossChainRequest(
            CrossChainRequestTypes.CrossChainFunction.UpdateChannelMeta, _payload, amount, GasLimit
        );
    }

    function test_WhenAllChecksPasses() public whencreateCrossChainReqIsCalled {
        // it should successfully create the CCR
        vm.expectEmit(true, false, false, false);
        emit LogMessagePublished(SourceChain.WORMHOLE_RELAYER_SOURCE, 2105, 0, requestPayload, 15);
        changePrank(actor.bob_channel_owner);
        commProxy.createCrossChainRequest{ value: 1e18 }(
            CrossChainRequestTypes.CrossChainFunction.UpdateChannelMeta, _payload, amount, GasLimit
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

    function test_WhenDeliveryHashIsUsedAlready() external whenReceiveFunctionIsCalledInCore {
        // it should Revert

        receiveWormholeMessage(requestPayload);
        vm.expectRevert(abi.encodeWithSelector(Errors.Payload_Duplicacy_Error.selector));
        receiveWormholeMessage(requestPayload);
    }

    function test_whenReceiveChecksPass() public whenReceiveFunctionIsCalledInCore {
        // it should emit event and create Channel

        uint256 HOLDER_FEE_POOL = coreProxy.HOLDER_FEE_POOL();
        uint256 WALLET_FEE_POOL = coreProxy.WALLET_FEE_POOL();
        uint256 oldCounter = coreProxy.channelUpdateCounter(toWormholeFormat(actor.bob_channel_owner));

        vm.expectEmit(true, true, false, true);
        emit UpdateChannel(toWormholeFormat(actor.bob_channel_owner), _newTestChannelIdentity, amount);

        receiveWormholeMessage(requestPayload);
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint256 channelUpdateBlock,
           ,
        ) = coreProxy.channelInfo(toWormholeFormat(actor.bob_channel_owner));
        assertEq(coreProxy.HOLDER_FEE_POOL(), HOLDER_FEE_POOL + BaseHelper.calcPercentage(amount , HOLDER_SPLIT));
        assertEq(coreProxy.WALLET_FEE_POOL(), WALLET_FEE_POOL +  amount - BaseHelper.calcPercentage(amount , HOLDER_SPLIT));
        assertEq(coreProxy.channelUpdateCounter(toWormholeFormat(actor.bob_channel_owner)), oldCounter + 1);
        assertEq(channelUpdateBlock, block.number);
    }

    function test_whenTokensAreTransferred() external {
        vm.recordLogs();
        test_whenReceiveChecksPass();
        (address sourceNttManager, bytes32 recipient, uint256 _amount, uint16 recipientChain) =
            getMessagefromLog(vm.getRecordedLogs());


        bytes[] memory a;
        (bytes memory transceiverMessage, bytes32 hash) =
            getRequestPayload(_amount, recipient, recipientChain, sourceNttManager);

        changePrank(DestChain.WORMHOLE_RELAYER_DEST);
        uint balanceCoreBefore = pushToken.balanceOf(address(coreProxy));

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
