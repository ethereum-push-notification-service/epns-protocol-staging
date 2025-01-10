pragma solidity ^0.8.20;
pragma experimental ABIEncoderV2;

import { BasePushStaking } from "../BasePushStaking.t.sol";

contract BasePushTokenStaking is BasePushStaking {

    function setUp() public virtual override {
        BasePushStaking.setUp();
    }

    //Helper Functions
    function stake(address signer, uint256 amount) internal {
        changePrank(signer);
        pushStaking.stake(amount * 1e18);
    }

    function harvest(address signer) internal {
        changePrank(signer);
        pushStaking.harvestAll();
    }

    function harvestPaginated(address signer, uint256 _till) internal {
        changePrank(signer);
        pushStaking.harvestPaginated(_till);
    }

    function unstake(address signer) internal {
        changePrank(signer);
        pushStaking.unstake();
    }

    function daoHarvest(address signer, uint256 _epoch) internal {
        changePrank(signer);
        pushStaking.daoHarvestPaginated(_epoch);
    }
}
