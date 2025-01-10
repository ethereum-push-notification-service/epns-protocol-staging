// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { BaseWalletSharesStaking } from "../../BaseWalletSharesStaking.t.sol";
import { GenericTypes } from "../../../../../contracts/libraries/DataTypes.sol";
import {console2} from "forge-std/console2.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { BaseHelper } from "contracts/libraries/BaseHelper.sol";

contract DecreaseWalletShareTest is BaseWalletSharesStaking {

    function setUp() public virtual override {
        BaseWalletSharesStaking.setUp();
    }

    function test_Revertwhen_Caller_NotGovernance() public validateShareInvariants {
        changePrank(actor.bob_channel_owner);
        GenericTypes.Percentage memory percentAllocation = GenericTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotGovernance.selector));
        pushStaking.decreaseWalletShare(actor.bob_channel_owner, percentAllocation);
    }

    function test_Revertwhen_WalletAddress_Zero_OrFoundation() public validateShareInvariants {
        changePrank(actor.admin);
        GenericTypes.Percentage memory percentAllocation = GenericTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArgument_WrongAddress.selector, address(0)));
        pushStaking.decreaseWalletShare(address(0), percentAllocation);

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArgument_WrongAddress.selector, actor.admin));
        pushStaking.decreaseWalletShare(actor.admin, percentAllocation);
    }

    function test_Revertwhen_InvalidPercentage() public validateShareInvariants {
        changePrank(actor.admin);
        GenericTypes.Percentage memory percentAllocationZero = GenericTypes.Percentage({ percentageNumber: 0, decimalPlaces: 0 });
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArg_MoreThanExpected.selector, 0, 0));
        pushStaking.decreaseWalletShare(actor.bob_channel_owner, percentAllocationZero);

        GenericTypes.Percentage memory percentAllocationHundred = GenericTypes.Percentage({ percentageNumber: 100, decimalPlaces: 0 });
        uint256 calculatedShares = BaseHelper.calcPercentage(pushStaking.WALLET_TOTAL_SHARES(), percentAllocationHundred);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArg_MoreThanExpected.selector, 0, calculatedShares));
        pushStaking.decreaseWalletShare(actor.bob_channel_owner, percentAllocationHundred);
    }

    function test_Revertwhen_Percentage_GE_Allocated() public validateShareInvariants {
        changePrank(actor.admin);
        GenericTypes.Percentage memory percentAllocation1 = GenericTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation1);
        (uint256 bobWalletShares,,) = pushStaking.walletShareInfo(actor.bob_channel_owner);

        // revert when new allocation is equal to already allocated shares
        GenericTypes.Percentage memory percentAllocation2 = GenericTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });
        uint256 calculatedShares = BaseHelper.calcPercentage(pushStaking.WALLET_TOTAL_SHARES(), percentAllocation2);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArg_MoreThanExpected.selector, bobWalletShares, calculatedShares));
        pushStaking.decreaseWalletShare(actor.bob_channel_owner, percentAllocation2);

        // revert when new allocation is greater than already allocated shares
        GenericTypes.Percentage memory percentAllocation3 = GenericTypes.Percentage({ percentageNumber: 30, decimalPlaces: 0 });
        uint256 calculatedShares2 = BaseHelper.calcPercentage(pushStaking.WALLET_TOTAL_SHARES(), percentAllocation3);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArg_MoreThanExpected.selector, bobWalletShares, calculatedShares2));
        pushStaking.decreaseWalletShare(actor.bob_channel_owner, percentAllocation3);
    }

    function test_DecreaseWalletShare_SameEpoch() public validateShareInvariants {
        addPool(1000);
        changePrank(actor.admin);
        // Add wallet shares of bob
        GenericTypes.Percentage memory percentAllocationFifty = GenericTypes.Percentage({ percentageNumber: 50, decimalPlaces: 0 });
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocationFifty);
        pushStaking.addWalletShare(actor.charlie_channel_owner, percentAllocationFifty);

        uint256 walletTotalSharesBefore = pushStaking.WALLET_TOTAL_SHARES();
        uint256 epochToTotalSharesBefore = pushStaking.epochToTotalShares(getCurrentEpoch());
        (uint256 charlieWalletSharesBefore, , uint256 charlieClaimedBlockBefore) = pushStaking.walletShareInfo(actor.charlie_channel_owner);
        (uint256 bobWalletSharesBefore, ,) = pushStaking.walletShareInfo(actor.bob_channel_owner);
        (uint256 foundationWalletSharesBefore, , ) = pushStaking.walletShareInfo(actor.admin);

        // Decrease wallet shares of charlie from 50 to 40%
        GenericTypes.Percentage memory newPercentAllocationCharlie = GenericTypes.Percentage({ percentageNumber: 40, decimalPlaces: 0 });
        uint256 expectedCharlieShares = (newPercentAllocationCharlie.percentageNumber * walletTotalSharesBefore ) / 100;
        vm.expectEmit(true,true, false, true);
        emit SharesDecreased(actor.charlie_channel_owner, charlieWalletSharesBefore, expectedCharlieShares);
        pushStaking.decreaseWalletShare(actor.charlie_channel_owner, newPercentAllocationCharlie);

        uint256 walletTotalSharesAfter = pushStaking.WALLET_TOTAL_SHARES();
        uint256 epochToTotalSharesAfter = pushStaking.epochToTotalShares(getCurrentEpoch());
        (uint256 charlieWalletSharesAfter, , uint256 charlieClaimedBlockAfter) = pushStaking.walletShareInfo(actor.charlie_channel_owner);
        (uint256 bobWalletSharesAfter, ,) = pushStaking.walletShareInfo(actor.bob_channel_owner);
        (uint256 foundationWalletSharesAfter, uint256 foundationStakedBlockAfter, ) = pushStaking.walletShareInfo(actor.admin);

        assertEq(charlieWalletSharesAfter, expectedCharlieShares);
        assertEq(bobWalletSharesBefore, bobWalletSharesAfter,"bob shares");
        assertEq(walletTotalSharesBefore, walletTotalSharesAfter);
        assertEq(epochToTotalSharesBefore, epochToTotalSharesAfter);
        assertEq(foundationWalletSharesAfter, foundationWalletSharesBefore + (charlieWalletSharesBefore - charlieWalletSharesAfter));
        assertEq(foundationStakedBlockAfter, block.number,"foundation staked block");
        assertEq(charlieClaimedBlockAfter, charlieClaimedBlockBefore,"charlie claimed block");
    }

    function test_DecreaseWalletShare_DifferentEpoch() public validateShareInvariants {
        addPool(1000);
        changePrank(actor.admin);
        // Add wallet shares of bob
        GenericTypes.Percentage memory percentAllocationFifty = GenericTypes.Percentage({ percentageNumber: 50, decimalPlaces: 0 });
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocationFifty);
        pushStaking.addWalletShare(actor.charlie_channel_owner, percentAllocationFifty);

        uint256 epochToTotalSharesBefore = pushStaking.epochToTotalShares(getCurrentEpoch());
        roll(epochDuration * 2);
        addPool(1000);

        uint256 walletTotalSharesBefore = pushStaking.WALLET_TOTAL_SHARES();
        (uint256 charlieWalletSharesBefore, , uint256 charlieClaimedBlockBefore) = pushStaking.walletShareInfo(actor.charlie_channel_owner);
        (uint256 bobWalletSharesBefore, ,) = pushStaking.walletShareInfo(actor.bob_channel_owner);
        (uint256 foundationWalletSharesBefore, , ) = pushStaking.walletShareInfo(actor.admin);

        // Decrease wallet shares of charlie from 50 to 40%
        GenericTypes.Percentage memory newPercentAllocationCharlie = GenericTypes.Percentage({ percentageNumber: 40, decimalPlaces: 0 });
        uint256 expectedCharlieShares = (newPercentAllocationCharlie.percentageNumber * walletTotalSharesBefore) / 100;
        vm.expectEmit(true,true, false, true);
        emit SharesDecreased(actor.charlie_channel_owner, charlieWalletSharesBefore, expectedCharlieShares);
        pushStaking.decreaseWalletShare(actor.charlie_channel_owner, newPercentAllocationCharlie);

        uint256 walletTotalSharesAfter = pushStaking.WALLET_TOTAL_SHARES();
        uint256 epochToTotalSharesAfter = pushStaking.epochToTotalShares(getCurrentEpoch());
        (uint256 charlieWalletSharesAfter, , uint256 charlieClaimedBlockAfter) = pushStaking.walletShareInfo(actor.charlie_channel_owner);
        (uint256 bobWalletSharesAfter, ,) = pushStaking.walletShareInfo(actor.bob_channel_owner);
        (uint256 foundationWalletSharesAfter, , ) = pushStaking.walletShareInfo(actor.admin);
         
        assertEq(charlieWalletSharesAfter, expectedCharlieShares,"Charlie");
        assertEq(bobWalletSharesBefore, bobWalletSharesAfter,"bob shares");
        assertEq(expectedCharlieShares, pushStaking.getEpochToWalletShare(actor.charlie_channel_owner,2),"E2TW");
        assertEq(walletTotalSharesBefore, walletTotalSharesAfter,"Total");
        assertEq(epochToTotalSharesBefore, epochToTotalSharesAfter,"EtT");
        assertEq(foundationWalletSharesAfter, foundationWalletSharesBefore + (charlieWalletSharesBefore - charlieWalletSharesAfter),"Combine");
        assertEq(charlieClaimedBlockAfter, charlieClaimedBlockBefore,"charlie claimed block");
    }


    function test_DecreaseWalletShare_3_Wallets() public validateShareInvariants {
        addPool(1000);
        changePrank(actor.admin);
        // Add wallet shares of bob
        GenericTypes.Percentage memory percentAllocation20 = GenericTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });
        GenericTypes.Percentage memory percentAllocation25 = GenericTypes.Percentage({ percentageNumber: 25, decimalPlaces: 0 });
        GenericTypes.Percentage memory percentAllocation30 = GenericTypes.Percentage({ percentageNumber: 30, decimalPlaces: 0 });

        pushStaking.addWalletShare(actor.alice_channel_owner, percentAllocation25);
        pushStaking.addWalletShare(actor.charlie_channel_owner, percentAllocation30);
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation20);

        uint256 epochToTotalSharesBefore = pushStaking.epochToTotalShares(getCurrentEpoch());
        roll(epochDuration * 2);
        addPool(1000);

        uint256 walletTotalSharesBefore = pushStaking.WALLET_TOTAL_SHARES();
        (uint256 charlieWalletSharesBefore, ,) = pushStaking.walletShareInfo(actor.charlie_channel_owner);
        (uint256 bobWalletSharesBefore, ,) = pushStaking.walletShareInfo(actor.bob_channel_owner);
        (uint256 aliceWalletSharesBefore, ,) = pushStaking.walletShareInfo(actor.alice_channel_owner);
        (uint256 foundationWalletSharesBefore, , ) = pushStaking.walletShareInfo(actor.admin);

        // Decrease wallet shares of charlie from 20 to 10%
        GenericTypes.Percentage memory newPercentAllocation = GenericTypes.Percentage({ percentageNumber: 10, decimalPlaces: 0 });
        uint256 expectedBobShares = (newPercentAllocation.percentageNumber * walletTotalSharesBefore) / 100;
        vm.expectEmit(true,true, false, true);
        emit SharesDecreased(actor.bob_channel_owner, bobWalletSharesBefore, expectedBobShares);
        pushStaking.decreaseWalletShare(actor.bob_channel_owner, newPercentAllocation);

        uint256 walletTotalSharesAfter = pushStaking.WALLET_TOTAL_SHARES();
        uint256 epochToTotalSharesAfter = pushStaking.epochToTotalShares(getCurrentEpoch());
        (uint256 charlieWalletSharesAfter, ,) = pushStaking.walletShareInfo(actor.charlie_channel_owner);
        (uint256 bobWalletSharesAfter, ,) = pushStaking.walletShareInfo(actor.bob_channel_owner);
        (uint256 aliceWalletSharesAfter, ,) = pushStaking.walletShareInfo(actor.alice_channel_owner);
        (uint256 foundationWalletSharesAfter, , ) = pushStaking.walletShareInfo(actor.admin);

        assertEq(bobWalletSharesAfter, expectedBobShares);
        assertEq(walletTotalSharesBefore, walletTotalSharesAfter);
        assertEq(epochToTotalSharesBefore, epochToTotalSharesAfter);
        assertEq(charlieWalletSharesBefore, charlieWalletSharesAfter);
        assertEq(aliceWalletSharesBefore, aliceWalletSharesAfter);
    }
}
