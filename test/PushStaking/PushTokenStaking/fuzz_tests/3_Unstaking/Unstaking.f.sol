pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import { BasePushTokenStaking } from "../../BasePushTokenStaking.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";

contract Unstaking_test is BasePushTokenStaking {
    function setUp() public virtual override {
        BasePushTokenStaking.setUp();
    }

    //  Unstaking allows users to Claim their pending rewards
    function test_Unstaking(uint256 _fee, uint256 _amount, uint256 _passEpoch) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        _amount = bound(_amount, 1, pushToken.balanceOf(actor.bob_channel_owner) / 1e18);
        _passEpoch = bound(_passEpoch, 2, 22);

        addPool(_fee);

        stake(actor.bob_channel_owner, _amount);

        roll(epochDuration * _passEpoch);

        unstake(actor.bob_channel_owner);
        assertEq(pushStaking.usersRewardsClaimed(actor.bob_channel_owner) > 0, true);
    }

    //Users cannot claim rewards after unstaking
    function test_RewardsAfterUnstake(uint256 _fee, uint256 _amount) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        vm.assume(
            _amount <= pushToken.balanceOf(actor.bob_channel_owner) / 1e18
                && _amount <= pushToken.balanceOf(actor.alice_channel_owner) / 1e18
        );
        stake(actor.bob_channel_owner, 100);
        addPool(_fee);
        roll(epochDuration + 1);
        stake(actor.alice_channel_owner, 1);

        harvest(actor.bob_channel_owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.PushStaking_InvalidEpoch_LessThanExpected.selector));
        unstake(actor.bob_channel_owner);
    }

    //Unstaking function should transfer accurate amount of PUSH tokens to User

    function test_UnstakeAccuracy(uint256 _fee, uint256 _amount, uint256 _passEpoch) public {
        uint256 balanceBefore = pushToken.balanceOf(actor.bob_channel_owner);

        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        _amount = bound(_amount, 1, balanceBefore / 1e18);
        _passEpoch = bound(_passEpoch, 2, 22);

        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);
        roll(epochDuration * _passEpoch);
        unstake(actor.bob_channel_owner);
        uint256 rewards = pushStaking.usersRewardsClaimed(actor.bob_channel_owner);
        uint256 expectedAmount = rewards + balanceBefore;
        assertEq(expectedAmount, pushToken.balanceOf(actor.bob_channel_owner));
    }

    //Unstaking should only work after 1 complete EPOCH",

    function test_UnstakeLimit(uint256 _fee, uint256 _amount, uint256 _passEpoch) public {
        uint256 balanceBefore = pushToken.balanceOf(actor.bob_channel_owner);

        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        _amount = bound(_amount, 1, balanceBefore / 1e18);
        _passEpoch = bound(_passEpoch, 2, 22);

        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);
        roll(epochDuration * 1);
        vm.expectRevert(abi.encodeWithSelector(Errors.PushStaking_InvalidEpoch_LessThanExpected.selector));
        unstake(actor.bob_channel_owner);
        roll(epochDuration * _passEpoch);
        unstake(actor.bob_channel_owner);
        uint256 rewards = pushStaking.usersRewardsClaimed(actor.bob_channel_owner);
        uint256 expectedAmount = rewards + balanceBefore;
        assertEq(expectedAmount, pushToken.balanceOf(actor.bob_channel_owner));
    }
}
