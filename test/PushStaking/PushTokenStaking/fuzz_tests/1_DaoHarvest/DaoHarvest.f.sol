pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import { BasePushTokenStaking } from "../../BasePushTokenStaking.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";

contract DaoHarvest_test is BasePushTokenStaking {
    function setUp() public virtual override {
        BasePushTokenStaking.setUp();
    }
    //   allows admin to harvest,

    function test_AdminHarvest(uint256 _fee, uint256 _passEpoch) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 3e18);

        _passEpoch = bound(_passEpoch, 3, 22);

        addPool(_fee);

        roll(epochDuration * _passEpoch);

        daoHarvest(actor.admin, _passEpoch - 1);
        uint256 rewards = pushStaking.usersRewardsClaimed(address(coreProxy));

        assertEq(rewards, _fee * 1e18);
    }

    //  yields `0` if no pool funds added,  //  allows only admin to harvest
    function test_AdminHarvestZeroReward(uint256 _passEpoch) public {
        _passEpoch = bound(_passEpoch, 3, 22);

        roll(epochDuration * _passEpoch);
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotGovernance.selector));
        daoHarvest(actor.bob_channel_owner, _passEpoch - 1);
        daoHarvest(actor.admin, _passEpoch - 1);
        uint256 rewardsBef = pushStaking.usersRewardsClaimed(address(coreProxy));

        assertEq(rewardsBef, 0);
    }

    //  admin rewards and user rewards match the pool fees,
    function test_TotalClaimedRewards(uint256 _amount, uint256 _fee, uint256 _passEpoch) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 3e18);
        _amount = bound(_amount, 1, pushToken.balanceOf(actor.bob_channel_owner) / 1e18);

        _passEpoch = bound(_passEpoch, 2, 22);

        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);
        roll(epochDuration * _passEpoch);
        harvest(actor.bob_channel_owner);
        daoHarvest(actor.admin, _passEpoch - 1);
        uint256 rewardsAd = pushStaking.usersRewardsClaimed(address(coreProxy));
        uint256 rewardsBob = pushStaking.usersRewardsClaimed(actor.bob_channel_owner);
        uint256 claimed = rewardsAd + rewardsBob;
        assertApproxEqAbs(_fee * 1e18, claimed, 1 ether);
    }

    //  dao gets all rewards if no one stakes,
    function test_NoStakerDaoGetsRewards(uint256 _passEpoch, uint256 _fee) public {
        _passEpoch = bound(_passEpoch, 3, 22);
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 3e18);

        addPool(_fee);
        roll(epochDuration * _passEpoch);
        daoHarvest(actor.admin, _passEpoch - 1);

        uint256 claimed = pushStaking.usersRewardsClaimed(address(coreProxy));
        assertEq(claimed, _fee * 1e18);
    }
}
