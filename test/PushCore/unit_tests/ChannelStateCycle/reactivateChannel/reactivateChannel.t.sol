pragma solidity ^0.8.20;

import { BasePushCoreTest } from "../../BasePushCoreTest.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { BaseHelper } from "contracts/libraries/BaseHelper.sol";

contract ReactivateChannel_Test is BasePushCoreTest {
    function setUp() public virtual override {
        BasePushCoreTest.setUp();

        _createChannel(actor.bob_channel_owner);
    }

    modifier whenNotPaused() {
        _;
    }

    function test_Revertwhen_ReactivatingBlockedChannel() public whenNotPaused {
        approveTokens(actor.bob_channel_owner, address(coreProxy), ADD_CHANNEL_MIN_FEES);

        vm.prank(actor.admin);
        coreProxy.blockChannel(toWormholeFormat(actor.bob_channel_owner));

        vm.prank(actor.bob_channel_owner);
        vm.expectRevert(Errors.Core_InvalidChannel.selector);
        coreProxy.updateChannelState(ADD_CHANNEL_MIN_FEES);
    }

    function test_Revertwhen_PushAllowanceNotEnough() public whenNotPaused {
        uint256 _amountBeingTransferred = 10 ether;
        approveTokens(actor.bob_channel_owner, address(coreProxy), _amountBeingTransferred);

        vm.startPrank(actor.bob_channel_owner);
        coreProxy.updateChannelState(0);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidArg_LessThanExpected.selector, 50 ether, _amountBeingTransferred)
        );
        coreProxy.updateChannelState(_amountBeingTransferred);
        vm.stopPrank();
    }

    function test_ReactivatingDeactivatedChannel() public whenNotPaused {
        approveTokens(actor.bob_channel_owner, address(coreProxy), ADD_CHANNEL_MIN_FEES);

        vm.startPrank(actor.bob_channel_owner);
        coreProxy.updateChannelState(0);

        vm.expectEmit(true, true, false, false, address(coreProxy));
        emit ChannelStateUpdate(channelCreators.bob_channel_owner_Bytes32, 0, ADD_CHANNEL_MIN_FEES);

        coreProxy.updateChannelState(ADD_CHANNEL_MIN_FEES);

        vm.stopPrank();
    }

    function test_CoreContract_ShouldReceive_CorrectRefund_PostReactivation() public whenNotPaused {
        approveTokens(actor.bob_channel_owner, address(coreProxy), ADD_CHANNEL_MIN_FEES);

        vm.startPrank(actor.bob_channel_owner);
        coreProxy.updateChannelState(0);

        uint256 pushBalanceOfCore_beforeReactivation = pushToken.balanceOf(address(coreProxy));

        uint256 expectedDepositAmount = ADD_CHANNEL_MIN_FEES;
        coreProxy.updateChannelState(ADD_CHANNEL_MIN_FEES);

        uint256 pushBalanceOfCore_afterReactivation = pushToken.balanceOf(address(coreProxy));
        uint256 expectedCoreBalance = pushBalanceOfCore_beforeReactivation + expectedDepositAmount;

        assertEq(pushBalanceOfCore_afterReactivation, expectedCoreBalance);

        vm.stopPrank();
    }

    function test_ChannelStateUpdation_PostReactivation() public whenNotPaused {
        approveTokens(actor.bob_channel_owner, address(coreProxy), ADD_CHANNEL_MIN_FEES);

        uint8 actualChannelStateBeforeDeactivation = _getChannelState(actor.bob_channel_owner);

        vm.startPrank(actor.bob_channel_owner);
        coreProxy.updateChannelState(0);
        uint8 actualChannelStateAfterDeactivation = _getChannelState(actor.bob_channel_owner);

        coreProxy.updateChannelState(ADD_CHANNEL_MIN_FEES);
        uint8 actualChannelStateAfterReactivation = _getChannelState(actor.bob_channel_owner);

        uint8 expectedChannelStateBeforeDeactivation = 1;
        uint8 expectedChannelStateAfterDeactivation = 2;
        uint8 expectedChannelStateAfterReactivation = 1;

        assertEq(actualChannelStateBeforeDeactivation, expectedChannelStateBeforeDeactivation);
        assertEq(actualChannelStateAfterDeactivation, expectedChannelStateAfterDeactivation);
        assertEq(actualChannelStateAfterReactivation, expectedChannelStateAfterReactivation);

        vm.stopPrank();
    }

    function test_FundsVariablesUpdation_PostReactivation() public whenNotPaused {
        approveTokens(actor.bob_channel_owner, address(coreProxy), ADD_CHANNEL_MIN_FEES);
        uint256 HOLDER_FEE_POOL = coreProxy.HOLDER_FEE_POOL();
        uint256 WALLET_FEE_POOL = coreProxy.WALLET_FEE_POOL();

        vm.startPrank(actor.bob_channel_owner);
        coreProxy.updateChannelState(0);

        coreProxy.updateChannelState(ADD_CHANNEL_MIN_FEES);
        uint256 actualChannelFundsAfterReactivation = coreProxy.CHANNEL_POOL_FUNDS();
        uint256 actualChannelWeightAfterReactivation = _getChannelWeight(actor.bob_channel_owner);
        uint256 actualChannelPoolContributionAfterReactivation = _getChannelPoolContribution(actor.bob_channel_owner);

        uint256 expectedChannelFundsAfterReactivation = ADD_CHANNEL_MIN_FEES - FEE_AMOUNT + MIN_POOL_CONTRIBUTION;
        uint256 expectedChannelPoolContributionAfterReactivation =
            MIN_POOL_CONTRIBUTION + ADD_CHANNEL_MIN_FEES - FEE_AMOUNT;
        uint256 expectedChannelWeightAfterReactivation =
            (expectedChannelPoolContributionAfterReactivation * ADJUST_FOR_FLOAT) / (MIN_POOL_CONTRIBUTION);

        assertEq(actualChannelFundsAfterReactivation, expectedChannelFundsAfterReactivation);
        assertEq(coreProxy.HOLDER_FEE_POOL(), HOLDER_FEE_POOL + BaseHelper.calcPercentage(FEE_AMOUNT , HOLDER_SPLIT));
        assertEq(coreProxy.WALLET_FEE_POOL(), WALLET_FEE_POOL + FEE_AMOUNT - BaseHelper.calcPercentage(FEE_AMOUNT , HOLDER_SPLIT));
        assertEq(actualChannelWeightAfterReactivation, expectedChannelWeightAfterReactivation);
        assertEq(actualChannelPoolContributionAfterReactivation, expectedChannelPoolContributionAfterReactivation);

        vm.stopPrank();
    }
}
