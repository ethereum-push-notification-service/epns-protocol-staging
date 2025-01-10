// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseCCRTest } from "../../BaseCCR.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";

import { CrossChainRequestTypes } from "contracts/libraries/DataTypes.sol";
import { BaseHelper } from "contracts/libraries/BaseHelper.sol";
import { IRateLimiter } from "contracts/interfaces/wormhole/IRateLimiter.sol";

contract CreateChatCCR is BaseCCRTest {
    uint256 amount = 100e18;

    function setUp() public override {
        BaseCCRTest.setUp();
        sourceAddress = toWormholeFormat(address(commProxy));
        (_payload, requestPayload) = getSpecificPayload(
            CrossChainRequestTypes.CrossChainFunction.IncentivizedChat,
            BaseHelper.addressToBytes32(actor.charlie_channel_owner),
            amount,
            0,
            percentage,
            0,
            "",
            "",
            BaseHelper.addressToBytes32(actor.bob_channel_owner)
        );
    }

    modifier whenCreateChatIsCalled() {
        _;
    }

    function test_WhenContractIsPaused() external whenCreateChatIsCalled {
        // it should Revert

        changePrank(actor.admin);
        commProxy.pauseContract();
        vm.expectRevert("Pausable: paused");
        changePrank(actor.bob_channel_owner);
        commProxy.createCrossChainRequest(
            CrossChainRequestTypes.CrossChainFunction.IncentivizedChat, _payload, amount, GasLimit
        );
    }

    function test_RevertWhen_AmountIsLessThanMinimumFees() external whenCreateChatIsCalled {
        // it should revert
        amount = FEE_AMOUNT - 1e18;
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArg_LessThanExpected.selector, FEE_AMOUNT, amount));
        changePrank(actor.bob_channel_owner);
        commProxy.createCrossChainRequest(
            CrossChainRequestTypes.CrossChainFunction.IncentivizedChat, _payload, amount, GasLimit
        );
    }

    function test_RevertWhen_EtherPassedIsLess() external whenCreateChatIsCalled {
        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientFunds.selector));
        changePrank(actor.bob_channel_owner);
        commProxy.createCrossChainRequest(
            CrossChainRequestTypes.CrossChainFunction.IncentivizedChat, _payload, amount, GasLimit
        );
    }

    function test_revertWhen_OutboundQueueDisabled() external whenCreateChatIsCalled {
        changePrank(SourceChain.NTT_MANAGER);
        uint256 transferTooLarge = MAX_WINDOW + 1e18; // one token more than the outbound capacity
        pushNttToken.mint(actor.bob_channel_owner, transferTooLarge);

        changePrank(actor.bob_channel_owner);
        // test revert on a transfer that is larger than max window size without enabling queueing
        vm.expectRevert(abi.encodeWithSelector(IRateLimiter.NotEnoughCapacity.selector, MAX_WINDOW, transferTooLarge));
        commProxy.createCrossChainRequest{ value: 1e18 }(
            CrossChainRequestTypes.CrossChainFunction.IncentivizedChat, _payload, transferTooLarge, GasLimit
        );
    }

    function test_WhenAllChecksPasses() public whenCreateChatIsCalled {
        // it should successfully create the CCR
        vm.expectEmit(true, false, false, false);
        emit LogMessagePublished(SourceChain.WORMHOLE_RELAYER_SOURCE, 2105, 0, requestPayload, 15);
        changePrank(actor.bob_channel_owner);
        commProxy.createCrossChainRequest{ value: 1e18 }(
            CrossChainRequestTypes.CrossChainFunction.IncentivizedChat, _payload, amount, GasLimit
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

        uint256 poolFeeAmount = coreProxy.FEE_AMOUNT();
        uint256 userFundsPre = coreProxy.celebUserFunds(actor.charlie_channel_owner);
        uint256 HOLDER_FEE_POOL = coreProxy.HOLDER_FEE_POOL();
        uint256 WALLET_FEE_POOL = coreProxy.WALLET_FEE_POOL();

        vm.expectEmit(false, false, false, true);
        emit IncentivizedChatReqReceived(
            BaseHelper.addressToBytes32(actor.bob_channel_owner), BaseHelper.addressToBytes32(actor.charlie_channel_owner), amount - poolFeeAmount, poolFeeAmount, block.timestamp
        );

        receiveWormholeMessage(requestPayload);

        assertEq(coreProxy.celebUserFunds(actor.charlie_channel_owner), userFundsPre + amount - poolFeeAmount);
        assertEq(coreProxy.HOLDER_FEE_POOL(), HOLDER_FEE_POOL + BaseHelper.calcPercentage(poolFeeAmount , HOLDER_SPLIT));
        assertEq(coreProxy.WALLET_FEE_POOL(), WALLET_FEE_POOL + poolFeeAmount - BaseHelper.calcPercentage(poolFeeAmount , HOLDER_SPLIT));
    }
    function test_whenTokensAreTransferred() public {
        vm.recordLogs();
        test_whenReceiveChecksPass();
        (address sourceNttManager, bytes32 recipient, uint256 _amount, uint16 recipientChain) =
            getMessagefromLog(vm.getRecordedLogs());

       uint balanceCoreBefore = pushToken.balanceOf(address(coreProxy));

        bytes[] memory a;
        (bytes memory transceiverMessage, bytes32 hash) =
            getRequestPayload(_amount, recipient, recipientChain, sourceNttManager);

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

    function test_when_celebUserTries_ClaimingTokens() external {
        // it should transfer the tokens to celeb user
        test_whenTokensAreTransferred();
        uint256 balanceBefore = pushToken.balanceOf(address(actor.charlie_channel_owner));
        changePrank(actor.charlie_channel_owner);
        coreProxy.claimChatIncentives(coreProxy.celebUserFunds(actor.charlie_channel_owner));
        assertEq(pushToken.balanceOf(address(actor.charlie_channel_owner)), balanceBefore + amount - FEE_AMOUNT);
    }
}
