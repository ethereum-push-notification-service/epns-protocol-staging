import { BasePushCoreTest } from "../BasePushCoreTest.t.sol";
import { GenericTypes } from "contracts/libraries/DataTypes.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { BaseHelper } from "contracts/libraries/BaseHelper.sol";
import { console } from "forge-std/console.sol";

contract HandleArbitraryReq is BasePushCoreTest {
    GenericTypes.Percentage feePercentage = GenericTypes.Percentage(2322, 2);
    uint256 amount = 100e18;

    function setUp() public virtual override {
        BasePushCoreTest.setUp();
    }

    modifier whenUserCreatesAnArbitraryRequest() {
        _;
    }

    function test_RevertWhen_TheySend_ZeroTokens() external whenUserCreatesAnArbitraryRequest {
        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArg_LessThanExpected.selector, 1, 0));
        changePrank(actor.bob_channel_owner);
        coreProxy.handleArbitraryRequestData(1, feePercentage, actor.charlie_channel_owner, 0);
    }

    function test_WhenTheySendAmount_GreaterThanZero() public whenUserCreatesAnArbitraryRequest {
        // it should execute and update storage
        uint256 HOLDER_FEE_POOL = coreProxy.HOLDER_FEE_POOL();
        uint256 WALLET_FEE_POOL = coreProxy.WALLET_FEE_POOL();
        uint256 arbitraryFees = coreProxy.arbitraryReqFees(actor.charlie_channel_owner);

        vm.expectEmit(true, true, false, true);
        emit ArbitraryRequest(BaseHelper.addressToBytes32(actor.bob_channel_owner), BaseHelper.addressToBytes32(actor.charlie_channel_owner), amount, feePercentage, 1);
        changePrank(actor.bob_channel_owner);
        coreProxy.handleArbitraryRequestData(1, feePercentage, actor.charlie_channel_owner, amount);
        uint256 feeAmount = BaseHelper.calcPercentage(amount, feePercentage);

        // Update states based on Fee Percentage calculation
        assertEq(coreProxy.HOLDER_FEE_POOL(), HOLDER_FEE_POOL + BaseHelper.calcPercentage(feeAmount , HOLDER_SPLIT));
        assertEq(coreProxy.WALLET_FEE_POOL(), WALLET_FEE_POOL + feeAmount - BaseHelper.calcPercentage(feeAmount , HOLDER_SPLIT));
        assertEq(coreProxy.arbitraryReqFees(actor.charlie_channel_owner), arbitraryFees + amount - feeAmount);
    }

    function test_whenUserTries_ToClaimArbitraryFees() external {
        //it should send the tokens to user
        test_WhenTheySendAmount_GreaterThanZero();
        uint256 balanceBefore = pushToken.balanceOf(address(actor.charlie_channel_owner));
        changePrank(actor.charlie_channel_owner);
        coreProxy.claimArbitraryRequestFees(coreProxy.arbitraryReqFees(actor.charlie_channel_owner));
        uint256 feeAmount = BaseHelper.calcPercentage(amount, feePercentage);
        console.log(pushToken.balanceOf(address(actor.charlie_channel_owner)), balanceBefore, amount, feeAmount);
        assertEq(pushToken.balanceOf(address(actor.charlie_channel_owner)), balanceBefore + amount - feeAmount);
        assertEq(coreProxy.arbitraryReqFees(actor.charlie_channel_owner), 0);
    }
}
