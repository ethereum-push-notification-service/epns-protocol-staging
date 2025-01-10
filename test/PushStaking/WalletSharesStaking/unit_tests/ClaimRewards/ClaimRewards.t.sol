// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { BaseWalletSharesStaking } from "../../BaseWalletSharesStaking.t.sol";
import { GenericTypes } from "../../../../../contracts/libraries/DataTypes.sol";
import { console2 } from "forge-std/console2.sol";
import { Errors } from "contracts/libraries/Errors.sol";

contract ClaimRewardsTest is BaseWalletSharesStaking {
    function setUp() public virtual override {
        BaseWalletSharesStaking.setUp();
    }

    function test_whenUser_claimsIn_stakedEpoch() external validateShareInvariants {
        uint256 walletTotalSharesBefore = pushStaking.WALLET_TOTAL_SHARES();
        // gets zero rewards for that epoch
        GenericTypes.Percentage memory percentAllocation =
            GenericTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });
        addPool(1000);
        changePrank(actor.admin);
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation);

        uint256 balanceBobBefore = pushToken.balanceOf(actor.bob_channel_owner);
        (uint256 bobWalletSharesBefore, uint256 bobStakedBlockBefore, uint256 bobLastClaimedBlock) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);

        //Claims in the same epoch as shares issued
        uint256 expectedRewards = 0;
        vm.expectEmit(true, true, false, true);
        emit RewardsHarvested(
            actor.bob_channel_owner,
            expectedRewards,
            pushStaking.lastEpochRelative(genesisEpoch, bobLastClaimedBlock),
            getCurrentEpoch() - 1
        );
        changePrank(actor.bob_channel_owner);
        pushStaking.claimShareRewards();
        uint256 walletTotalSharesAfter = pushStaking.WALLET_TOTAL_SHARES();
        uint256 epochToTotalSharesAfter = pushStaking.epochToTotalShares(getCurrentEpoch());

        assertEq(epochToTotalSharesAfter, walletTotalSharesAfter, "eq epoch to total");

        (uint256 bobWalletSharesAfter, uint256 bobStakedBlockAfter, uint256 bobClaimedBlockAfter) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);

        assertEq(bobWalletSharesBefore, bobWalletSharesAfter, "Shares");
        assertEq(bobStakedBlockBefore, bobStakedBlockAfter, "StakedBlock");
        assertEq(bobClaimedBlockAfter, genesisEpoch + (getCurrentEpoch() - 1) * epochDuration, "ClaimedBlock");

        uint256 claimedRewards = pushStaking.walletRewardsClaimed(actor.bob_channel_owner);
        assertEq(balanceBobBefore + expectedRewards, pushToken.balanceOf(actor.bob_channel_owner), "Balance");
        assertEq(expectedRewards, claimedRewards);

        assertLe(walletTotalSharesBefore, walletTotalSharesAfter, "Wallet Total Shares");
        assertLe(epochToTotalSharesAfter, walletTotalSharesAfter, "LE Epoch to total");
    }

    function test_WhenUserClaims_in_DifferentEpoch() public validateShareInvariants {
        uint256 walletTotalSharesBefore = pushStaking.WALLET_TOTAL_SHARES();
        //SHould succesully Claim the reward

        GenericTypes.Percentage memory percentAllocation =
            GenericTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });
        addPool(1000);
        changePrank(actor.admin);
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation);

        uint256 balanceBobBefore = pushToken.balanceOf(actor.bob_channel_owner);
        (uint256 bobWalletSharesBefore, uint256 bobStakedBlockBefore, uint256 bobLastClaimedBlock) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);

        //claims in the second epoch
        roll(epochDuration + 1);
        uint256 expectedRewards = (coreProxy.WALLET_FEE_POOL() * 20) / 100;
        vm.expectEmit(true, true, false, true);
        emit RewardsHarvested(
            actor.bob_channel_owner,
            expectedRewards,
            pushStaking.lastEpochRelative(genesisEpoch, bobLastClaimedBlock),
            getCurrentEpoch() - 1
        );
        changePrank(actor.bob_channel_owner);
        pushStaking.claimShareRewards();

        uint256 walletTotalSharesAfter = pushStaking.WALLET_TOTAL_SHARES();
        uint256 epochToTotalSharesAfter = pushStaking.epochToTotalShares(getCurrentEpoch());

        assertEq(epochToTotalSharesAfter, walletTotalSharesAfter, "eq epoch to total");

        (uint256 bobWalletSharesAfter, uint256 bobStakedBlockAfter, uint256 bobClaimedBlockAfter) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);

        assertEq(bobWalletSharesBefore, bobWalletSharesAfter, "Shares");
        assertEq(bobStakedBlockBefore, bobStakedBlockAfter, "StakedBlock");
        assertEq(bobClaimedBlockAfter, genesisEpoch + (getCurrentEpoch() - 1) * epochDuration, "ClaimedBlock");

        uint256 claimedRewards = pushStaking.walletRewardsClaimed(actor.bob_channel_owner);
        assertEq(balanceBobBefore + expectedRewards, pushToken.balanceOf(actor.bob_channel_owner), "Balance");
        assertEq(expectedRewards, claimedRewards);

        assertLe(walletTotalSharesBefore, walletTotalSharesAfter, "Wallet Total Shares");
        assertLe(epochToTotalSharesAfter, walletTotalSharesAfter, "LE Epoch to total");
    }

    function test_whenUser_claimsIn_sameClaimedEpoch() external validateShareInvariants {
        test_WhenUserClaims_in_DifferentEpoch();

        uint256 balanceBobBefore = pushToken.balanceOf(actor.bob_channel_owner);
        uint256 claimedRewardsBefore = pushStaking.walletRewardsClaimed(actor.bob_channel_owner);
        (uint256 bobWalletSharesBefore, uint256 bobStakedBlockBefore, uint256 bobLastClaimedBlock) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);

        // claims again in the second epoch
        vm.expectEmit(true, true, false, true);
        emit RewardsHarvested(
            actor.bob_channel_owner,
            0,
            pushStaking.lastEpochRelative(genesisEpoch, bobLastClaimedBlock),
            getCurrentEpoch() - 1
        );
        changePrank(actor.bob_channel_owner);
        pushStaking.claimShareRewards();

        (uint256 bobWalletSharesAfter2, uint256 bobStakedBlockAfter2, uint256 bobClaimedBlockAfter2) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);

        //No changes in balance and claimed rewards
        assertEq(bobWalletSharesBefore, bobWalletSharesAfter2, "Shares");
        assertEq(bobStakedBlockBefore, bobStakedBlockAfter2, "StakedBlock");
        assertEq(bobClaimedBlockAfter2, genesisEpoch + (getCurrentEpoch() - 1) * epochDuration, "ClaimedBlock");

        uint256 claimedRewards = pushStaking.walletRewardsClaimed(actor.bob_channel_owner);
        assertEq(balanceBobBefore, pushToken.balanceOf(actor.bob_channel_owner), "Balance");
        assertEq(claimedRewardsBefore, claimedRewards);
    }

    function test_whenUser_claimsFor_multipleEpochs() external validateShareInvariants {
        uint256 walletTotalSharesBefore = pushStaking.WALLET_TOTAL_SHARES();
        //shares issues in epoch one, reward added in subsequent epoch, wallet claims in 4th epoch
        GenericTypes.Percentage memory percentAllocation =
            GenericTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });
        addPool(1000);
        changePrank(actor.admin);
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation);

        roll(epochDuration + 1);
        addPool(2000);

        roll(epochDuration * 2 + 1);
        addPool(3000);

        roll(epochDuration * 3 + 1);
        addPool(4000);

        roll(epochDuration * 4 + 1);

        uint256 balanceBobBefore = pushToken.balanceOf(actor.bob_channel_owner);
        (uint256 bobWalletSharesBefore, uint256 bobStakedBlockBefore, uint256 bobLastClaimedBlock) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);

        uint256 expectedRewards = (coreProxy.WALLET_FEE_POOL() * 20) / 100;

        vm.expectEmit(true, true, false, true);
        emit RewardsHarvested(
            actor.bob_channel_owner,
            expectedRewards,
            pushStaking.lastEpochRelative(genesisEpoch, bobLastClaimedBlock),
            getCurrentEpoch() - 1
        );

        changePrank(actor.bob_channel_owner);
        pushStaking.claimShareRewards();

        uint256 walletTotalSharesAfter = pushStaking.WALLET_TOTAL_SHARES();
        uint256 epochToTotalSharesAfter = pushStaking.epochToTotalShares(getCurrentEpoch());

        assertEq(epochToTotalSharesAfter, walletTotalSharesAfter, "eq epoch to total");

        (uint256 bobWalletSharesAfter, uint256 bobStakedBlockAfter, uint256 bobClaimedBlockAfter2) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);

        //No changes in balance and claimed rewards
        assertEq(bobWalletSharesBefore, bobWalletSharesAfter, "Shares");
        assertEq(bobStakedBlockBefore, bobStakedBlockAfter, "StakedBlock");
        assertEq(bobClaimedBlockAfter2, genesisEpoch + (getCurrentEpoch() - 1) * epochDuration, "ClaimedBlock");

        uint256 claimedRewards = pushStaking.walletRewardsClaimed(actor.bob_channel_owner);

        assertEq(balanceBobBefore + expectedRewards, pushToken.balanceOf(actor.bob_channel_owner), "Balance");
        assertEq(expectedRewards, claimedRewards);

        assertLe(walletTotalSharesBefore, walletTotalSharesAfter, "Wallet Total Shares");
        assertLe(epochToTotalSharesAfter, walletTotalSharesAfter, "LE Epoch to total");
    }

    function test_whenFoundation_ClaimRewards() external validateShareInvariants {
        uint256 walletTotalSharesBefore = pushStaking.WALLET_TOTAL_SHARES();

        GenericTypes.Percentage memory percentAllocation =
            GenericTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });
        addPool(1000);
        changePrank(actor.admin);
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation);
        roll(epochDuration * 2);
        uint256 balanceAdminBefore = pushToken.balanceOf(actor.admin);
        (uint256 adminWalletSharesBefore, uint256 adminStakedBlockBefore, uint256 adminLastClaimedBlock) =
            pushStaking.walletShareInfo(actor.admin);

        uint256 expectedRewards = (coreProxy.WALLET_FEE_POOL() * 80) / 100;
        vm.expectEmit(true, true, false, true);
        emit RewardsHarvested(
            actor.admin,
            expectedRewards,
            pushStaking.lastEpochRelative(genesisEpoch, adminLastClaimedBlock),
            getCurrentEpoch() - 1
        );
        changePrank(actor.admin);
        pushStaking.claimShareRewards();
        (uint256 adminWalletSharesAfter, uint256 adminStakedBlockAfter, uint256 adminClaimedBlockAfter) =
            pushStaking.walletShareInfo(actor.admin);

        uint256 walletTotalSharesAfter = pushStaking.WALLET_TOTAL_SHARES();
        uint256 epochToTotalSharesAfter = pushStaking.epochToTotalShares(getCurrentEpoch());

        assertEq(epochToTotalSharesAfter, walletTotalSharesAfter, "eq epoch to total");

        assertEq(adminWalletSharesBefore, adminWalletSharesAfter, "Shares");
        assertEq(adminStakedBlockBefore, adminStakedBlockAfter, "StakedBlock");
        assertEq(adminClaimedBlockAfter, genesisEpoch + (getCurrentEpoch() - 1) * epochDuration, "ClaimedBlock");

        uint256 claimedRewards = pushStaking.walletRewardsClaimed(actor.admin);
        assertEq(balanceAdminBefore + expectedRewards, pushToken.balanceOf(actor.admin), "Balance");
        assertEq(expectedRewards, claimedRewards);

        assertLe(walletTotalSharesBefore, walletTotalSharesAfter, "Wallet Total Shares");
        assertLe(epochToTotalSharesAfter, walletTotalSharesAfter, "LE Epoch to total");
    }

    function test_whenWalletsAndUsers_ClaimRewards() external {
        addPool(1000);
        GenericTypes.Percentage memory percentAllocation =
            GenericTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });

        changePrank(actor.admin);
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation);

        GenericTypes.Percentage memory percentAllocation2 =
            GenericTypes.Percentage({ percentageNumber: 50, decimalPlaces: 0 });

        changePrank(actor.admin);
        pushStaking.addWalletShare(actor.alice_channel_owner, percentAllocation2);

        changePrank(actor.charlie_channel_owner);
        pushStaking.stake(200 ether);
        changePrank(actor.tony_channel_owner);
        pushStaking.stake(1000 ether);

        roll(epochDuration * 2);
        uint256 balanceBobBefore = pushToken.balanceOf(actor.bob_channel_owner);
        (uint256 bobWalletSharesBefore, uint256 bobStakedBlockBefore,) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);
        uint256 balanceAliceBefore = pushToken.balanceOf(actor.alice_channel_owner);
        (uint256 aliceWalletSharesBefore, uint256 aliceStakedBlockBefore,) =
            pushStaking.walletShareInfo(actor.alice_channel_owner);

        changePrank(actor.bob_channel_owner);
        pushStaking.claimShareRewards();
        changePrank(actor.alice_channel_owner);
        pushStaking.claimShareRewards();

        changePrank(actor.charlie_channel_owner);
        pushStaking.harvestAll();
        changePrank(actor.tony_channel_owner);
        pushStaking.harvestAll();

        (uint256 bobWalletSharesAfter, uint256 bobStakedBlockAfter, uint256 bobClaimedBlockAfter) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);
        (uint256 aliceWalletSharesAfter, uint256 aliceStakedBlockAfter, uint256 aliceClaimedBlockAfter) =
            pushStaking.walletShareInfo(actor.alice_channel_owner);

        assertEq(bobWalletSharesBefore, bobWalletSharesAfter, "Shares");
        assertEq(bobStakedBlockBefore, bobStakedBlockAfter, "StakedBlock");
        assertEq(bobClaimedBlockAfter, genesisEpoch + (getCurrentEpoch() - 1) * epochDuration, "ClaimedBlock");

        uint256 claimedRewardsBob = pushStaking.walletRewardsClaimed(actor.bob_channel_owner);

        uint256 expectedRewardsBob = (coreProxy.WALLET_FEE_POOL() * 10) / 100;
        assertEq(balanceBobBefore + expectedRewardsBob, pushToken.balanceOf(actor.bob_channel_owner), "balanceBob");
        assertEq(expectedRewardsBob, claimedRewardsBob, "bobClaimed");

        assertEq(aliceWalletSharesBefore, aliceWalletSharesAfter, "Shares");
        assertEq(aliceStakedBlockBefore, aliceStakedBlockAfter, "StakedBlock");
        assertEq(aliceClaimedBlockAfter, genesisEpoch + (getCurrentEpoch() - 1) * epochDuration, "ClaimedBlock");

        uint256 claimedRewardsAlice = pushStaking.walletRewardsClaimed(actor.alice_channel_owner);

        uint256 expectedRewardsAlice = coreProxy.WALLET_FEE_POOL() * 50 / 100;
        assertEq(
            balanceAliceBefore + expectedRewardsAlice, pushToken.balanceOf(actor.alice_channel_owner), "balanceAlice"
        );
        assertEq(expectedRewardsAlice, claimedRewardsAlice, "Alice Claimed");

        uint256 claimedRewardsCharlie = pushStaking.usersRewardsClaimed(actor.charlie_channel_owner);
        uint256 claimedRewardsTony = pushStaking.usersRewardsClaimed(actor.tony_channel_owner);
        assertGt(claimedRewardsTony, claimedRewardsCharlie);
    }
}
