// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { BaseWalletSharesStaking } from "../../BaseWalletSharesStaking.t.sol";
import { GenericTypes } from "../../../../../contracts/libraries/DataTypes.sol";
import {console2} from "forge-std/console2.sol";
import { Errors } from "contracts/libraries/Errors.sol";

contract RemoveWalletShareTest is BaseWalletSharesStaking {

    function setUp() public virtual override {
        BaseWalletSharesStaking.setUp();
    }

    function test_Revertwhen_Caller_NotGovernance() public validateShareInvariants {
        changePrank(actor.bob_channel_owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotGovernance.selector));
        pushStaking.removeWalletShare(actor.bob_channel_owner);
    }

    function test_Revertwhen_WalletAddress_Zero_OrFoundation() public validateShareInvariants {
        changePrank(actor.admin);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArgument_WrongAddress.selector, address(0)));
        pushStaking.removeWalletShare(address(0));

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArgument_WrongAddress.selector, actor.admin));
        pushStaking.removeWalletShare(actor.admin);
    }

    function test_Revertwhen_RemovesBefore_1Epoch() public validateShareInvariants {
        changePrank(actor.admin);
        // Add wallet shares of bob
        GenericTypes.Percentage memory percentAllocation = GenericTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation);

        vm.expectRevert(abi.encodeWithSelector(Errors.PushStaking_InvalidEpoch_LessThanExpected.selector));
        pushStaking.removeWalletShare(actor.bob_channel_owner);
    }

    function test_RemoveWalletShare() public validateShareInvariants {
        addPool(1000);
        changePrank(actor.admin);
        // Add wallet shares of bob
        GenericTypes.Percentage memory percentAllocation = GenericTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation);

        uint256 walletTotalSharesBefore = pushStaking.WALLET_TOTAL_SHARES();
        uint256 epochToTotalSharesBefore = pushStaking.epochToTotalShares(getCurrentEpoch());
        (uint256 bobWalletSharesBefore, , uint256 bobClaimedBlockBefore) = pushStaking.walletShareInfo(actor.bob_channel_owner);
        (uint256 foundationWalletSharesBefore, , uint256 foundationClaimedBlockBefore) = pushStaking.walletShareInfo(actor.admin);

        roll(epochDuration * 2);

        emit SharesRemoved(actor.bob_channel_owner, bobWalletSharesBefore);
        // Remove wallet shares of bob
        pushStaking.removeWalletShare(actor.bob_channel_owner);

        uint256 walletTotalSharesAfter = pushStaking.WALLET_TOTAL_SHARES();
        uint256 epochToTotalSharesAfter = pushStaking.epochToTotalShares(getCurrentEpoch());
        (uint256 bobWalletSharesAfter, , uint256 bobClaimedBlockAfter) = pushStaking.walletShareInfo(actor.bob_channel_owner);
        (uint256 foundationWalletSharesAfter, uint256 foundationStakedBlockAfter, uint256 foundationClaimedBlockAfter) = pushStaking.walletShareInfo(actor.admin);

        assertEq(walletTotalSharesBefore, walletTotalSharesAfter);
        assertEq(epochToTotalSharesBefore, epochToTotalSharesAfter);
        assertEq(bobWalletSharesAfter, 0);
        assertEq(foundationWalletSharesAfter, foundationWalletSharesBefore + bobWalletSharesBefore);
        assertEq(foundationStakedBlockAfter, block.number);
        assertEq(foundationClaimedBlockBefore, foundationClaimedBlockAfter);
        assertEq(bobClaimedBlockAfter, bobClaimedBlockBefore);
    }

    function test_RemoveWalletShare_SameEpoch_Rewards() public validateShareInvariants {
        test_RemoveWalletShare();

        uint256 bobRewards = pushStaking.calculateWalletRewards(actor.bob_channel_owner, getCurrentEpoch());
        assertEq(bobRewards, 0);
    }

    function test_RemoveWalletShare_DifferentEpoch() public validateShareInvariants {
        addPool(1000); // doubt
        changePrank(actor.admin);
        // Add wallet shares of bob
        GenericTypes.Percentage memory percentAllocation = GenericTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation);

        roll(epochDuration * 2);
        addPool(1000);

        uint256 walletTotalSharesBefore = pushStaking.WALLET_TOTAL_SHARES();
        (uint256 bobWalletSharesBefore, , uint256 bobClaimedBlockBefore) = pushStaking.walletShareInfo(actor.bob_channel_owner);
        (uint256 foundationWalletSharesBefore, , uint256 foundationClaimedBlockBefore) = pushStaking.walletShareInfo(actor.admin);

        emit SharesRemoved(actor.bob_channel_owner, bobWalletSharesBefore);
        // Remove wallet shares of bob
        pushStaking.removeWalletShare(actor.bob_channel_owner);

        uint256 walletTotalSharesAfter = pushStaking.WALLET_TOTAL_SHARES();
        uint256 epochToTotalSharesAfter = pushStaking.epochToTotalShares(getCurrentEpoch());
        (uint256 bobWalletSharesAfter, , uint256 bobClaimedBlockAfter) = pushStaking.walletShareInfo(actor.bob_channel_owner);
        (uint256 foundationWalletSharesAfter, uint256 foundationStakedBlockAfter, uint256 foundationClaimedBlockAfter) = pushStaking.walletShareInfo(actor.admin);

        assertEq(walletTotalSharesBefore, walletTotalSharesAfter);
        assertEq(epochToTotalSharesAfter, walletTotalSharesAfter);
        assertEq(bobWalletSharesAfter, 0);
        assertEq(foundationWalletSharesAfter, foundationWalletSharesBefore + bobWalletSharesBefore);
        assertEq(foundationStakedBlockAfter, block.number);
        assertEq(foundationClaimedBlockBefore, foundationClaimedBlockAfter);
        assertEq(bobClaimedBlockAfter, bobClaimedBlockBefore);
    }

    function test_RemoveWalletShare_DifferentEpoch_Rewards() public validateShareInvariants {
        test_RemoveWalletShare_DifferentEpoch();

        uint256 bobRewards = pushStaking.calculateWalletRewards(actor.bob_channel_owner, 1);
        assertGt(bobRewards, 0);
    }
}