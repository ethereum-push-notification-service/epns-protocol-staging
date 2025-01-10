pragma solidity ^0.8.20;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";

import "contracts/token/EPNS.sol";
import "contracts/token/Push.sol";
import "contracts/interfaces/uniswap/IUniswapV2Router.sol";
import { PushCoreMock } from "contracts/mocks/PushCoreMock.sol";
import { EPNSCoreProxy } from "contracts/PushCore/EPNSCoreProxy.sol";
import { EPNSCoreAdmin } from "contracts/PushCore/EPNSCoreAdmin.sol";
import { PushCommETHV3 } from "contracts/PushComm/PushCommEthV3.sol";
import { PushCommV3 } from "contracts/PushComm/PushCommV3.sol";
import { EPNSCommProxy } from "contracts/PushComm/EPNSCommProxy.sol";
import { EPNSCommAdmin } from "contracts/PushComm/EPNSCommAdmin.sol";
import { PushMigrationHelper } from "contracts/token/PushMigration.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { PushStaking } from "contracts/PushStaking/PushStaking.sol";
import { PushStakingProxy } from "contracts/PushStaking/PushStakingProxy.sol";
import { PushStakingAdmin } from "contracts/PushStaking/PushStakingAdmin.sol";
import { Actors, ChannelCreators } from "./utils/Actors.sol";
import { Events } from "./utils/Events.sol";
import { Constants } from "./utils/Constants.sol";
import { BaseHelper } from "contracts/libraries/BaseHelper.sol";

