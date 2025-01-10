pragma solidity ^0.8.0;

import { BasePushCoreTest } from "../BasePushCoreTest.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { GenericTypes } from "contracts/libraries/DataTypes.sol";
import { BaseHelper } from "contracts/libraries/BaseHelper.sol";

contract CoreAdminActions_Test is BasePushCoreTest {
    function setUp() public virtual override {
        BasePushCoreTest.setUp();
    }

    function test_WhenNonAdminTriesTo_Set_CommunicatorAddress() external {
        // it should Revert
        vm.expectRevert(Errors.CallerNotAdmin.selector);
        changePrank(actor.bob_channel_owner);
        coreProxy.setPushCommunicatorAddress(address(123));
        assertTrue(coreProxy.pushCommunicator() != address(123));
    }

    function test_WhenAdmin_TriesToSet_CommunicatorAddress() external {
        // it should succesfuly set the communicator address
        changePrank(actor.admin);
        coreProxy.setPushCommunicatorAddress(address(0x0));
        assertTrue(coreProxy.pushCommunicator() == address(0x0));
    }

    function test_RevertWhenNonAdmin_Set_GovernanceAddress() external {
        // it should Revert
        vm.expectRevert(Errors.CallerNotAdmin.selector);
        changePrank(actor.bob_channel_owner);
        coreProxy.setGovernanceAddress(actor.governance);
        assertTrue(coreProxy.governance() != actor.governance);
    }

    function test_WhenAdmin_TriesToSet_GovernanceAddress() external {
        // it should succesfuly set the governance address
        changePrank(actor.admin);
        coreProxy.setGovernanceAddress(actor.governance);
        assertTrue(coreProxy.governance() == actor.governance);
    }

    modifier whenAdminTransfersTheAdminControl() {
        _;
    }

    function test_RevertWhen_NonAdminTriesTo_TransferAdminControl() external whenAdminTransfersTheAdminControl {
        // it should Revert
        vm.expectRevert(Errors.CallerNotAdmin.selector);
        changePrank(actor.bob_channel_owner);
        coreProxy.transferPushChannelAdminControl(actor.bob_channel_owner);
        assertTrue(coreProxy.pushChannelAdmin() == actor.admin);
    }

    function test_RevertWhen_NewAdminAddress_IsZeroAddress() external whenAdminTransfersTheAdminControl {
        // it should Revert Errors.InvalidArgument_WrongAddress
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArgument_WrongAddress.selector, address(0)));
        changePrank(actor.admin);
        coreProxy.transferPushChannelAdminControl(address(0));
        assertTrue(coreProxy.pushChannelAdmin() == actor.admin);
    }

    function test_RevertWhen_NewAdminAddress_IsSameAs_OldAdminAddress() external whenAdminTransfersTheAdminControl {
        // it should Revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArgument_WrongAddress.selector, actor.admin));
        changePrank(actor.admin);
        coreProxy.transferPushChannelAdminControl(actor.admin);
    }

    function test_WhenNewAdmin_AddressIsCorrect() external whenAdminTransfersTheAdminControl {
        // it should change the admin address
        changePrank(actor.admin);
        coreProxy.transferPushChannelAdminControl(actor.charlie_channel_owner);
        assertTrue(coreProxy.pushChannelAdmin() == actor.charlie_channel_owner);
    }

    modifier when_GovernanceCalls_TheSetterFunctions() {
        changePrank(actor.admin);
        coreProxy.setGovernanceAddress(actor.governance);
        _;
    }

    function test_RevertWhen_NewFeeIs_GreaterThanOrEqualTo_AddChannelFees()
        external
        when_GovernanceCalls_TheSetterFunctions
    {
        // it should Revert
        uint256 addChannelMin = coreProxy.ADD_CHANNEL_MIN_FEES();
        vm.expectRevert();
        changePrank(actor.governance);
        coreProxy.setFeeAmount(addChannelMin);
        vm.expectRevert();
        coreProxy.setFeeAmount(addChannelMin + 1000);
    }

    function test_WhenNewFee_IsSmaller_ThanAddChannelFees() external when_GovernanceCalls_TheSetterFunctions {
        // it should update the FEE_AMOUNT
        uint256 addChannelMin = coreProxy.ADD_CHANNEL_MIN_FEES();
        changePrank(actor.governance);
        coreProxy.setFeeAmount(addChannelMin - 1);
        assertEq(coreProxy.FEE_AMOUNT(), addChannelMin - 1);
    }

    //TODO - add a test for FEE_AMOUNT never being 0 after merging PR- 260

    function test_RevertWhen_TheNewValueIsZero() external when_GovernanceCalls_TheSetterFunctions {
        // it should Revert Errors.InvalidArg_LessThanExpected(0, _newAmount);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArg_LessThanExpected.selector, 1, 0));
        changePrank(actor.governance);
        coreProxy.setMinPoolContribution(0);
    }

    function test_WhenTheNewValue_IsGreaterThanZero() external when_GovernanceCalls_TheSetterFunctions {
        // it should update the MinPoolContribution
        changePrank(actor.governance);
        coreProxy.setMinPoolContribution(1);
        assertEq(coreProxy.MIN_POOL_CONTRIBUTION(), 1);
    }

    modifier whenGovernanceSetsTheMinChannelCreationFees() {
        _;
    }

    function test_WhenNewFees_IsSmallerThan_MinRequiredFees()
        external
        when_GovernanceCalls_TheSetterFunctions
        whenGovernanceSetsTheMinChannelCreationFees
    {
        uint256 minFeeRequired = coreProxy.MIN_POOL_CONTRIBUTION() + coreProxy.FEE_AMOUNT();
        // it should Revert
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidArg_LessThanExpected.selector, minFeeRequired, minFeeRequired - 10)
        );
        changePrank(actor.governance);
        coreProxy.setMinChannelCreationFees(minFeeRequired - 10);
    }

    function test_WhenNewFees_IsGreaterOrEqualTo_MinRequiredFees()
        external
        when_GovernanceCalls_TheSetterFunctions
        whenGovernanceSetsTheMinChannelCreationFees
    {
        // it should update the minChannelCreationFees
        uint256 minFeeRequired = coreProxy.MIN_POOL_CONTRIBUTION() + coreProxy.FEE_AMOUNT();
        // it should Revert
        changePrank(actor.governance);
        coreProxy.setMinChannelCreationFees(minFeeRequired);
        assertEq(coreProxy.ADD_CHANNEL_MIN_FEES(), minFeeRequired);
        coreProxy.setMinChannelCreationFees(minFeeRequired + 10);
        assertEq(coreProxy.ADD_CHANNEL_MIN_FEES(), minFeeRequired + 10);
    }

    function test_whenSplitsFeePool(GenericTypes.Percentage memory  _percentage) external {
        _percentage.percentageNumber = bound(_percentage.percentageNumber, 1, 100);
        _percentage.decimalPlaces = bound(_percentage.decimalPlaces, 0, 4);
        changePrank(actor.admin);
        coreProxy.splitFeePool(_percentage);
        (uint percentNumber, uint decimals) = coreProxy.SPLIT_PERCENTAGE_FOR_HOLDER();

        assertEq(percentNumber, _percentage.percentageNumber);
        assertEq(decimals, _percentage.decimalPlaces);

        uint FeesToAdd = 1000 ether;

        uint expectedHolderFees = coreProxy.HOLDER_FEE_POOL() + BaseHelper.calcPercentage(FeesToAdd, _percentage); 
        uint expectedWalletFees = coreProxy.WALLET_FEE_POOL() + FeesToAdd - expectedHolderFees; 

        coreProxy.addPoolFees(FeesToAdd);
        
        assertEq(coreProxy.HOLDER_FEE_POOL(),expectedHolderFees );
        assertEq(coreProxy.WALLET_FEE_POOL(),expectedWalletFees );
    }
}
