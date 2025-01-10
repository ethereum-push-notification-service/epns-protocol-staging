// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;


import { BaseWalletSharesStaking } from "../../BaseWalletSharesStaking.t.sol";
import { GenericTypes } from "../../../../../contracts/libraries/DataTypes.sol";
import {console2} from "forge-std/console2.sol";

contract WalletShareTest is BaseWalletSharesStaking {
    /// @dev A function invoked before each test case is run.
    function setUp() public virtual override {
        BaseWalletSharesStaking.setUp();
    }

    function test_FoundationGetsInitialShares() public {
        uint256 initialSharesAmount = 100_000 * 1e18;
        (uint256 foundationWalletShares,,) = pushStaking.walletShareInfo(actor.admin);
        uint256 actualTotalShares = pushStaking.WALLET_TOTAL_SHARES();
        assertEq(initialSharesAmount, foundationWalletShares);
        assertEq(foundationWalletShares, actualTotalShares);
    }

    function test_whenFoundation_ClaimRewards() external {
        addPool(1000);
        test_WalletGets_20PercentAllocation();
        roll(epochDuration * 2);
        uint256 balanceAdminBefore = pushToken.balanceOf(actor.admin);
        (uint256 adminWalletSharesBefore, uint256 adminStakedBlockBefore,) = pushStaking.walletShareInfo(actor.admin);
        changePrank(actor.admin);
        pushStaking.claimShareRewards();
        (uint256 adminWalletSharesAfter, uint256 adminStakedBlockAfter, uint256 adminClaimedBlockAfter) =
            pushStaking.walletShareInfo(actor.admin);

        assertEq(adminWalletSharesBefore, adminWalletSharesAfter, "Shares");
        assertEq(adminStakedBlockBefore, adminStakedBlockAfter, "StakedBlock");
        assertEq(adminClaimedBlockAfter, genesisEpoch + (getCurrentEpoch() - 1) * epochDuration, "ClaimedBlock");

        uint256 claimedRewards = pushStaking.walletRewardsClaimed(actor.admin);
        uint256 expectedRewards = (coreProxy.WALLET_FEE_POOL() * 80) / 100;
        assertEq(balanceAdminBefore + expectedRewards, pushToken.balanceOf(actor.admin), "Balance");
        assertEq(expectedRewards, claimedRewards);
    }

    function test_WalletGets_20PercentAllocation() public {
        (uint256 bobWalletSharesBefore, uint256 bobStakedBlockBefore, uint256 bobClaimedBlockBefore) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);
        GenericTypes.Percentage memory percentAllocation =
            GenericTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });

        changePrank(actor.admin);
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation);
        uint256 expectedAllocationShares = 25_000 * 1e18;
        (uint256 bobWalletSharesAfter, uint256 bobStakedBlockAfter, uint256 bobClaimedBlockAfter) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);
        uint256 actualTotalShares = pushStaking.WALLET_TOTAL_SHARES();

        assertEq(bobWalletSharesBefore, 0);
        assertEq(bobWalletSharesAfter, expectedAllocationShares);
        assertEq(actualTotalShares, 125_000 * 1e18);

        uint256 percentage = (bobWalletSharesAfter * 100) / actualTotalShares;
        assertEq(percentage, percentAllocation.percentageNumber);
    }

    function test_whenWallet_ClaimRewards_for20Percent() external {
        addPool(1000);
        test_WalletGets_20PercentAllocation();
        changePrank(actor.bob_channel_owner);
        roll(epochDuration * 2);
        uint256 balanceBobBefore = pushToken.balanceOf(actor.bob_channel_owner);
        (uint256 bobWalletSharesBefore, uint256 bobStakedBlockBefore, uint256 bobClaimedBlockBefore) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);
        pushStaking.claimShareRewards();
        (uint256 bobWalletSharesAfter, uint256 bobStakedBlockAfter, uint256 bobClaimedBlockAfter) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);

        assertEq(bobWalletSharesBefore, bobWalletSharesAfter, "Shares");
        assertEq(bobStakedBlockBefore, bobStakedBlockAfter, "StakedBlock");
        assertEq(bobClaimedBlockAfter, genesisEpoch + (getCurrentEpoch() - 1) * epochDuration, "ClaimedBlock");

        uint256 claimedRewards = pushStaking.walletRewardsClaimed(actor.bob_channel_owner);
        uint256 expectedRewards = (coreProxy.WALLET_FEE_POOL() * 20) / 100;
        assertEq(balanceBobBefore + expectedRewards, pushToken.balanceOf(actor.bob_channel_owner), "Balance");
        assertEq(expectedRewards, claimedRewards);
    }

    function test_whenWallets_ClaimRewards_for_20_50_Percent() external {
        addPool(1000);
        test_WalletGets_50PercentAllocation();
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
    }

    // function test_whenWalletsAndUsers_ClaimRewards() external {
    //     addPool(1000);
    //     test_WalletGets_50PercentAllocation();
    //     stake(actor.charlie_channel_owner, 200);
    //     stake(actor.tony_channel_owner, 1000);
    //     roll(epochDuration * 2);
    //     uint256 balanceBobBefore = pushToken.balanceOf(actor.bob_channel_owner);
    //     (uint256 bobWalletSharesBefore, uint256 bobStakedBlockBefore,) =
    //         pushStaking.walletShareInfo(actor.bob_channel_owner);
    //     uint256 balanceAliceBefore = pushToken.balanceOf(actor.alice_channel_owner);
    //     (uint256 aliceWalletSharesBefore, uint256 aliceStakedBlockBefore,) =
    //         pushStaking.walletShareInfo(actor.alice_channel_owner);

    //     changePrank(actor.bob_channel_owner);
    //     pushStaking.claimShareRewards();
    //     changePrank(actor.alice_channel_owner);
    //     pushStaking.claimShareRewards();

    //     harvest(actor.charlie_channel_owner);
    //     harvest(actor.tony_channel_owner);

    //     (uint256 bobWalletSharesAfter, uint256 bobStakedBlockAfter, uint256 bobClaimedBlockAfter) =
    //         pushStaking.walletShareInfo(actor.bob_channel_owner);
    //     (uint256 aliceWalletSharesAfter, uint256 aliceStakedBlockAfter, uint256 aliceClaimedBlockAfter) =
    //         pushStaking.walletShareInfo(actor.alice_channel_owner);

    //     assertEq(bobWalletSharesBefore, bobWalletSharesAfter, "Shares");
    //     assertEq(bobStakedBlockBefore, bobStakedBlockAfter, "StakedBlock");
    //     assertEq(bobClaimedBlockAfter, genesisEpoch + (getCurrentEpoch() - 1) * epochDuration, "ClaimedBlock");

    //     uint256 claimedRewardsBob = pushStaking.walletRewardsClaimed(actor.bob_channel_owner);

    //     uint256 expectedRewardsBob = (coreProxy.WALLET_FEE_POOL() * 10) / 100;
    //     assertEq(balanceBobBefore + expectedRewardsBob, pushToken.balanceOf(actor.bob_channel_owner), "balanceBob");
    //     assertEq(expectedRewardsBob, claimedRewardsBob, "bobClaimed");

    //     assertEq(aliceWalletSharesBefore, aliceWalletSharesAfter, "Shares");
    //     assertEq(aliceStakedBlockBefore, aliceStakedBlockAfter, "StakedBlock");
    //     assertEq(aliceClaimedBlockAfter, genesisEpoch + (getCurrentEpoch() - 1) * epochDuration, "ClaimedBlock");

    //     uint256 claimedRewardsAlice = pushStaking.walletRewardsClaimed(actor.alice_channel_owner);

    //     uint256 expectedRewardsAlice = coreProxy.WALLET_FEE_POOL() * 50 / 100;
    //     assertEq(
    //         balanceAliceBefore + expectedRewardsAlice, pushToken.balanceOf(actor.alice_channel_owner), "balanceAlice"
    //     );
    //     assertEq(expectedRewardsAlice, claimedRewardsAlice, "Alice Claimed");

    //     uint256 claimedRewardsCharlie = pushStaking.usersRewardsClaimed(actor.charlie_channel_owner);
    //     uint256 claimedRewardsTony = pushStaking.usersRewardsClaimed(actor.tony_channel_owner);
    //     assertGt(claimedRewardsTony, claimedRewardsCharlie);
    // }

    function test_WalletGets_50PercentAllocation() public {
        // bob wallet gets allocated 20% shares i.e. 25k
        test_WalletGets_20PercentAllocation();

        (uint256 aliceWalletSharesBefore,,) = pushStaking.walletShareInfo(actor.alice_channel_owner);
        GenericTypes.Percentage memory percentAllocation =
            GenericTypes.Percentage({ percentageNumber: 50, decimalPlaces: 0 });

        changePrank(actor.admin);
        pushStaking.addWalletShare(actor.alice_channel_owner, percentAllocation);
        uint256 expectedAllocationShares = 125_000 * 1e18;
        (uint256 bobWalletSharesAfter, uint256 bobStakedBlockAfter, uint256 bobClaimedBlockAfter) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);
        (uint256 aliceWalletSharesAfter,,) = pushStaking.walletShareInfo(actor.alice_channel_owner);
        (uint256 foundationWalletSharesAfter,,) = pushStaking.walletShareInfo(actor.admin);
        uint256 actualTotalShares = pushStaking.WALLET_TOTAL_SHARES();

        assertEq(aliceWalletSharesBefore, 0);
        assertEq(bobWalletSharesAfter, 25_000 * 1e18);
        assertEq(aliceWalletSharesAfter, expectedAllocationShares);
        assertEq(foundationWalletSharesAfter, 100_000 * 1e18);
        assertEq(actualTotalShares, 250_000 * 1e18);
        uint256 percentage = (aliceWalletSharesAfter * 100) / actualTotalShares;
        assertEq(percentage, percentAllocation.percentageNumber);
    }

    // removes wallet allocation and assign shares to the foundation
    function test_RemovalWalletM2() public {
        // actor.bob_channel_owner has 20% allocation (25k shares), actor.alice_channel_owner has 50% (125k) &
        // foundation (100k)
        test_WalletGets_50PercentAllocation();

        uint256 totalSharesBefore = pushStaking.WALLET_TOTAL_SHARES();
        (uint256 bobWalletSharesBefore, uint256 bobStakedBlockBefore, uint256 bobClaimedBlockBefore) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);
        (uint256 aliceWalletSharesBefore,,) = pushStaking.walletShareInfo(actor.alice_channel_owner);
        (uint256 foundationWalletSharesBefore,,) = pushStaking.walletShareInfo(actor.admin);
        roll(epochDuration * 2);

        changePrank(actor.admin);
        pushStaking.removeWalletShare(actor.bob_channel_owner);

        uint256 totalSharesAfter = pushStaking.WALLET_TOTAL_SHARES();
        (uint256 bobWalletSharesAfter, uint256 bobStakedBlockAfter, uint256 bobClaimedBlockAfter) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);
        (uint256 aliceWalletSharesAfter,,) = pushStaking.walletShareInfo(actor.alice_channel_owner);
        (uint256 foundationWalletSharesAfter,,) = pushStaking.walletShareInfo(actor.admin);

        assertEq(bobWalletSharesAfter, 0, "bob wallet share");
        assertEq(aliceWalletSharesAfter, aliceWalletSharesBefore, "alice wallet share");
        assertEq(
            foundationWalletSharesAfter, foundationWalletSharesBefore + bobWalletSharesBefore, "foundation wallet share"
        );
        assertEq(totalSharesAfter, totalSharesBefore, "total wallet share");
    }
    // testing add wallet after removal with method m2 (assign shares to foundation)

    function test_AddWallet_AfterRemoval_M2() public {
        test_RemovalWalletM2();
        (uint256 charlieWalletSharesBefore,,) = pushStaking.walletShareInfo(actor.charlie_channel_owner);

        GenericTypes.Percentage memory percentAllocation =
            GenericTypes.Percentage({ percentageNumber: 50, decimalPlaces: 0 });

        changePrank(actor.admin);
        pushStaking.addWalletShare(actor.charlie_channel_owner, percentAllocation);
        uint256 expectedAllocationShares = 250_000 * 1e18;
        (uint256 charlieWalletSharesAfter,,) = pushStaking.walletShareInfo(actor.charlie_channel_owner);
        uint256 totalSharesAfter = pushStaking.WALLET_TOTAL_SHARES();

        assertEq(charlieWalletSharesBefore, 0);
        assertEq(charlieWalletSharesAfter, expectedAllocationShares);
        assertEq(totalSharesAfter, 500_000 * 1e18);
    }

    // assign wallet 0.001% shares
    function test_WalletGets_NegligiblePercentAllocation() public {
        (uint256 bobWalletSharesBefore, uint256 bobStakedBlockBefore, uint256 bobClaimedBlockBefore) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);
        GenericTypes.Percentage memory percentAllocation =
            GenericTypes.Percentage({ percentageNumber: 1, decimalPlaces: 3 });

        uint256 expectedAllocationShares =
            pushStaking.getSharesAmount(pushStaking.WALLET_TOTAL_SHARES(), percentAllocation);
        changePrank(actor.admin);
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation);
        (uint256 bobWalletSharesAfter, uint256 bobStakedBlockAfter, uint256 bobClaimedBlockAfter) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);
        uint256 actualTotalShares = pushStaking.WALLET_TOTAL_SHARES();

        assertEq(bobWalletSharesBefore, 0);
        assertEq(bobWalletSharesAfter, expectedAllocationShares);
        assertEq(actualTotalShares, 100_000 * 1e18 + expectedAllocationShares);
    }

    // assign wallet 0.0001% shares
    function test_WalletGets_NegligiblePercentAllocation2() public {
        (uint256 bobWalletSharesBefore, uint256 bobStakedBlockBefore, uint256 bobClaimedBlockBefore) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);
        GenericTypes.Percentage memory percentAllocation =
            GenericTypes.Percentage({ percentageNumber: 1, decimalPlaces: 4 });

        uint256 expectedAllocationShares =
            pushStaking.getSharesAmount(pushStaking.WALLET_TOTAL_SHARES(), percentAllocation);
        changePrank(actor.admin);
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation);
        (uint256 bobWalletSharesAfter, uint256 bobStakedBlockAfter, uint256 bobClaimedBlockAfter) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);
        uint256 actualTotalShares = pushStaking.WALLET_TOTAL_SHARES();
        assertEq(bobWalletSharesBefore, 0);
        assertEq(bobWalletSharesAfter, expectedAllocationShares);
        assertEq(actualTotalShares, 100_000 * 1e18 + expectedAllocationShares);
    }

    function test_IncreaseWalletShare() public {
        // assigns actor.bob_channel_owner 20% allocation
        test_WalletGets_20PercentAllocation();

        // let's increase actor.bob_channel_owner allocation to 50%
        uint256 totalSharesBefore = pushStaking.WALLET_TOTAL_SHARES();
        (uint256 bobWalletSharesBefore, uint256 bobStakedBlockBefore, uint256 bobClaimedBlockBefore) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);
        (uint256 foundationWalletSharesBefore,,) = pushStaking.walletShareInfo(actor.admin);

        GenericTypes.Percentage memory percentAllocation =
            GenericTypes.Percentage({ percentageNumber: 50, decimalPlaces: 0 });

        changePrank(actor.admin);
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation);
        uint256 expectedAllocationShares = 100_000 * 1e18;
        uint256 totalSharesAfter = pushStaking.WALLET_TOTAL_SHARES();
        (uint256 bobWalletSharesAfter, uint256 bobStakedBlockAfter, uint256 bobClaimedBlockAfter) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);
        (uint256 foundationWalletSharesAfter,,) = pushStaking.walletShareInfo(actor.admin);

        assertEq(bobWalletSharesBefore, 25_000 * 1e18, "bob wallet share");
        assertEq(totalSharesBefore, 125_000 * 1e18, "total wallet share");
        assertEq(foundationWalletSharesBefore, 100_000 * 1e18, "foundation wallet share");
        assertEq(bobWalletSharesAfter, expectedAllocationShares, "bob wallet share after");
        assertEq(totalSharesAfter, 200_000 * 1e18, "total wallet share after");
        assertEq(foundationWalletSharesAfter, 100_000 * 1e18, "foundation wallet share after");
    }

    function test_RevertWhen_DecreaseWalletShare_UsingAdd() public {
        // assigns actor.bob_channel_owner 20% allocation
        test_WalletGets_20PercentAllocation();

        // let's increase actor.bob_channel_owner allocation to 50%
        uint256 totalSharesBefore = pushStaking.WALLET_TOTAL_SHARES();
        (uint256 bobWalletSharesBefore, uint256 bobStakedBlockBefore, uint256 bobClaimedBlockBefore) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);

        GenericTypes.Percentage memory percentAllocation =
            GenericTypes.Percentage({ percentageNumber: 10, decimalPlaces: 0 });

        changePrank(actor.admin);
        vm.expectRevert();
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation);
        (uint256 bobWalletSharesAfter, uint256 bobStakedBlockAfter, uint256 bobClaimedBlockAfter) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);
        uint256 actualTotalShares = pushStaking.WALLET_TOTAL_SHARES();

        assertEq(bobWalletSharesBefore, bobWalletSharesAfter);
        assertEq(actualTotalShares, totalSharesBefore);

        uint256 percentage = (bobWalletSharesAfter * 100) / actualTotalShares;
        assertEq(percentage, 20);
    }
    function test_whenWallet_SharesIncrease_InSameEpoch() public {
        (uint256 bobWalletSharesBefore, uint256 bobStakedBlockBefore, uint256 bobClaimedBlockBefore) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);
        GenericTypes.Percentage memory percentAllocation =
            GenericTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });

        changePrank(actor.admin);
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation);
        uint256 expectedAllocationShares = 25_000 * 1e18;
        (uint256 bobWalletSharesAfter, uint256 bobStakedBlockAfter, uint256 bobClaimedBlockAfter) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);
        uint256 actualTotalShares = pushStaking.WALLET_TOTAL_SHARES();
        uint256 epochToTotalSharesAfter = pushStaking.epochToTotalShares(1);

        assertEq(bobWalletSharesBefore, 0);
        assertEq(bobWalletSharesAfter, expectedAllocationShares);
        assertEq(actualTotalShares, 125_000 * 1e18);
        assertEq(epochToTotalSharesAfter, actualTotalShares);

        uint256 percentage = (bobWalletSharesAfter * 100) / actualTotalShares;
        assertEq(percentage, percentAllocation.percentageNumber);

        GenericTypes.Percentage memory percentAllocation2 =
            GenericTypes.Percentage({ percentageNumber: 50, decimalPlaces: 0 });

        changePrank(actor.admin);
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation2);

        uint256 expectedAllocationShares2 = 100_000 * 1e18;
        (uint256 bobWalletSharesAfter2, uint256 bobStakedBlockAfter2, uint256 bobClaimedBlockAfter2) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);
        uint256 actualTotalShares2 = pushStaking.WALLET_TOTAL_SHARES();
        uint256 epochToTotalSharesAfter2 = pushStaking.epochToTotalShares(1);

        assertEq(bobWalletSharesAfter2, expectedAllocationShares2);
        assertEq(actualTotalShares2, 200_000 * 1e18);
        assertEq(epochToTotalSharesAfter2, actualTotalShares2);
    }

    function test_whenWallet_SharesIncrease_InDifferentEpoch() public {
        (uint256 bobWalletSharesBefore, uint256 bobStakedBlockBefore, uint256 bobClaimedBlockBefore) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);
        GenericTypes.Percentage memory percentAllocation =
            GenericTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });

        changePrank(actor.admin);
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation);
        uint256 expectedAllocationShares = 25_000 * 1e18;
        (uint256 bobWalletSharesAfter, uint256 bobStakedBlockAfter, uint256 bobClaimedBlockAfter) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);
        uint256 actualTotalShares = pushStaking.WALLET_TOTAL_SHARES();
        uint256 epochToTotalSharesAfter = pushStaking.epochToTotalShares(1);

        assertEq(bobWalletSharesBefore, 0);
        assertEq(bobWalletSharesAfter, expectedAllocationShares);
        assertEq(actualTotalShares, 125_000 * 1e18);
        assertEq(epochToTotalSharesAfter, actualTotalShares);

        uint256 percentage = (bobWalletSharesAfter * 100) / actualTotalShares;
        assertEq(percentage, percentAllocation.percentageNumber);

        roll(epochDuration + 1);

        GenericTypes.Percentage memory percentAllocation2 =
            GenericTypes.Percentage({ percentageNumber: 50, decimalPlaces: 0 });

        changePrank(actor.admin);
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation2);

        uint256 expectedAllocationShares2 = 100_000 * 1e18;
        (uint256 bobWalletSharesAfter2, uint256 bobStakedBlockAfter2, uint256 bobClaimedBlockAfter2) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);
        uint256 actualTotalShares2 = pushStaking.WALLET_TOTAL_SHARES();
        uint256 epochToTotalSharesAfter2 = pushStaking.epochToTotalShares(2);

        assertEq(bobWalletSharesAfter2, expectedAllocationShares2);
        assertEq(actualTotalShares2, 200_000 * 1e18);
        assertEq(epochToTotalSharesAfter2, actualTotalShares2);
    }

    // POC
    function test_whenWallet_ClaimRewards_InSameEpoch() external {
        addPool(1000);
        test_WalletGets_20PercentAllocation();
        changePrank(actor.bob_channel_owner);
        roll(epochDuration + 1);
        addPool(1000);
        GenericTypes.Percentage memory percentAllocation2 = GenericTypes.Percentage({ percentageNumber: 50, decimalPlaces: 0 });

        changePrank(actor.admin);
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation2);
        (uint256 bobWalletSharesBefore,,) = pushStaking.walletShareInfo(actor.bob_channel_owner);

        changePrank(actor.bob_channel_owner);
        pushStaking.claimShareRewards();
        (uint256 bobWalletSharesAfter,,) = pushStaking.walletShareInfo(actor.bob_channel_owner);
        assertEq(bobWalletSharesBefore, bobWalletSharesAfter);
    }

    function test_foundation() external {
        addPool(1000);
        GenericTypes.Percentage memory percentAllocation2 = GenericTypes.Percentage({ percentageNumber: 50, decimalPlaces: 0 });
        pushStaking.addWalletShare(actor.charlie_channel_owner, percentAllocation2);
        roll(epochDuration + 2);
        addPool(1000);
        pushStaking.setFoundationAddress(actor.bob_channel_owner);
        // GenericTypes.Percentage memory percentAllocation2 = GenericTypes.Percentage({ percentageNumber: 50, decimalPlaces: 0 });
        // pushStaking.addWalletShare(actor.charlie_channel_owner, percentAllocation2);
        roll(epochDuration * 3);
        changePrank(actor.admin);
        pushStaking.claimShareRewards();
        changePrank(actor.bob_channel_owner);
        pushStaking.claimShareRewards();
        changePrank(actor.charlie_channel_owner);
        pushStaking.claimShareRewards();
    }

    function test_WhenFoundationIsChanged() external {
        addPool(1000);
        // pushStaking.claimShareRewards();
        (uint256 foundationWalletShares,uint256 foundationStakedBlock, uint256 foundationClaimedBlock) = pushStaking.walletShareInfo(actor.admin);
        assertEq(foundationWalletShares, 100_000 ether);
        assertEq(foundationStakedBlock, genesisEpoch);
        assertEq(foundationClaimedBlock, genesisEpoch);
        changePrank(actor.admin);
        roll(epochDuration + 2);
        pushStaking.setFoundationAddress(actor.bob_channel_owner);
        addPool(1000);

        (uint256 newfoundationWalletShares,uint256 newfoundationStakedBlock, uint256 newfoundationClaimedBlock) = pushStaking.walletShareInfo(actor.bob_channel_owner);
        assertEq(newfoundationWalletShares, 100_000 ether);
        assertEq(newfoundationStakedBlock, block.number);
        uint256 _tillEpoch = pushStaking.lastEpochRelative(genesisEpoch, block.number) - 1;
        assertEq(newfoundationClaimedBlock,  genesisEpoch + _tillEpoch * epochDuration);

        (uint256 oldfoundationWalletShares,uint256 oldfoundationStakedBlock, uint256 oldfoundationClaimedBlock) = pushStaking.walletShareInfo(actor.admin);

        roll(epochDuration * 2);

        pushStaking.claimShareRewards();
        changePrank(actor.bob_channel_owner);
        pushStaking.claimShareRewards();

        assertEq(oldfoundationWalletShares, 0);
        assertEq(oldfoundationStakedBlock, genesisEpoch);
        assertEq(oldfoundationClaimedBlock, genesisEpoch);
    }
    
    // function test_MaxDecimalAmount () public  {
    //     // fixed at most 10 decimal places
    //     // percentage = 10.1111111111
    //     GenericTypes.Percentage memory _percentage = GenericTypes.Percentage({
    //         percentageNumber: 101111111111,
    //         decimalPlaces: 10
    //     });

    //     for (uint256 i=1; i<50; i++) {
    //         uint256 shares = pushStaking.getSharesAmount({
    //             _totalShares: 10 ** i,
    //             _percentage: _percentage
    //         });
    //         console2.log("totalShares = ", i);
    //         console2.log(shares/1e18);
    //         console2.log("");
    //     }
    // }
}