abstract contract BaseTest is Test, Constants, Events {
    Push public pushNtt;
    Push public pushNttToken;
    EPNS public pushToken;
    PushCoreMock public coreProxy;
    PushCommV3 public commProxy;
    PushCommETHV3 public commEth;
    PushCommETHV3 public commEthProxy;
    IUniswapV2Router public uniV2Router;
    EPNSCoreProxy public epnsCoreProxy;
    EPNSCoreAdmin public epnsCoreProxyAdmin;
    EPNSCommProxy public epnsCommProxy;
    EPNSCommAdmin public epnsCommProxyAdmin;
    EPNSCommProxy public epnsCommEthProxy;
    EPNSCommAdmin public epnsCommEthProxyAdmin;
    PushMigrationHelper public pushMigrationHelper;
    PushMigrationHelper public pushMigrationHelperProxy;
    TransparentUpgradeableProxy public pushMigrationProxy;
    TransparentUpgradeableProxy public pushNttProxy;
    ProxyAdmin public nttMigrationProxyAdmin;
    ProxyAdmin public nttProxyAdmin;
    PushStaking public pushStaking;
    PushStakingProxy public pushStakingProxy;
    PushStakingAdmin public pushStakingProxyAdmin;

    /* ***************
        Main Actors in Test
     *************** */
    Actors internal actor;
    ChannelCreators internal channelCreators;
    address tokenDistributor;

    /* ***************
        State Variables
     *************** */
    mapping(address => uint256) privateKeys;

    /* ***************
       Initializing Set-Up for Push Contracts
     *************** */

    function setUp() public virtual {
        tokenDistributor = makeAddr("tokenDistributor");

        pushToken = new EPNS(tokenDistributor);
        coreProxy = new PushCoreMock();
        commProxy = new PushCommV3();
        commEth = new PushCommETHV3();
        pushMigrationHelper = new PushMigrationHelper();
        uniV2Router = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        pushNtt = new Push();
        pushStaking = new PushStaking();

        actor = Actors({
            admin: createActor("admin"),
            governance: createActor("governance"),
            bob_channel_owner: createActor("bob_channel_owner"),
            alice_channel_owner: createActor("alice_channel_owner"),
            charlie_channel_owner: createActor("charlie_channel_owner"),
            tony_channel_owner: createActor("tony_channel_owner"),
            dan_push_holder: createActor("dan_push_holder"),
            tim_push_holder: createActor("tim_push_holder")
        });

        // Initialize channel creators with bytes32
        channelCreators = ChannelCreators({
            admin_Bytes32: createChannelCreatorsID(actor.admin),
            governance_Bytes32: createChannelCreatorsID(actor.governance),
            bob_channel_owner_Bytes32: createChannelCreatorsID(actor.bob_channel_owner),
            alice_channel_owner_Bytes32: createChannelCreatorsID(actor.alice_channel_owner),
            charlie_channel_owner_Bytes32: createChannelCreatorsID(actor.charlie_channel_owner),
            tony_channel_owner_Bytes32: createChannelCreatorsID(actor.tony_channel_owner),
            dan_push_holder_Bytes32: createChannelCreatorsID(actor.dan_push_holder),
            tim_push_holder_Bytes32: createChannelCreatorsID(actor.tim_push_holder)
        });

        changePrank(actor.admin);
        nttProxyAdmin = new ProxyAdmin();
        pushNttProxy = new TransparentUpgradeableProxy(
            address(pushNtt), address(nttProxyAdmin), abi.encodeWithSignature("initialize()")
        );
        pushNttToken = Push(address(pushNttProxy));
        nttMigrationProxyAdmin = new ProxyAdmin();

        // Initialize pushMigration proxy admin and proxy contract
        pushMigrationProxy = new TransparentUpgradeableProxy(
            address(pushMigrationHelper),
            address(nttMigrationProxyAdmin),
            abi.encodeWithSignature("initialize(address)", address(pushToken))
        );
        pushMigrationHelperProxy = PushMigrationHelper(address(pushMigrationProxy));
        // set governance as minter of ntt token
        // vm.prank(actor.admin);
        pushNttToken.setMinter(actor.governance);
        epnsCoreProxyAdmin = new EPNSCoreAdmin();

        epnsCoreProxyAdmin = new EPNSCoreAdmin();
        // Initialize coreMock proxy admin and coreProxy contract
        epnsCoreProxy = new EPNSCoreProxy(
            address(coreProxy),
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

        coreProxy = PushCoreMock(address(epnsCoreProxy));

        // Initialize comm proxy admin and commProxy contract
        epnsCommProxyAdmin = new EPNSCommAdmin();
        epnsCommProxy =
            new EPNSCommProxy(address(commProxy), address(epnsCommProxyAdmin), actor.admin, "FOUNDRY_TEST_NETWORK");
        commProxy = PushCommV3(address(epnsCommProxy));

        //Setup PushStaking Contracts
        pushStakingProxyAdmin = new PushStakingAdmin();
        pushStakingProxy =
            new PushStakingProxy(address(pushStaking), address(pushStakingProxyAdmin),  actor.admin, address(coreProxy), address(pushToken));
        pushStaking = PushStaking(address(pushStakingProxy));

        // Set-up Core Address in Comm & Vice-Versa
        changePrank(actor.admin);
        commProxy.setPushCoreAddress(address(coreProxy));
        commProxy.setPushTokenAddress(address(pushToken));
        vm.stopPrank();

        // Initialize comm proxy admin and commProxy contract
        epnsCommEthProxyAdmin = new EPNSCommAdmin();
        epnsCommEthProxy =
            new EPNSCommProxy(address(commEth), address(epnsCommEthProxyAdmin), actor.admin, "FOUNDRY_TEST_NETWORK");
        commEthProxy = PushCommETHV3(address(epnsCommEthProxy));

        // Set-up Core Address in Comm Eth
        changePrank(actor.admin);
        commEthProxy.setPushCoreAddress(address(coreProxy));
        commEthProxy.setPushTokenAddress(address(pushToken));
        coreProxy.setPushCommunicatorAddress(address(commEthProxy));
        commProxy.setCoreFeeConfig(ADD_CHANNEL_MIN_FEES, FEE_AMOUNT, MIN_POOL_CONTRIBUTION);
        coreProxy.updateStakingAddress(address(pushStaking));
        coreProxy.splitFeePool(HOLDER_SPLIT);
        vm.stopPrank();

        // Approve tokens of actors now to core contract proxy address
        approveTokens(actor.admin, address(coreProxy), 50_000 ether);
        approveTokens(actor.governance, address(coreProxy), 50_000 ether);
        approveTokens(actor.bob_channel_owner, address(coreProxy), 50_000 ether);
        approveTokens(actor.alice_channel_owner, address(coreProxy), 50_000 ether);
        approveTokens(actor.charlie_channel_owner, address(coreProxy), 50_000 ether);
        approveTokens(actor.tony_channel_owner, address(coreProxy), 50_000 ether);
        approveTokens(actor.dan_push_holder, address(coreProxy), 50_000 ether);
        approveTokens(actor.tim_push_holder, address(coreProxy), 50_000 ether);
        vm.warp(DEC_27_2021);
    }

    /* ***************
       Core Contract Helper Functions
    *************** */

    function roll(uint256 num) internal {
        vm.roll(num);
    }

    function approveTokens(address from, address to, uint256 amount) internal {
        changePrank(from);
        pushToken.approve(to, amount);
        pushToken.setHolderDelegation(to, true);
        vm.stopPrank();
    }

    function approveNttTokens(address from, address to, uint256 amount) internal {
        changePrank(from);
        pushNttToken.approve(to, amount);
        pushNttToken.setHolderDelegation(to, true);
        vm.stopPrank();
    }

    function createActor(string memory name) internal returns (address payable) {
        address actor;
        uint256 Private;
        (actor, Private) = makeAddrAndKey(name);
        address payable _actor = payable(actor);
        privateKeys[actor] = Private;
        // Transfer 50 eth to every actor
        vm.deal({ account: _actor, newBalance: 50 ether });
        // Transfer 50K PUSH Tokens for every actor
        changePrank(tokenDistributor);
        pushToken.transfer(_actor, 50_000 ether);
        return _actor;
    }

    function createChannelCreatorsID(address _actor) internal pure returns (bytes32 _channelCreatorBytes32) {
        _channelCreatorBytes32 = BaseHelper.addressToBytes32(_actor);
    }

    function toWormholeFormat(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    function getPoolFundsAndFees(uint256 _amountDeposited)
        internal
        view
        returns (uint256 CHANNEL_POOL_FUNDS, uint256 HOLDER_FEE_POOL,uint256 WALLET_FEE_POOL )
    {
        uint256 poolFeeAmount = coreProxy.FEE_AMOUNT();
        uint256 poolFundAmount = _amountDeposited - poolFeeAmount;
        //store funds in pool_funds & pool_fees
        CHANNEL_POOL_FUNDS = coreProxy.CHANNEL_POOL_FUNDS() + poolFundAmount;
        uint holderFees = BaseHelper.calcPercentage(poolFeeAmount , HOLDER_SPLIT);
        HOLDER_FEE_POOL = coreProxy.HOLDER_FEE_POOL() + holderFees ;
        WALLET_FEE_POOL = coreProxy.WALLET_FEE_POOL() + poolFeeAmount - holderFees;
    }
}
