// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseCCRTest } from "../BaseCCR.t.sol";
import { Errors } from ".././../../../contracts/libraries/Errors.sol";
import { console } from "forge-std/console.sol";
import { CrossChainRequestTypes, GenericTypes  } from "../../../../contracts/libraries/DataTypes.sol";

import "./../../../../contracts/libraries/wormhole-lib/TrimmedAmount.sol";
import { TransceiverStructs } from "./../../../../contracts/libraries/wormhole-lib/TransceiverStructs.sol";

import {BaseHelper} from "./../../../contracts/libraries/BaseHelper.sol";
contract ArbitraryRequesttsol is BaseCCRTest {
    uint256 amount = 100e18;
    function setUp() public override {
        BaseCCRTest.setUp();

        percentage = GenericTypes.Percentage(2322, 2); 

        (_payload, requestPayload) = getSpecificPayload(
            CrossChainRequestTypes.CrossChainFunction.ArbitraryRequest,
            actor.charlie_channel_owner,
            amount,
            1,
            percentage,
            actor.bob_channel_owner
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

    function test_WhenAllChecksPasses() public whencreateCrossChainRequestIsCalled {
        // it should successfully create the CCR
        vm.expectEmit(true, false, false, false);
        emit LogMessagePublished(ArbSepolia.WORMHOLE_RELAYER_SOURCE, 2105, 0, requestPayload, 15);
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

        setUpDestChain(EthSepolia.rpc);
        //set sender to zero address
        coreProxy.setRegisteredSender(ArbSepolia.SourceChainId, toWormholeFormat(address(0)));

        vm.expectRevert("Not registered sender");
        changePrank(EthSepolia.WORMHOLE_RELAYER_DEST);
        coreProxy.receiveWormholeMessages(
            requestPayload, additionalVaas, sourceAddress, ArbSepolia.SourceChainId, deliveryHash
        );
    }

    function test_WhenSenderIsNotRelayer() external whenReceiveFunctionIsCalledInCore {
        // it should Revert
        test_WhenAllChecksPasses();

        setUpDestChain(EthSepolia.rpc);
        coreProxy.setWormholeRelayer(address(0));
        changePrank(EthSepolia.WORMHOLE_RELAYER_DEST);
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotAdmin.selector));
        coreProxy.receiveWormholeMessages(
            requestPayload, additionalVaas, sourceAddress, ArbSepolia.SourceChainId, deliveryHash
        );
    }

    function test_WhenDeliveryHashIsUsedAlready() external whenReceiveFunctionIsCalledInCore {
        // it should Revert

        setUpDestChain(EthSepolia.rpc);

        changePrank(EthSepolia.WORMHOLE_RELAYER_DEST);
        coreProxy.receiveWormholeMessages(
            requestPayload, additionalVaas, sourceAddress, ArbSepolia.SourceChainId, deliveryHash
        );
        vm.expectRevert(abi.encodeWithSelector(Errors.Payload_Duplicacy_Error.selector));
        coreProxy.receiveWormholeMessages(
            requestPayload, additionalVaas, sourceAddress, ArbSepolia.SourceChainId, deliveryHash
        );
    }

    function test_whenReceiveChecksPass() public whenReceiveFunctionIsCalledInCore {
        // it should emit event and update storage
        test_WhenAllChecksPasses();

        setUpDestChain(EthSepolia.rpc);
        uint256 PROTOCOL_POOL_FEES = coreProxy.PROTOCOL_POOL_FEES();
        uint256 arbitraryFees = coreProxy.arbitraryReqFees(actor.charlie_channel_owner);
        changePrank(EthSepolia.WORMHOLE_RELAYER_DEST);

        (uint256 poolFunds, uint256 poolFees) = getPoolFundsAndFees(amount);

        vm.expectEmit(true, true, false, true);
        emit ArbitraryRequest(actor.bob_channel_owner, actor.charlie_channel_owner, amount, percentage, 1);

        coreProxy.receiveWormholeMessages(
            requestPayload, additionalVaas, sourceAddress, ArbSepolia.SourceChainId, deliveryHash
        );

        uint256 feeAmount = BaseHelper.calcPercentage(amount, percentage);

        // Update states based on Fee Percentage calculation
        assertEq(coreProxy.PROTOCOL_POOL_FEES(), PROTOCOL_POOL_FEES + feeAmount);
        assertEq(coreProxy.arbitraryReqFees(actor.charlie_channel_owner), arbitraryFees + amount - feeAmount);
    }

    function test_whenTokensAreTransferred() external {
        test_whenReceiveChecksPass();

        bytes[] memory a;
        TrimmedAmount _amt = _trimTransferAmount(amount);
        bytes memory tokenTransferMessage = TransceiverStructs.encodeNativeTokenTransfer(
            TransceiverStructs.NativeTokenTransfer({
                amount: _amt,
                sourceToken: toWormholeFormat(address(ArbSepolia.PUSH_NTT_SOURCE)),
                to: toWormholeFormat(address(coreProxy)),
                toChain: EthSepolia.DestChainId
            })
        );

        bytes memory transceiverMessage;
        TransceiverStructs.NttManagerMessage memory nttManagerMessage;
        (nttManagerMessage, transceiverMessage) = buildTransceiverMessageWithNttManagerPayload(
            0,
            toWormholeFormat(address(ArbSepolia.PushHolder)),
            toWormholeFormat(ArbSepolia.NTT_MANAGER),
            toWormholeFormat(EthSepolia.NTT_MANAGER),
            tokenTransferMessage
        );
        bytes32 hash = TransceiverStructs.nttManagerMessageDigest(10_003, nttManagerMessage);
        changePrank(EthSepolia.WORMHOLE_RELAYER_DEST);
        EthSepolia.wormholeTransceiverChain2.receiveWormholeMessages(
            transceiverMessage, // Verified
            a, // Should be zero
            bytes32(uint256(uint160(address(ArbSepolia.wormholeTransceiverChain1)))), // Must be a wormhole peers
            10_003, // ChainID from the call
            hash // Hash of the VAA being used
        );

        assertEq(pushNttToken.balanceOf(address(coreProxy)), amount);
    }
}