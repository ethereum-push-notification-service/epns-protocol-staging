// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseCCRTest } from "../BaseCCR.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { console } from "forge-std/console.sol";
import { CrossChainRequestTypes, GenericTypes } from "contracts/libraries/DataTypes.sol";

import { IRateLimiter } from "contracts/interfaces/wormhole/IRateLimiter.sol";
import { BaseHelper } from "contracts/libraries/BaseHelper.sol";

contract ArbitraryRequesttsol is BaseCCRTest {
    uint256 amount = 100e18;

    function setUp() public override {
        BaseCCRTest.setUp();

        percentage = GenericTypes.Percentage(2322, 2);

        (_payload, requestPayload) = getSpecificPayload(
            CrossChainRequestTypes.CrossChainFunction.ArbitraryRequest,
            BaseHelper.addressToBytes32(actor.charlie_channel_owner),
            amount,
            1,
            percentage,
            0,
            "",
            "",
            BaseHelper.addressToBytes32(actor.bob_channel_owner)
        );
    }

    modifier whencreateCrossChainRequestIsCalled() {
        _;
    }

    function test_WhenContractIsPaused() external whencreateCrossChainRequestIsCalled {
        // it should Revert
        changePrank(actor.admin);
        commProxy.pauseContract();
        vm.expectRevert("Pausable: paused");
        changePrank(actor.bob_channel_owner);
        commProxy.createCrossChainRequest(
            CrossChainRequestTypes.CrossChainFunction.ArbitraryRequest, _payload, amount, GasLimit
        );
    }

    function test_RevertWhen_AmountNotGreaterThanZero() external whencreateCrossChainRequestIsCalled {
        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArg_LessThanExpected.selector, 1, 0));
        changePrank(actor.bob_channel_owner);
        commProxy.createCrossChainRequest(
            CrossChainRequestTypes.CrossChainFunction.ArbitraryRequest, _payload, 0, GasLimit
        );
    }

    function test_RevertWhen_EtherPassedIsLess() external whencreateCrossChainRequestIsCalled {
        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientFunds.selector));
        changePrank(actor.bob_channel_owner);
        commProxy.createCrossChainRequest(
            CrossChainRequestTypes.CrossChainFunction.ArbitraryRequest, _payload, amount, GasLimit
        );
    }

    function test_revertWhen_OutboundQueueDisabled() external whencreateCrossChainRequestIsCalled {
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

    function test_WhenAllChecksPasses() public whencreateCrossChainRequestIsCalled {
        // it should successfully create the CCR
        vm.expectEmit(true, false, false, false);
        emit LogMessagePublished(SourceChain.WORMHOLE_RELAYER_SOURCE, 2105, 0, requestPayload, 15);
        changePrank(actor.bob_channel_owner);
        commProxy.createCrossChainRequest{ value: 1e18 }(
            CrossChainRequestTypes.CrossChainFunction.ArbitraryRequest, _payload, amount, GasLimit
        );
    }

    modifier whenReceiveFunctionIsCalledInCore() {
        _;
    }

    function test_WhenSenderIsNotRegistered() external whenReceiveFunctionIsCalledInCore {
        // it should Revert
        test_WhenAllChecksPasses();

        setUpDestChain();
        //set sender to zero address
        coreProxy.setRegisteredSender(SourceChain.SourceChainId, toWormholeFormat(address(0)));

        vm.expectRevert("Not registered sender");
        changePrank(DestChain.WORMHOLE_RELAYER_DEST);
        coreProxy.receiveWormholeMessages(
            requestPayload, additionalVaas, sourceAddress, SourceChain.SourceChainId, deliveryHash
        );
    }

    function test_WhenSenderIsNotRelayer() external whenReceiveFunctionIsCalledInCore {
        // it should Revert
        test_WhenAllChecksPasses();

        setUpDestChain();
        coreProxy.setWormholeRelayer(address(0));
        changePrank(DestChain.WORMHOLE_RELAYER_DEST);
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotAdmin.selector));
        coreProxy.receiveWormholeMessages(
            requestPayload, additionalVaas, sourceAddress, SourceChain.SourceChainId, deliveryHash
        );
    }

    function test_WhenDeliveryHashIsUsedAlready() external whenReceiveFunctionIsCalledInCore {
        // it should Revert
        test_WhenAllChecksPasses();
        setUpDestChain();

        changePrank(DestChain.WORMHOLE_RELAYER_DEST);
        coreProxy.receiveWormholeMessages(
            requestPayload, additionalVaas, sourceAddress, SourceChain.SourceChainId, deliveryHash
        );
        vm.expectRevert(abi.encodeWithSelector(Errors.Payload_Duplicacy_Error.selector));
        coreProxy.receiveWormholeMessages(
            requestPayload, additionalVaas, sourceAddress, SourceChain.SourceChainId, deliveryHash
        );
    }

    function test_whenReceiveChecksPass() public whenReceiveFunctionIsCalledInCore {
        // it should emit event and update storage
        test_WhenAllChecksPasses();

        setUpDestChain();
        uint256 HOLDER_FEE_POOL = coreProxy.HOLDER_FEE_POOL();
        uint256 WALLET_FEE_POOL = coreProxy.WALLET_FEE_POOL();
        uint256 arbitraryFees = coreProxy.arbitraryReqFees(actor.charlie_channel_owner);
        changePrank(DestChain.WORMHOLE_RELAYER_DEST);

        vm.expectEmit(true, true, false, true);
        emit ArbitraryRequest(BaseHelper.addressToBytes32(actor.bob_channel_owner), BaseHelper.addressToBytes32(actor.charlie_channel_owner), amount, percentage, 1);

        coreProxy.receiveWormholeMessages(
            requestPayload, additionalVaas, sourceAddress, SourceChain.SourceChainId, deliveryHash
        );

        uint256 feeAmount = BaseHelper.calcPercentage(amount, percentage);

        // Update states based on Fee Percentage calculation
        assertEq(coreProxy.HOLDER_FEE_POOL(), HOLDER_FEE_POOL + BaseHelper.calcPercentage(feeAmount , HOLDER_SPLIT));
        assertEq(coreProxy.WALLET_FEE_POOL(), WALLET_FEE_POOL + feeAmount - BaseHelper.calcPercentage(feeAmount , HOLDER_SPLIT));
        assertEq(coreProxy.arbitraryReqFees(actor.charlie_channel_owner), arbitraryFees + amount - feeAmount);
    }

    function test_whenTokensAreTransferred() public {
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

    function test_when_UserTries_ClaimingArbitraryTokens() external {
        // it should transfer the tokens to celeb user
        test_whenTokensAreTransferred();
        uint256 balanceBefore = pushToken.balanceOf(address(actor.charlie_channel_owner));
        changePrank(actor.charlie_channel_owner);
        coreProxy.claimArbitraryRequestFees(coreProxy.arbitraryReqFees(actor.charlie_channel_owner));
        uint256 feeAmount = BaseHelper.calcPercentage(amount, percentage);
        assertEq(pushToken.balanceOf(address(actor.charlie_channel_owner)), balanceBefore + amount - feeAmount);
        assertEq(coreProxy.arbitraryReqFees(actor.charlie_channel_owner), 0);
    }
}
