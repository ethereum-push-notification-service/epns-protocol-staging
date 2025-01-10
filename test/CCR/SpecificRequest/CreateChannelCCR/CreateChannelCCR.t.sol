// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseCCRTest } from "../../BaseCCR.t.sol";
import { CoreTypes, CrossChainRequestTypes } from "contracts/libraries/DataTypes.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { BaseHelper } from "contracts/libraries/BaseHelper.sol";
import { IRateLimiter } from "contracts/interfaces/wormhole/IRateLimiter.sol";

contract CreateChannelCCR is BaseCCRTest {
    uint256 amount = ADD_CHANNEL_MIN_FEES;

    function setUp() public override {
        BaseCCRTest.setUp();
        sourceAddress = toWormholeFormat(address(commProxy));
        (_payload, requestPayload) = getSpecificPayload(
            CrossChainRequestTypes.CrossChainFunction.AddChannel,
            BaseHelper.addressToBytes32(address(0)),
            amount,
            0,
            percentage,
            0,
            "",
            "",
            BaseHelper.addressToBytes32(actor.charlie_channel_owner)
        );
    }

    modifier whenCreateChannelIsCalled() {
        _;
    }

    function test_WhenContractIsPaused() external whenCreateChannelIsCalled {
        // it should Revert

        changePrank(actor.admin);
        commProxy.pauseContract();
        vm.expectRevert("Pausable: paused");
        changePrank(actor.charlie_channel_owner);
        commProxy.createCrossChainRequest(
            CrossChainRequestTypes.CrossChainFunction.AddChannel, _payload, amount, GasLimit
        );
    }

    function test_RevertWhen_AmountIsLessThanMinimumFees() external whenCreateChannelIsCalled {
        // it should revert
        amount = 49e18;
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidArg_LessThanExpected.selector, ADD_CHANNEL_MIN_FEES, amount)
        );
        changePrank(actor.charlie_channel_owner);
        commProxy.createCrossChainRequest(
            CrossChainRequestTypes.CrossChainFunction.AddChannel, _payload, amount, GasLimit
        );
    }

    function test_RevertWhen_EtherPassedIsLess() external whenCreateChannelIsCalled {
        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientFunds.selector));
        changePrank(actor.charlie_channel_owner);
        commProxy.createCrossChainRequest(
            CrossChainRequestTypes.CrossChainFunction.AddChannel, _payload, amount, GasLimit
        );
    }

    function test_revertWhen_OutboundQueueDisabled() external whenCreateChannelIsCalled {
        changePrank(SourceChain.NTT_MANAGER);
        uint256 transferTooLarge = MAX_WINDOW + 1e18; // one token more than the outbound capacity
        pushNttToken.mint(actor.bob_channel_owner, transferTooLarge);

        changePrank(actor.bob_channel_owner);
        // test revert on a transfer that is larger than max window size without enabling queueing
        vm.expectRevert(abi.encodeWithSelector(IRateLimiter.NotEnoughCapacity.selector, MAX_WINDOW, transferTooLarge));
        commProxy.createCrossChainRequest{ value: 1e18 }(
            CrossChainRequestTypes.CrossChainFunction.ArbitraryRequest, _payload, transferTooLarge, GasLimit
        );
    }

    function test_WhenAllChecksPasses() public whenCreateChannelIsCalled {
        // it should successfully create the CCR

        vm.expectEmit(true, false, false, false);
        emit LogMessagePublished(SourceChain.WORMHOLE_RELAYER_SOURCE, 2105, 0, requestPayload, 15);
        changePrank(actor.charlie_channel_owner);
        commProxy.createCrossChainRequest{ value: 1e18 }(
            CrossChainRequestTypes.CrossChainFunction.AddChannel, _payload, amount, GasLimit
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

        (uint256 poolFunds, uint256 HOLDER_FEE_POOL, uint256 WALLET_FEE_POOL) = getPoolFundsAndFees(amount);

        vm.expectEmit(true, true, false, true);
        emit ChannelCreated(
            toWormholeFormat(actor.charlie_channel_owner),
            CoreTypes.ChannelType.InterestBearingMutual,
            _testChannelUpdatedIdentity
        );

        receiveWormholeMessage(requestPayload);
        assertEq(coreProxy.CHANNEL_POOL_FUNDS(), poolFunds);
        assertEq(coreProxy.HOLDER_FEE_POOL(),   HOLDER_FEE_POOL, "Holder pool");
        assertEq(coreProxy.WALLET_FEE_POOL(),   WALLET_FEE_POOL,"Wallet Pool");

        (
            CoreTypes.ChannelType channelType,
            uint8 channelState,
            ,
            uint256 poolContribution,
            ,
            ,
            ,
            uint256 channelStartBlock,
            uint256 channelUpdateBlock,
            uint256 channelWeight,
        ) = coreProxy.channelInfo(toWormholeFormat(actor.charlie_channel_owner));

        assertEq(uint8(channelType), uint8(CoreTypes.ChannelType.InterestBearingMutual), "channel Type");
        assertEq(channelState, 1, "channel State");
        assertEq(poolContribution, amount - coreProxy.FEE_AMOUNT(), "Pool Contribution");
        assertEq(channelStartBlock, block.number, "Channel Start Block");
        assertEq(channelUpdateBlock, block.number, "Chanel Update Block");
        assertEq(
            channelWeight,
            ((amount - coreProxy.FEE_AMOUNT()) * 10 ** 7) / coreProxy.MIN_POOL_CONTRIBUTION(),
            "Channel Weight"
        );
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
