pragma solidity ^0.8.20;

import { BasePushCoreTest } from "../../BasePushCoreTest.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { BaseHelper } from "contracts/libraries/BaseHelper.sol";

contract BlockChannel_Test is BasePushCoreTest {
    bytes32 bobBytes; 
    bytes32 charlieBytes;
    function setUp() public virtual override {
        BasePushCoreTest.setUp();

        _createChannel(actor.bob_channel_owner);
        bobBytes = toWormholeFormat(actor.bob_channel_owner);
        charlieBytes = toWormholeFormat(actor.charlie_channel_owner);
    }

    modifier whenNotPaused() {
        _;
    }

    modifier whenCallerIsAdmin() {
        _;
    }

    function test_Revertwhen_BlockCallerNotGovernance() public whenNotPaused whenCallerIsAdmin {
        vm.expectRevert(Errors.CallerNotGovernance.selector);

        coreProxy.blockChannel(bobBytes);
    }

    function test_AdminCanBlockActivatedChannel() public whenNotPaused whenCallerIsAdmin {
        vm.expectEmit(true, false, false, false, address(coreProxy));
        emit ChannelBlocked(channelCreators.bob_channel_owner_Bytes32);

        vm.prank(actor.admin);
        coreProxy.blockChannel(bobBytes);
    }

    function test_AdminCanBlockDeactivatedChannel() public whenNotPaused whenCallerIsAdmin {
        vm.prank(actor.bob_channel_owner);
        coreProxy.updateChannelState(0);

        vm.expectEmit(true, false, false, false, address(coreProxy));
        emit ChannelBlocked(channelCreators.bob_channel_owner_Bytes32);

        vm.prank(actor.admin);
        coreProxy.blockChannel(bobBytes);
    }

    function test_Revertwhen_BlockInactiveChannel() public whenNotPaused whenCallerIsAdmin {
        vm.prank(actor.admin);
        vm.expectRevert(Errors.Core_InvalidChannel.selector);
         coreProxy.blockChannel(charlieBytes);
    }

    function test_Revertwhen_AlreadyBlockedChannel() public whenNotPaused whenCallerIsAdmin {
        vm.startPrank(actor.admin);
        coreProxy.blockChannel(bobBytes);

        vm.expectRevert(Errors.Core_InvalidChannel.selector);
        coreProxy.blockChannel(bobBytes);
        vm.stopPrank();
    }

    function test_ChannelDetailsUpdation() public whenNotPaused whenCallerIsAdmin {
        uint256 channelsCountBeforeBlocked = coreProxy.channelsCount();
        vm.prank(actor.admin);
        coreProxy.blockChannel(bobBytes);

        (
            ,
            uint8 actualChannelState,
            ,
            uint256 actualPoolContribution,
            ,
            ,
            ,
            ,
            uint256 actualChannelUpdateBlock,
            uint256 actualChannelWeight,
        ) = coreProxy.channelInfo(channelCreators.bob_channel_owner_Bytes32);
        uint256 actualChannelsCount = coreProxy.channelsCount();

        uint256 expectedPoolContribution = MIN_POOL_CONTRIBUTION;
        uint256 expectedChannelsCount = channelsCountBeforeBlocked - 1;
        uint8 expectedChannelState = 3;
        uint256 expectedChannelWeight = (MIN_POOL_CONTRIBUTION * ADJUST_FOR_FLOAT) / MIN_POOL_CONTRIBUTION;
        uint256 expectedChannelUpdateBlock = block.number;

        assertEq(actualChannelState, expectedChannelState);
        assertEq(actualPoolContribution, expectedPoolContribution);
        assertEq(actualChannelUpdateBlock, expectedChannelUpdateBlock);
        assertEq(actualChannelWeight, expectedChannelWeight);
        assertEq(actualChannelsCount, expectedChannelsCount);
    }

    function test_FundsVariablesUpdation() public whenNotPaused whenCallerIsAdmin {
        uint256 poolContributionBeforeBlocked = _getChannelPoolContribution(actor.bob_channel_owner);
        uint256 HOLDER_FEE_POOL = coreProxy.HOLDER_FEE_POOL();
        uint256 WALLET_FEE_POOL = coreProxy.WALLET_FEE_POOL();
        uint256 poolFundsBeforeBlocked = coreProxy.CHANNEL_POOL_FUNDS();

        vm.prank(actor.admin);
        coreProxy.blockChannel(bobBytes);
        uint256 actualChannelFundsAfterBlocked = coreProxy.CHANNEL_POOL_FUNDS();

        uint256 expectedPoolContributionAfterBlocked = poolContributionBeforeBlocked - MIN_POOL_CONTRIBUTION;
        uint256 expectedChannelFundsAfterBlocked = poolFundsBeforeBlocked - expectedPoolContributionAfterBlocked;

        assertEq(coreProxy.HOLDER_FEE_POOL(), HOLDER_FEE_POOL + BaseHelper.calcPercentage(expectedPoolContributionAfterBlocked , HOLDER_SPLIT));
        assertEq(coreProxy.WALLET_FEE_POOL(), WALLET_FEE_POOL + expectedPoolContributionAfterBlocked - BaseHelper.calcPercentage(expectedPoolContributionAfterBlocked , HOLDER_SPLIT));
        assertEq(actualChannelFundsAfterBlocked, expectedChannelFundsAfterBlocked);
    }
}
