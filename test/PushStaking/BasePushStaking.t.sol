pragma solidity ^0.8.20;
pragma experimental ABIEncoderV2;

import { BaseTest } from "../BaseTest.t.sol";

contract BasePushStaking is BaseTest {

    function setUp() public virtual override {
        BaseTest.setUp();
        
        approveTokens(actor.admin, address(pushStaking), 50_000 ether);
        approveTokens(actor.governance, address(pushStaking), 50_000 ether);
        approveTokens(actor.bob_channel_owner, address(pushStaking), 50_000 ether);
        approveTokens(actor.alice_channel_owner, address(pushStaking), 50_000 ether);
        approveTokens(actor.charlie_channel_owner, address(pushStaking), 50_000 ether);
        approveTokens(actor.tony_channel_owner, address(pushStaking), 50_000 ether);
        approveTokens(actor.dan_push_holder, address(pushStaking), 50_000 ether);
        approveTokens(actor.tim_push_holder, address(pushStaking), 50_000 ether);
        
        changePrank(actor.admin);
        pushStaking.initializeStake(WALLET_TOTAL_SHARES);
        genesisEpoch = pushStaking.genesisEpoch();
    }

    function addPool(uint256 amount) internal {
        changePrank(actor.admin);
        coreProxy.addPoolFees(amount * 1e18);
    }

    function getCurrentEpoch() public view returns (uint256 currentEpoch) {
        currentEpoch = pushStaking.lastEpochRelative(genesisEpoch, block.number);
    }
}
