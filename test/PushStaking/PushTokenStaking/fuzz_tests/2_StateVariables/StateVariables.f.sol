pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import { BasePushTokenStaking } from "../../BasePushTokenStaking.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";

contract StateVariables_test is BasePushTokenStaking {
    function setUp() public virtual override {
        BasePushTokenStaking.setUp();
    }

    function test_BlockOverflow(uint256 _passEpoch) public {
        _passEpoch = bound(_passEpoch, 1, 22);
        roll(_passEpoch * epochDuration);
        uint256 future = block.number;

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArg_LessThanExpected.selector, future, genesisEpoch));
        pushStaking.lastEpochRelative(future, genesisEpoch);
    }

    //Should calculate relative epoch numbers accurately

    function test_CurrentEpoch(uint256 _passEpoch) public {
        _passEpoch = bound(_passEpoch, 1, 22);
        roll(_passEpoch * epochDuration);
        uint256 future = block.number;

        assertEq(pushStaking.lastEpochRelative(genesisEpoch, future), _passEpoch);
    }

    // Should count staked EPOCH of user correctly
    function test_StakeAndClaimEpoch(uint256 _passEpoch, uint256 _amount) public {
        _passEpoch = bound(_passEpoch, 1, 22);
        _amount = bound(_amount, 1, pushToken.balanceOf(actor.bob_channel_owner) / 1e18);

        roll(_passEpoch * epochDuration);
        stake(actor.bob_channel_owner, _amount);

        (uint256 stakedAmount, uint256 stakedWeight, uint256 lastStakedBlock, uint256 lastClaimedBlock) =
            pushStaking.userFeesInfo(actor.bob_channel_owner);

        uint256 lastClaimedEpoch = pushStaking.lastEpochRelative(genesisEpoch, lastClaimedBlock);
        uint256 lastStakedEpoch = pushStaking.lastEpochRelative(genesisEpoch, lastStakedBlock);
        assertEq(stakedAmount, _amount * 1e18);
        assertEq(lastClaimedEpoch, 1);
        assertEq(lastStakedEpoch, _passEpoch);
    }

    function test_HarvestEpoch(uint256 _passEpoch, uint256 _amount) public {
        _passEpoch = bound(_passEpoch, 1, 22);
        _amount = bound(_amount, 1, pushToken.balanceOf(actor.bob_channel_owner) / 1e18);

        roll(_passEpoch * epochDuration);
        uint256 stakeEpoch = getCurrentEpoch();
        // Stakes Push Tokens after 5 blocks, at 6th EPOCH
        stake(actor.bob_channel_owner, _amount);
        (,, uint256 lastStakedBlock,) = pushStaking.userFeesInfo(actor.bob_channel_owner);

        uint256 userLastStakedEpochId = pushStaking.lastEpochRelative(genesisEpoch, lastStakedBlock);

        roll((_passEpoch + 5) * epochDuration);
        uint256 harvestEpoch = getCurrentEpoch();
        // Harvests Push Tokens after 15 blocks, at 16th EPOCH
        harvest(actor.bob_channel_owner);
        (,,, uint256 lastClaimedBlockAfter) = pushStaking.userFeesInfo(actor.bob_channel_owner);
        uint256 userLastClaimedEpochId = pushStaking.lastEpochRelative(genesisEpoch, lastClaimedBlockAfter);
        assertEq(userLastStakedEpochId, _passEpoch);
        assertEq(userLastClaimedEpochId, 5 + _passEpoch);
    }

    // Unstaking function should update User's Detail accurately after unstake
    function test_UnstakeUpdatesDetails(uint256 _amount, uint256 _fee, uint256 _passEpoch) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 3e18);
        _amount = bound(_amount, 1, pushToken.balanceOf(actor.bob_channel_owner) / 1e18);

        _passEpoch = bound(_passEpoch, 2, 22);

        addPool(_fee);
        roll(epochDuration * _passEpoch);

        stake(actor.bob_channel_owner, _amount);
        roll(epochDuration * (_passEpoch + 2));

        (,, uint256 blocks,) = pushStaking.userFeesInfo(actor.bob_channel_owner);
        unstake(actor.bob_channel_owner);
        (uint256 stakedAmount, uint256 stakedWeight, uint256 lastStakedBlock, uint256 lastClaimedBlock) =
            pushStaking.userFeesInfo(actor.bob_channel_owner);

        assertEq(stakedAmount, 0);
        assertEq(stakedWeight, 0);
    }
}
