// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { BaseWalletSharesStaking } from "../BaseWalletSharesStaking.t.sol";
import { GenericTypes } from "contracts/libraries/DataTypes.sol";
import { console2 } from "forge-std/console2.sol";
import { Errors } from "contracts/libraries/Errors.sol";

contract AddWalletShareTestFuzz is BaseWalletSharesStaking {
    function setUp() public virtual override {
        BaseWalletSharesStaking.setUp();
    }

    function testFuzz_Revertwhen_NewShares_LE_ToOldShares(GenericTypes.Percentage memory percentAllocation1)
        public
        validateShareInvariants
    {
        percentAllocation1.percentageNumber = bound(percentAllocation1.percentageNumber, 10, 99);
        percentAllocation1.decimalPlaces = bound(percentAllocation1.decimalPlaces, 0, 10);

        changePrank(actor.admin);
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation1);
        (uint256 bobWalletSharesBefore,,) = pushStaking.walletShareInfo(actor.bob_channel_owner);

        // revert when new allocation is equal to already allocated shares
        uint256 sharesToBeAllocated2 =
            pushStaking.getSharesAmount(pushStaking.WALLET_TOTAL_SHARES() - bobWalletSharesBefore, percentAllocation1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidArg_LessThanExpected.selector, bobWalletSharesBefore, sharesToBeAllocated2
            )
        );
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation1);

        // revert when new allocation is less than already allocated shares
        percentAllocation1.percentageNumber = percentAllocation1.percentageNumber - 5;
        uint256 sharesToBeAllocated3 =
            pushStaking.getSharesAmount(pushStaking.WALLET_TOTAL_SHARES() - bobWalletSharesBefore, percentAllocation1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidArg_LessThanExpected.selector, bobWalletSharesBefore, sharesToBeAllocated3
            )
        );
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation1);
    }

    function testFuzz_AddWalletShare(GenericTypes.Percentage memory percentAllocation) public validateShareInvariants {
        percentAllocation.percentageNumber = bound(percentAllocation.percentageNumber, 5, 89);
        percentAllocation.decimalPlaces = bound(percentAllocation.decimalPlaces, 0, 10);
        changePrank(actor.admin);
        uint256 walletTotalSharesBefore = pushStaking.WALLET_TOTAL_SHARES();
        uint256 epochToTotalSharesBefore = pushStaking.epochToTotalShares(getCurrentEpoch());
        (uint256 bobWalletSharesBefore,, uint256 bobClaimedBlockBefore) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);

        uint256 expectedSharesOfBob = (percentAllocation.percentageNumber * walletTotalSharesBefore)
            / ((100 * (10 ** percentAllocation.decimalPlaces)) - percentAllocation.percentageNumber);
        vm.expectEmit(true, true, false, false);
        emit NewSharesIssued(actor.bob_channel_owner, expectedSharesOfBob);
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation);

        (uint256 bobWalletSharesAfter, uint256 bobStakedBlockAfter, uint256 bobClaimedBlockAfter) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);

        uint256 walletTotalSharesAfter = pushStaking.WALLET_TOTAL_SHARES();
        uint256 epochToTotalSharesAfter = pushStaking.epochToTotalShares(getCurrentEpoch());
        assertEq(walletTotalSharesAfter, walletTotalSharesBefore + expectedSharesOfBob);
        assertEq(epochToTotalSharesAfter, epochToTotalSharesBefore + expectedSharesOfBob);

        assertEq(bobWalletSharesBefore, 0);
        assertEq(bobWalletSharesAfter, expectedSharesOfBob);
        assertEq(bobStakedBlockAfter, block.number);
        assertEq(bobClaimedBlockAfter, pushStaking.genesisEpoch());
    }

    function testFuzz_IncreaseAllocation_InSameEpoch(GenericTypes.Percentage memory percentAllocation)
        public
        validateShareInvariants
    {
        percentAllocation.percentageNumber = bound(percentAllocation.percentageNumber, 5, 89);
        percentAllocation.decimalPlaces = bound(percentAllocation.decimalPlaces, 0, 10);

        testFuzz_AddWalletShare(percentAllocation);
        uint256 walletTotalSharesBefore = pushStaking.WALLET_TOTAL_SHARES();
        uint256 epochToTotalSharesBefore = pushStaking.epochToTotalShares(getCurrentEpoch());
        (uint256 bobWalletSharesBefore,,) = pushStaking.walletShareInfo(actor.bob_channel_owner);
        uint256 walletTotalSharesForCalc = walletTotalSharesBefore - bobWalletSharesBefore;

        GenericTypes.Percentage memory newPercentAllocation = GenericTypes.Percentage({
            percentageNumber: percentAllocation.percentageNumber + 10,
            decimalPlaces: percentAllocation.decimalPlaces
        });
        uint expectedSharesOfBob = (newPercentAllocation.percentageNumber * walletTotalSharesForCalc)
            / ((100 * (10 ** newPercentAllocation.decimalPlaces)) - newPercentAllocation.percentageNumber);// bob is 25k
        vm.expectEmit(true, true, false, false);
        emit NewSharesIssued(actor.bob_channel_owner, expectedSharesOfBob);

        pushStaking.addWalletShare(actor.bob_channel_owner, newPercentAllocation);

        (uint256 bobWalletSharesAfter, uint256 bobStakedBlockAfter, uint256 bobClaimedBlockAfter) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);

        uint256 walletTotalSharesAfter = pushStaking.WALLET_TOTAL_SHARES();
        uint256 epochToTotalSharesAfter = pushStaking.epochToTotalShares(getCurrentEpoch());
        assertEq(walletTotalSharesAfter, expectedSharesOfBob + walletTotalSharesForCalc);
        assertEq(epochToTotalSharesAfter, expectedSharesOfBob + walletTotalSharesForCalc);

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

    function testFuzz_IncreaseAllocation_InDifferentEpoch(GenericTypes.Percentage memory percentAllocation)
        public
        validateShareInvariants
    {
        percentAllocation.percentageNumber = bound(percentAllocation.percentageNumber, 5, 89);
        percentAllocation.decimalPlaces = bound(percentAllocation.decimalPlaces, 0, 10);

        testFuzz_AddWalletShare(percentAllocation);

        uint256 walletTotalSharesBefore = pushStaking.WALLET_TOTAL_SHARES();

        // uint256 epochToTotalSharesBefore = pushStaking.epochToTotalShares(getCurrentEpoch());
        (uint256 bobWalletSharesBefore,,) = pushStaking.walletShareInfo(actor.bob_channel_owner);
        uint256 walletTotalSharesForCalc = walletTotalSharesBefore - bobWalletSharesBefore;

        roll(epochDuration + 1);

        GenericTypes.Percentage memory newPercentAllocation = GenericTypes.Percentage({
            percentageNumber: percentAllocation.percentageNumber + 10,
            decimalPlaces: percentAllocation.decimalPlaces
        });

        uint expectedSharesOfBob = (newPercentAllocation.percentageNumber * walletTotalSharesForCalc)
            / ((100 * (10 ** newPercentAllocation.decimalPlaces)) - newPercentAllocation.percentageNumber);
            
        vm.expectEmit(true, true, false, false);
        emit NewSharesIssued(actor.bob_channel_owner, expectedSharesOfBob);
        pushStaking.addWalletShare(actor.bob_channel_owner, newPercentAllocation);

        (uint256 bobWalletSharesAfter, uint256 bobStakedBlockAfter, uint256 bobClaimedBlockAfter) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);

        uint256 walletTotalSharesAfter = pushStaking.WALLET_TOTAL_SHARES();
        uint256 epochToTotalSharesAfter = pushStaking.epochToTotalShares(getCurrentEpoch());
        assertEq(walletTotalSharesAfter, expectedSharesOfBob + walletTotalSharesForCalc);
        assertEq(epochToTotalSharesAfter, expectedSharesOfBob + walletTotalSharesForCalc);

        assertEq(bobWalletSharesAfter, expectedSharesOfBob);
        assertEq(bobStakedBlockAfter, block.number);
        assertEq(bobClaimedBlockAfter, pushStaking.genesisEpoch());

        // INVARIANT: wallet total shares should never be reduced after a function call
        assertLe(walletTotalSharesBefore, walletTotalSharesAfter);
        // INVARIANT: epochToTotalShares in any epoch should not exceed total wallet shares
        assertLe(epochToTotalSharesAfter, walletTotalSharesAfter);
    }
}
