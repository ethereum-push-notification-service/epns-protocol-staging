// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BasePushCoreTest } from "../BasePushCoreTest.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { BaseHelper } from "contracts/libraries/BaseHelper.sol";

contract test_createIncentivizedChat is BasePushCoreTest {
    function setUp() public override {
        BasePushCoreTest.setUp();
    }

    modifier whenUserCreatesIncentivizedChat() {
        approveTokens(actor.bob_channel_owner, address(coreProxy), 100 ether);
        _;
    }

    function test_WhenPassedAmountIsZero() external whenUserCreatesIncentivizedChat {
        // it should Revert
        changePrank(actor.bob_channel_owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArg_LessThanExpected.selector, coreProxy.FEE_AMOUNT(), 0));
        coreProxy.createIncentivizedChatRequest(actor.charlie_channel_owner, 0);
    }

    function test_WhenPassedReceiver_IsZeroAddress() external whenUserCreatesIncentivizedChat {
        // it should Revert
        changePrank(actor.bob_channel_owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArgument_WrongAddress.selector, address(0)));
        coreProxy.createIncentivizedChatRequest(address(0), 100e18);
    }

    function test_WhenParametersAreCorrect() public whenUserCreatesIncentivizedChat {
        // it should update chatInfo and call core and emit event
        uint256 bobBalanceBefore = pushToken.balanceOf(actor.bob_channel_owner);
        uint256 coreBalanceBefore = pushToken.balanceOf(address(coreProxy));

        // it should update storage and emit event
        uint256 previousAmount = coreProxy.celebUserFunds(actor.charlie_channel_owner);
        uint256 HOLDER_FEE_POOL = coreProxy.HOLDER_FEE_POOL();
        uint256 WALLET_FEE_POOL = coreProxy.WALLET_FEE_POOL();

        changePrank(actor.bob_channel_owner);

        vm.expectEmit(false, false, false, true);
        emit IncentivizedChatReqReceived(
            BaseHelper.addressToBytes32(actor.bob_channel_owner), BaseHelper.addressToBytes32(actor.charlie_channel_owner), 100e18 - FEE_AMOUNT, FEE_AMOUNT, block.timestamp
        );
        coreProxy.createIncentivizedChatRequest(actor.charlie_channel_owner, 100e18);

        assertEq(bobBalanceBefore - 100e18, pushToken.balanceOf(actor.bob_channel_owner));
        assertEq(coreBalanceBefore + 100e18, pushToken.balanceOf(address(coreProxy)));

        assertEq(previousAmount + 100e18 - FEE_AMOUNT, coreProxy.celebUserFunds(actor.charlie_channel_owner));
        assertEq(coreProxy.HOLDER_FEE_POOL(), HOLDER_FEE_POOL + BaseHelper.calcPercentage(FEE_AMOUNT , HOLDER_SPLIT));
        assertEq(coreProxy.WALLET_FEE_POOL(), WALLET_FEE_POOL + FEE_AMOUNT - BaseHelper.calcPercentage(FEE_AMOUNT , HOLDER_SPLIT));
    }

    modifier whenCelebTriesToClaimTheTokens() {
        _;
    }

    function test_WhenRequestedAmountIsMoreThanBalance() external whenCelebTriesToClaimTheTokens {
        // it should Revert
        test_WhenParametersAreCorrect();
        uint256 claimAmount = coreProxy.celebUserFunds(actor.charlie_channel_owner);

        changePrank(actor.charlie_channel_owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidArg_MoreThanExpected.selector,
                coreProxy.celebUserFunds(actor.charlie_channel_owner),
                claimAmount + 1
            )
        );
        coreProxy.claimChatIncentives(claimAmount + 1);
    }

    function test_WhenRequestedAmountIsCorrect() external whenCelebTriesToClaimTheTokens {
        // it should transfer the tokens to celebUser
        uint256 claimAmount = coreProxy.celebUserFunds(actor.charlie_channel_owner);
        uint256 charlieBalanceBefore = pushToken.balanceOf(actor.charlie_channel_owner);
        uint256 coreBalanceBefore = pushToken.balanceOf(address(coreProxy));

        changePrank(actor.charlie_channel_owner);
        coreProxy.claimChatIncentives(claimAmount);

        assertEq(charlieBalanceBefore + claimAmount, pushToken.balanceOf(actor.charlie_channel_owner));
        assertEq(coreBalanceBefore - claimAmount, pushToken.balanceOf(address(coreProxy)));
    }
}
