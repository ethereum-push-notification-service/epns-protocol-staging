// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { BaseWalletSharesStaking } from "../../BaseWalletSharesStaking.t.sol";
import { GenericTypes } from "contracts/libraries/DataTypes.sol";
import {console2} from "forge-std/console2.sol";
import { Errors } from "contracts/libraries/Errors.sol";

contract AddWalletShareTest is BaseWalletSharesStaking {

    function setUp() public virtual override {
        BaseWalletSharesStaking.setUp();
    }

    function test_Revertwhen_Caller_NotGovernance() public validateShareInvariants {
        changePrank(actor.bob_channel_owner);
        GenericTypes.Percentage memory percentAllocation = GenericTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotGovernance.selector));
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation);
    }

    function test_Revertwhen_InvalidPercentage() public validateShareInvariants {
        changePrank(actor.admin);
        GenericTypes.Percentage memory percentAllocationZero = GenericTypes.Percentage({ percentageNumber: 0, decimalPlaces: 0 });
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArg_MoreThanExpected.selector, 99, 0));
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocationZero);

        GenericTypes.Percentage memory percentAllocationHundred = GenericTypes.Percentage({ percentageNumber: 100, decimalPlaces: 0 });
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArg_MoreThanExpected.selector, 99, 100));
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocationHundred);
    }

    function test_Revertwhen_WalletAddress_Zero() public validateShareInvariants {
        changePrank(actor.admin);
        GenericTypes.Percentage memory percentAllocation = GenericTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArgument_WrongAddress.selector, address(0)));
        pushStaking.addWalletShare(address(0), percentAllocation);
    }

    function test_Revertwhen_Increased() public validateShareInvariants {
        changePrank(actor.admin);
        GenericTypes.Percentage memory percentAllocation = GenericTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArgument_WrongAddress.selector, address(0)));
        pushStaking.addWalletShare(address(0), percentAllocation);
    }

    function test_Revertwhen_NewShares_LE_ToOldShares() public validateShareInvariants {
        changePrank(actor.admin);
        GenericTypes.Percentage memory percentAllocation1 = GenericTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation1);
        (uint256 bobWalletSharesBefore, ,) = pushStaking.walletShareInfo(actor.bob_channel_owner);


        // revert when new allocation is equal to already allocated shares
        GenericTypes.Percentage memory percentAllocation2 = GenericTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });
        uint256 sharesToBeAllocated2 = pushStaking.getSharesAmount(pushStaking.WALLET_TOTAL_SHARES() - bobWalletSharesBefore, percentAllocation2);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArg_LessThanExpected.selector, bobWalletSharesBefore, sharesToBeAllocated2));
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation2);

        // revert when new allocation is less than already allocated shares
        GenericTypes.Percentage memory percentAllocation3 = GenericTypes.Percentage({ percentageNumber: 10, decimalPlaces: 0 });
        uint256 sharesToBeAllocated3 = pushStaking.getSharesAmount(pushStaking.WALLET_TOTAL_SHARES() - bobWalletSharesBefore, percentAllocation3);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArg_LessThanExpected.selector, bobWalletSharesBefore, sharesToBeAllocated3));
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation3);
    }

    function test_AddWalletShare() public validateShareInvariants {
        changePrank(actor.admin);
        uint256 walletTotalSharesBefore = pushStaking.WALLET_TOTAL_SHARES();
        uint256 epochToTotalSharesBefore = pushStaking.epochToTotalShares(getCurrentEpoch());
        (uint256 bobWalletSharesBefore, , uint256 bobClaimedBlockBefore) = pushStaking.walletShareInfo(actor.bob_channel_owner);

        uint256 expectedSharesOfBob = 25_000 * 1e18; // wallet total shares is 100k initially
        vm.expectEmit(true, true, false, false);
        emit NewSharesIssued(actor.bob_channel_owner, expectedSharesOfBob);

        GenericTypes.Percentage memory percentAllocation = GenericTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation);

        (uint256 bobWalletSharesAfter, uint256 bobStakedBlockAfter , uint256 bobClaimedBlockAfter) = pushStaking.walletShareInfo(actor.bob_channel_owner);

        uint256 walletTotalSharesAfter = pushStaking.WALLET_TOTAL_SHARES();
        uint256 epochToTotalSharesAfter = pushStaking.epochToTotalShares(getCurrentEpoch());
        assertEq(walletTotalSharesAfter, walletTotalSharesBefore + expectedSharesOfBob);
        assertEq(epochToTotalSharesAfter, epochToTotalSharesBefore + expectedSharesOfBob);

        assertEq(bobWalletSharesBefore, 0);
        assertEq(bobWalletSharesAfter, expectedSharesOfBob);
        assertEq(bobStakedBlockAfter, block.number);
        assertEq(bobClaimedBlockAfter, pushStaking.genesisEpoch());
    }

    function test_IncreaseAllocation_InSameEpoch() public validateShareInvariants {
        test_AddWalletShare();
        uint256 walletTotalSharesBefore = pushStaking.WALLET_TOTAL_SHARES();
        uint256 epochToTotalSharesBefore = pushStaking.epochToTotalShares(getCurrentEpoch());
        (uint256 bobWalletSharesBefore, , ) = pushStaking.walletShareInfo(actor.bob_channel_owner);

        uint256 expectedSharesOfBob = 100_000 * 1e18; // wallet total shares is 125k now, already allocated shares of bob is 25k
        vm.expectEmit(true, true, false, false);
        emit NewSharesIssued(actor.bob_channel_owner, expectedSharesOfBob);

        GenericTypes.Percentage memory newPercentAllocation = GenericTypes.Percentage({ percentageNumber: 50, decimalPlaces: 0 });
        pushStaking.addWalletShare(actor.bob_channel_owner, newPercentAllocation);

        (uint256 bobWalletSharesAfter, uint256 bobStakedBlockAfter , uint256 bobClaimedBlockAfter) = pushStaking.walletShareInfo(actor.bob_channel_owner);

        uint256 walletTotalSharesAfter = pushStaking.WALLET_TOTAL_SHARES();
        uint256 epochToTotalSharesAfter = pushStaking.epochToTotalShares(getCurrentEpoch());
        assertEq(walletTotalSharesAfter, 200_000 * 1e18);
        assertEq(epochToTotalSharesAfter, 200_000 * 1e18);

        assertEq(bobWalletSharesBefore, 25_000 * 1e18);
        assertEq(bobWalletSharesAfter, expectedSharesOfBob);
        assertEq(bobStakedBlockAfter, block.number);
        assertEq(bobClaimedBlockAfter, pushStaking.genesisEpoch());

        // INVARIANT: wallet total shares should never be reduced after a function call
        assertLe(walletTotalSharesBefore, walletTotalSharesAfter);
        // INVARIANT: epochToTotalShares should never be reduced after a function call
        assertLe(epochToTotalSharesBefore, epochToTotalSharesAfter);
        // INVARIANT: epochToTotalShares in any epoch should not exceed total wallet shares
        assertLe(epochToTotalSharesAfter, walletTotalSharesAfter);
    }

    function test_IncreaseAllocation_InDifferentEpoch() public validateShareInvariants {
        test_AddWalletShare();
        uint256 walletTotalSharesBefore = pushStaking.WALLET_TOTAL_SHARES();
        // uint256 epochToTotalSharesBefore = pushStaking.epochToTotalShares(getCurrentEpoch());
        (uint256 bobWalletSharesBefore, , ) = pushStaking.walletShareInfo(actor.bob_channel_owner);

        roll(epochDuration + 1);

        uint256 expectedSharesOfBob = 100_000 * 1e18; // wallet total shares is 125k now, already allocated shares of bob is 25k
        vm.expectEmit(true, true, false, false);
        emit NewSharesIssued(actor.bob_channel_owner, expectedSharesOfBob);

        GenericTypes.Percentage memory newPercentAllocation = GenericTypes.Percentage({ percentageNumber: 50, decimalPlaces: 0 });
        pushStaking.addWalletShare(actor.bob_channel_owner, newPercentAllocation);

        (uint256 bobWalletSharesAfter, uint256 bobStakedBlockAfter , uint256 bobClaimedBlockAfter) = pushStaking.walletShareInfo(actor.bob_channel_owner);

        uint256 walletTotalSharesAfter = pushStaking.WALLET_TOTAL_SHARES();
        uint256 epochToTotalSharesAfter = pushStaking.epochToTotalShares(getCurrentEpoch());
        assertEq(walletTotalSharesAfter, 200_000 * 1e18);
        assertEq(epochToTotalSharesAfter, walletTotalSharesAfter);

        assertEq(bobWalletSharesBefore, 25_000 * 1e18);
        assertEq(bobWalletSharesAfter, expectedSharesOfBob);
        assertEq(bobStakedBlockAfter, block.number);
        assertEq(bobClaimedBlockAfter, pushStaking.genesisEpoch());

        // INVARIANT: wallet total shares should never be reduced after a function call
        assertLe(walletTotalSharesBefore, walletTotalSharesAfter);
        // INVARIANT: epochToTotalShares in any epoch should not exceed total wallet shares
        assertLe(epochToTotalSharesAfter, walletTotalSharesAfter);
    }
}