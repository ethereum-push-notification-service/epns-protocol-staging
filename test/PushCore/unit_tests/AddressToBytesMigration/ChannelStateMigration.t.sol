pragma solidity ^0.8.20;

import { BasePushCoreTest } from "../BasePushCoreTest.t.sol";
import { CoreTypes } from "contracts/libraries/DataTypes.sol";
import { EPNSCoreProxy, ITransparentUpgradeableProxy } from "contracts/PushCore/EPNSCoreProxy.sol";
import { PushCoreMock } from "contracts/mocks/PushCoreMock.sol";
import { console } from "forge-std/console.sol";
import { PushCoreV3 } from "contracts/PushCore/PushCoreV3.sol";
import { EPNSCoreProxy, ITransparentUpgradeableProxy } from "contracts/PushCore/EPNSCoreProxy.sol";
import { BaseHelper } from "contracts/libraries/BaseHelper.sol";

contract StateMigration_Test is BasePushCoreTest {
    PushCoreMock public coreV2;
    PushCoreV3 public coreV3;
    EPNSCoreProxy public epnsCoreProxyV2;

    function setUp() public virtual override {
        BasePushCoreTest.setUp();
        coreV2 = new PushCoreMock();
        coreV3 = new PushCoreV3();
        epnsCoreProxyV2 = new EPNSCoreProxy(
            address(coreV2),
            address(epnsCoreProxyAdmin),
            actor.admin,
            address(pushToken),
            address(0), // WETH Address
            address(uniV2Router), // Uniswap_Router
            address(0), // Lending_Pool_Aave
            address(0), // Dai_Address
            address(0), // aDai address
            0
        );
        coreV2 = PushCoreMock(address(epnsCoreProxyV2));
        
        changePrank(actor.admin);
        coreV2.setPushCommunicatorAddress(address(commEthProxy));
        coreV2.updateStakingAddress(address(pushStaking));
        coreV2.splitFeePool(HOLDER_SPLIT);

        changePrank(tokenDistributor);
        pushToken.transfer(address(coreV2), 1 ether);

        // Approve tokens of actors now to core contract proxy address
        approveTokens(actor.admin, address(coreV2), 50_000 ether);
        approveTokens(actor.governance, address(coreV2), 50_000 ether);
        approveTokens(actor.bob_channel_owner, address(coreV2), 50_000 ether);
        approveTokens(actor.alice_channel_owner, address(coreV2), 50_000 ether);
        approveTokens(actor.charlie_channel_owner, address(coreV2), 50_000 ether);
        approveTokens(actor.dan_push_holder, address(coreV2), 50_000 ether);
        approveTokens(actor.tim_push_holder, address(coreV2), 50_000 ether);
    }

    function test_ProtocolPoolFees_IsCorrect_ForMultipleChannelsCreation() public {
        uint256 HOLDER_FEE_POOL = coreV2.HOLDER_FEE_POOL();
        uint256 WALLET_FEE_POOL = coreV2.WALLET_FEE_POOL();

        changePrank(actor.bob_channel_owner);
        coreV2.createChannelWithPUSH(
            CoreTypes.ChannelType.InterestBearingOpen, _testChannelIdentity, ADD_CHANNEL_MIN_FEES, 0
        );

        changePrank(actor.charlie_channel_owner);
        coreV2.createChannelWithPUSH(
            CoreTypes.ChannelType.InterestBearingOpen, _testChannelIdentity, ADD_CHANNEL_MIN_FEES * 2, 0
        );
        uint256 expectedProtocolPoolFees = FEE_AMOUNT * 2;
        uint256 expectedChannelPoolFunds =
            (ADD_CHANNEL_MIN_FEES + (ADD_CHANNEL_MIN_FEES * 2)) - expectedProtocolPoolFees;
        
        assertEq(coreV2.HOLDER_FEE_POOL(), HOLDER_FEE_POOL + BaseHelper.calcPercentage(expectedProtocolPoolFees , HOLDER_SPLIT));
        assertEq(coreV2.WALLET_FEE_POOL(), WALLET_FEE_POOL + expectedProtocolPoolFees - BaseHelper.calcPercentage(expectedProtocolPoolFees , HOLDER_SPLIT));
        assertEq(expectedChannelPoolFunds, coreV2.CHANNEL_POOL_FUNDS());
    }

    function test_ChannelsState_Migration() external {
        test_ProtocolPoolFees_IsCorrect_ForMultipleChannelsCreation();

        address[] memory _channels = new address[](2);
        _channels[0] = actor.bob_channel_owner;
        _channels[1] = actor.charlie_channel_owner;

        for (uint256 i; i < _channels.length; ++i) {
            (
                ,
                uint8 actualChannelState,
                ,
                uint256 actualPoolContribution,
                ,
                ,
                ,
                uint256 actualChannelStartBlock,
                uint256 actualChannelUpdateBlock,
                uint256 actualChannelWeight,
                uint256 actualExpiryTime
            ) = coreV2.channels(_channels[i]);
            console.log(actualChannelState, actualPoolContribution, actualChannelStartBlock, actualChannelUpdateBlock);
        }
        changePrank(actor.admin);
        epnsCoreProxyAdmin.upgrade(ITransparentUpgradeableProxy(address(epnsCoreProxyV2)), address(coreV3));
        coreV3 = PushCoreV3(address(epnsCoreProxyV2));

        bytes32[] memory _channelsBytes = new bytes32[](2);
        _channelsBytes[0] = channelCreators.bob_channel_owner_Bytes32;
        _channelsBytes[1] = channelCreators.charlie_channel_owner_Bytes32;

        vm.expectRevert();
        coreV3.migrateAddressToBytes32(_channels);

        coreV3.pauseContract();
        coreV3.migrateAddressToBytes32(_channels);
        for (uint256 i; i < _channelsBytes.length; ++i) {
            (
                ,
                uint8 actualChannelState,
                ,
                uint256 actualPoolContribution,
                ,
                ,
                ,
                uint256 actualChannelStartBlock,
                uint256 actualChannelUpdateBlock,
                uint256 actualChannelWeight,
                uint256 actualExpiryTime
            ) = coreV3.channelInfo(_channelsBytes[i]);
            console.log(actualChannelState, actualPoolContribution, actualChannelStartBlock, actualChannelUpdateBlock);
        }
    }
}
