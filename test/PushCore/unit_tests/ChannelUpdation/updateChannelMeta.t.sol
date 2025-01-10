pragma solidity ^0.8.20;

import { BasePushCoreTest } from "../BasePushCoreTest.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { BaseHelper } from "contracts/libraries/BaseHelper.sol";

contract UpdateChannelMeta_Test is BasePushCoreTest {
    function setUp() public virtual override {
        BasePushCoreTest.setUp();
    }

    modifier whenNotPaused() {
        _;
    }

    function test_Revertwhen_UpdatingInactiveChannel() public whenNotPaused {
        uint256 _amountBeingTransferred = ADD_CHANNEL_MIN_FEES;

        vm.prank(actor.bob_channel_owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.Core_InvalidChannel.selector));
        coreProxy.updateChannelMeta( _testChannelUpdatedIdentity, _amountBeingTransferred);
    }
    // Todo - fix updateChannelState function - Test case fails until then

    function test_Revertwhen_UpdatingDeactivatedChannel() public whenNotPaused {
        uint256 _amountBeingTransferred = ADD_CHANNEL_MIN_FEES;
        _createChannel(actor.bob_channel_owner);
        vm.prank(actor.bob_channel_owner);
        coreProxy.updateChannelState(0);

        vm.prank(actor.bob_channel_owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.Core_InvalidChannel.selector));
        coreProxy.updateChannelMeta( _testChannelUpdatedIdentity, _amountBeingTransferred);
    }

    function test_Revertwhen_AmountLessThanRequiredFees() public whenNotPaused {
        uint256 _amountBeingTransferred = ADD_CHANNEL_MIN_FEES - 10 ether;
        _createChannel(actor.bob_channel_owner);

        vm.prank(actor.bob_channel_owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidArg_LessThanExpected.selector, ADD_CHANNEL_MIN_FEES, _amountBeingTransferred
            )
        );
        coreProxy.updateChannelMeta( _testChannelUpdatedIdentity, _amountBeingTransferred);
    }

    function test_Revertwhen_AmountLessThanRequiredFeesForSecondUpdate() public whenNotPaused {
        uint256 _amountBeingTransferred = ADD_CHANNEL_MIN_FEES;
        _createChannel(actor.bob_channel_owner);

        vm.startPrank(actor.bob_channel_owner);
        coreProxy.updateChannelMeta( _testChannelUpdatedIdentity, _amountBeingTransferred);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidArg_LessThanExpected.selector, ADD_CHANNEL_MIN_FEES * 2, _amountBeingTransferred
            )
        );
        coreProxy.updateChannelMeta( _testChannelUpdatedIdentity, _amountBeingTransferred);
        vm.stopPrank();
    }

    function test_UpdateWithSufficientFees() public whenNotPaused {
        uint256 _numberOfUpdates = 5;
        _createChannel(actor.bob_channel_owner);

        for (uint256 i; i < _numberOfUpdates; ++i) {
            uint256 _amountBeingTransferred = ADD_CHANNEL_MIN_FEES * (i + 1);

            approveTokens(actor.bob_channel_owner, address(coreProxy), _amountBeingTransferred);

            vm.prank(actor.bob_channel_owner);
            coreProxy.updateChannelMeta( _testChannelUpdatedIdentity, _amountBeingTransferred);
        }
    }

    function test_ContractShouldReceiveFeeTokens() public whenNotPaused {
        uint256 _numberOfUpdates = 5;
        _createChannel(actor.bob_channel_owner);

        for (uint256 i; i < _numberOfUpdates; ++i) {
            uint256 _amountBeingTransferred = ADD_CHANNEL_MIN_FEES * (i + 1);

            approveTokens(actor.bob_channel_owner, address(coreProxy), _amountBeingTransferred);

            uint256 _balanceOfPushTokensBeforeUpdateInProxy = pushToken.balanceOf(address(coreProxy));

            vm.prank(actor.bob_channel_owner);
            coreProxy.updateChannelMeta( _testChannelUpdatedIdentity, _amountBeingTransferred);

            uint256 _balanceOfPushTokensAfterUpdateInProxy = pushToken.balanceOf(address(coreProxy));
            assertEq(
                _balanceOfPushTokensAfterUpdateInProxy,
                _balanceOfPushTokensBeforeUpdateInProxy + _amountBeingTransferred
            );
        }
    }

    function test_ShouldUpdateChannelVariables() public whenNotPaused {
        uint256 _numberOfUpdates = 5;
        _createChannel(actor.bob_channel_owner);

        for (uint256 i; i < _numberOfUpdates; ++i) {
            uint256 _amountBeingTransferred = ADD_CHANNEL_MIN_FEES * (i + 1);

            approveTokens(actor.bob_channel_owner, address(coreProxy), _amountBeingTransferred);

            vm.prank(actor.bob_channel_owner);
            coreProxy.updateChannelMeta( _testChannelUpdatedIdentity, _amountBeingTransferred);

            uint256 _channelUpdateCounterAfter = coreProxy.channelUpdateCounter(toWormholeFormat(actor.bob_channel_owner));
            uint256 _channelUpdateBlock = _getChannelUpdateBlock(actor.bob_channel_owner);
            assertEq(_channelUpdateCounterAfter, i + 1);
            assertEq(_channelUpdateBlock, block.number);
        }
    }

    function test_ShouldUpdateFeeVariables() public whenNotPaused {
        _createChannel(actor.bob_channel_owner);

        uint256 _amountBeingTransferred = ADD_CHANNEL_MIN_FEES;
        uint256 HOLDER_FEE_POOL = coreProxy.HOLDER_FEE_POOL();
        uint256 WALLET_FEE_POOL = coreProxy.WALLET_FEE_POOL();
        uint256 channelPoolFundsBeforeUpdate = coreProxy.CHANNEL_POOL_FUNDS();

        vm.prank(actor.bob_channel_owner);
        coreProxy.updateChannelMeta( _testChannelUpdatedIdentity, _amountBeingTransferred);

        uint256 expectedChannelPoolFunds = channelPoolFundsBeforeUpdate;

        assertEq(coreProxy.HOLDER_FEE_POOL(), HOLDER_FEE_POOL + BaseHelper.calcPercentage(_amountBeingTransferred , HOLDER_SPLIT));
        assertEq(coreProxy.WALLET_FEE_POOL(), WALLET_FEE_POOL + _amountBeingTransferred - BaseHelper.calcPercentage(_amountBeingTransferred , HOLDER_SPLIT));
        assertEq(coreProxy.CHANNEL_POOL_FUNDS(), expectedChannelPoolFunds);
    }

    function test_EmitRelevantEvents() public {
        _createChannel(actor.bob_channel_owner);
        uint256 _amountBeingTransferred = ADD_CHANNEL_MIN_FEES;

        vm.expectEmit(true, true, false, true, address(coreProxy));
        emit UpdateChannel(
            channelCreators.bob_channel_owner_Bytes32, _testChannelUpdatedIdentity, _amountBeingTransferred
        );

        vm.prank(actor.bob_channel_owner);
        coreProxy.updateChannelMeta( _testChannelUpdatedIdentity, _amountBeingTransferred);
    }

    // Zero-Address Channel Support - Now Deprecated
    // function test_UpdateZeroAddressChannel() public whenNotPaused {
    //     uint256 _amountBeingTransferred = ADD_CHANNEL_MIN_FEES;
    //     address _channelAddress = address(0x0);

    //     vm.prank(actor.admin);
    //     coreProxy.updateChannelMeta(_channelAddress, _testChannelUpdatedIdentity, _amountBeingTransferred);
    // }
}
