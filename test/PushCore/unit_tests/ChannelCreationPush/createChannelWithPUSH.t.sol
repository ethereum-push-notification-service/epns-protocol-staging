pragma solidity ^0.8.20;

import { BasePushCoreTest } from "../BasePushCoreTest.t.sol";
import { CoreTypes } from "contracts/libraries/DataTypes.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { BaseHelper } from "contracts/libraries/BaseHelper.sol";

contract CreateChannelWithPUSH_Test is BasePushCoreTest {
    function setUp() public virtual override {
        BasePushCoreTest.setUp();
    }

    modifier whenNotPaused() {
        _;
    }

    function test_Revertwhen_PushAllowanceNotEnough() public whenNotPaused {
        uint256 _amountBeingTransferred = 10 ether;
        approveTokens(actor.bob_channel_owner, address(coreProxy), _amountBeingTransferred);

        vm.prank(actor.bob_channel_owner);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidArg_LessThanExpected.selector, 50 ether, _amountBeingTransferred)
        );
        coreProxy.createChannelWithPUSH(
            CoreTypes.ChannelType.InterestBearingOpen, _testChannelIdentity, _amountBeingTransferred, 0
        );
    }

    function test_Revertwhen_AlreadyActivatedChannel() public whenNotPaused {
        vm.startPrank(actor.bob_channel_owner);
        coreProxy.createChannelWithPUSH(
            CoreTypes.ChannelType.InterestBearingOpen, _testChannelIdentity, ADD_CHANNEL_MIN_FEES, 0
        );

        vm.expectRevert(Errors.Core_InvalidChannel.selector);
        coreProxy.createChannelWithPUSH(
            CoreTypes.ChannelType.InterestBearingOpen, _testChannelIdentity, ADD_CHANNEL_MIN_FEES, 0
        );
        vm.stopPrank();
    }

    function test_Revertwhen_ChannelTypeNotAllowed() public whenNotPaused {
        vm.startPrank(actor.bob_channel_owner);

        vm.expectRevert(Errors.Core_InvalidChannelType.selector);
        coreProxy.createChannelWithPUSH(
            CoreTypes.ChannelType.ProtocolPromotion, _testChannelIdentity, ADD_CHANNEL_MIN_FEES, 0
        );
        vm.stopPrank();
    }

    function test_Revertwhen_PushTranferredMoreThanApproval() public whenNotPaused {
        approveTokens(actor.bob_channel_owner, address(coreProxy), ADD_CHANNEL_MIN_FEES);

        vm.prank(actor.bob_channel_owner);
        vm.expectRevert(bytes("Push::transferFrom: transfer amount exceeds spender allowance"));
        coreProxy.createChannelWithPUSH(
            CoreTypes.ChannelType.InterestBearingOpen, _testChannelIdentity, ADD_CHANNEL_MAX_POOL_CONTRIBUTION, 0
        );
    }

    function test_CoreGetsFeeAmount() public whenNotPaused {
        vm.startPrank(actor.bob_channel_owner);
        uint256 pushBalanceBeforeUser = pushToken.balanceOf(actor.bob_channel_owner);
        uint256 pushBalanceBeforeCore = pushToken.balanceOf(address(coreProxy));

        coreProxy.createChannelWithPUSH(
            CoreTypes.ChannelType.InterestBearingOpen, _testChannelIdentity, ADD_CHANNEL_MIN_FEES, 0
        );

        uint256 pushBalanceAfterUser = pushToken.balanceOf(actor.bob_channel_owner);
        uint256 pushBalanceAfterCore = pushToken.balanceOf(address(coreProxy));

        assertEq(pushBalanceBeforeUser - pushBalanceAfterUser, pushBalanceAfterCore - pushBalanceBeforeCore);
        assertEq(pushBalanceAfterCore - pushBalanceBeforeCore, ADD_CHANNEL_MIN_FEES);
        vm.stopPrank();
    }

    function test_CreateChannel() public whenNotPaused {
        (uint256 CHANNEL_POOL_FUNDS, uint256 HOLDER_FEE_POOL,uint256 WALLET_FEE_POOL) = getPoolFundsAndFees(ADD_CHANNEL_MIN_FEES);
        vm.startPrank(actor.bob_channel_owner);
        uint256 channelsCountBefore = coreProxy.channelsCount();

        coreProxy.createChannelWithPUSH(
            CoreTypes.ChannelType.InterestBearingOpen, _testChannelIdentity, ADD_CHANNEL_MIN_FEES, 0
        );

        uint256 expectedBlockNumber = block.number;
        uint256 expectedChannelsCount = channelsCountBefore + 1;
        uint8 expectedChannelState = 1;
        uint256 expectedChannelWeight = (CHANNEL_POOL_FUNDS * ADJUST_FOR_FLOAT) / MIN_POOL_CONTRIBUTION;
        uint256 expectedChannelExpiryTime = 0;

        (
            ,
            uint8 actualChannelState,
            ,
            uint256 actualPoolContribution,
            ,
            ,
            ,
            uint256 actualChannelStartBlock,
            uint256 actualChannelUpdateBlock,
            uint256 actualChannelWeight,
            uint256 actualExpiryTime
        ) = coreProxy.channelInfo(channelCreators.bob_channel_owner_Bytes32);

        assertEq(CHANNEL_POOL_FUNDS, coreProxy.CHANNEL_POOL_FUNDS());
        assertEq(expectedChannelsCount, coreProxy.channelsCount());
        assertEq(expectedChannelState, actualChannelState);
        assertEq(CHANNEL_POOL_FUNDS, actualPoolContribution);
        assertEq(expectedBlockNumber, actualChannelStartBlock);
        assertEq(expectedBlockNumber, actualChannelUpdateBlock);
        assertEq(expectedChannelWeight, actualChannelWeight);
        assertEq(expectedChannelExpiryTime, actualExpiryTime);
        assertEq(coreProxy.HOLDER_FEE_POOL(), HOLDER_FEE_POOL );
        assertEq(coreProxy.WALLET_FEE_POOL(), WALLET_FEE_POOL );

        vm.stopPrank();
    }

    function test_ProtocolPoolFeesCorrectForMultipleChannelsCreation() public whenNotPaused {
        uint256 HOLDER_FEE_POOL = coreProxy.HOLDER_FEE_POOL();
        uint256 WALLET_FEE_POOL = coreProxy.WALLET_FEE_POOL();
        vm.prank(actor.bob_channel_owner);
        coreProxy.createChannelWithPUSH(
            CoreTypes.ChannelType.InterestBearingOpen, _testChannelIdentity, ADD_CHANNEL_MIN_FEES, 0
        );

        vm.prank(actor.charlie_channel_owner);
        coreProxy.createChannelWithPUSH(
            CoreTypes.ChannelType.InterestBearingOpen, _testChannelIdentity, ADD_CHANNEL_MIN_FEES * 2, 0
        );

        uint256 expectedProtocolPoolFees = FEE_AMOUNT * 2;
        uint256 expectedChannelPoolFunds =
            (ADD_CHANNEL_MIN_FEES + (ADD_CHANNEL_MIN_FEES * 2)) - expectedProtocolPoolFees;
        assertEq(coreProxy.HOLDER_FEE_POOL(), HOLDER_FEE_POOL + BaseHelper.calcPercentage(expectedProtocolPoolFees , HOLDER_SPLIT));
        assertEq(coreProxy.WALLET_FEE_POOL(), WALLET_FEE_POOL + expectedProtocolPoolFees - BaseHelper.calcPercentage(expectedProtocolPoolFees , HOLDER_SPLIT));
        assertEq(expectedChannelPoolFunds, coreProxy.CHANNEL_POOL_FUNDS());
    }

    function test_Revertwhen_ChannelExpiryLessThanBlockTimestamp() public whenNotPaused {
        vm.startPrank(actor.bob_channel_owner);

        vm.expectRevert(Errors.Core_InvalidExpiryTime.selector);
        coreProxy.createChannelWithPUSH(CoreTypes.ChannelType.TimeBound, _testChannelIdentity, ADD_CHANNEL_MIN_FEES, 0);
        vm.stopPrank();
    }

    function test_EmitRelevantEvents() public whenNotPaused {
        vm.expectEmit(true, true, false, true, address(coreProxy));
        emit ChannelCreated(
            channelCreators.bob_channel_owner_Bytes32, CoreTypes.ChannelType.InterestBearingOpen, _testChannelIdentity
        );

        vm.prank(actor.bob_channel_owner);
        coreProxy.createChannelWithPUSH(
            CoreTypes.ChannelType.InterestBearingOpen, _testChannelIdentity, ADD_CHANNEL_MIN_FEES, 0
        );
    }
}
