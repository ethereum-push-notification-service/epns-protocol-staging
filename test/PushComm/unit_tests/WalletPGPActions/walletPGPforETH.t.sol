pragma solidity ^0.8.0;

import { BasePushCommTest } from "../BasePushCommTest.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { MockERC721 } from "contracts/mocks/MockERC721.sol";
import { PushCommETHV3 } from "contracts/PushComm/PushCommETHV3.sol";
import { EPNSCommProxy } from "contracts/PushComm/EPNSCommProxy.sol";

contract walletPGPforETH_Test is BasePushCommTest {
    string pgp1 = "PGP1";
    string pgp2 = "PGP2";
    string pgp3 = "PGP3";
    string pgp4 = "PGP4";
    MockERC721 firstERC721;
    MockERC721 secondERC721;
    MockERC721 thirdERC721;
    // PushCommETHV3 public commEth;
    PushCommETHV3 public commProxyEth;

    function setUp() public override {
        BasePushCommTest.setUp();
        // commEth = new PushCommEthV3();
        epnsCommProxy =
            new EPNSCommProxy(address(commEth), address(epnsCommProxyAdmin), actor.admin, "FOUNDRY_TEST_NETWORK");
        changePrank(actor.admin);
        commProxyEth = PushCommETHV3(address(epnsCommProxy));
        commProxyEth.setPushCoreAddress(address(coreProxy));
        commProxyEth.setPushTokenAddress(address(pushToken));
        coreProxy.setPushCommunicatorAddress(address(commProxyEth));

        commProxyEth.setFeeAmount(10e18);
        firstERC721 = new MockERC721(actor.bob_channel_owner);
        secondERC721 = new MockERC721(actor.bob_channel_owner);
        thirdERC721 = new MockERC721(actor.bob_channel_owner);
        approveTokens(actor.admin, address(commProxyEth), 50_000 ether);
        approveTokens(actor.governance, address(commProxyEth), 50_000 ether);
        approveTokens(actor.bob_channel_owner, address(commProxyEth), 50_000 ether);
        approveTokens(actor.alice_channel_owner, address(commProxyEth), 50_000 ether);
        approveTokens(actor.charlie_channel_owner, address(commProxyEth), 50_000 ether);
        approveTokens(actor.dan_push_holder, address(commProxyEth), 50_000 ether);
        approveTokens(actor.tim_push_holder, address(commProxyEth), 50_000 ether);
    }

    modifier whenAUserTriesToAddAnEOAToPGP() {
        _;
    }

    function test_When_TheEOA_IsNotOwned_ByCaller() external whenAUserTriesToAddAnEOAToPGP {
        // it REVERTS
        bytes memory _data = getEncodedData(actor.bob_channel_owner);

        vm.expectRevert(abi.encodeWithSelector(Errors.Comm_InvalidArguments.selector));
        changePrank(actor.alice_channel_owner);
        commProxyEth.registerUserPGP(_data, pgp1, false);
    }

    function test_WhenEOAIsOwnedAndDoesntHaveAPGP() external whenAUserTriesToAddAnEOAToPGP {
        uint256 coreBalanceBefore = pushToken.balanceOf(address(coreProxy));

        // it should execute and set update the mappings
        bytes memory _data = getEncodedData(actor.bob_channel_owner);

        changePrank(actor.bob_channel_owner);
        commProxyEth.registerUserPGP(_data, pgp1, false);
        string memory _storedPgp = getWalletToPgp(_data);
        assertEq(_storedPgp, pgp1);

        assertEq(pushToken.balanceOf(address(coreProxy)), coreBalanceBefore + 10e18);
    }

    function test_WhenTheEOAIsOwnedButAlreadyHasAPGP() external whenAUserTriesToAddAnEOAToPGP {
        // it
        uint256 coreBalanceBefore = pushToken.balanceOf(address(coreProxy));

        bytes memory _data = getEncodedData(actor.bob_channel_owner);

        changePrank(actor.bob_channel_owner);
        commProxyEth.registerUserPGP(_data, pgp1, false);
        string memory _storedPgp = getWalletToPgp(_data);
        assertEq(_storedPgp, pgp1);

        vm.expectRevert(abi.encodeWithSelector(Errors.Comm_InvalidArguments.selector));
        changePrank(actor.bob_channel_owner);
        commProxyEth.registerUserPGP(_data, pgp2, false);

        string memory _storedPgp1 = getWalletToPgp(_data);
        assertEq(_storedPgp1, pgp1);

        assertEq(pushToken.balanceOf(address(coreProxy)), coreBalanceBefore + 10e18);
    }

    modifier whenAUserTriesToAddAnNFTToPGP() {
        _;
    }

    function test_WhenCallerDoesntOwnTheNFT() external whenAUserTriesToAddAnNFTToPGP {
        // it REVERTS

        bytes memory _data = getEncodedData(address(firstERC721), 0);

        vm.expectRevert("NFT not owned");
        changePrank(actor.alice_channel_owner);
        commProxyEth.registerUserPGP(_data, pgp1, true);
        string memory _storedPgp = getWalletToPgp(_data);
    }

    function test_WhenCallerOwnsAnNFTThatsNotAlreadyAttached() external whenAUserTriesToAddAnNFTToPGP {
        // it should execute and update mappings
        uint256 coreBalanceBefore = pushToken.balanceOf(address(coreProxy));
        bytes memory _data = getEncodedData(address(firstERC721), 0);

        changePrank(actor.bob_channel_owner);
        commProxyEth.registerUserPGP(_data, pgp1, true);
        string memory _storedPgp = getWalletToPgp(_data);
        assertEq(_storedPgp, pgp1);
        assertEq(pushToken.balanceOf(address(coreProxy)), coreBalanceBefore + 10e18);
    }

    function test_WhenCaller_OwnsAnNFT_ThatsAlreadyAttached() external whenAUserTriesToAddAnNFTToPGP {
        // it should delete old PGP and update new

        uint256 coreBalanceBefore = pushToken.balanceOf(address(coreProxy));
        bytes memory _data = getEncodedData(address(firstERC721), 0);

        changePrank(actor.bob_channel_owner);
        commProxyEth.registerUserPGP(_data, pgp1, true);
        string memory _storedPgp = getWalletToPgp(_data);
        assertEq(_storedPgp, pgp1);

        firstERC721.transferFrom(actor.bob_channel_owner, actor.alice_channel_owner, 0);
        changePrank(actor.alice_channel_owner);
        commProxyEth.registerUserPGP(_data, pgp2, true);
        string memory _storedPgpAlice = getWalletToPgp(_data);
        assertEq(_storedPgpAlice, pgp2);

        assertEq(pushToken.balanceOf(address(coreProxy)), coreBalanceBefore + 20e18);
    }

    modifier whenAUserTriesToRemoveAnEOAFromPGP() {
        _;
    }

    function test_WhenTheCallerIsNotOwner() external whenAUserTriesToRemoveAnEOAFromPGP {
        // it REVERTS
        bytes memory _data = getEncodedData(actor.bob_channel_owner);
        changePrank(actor.bob_channel_owner);
        commProxyEth.registerUserPGP(_data, pgp1, false);

        vm.expectRevert(abi.encodeWithSelector(Errors.Comm_InvalidArguments.selector));
        changePrank(actor.alice_channel_owner);
        commProxyEth.removeWalletFromUser(_data, false);
    }

    function test_WhenTheEOAIsOwnedAndAlreadyHasAPGP() external whenAUserTriesToRemoveAnEOAFromPGP {
        // it Removes the stored data
        uint256 coreBalanceBefore = pushToken.balanceOf(address(coreProxy));
        bytes memory _data = getEncodedData(actor.bob_channel_owner);

        changePrank(actor.bob_channel_owner);
        commProxyEth.registerUserPGP(_data, pgp1, false);
        string memory _storedPgp = getWalletToPgp(_data);
        assertEq(_storedPgp, pgp1);

        commProxyEth.removeWalletFromUser(_data, false);
        string memory _storedPgpAfter = getWalletToPgp(_data);
        assertEq(_storedPgpAfter, "");

        assertEq(pushToken.balanceOf(address(coreProxy)), coreBalanceBefore + 20e18);
    }

    function test_WhenEOAIsOwnedButDoesntHaveAPGP() external whenAUserTriesToRemoveAnEOAFromPGP {
        // it should REVERT
        bytes memory _data = getEncodedData(actor.bob_channel_owner);

        vm.expectRevert("Invalid Call");
        changePrank(actor.bob_channel_owner);
        commProxyEth.removeWalletFromUser(_data, false);
    }

    modifier whenAUserTriesToRemoveAnNFTFromPGP() {
        _;
    }

    function test_WhenTheNFTIsNotOwnedByTheCaller() external whenAUserTriesToRemoveAnNFTFromPGP {
        // it REVERTS
        bytes memory _data = getEncodedData(address(firstERC721), 0);
        changePrank(actor.bob_channel_owner);
        commProxyEth.registerUserPGP(_data, pgp1, true);

        vm.expectRevert("NFT not owned");
        changePrank(actor.alice_channel_owner);
        commProxyEth.removeWalletFromUser(_data, true);
    }

    function test_WhenTheNFTIsOwnedAndAlreadyHasAPGP() external whenAUserTriesToRemoveAnNFTFromPGP {
        // it renoves the stored data
        uint256 coreBalanceBefore = pushToken.balanceOf(address(coreProxy));
        bytes memory _data = getEncodedData(address(firstERC721), 0);

        changePrank(actor.bob_channel_owner);
        commProxyEth.registerUserPGP(_data, pgp1, true);
        string memory _storedPgp = getWalletToPgp(_data);
        assertEq(_storedPgp, pgp1);

        commProxyEth.removeWalletFromUser(_data, true);
        string memory _storedPgpAfter = getWalletToPgp(_data);
        assertEq(_storedPgpAfter, "");
        assertEq(pushToken.balanceOf(address(coreProxy)), coreBalanceBefore + 20e18);
    }

    function test_WhenNFTIsOwnedButDoesntHaveAPGP() external whenAUserTriesToRemoveAnNFTFromPGP {
        // it should REVERT
        uint256 coreBalanceBefore = pushToken.balanceOf(address(coreProxy));
        bytes memory _data = getEncodedData(address(firstERC721), 0);

        vm.expectRevert("Invalid Call");
        changePrank(actor.bob_channel_owner);
        commProxyEth.removeWalletFromUser(_data, true);
    }

    function test_multipleAddresses_andFullRun(address _addr1, address _addr2) external {
        uint256 coreBalanceBefore = pushToken.balanceOf(address(coreProxy));

        vm.assume(_addr1 != _addr2 && _addr1 != actor.admin);
        vm.assume(_addr2 != address(0) && _addr1 != address(0));
        bytes memory _dataNft1 = getEncodedData(address(firstERC721), 1);
        bytes memory _dataNft2 = getEncodedData(address(secondERC721), 1);
        bytes memory _dataNft3 = getEncodedData(address(thirdERC721), 1);
        bytes memory _dataEoa1 = getEncodedData(_addr1);
        bytes memory _dataEoa2 = getEncodedData(_addr2);

        changePrank(tokenDistributor);
        pushToken.transfer(_addr1, 50_000 ether);
        pushToken.transfer(_addr2, 50_000 ether);

        approveTokens(_addr1, address(commProxyEth), 50_000 ether);
        approveTokens(_addr2, address(commProxyEth), 50_000 ether);

        mintNft(_addr1, firstERC721);
        mintNft(_addr2, secondERC721);

        changePrank(_addr1);
        commProxyEth.registerUserPGP(_dataEoa1, pgp1, false);
        string memory _storedPgpEoa = getWalletToPgp(_dataEoa1);
        assertEq(_storedPgpEoa, pgp1);
        commProxyEth.registerUserPGP(_dataNft1, pgp1, true);
        string memory _storedPgp = getWalletToPgp(_dataNft1);
        assertEq(_storedPgp, pgp1);

        changePrank(_addr2);
        commProxyEth.registerUserPGP(_dataEoa2, pgp2, false);
        string memory _storedPgpEoa2 = getWalletToPgp(_dataEoa2);
        assertEq(_storedPgpEoa2, pgp2);
        commProxyEth.registerUserPGP(_dataNft2, pgp2, true);
        string memory _storedPgp2 = getWalletToPgp(_dataNft2);
        assertEq(_storedPgp2, pgp2);

        changePrank(_addr1);
        firstERC721.transferFrom(_addr1, _addr2, 1);
        string memory _storedPgpTransfer = getWalletToPgp(_dataNft1);
        assertEq(_storedPgpTransfer, pgp1);
        changePrank(_addr2);
        commProxyEth.registerUserPGP(_dataNft1, pgp2, true);
        string memory _storedPgpTransferAndRegister = getWalletToPgp(_dataNft1);
        assertEq(_storedPgpTransferAndRegister, pgp2);

        assertEq(pushToken.balanceOf(address(coreProxy)), coreBalanceBefore + 50e18);
    }

    //Helper Functions

    function getWalletToPgp(bytes memory _data) internal view returns (string memory) {
        return commProxyEth.walletToPGP(keccak256(_data));
    }

    function getEncodedData(address _wallet) internal view returns (bytes memory _data) {
        _data = abi.encode("eip155", block.chainid, _wallet);
    }

    function getEncodedData(address _nft, uint256 _id) internal view returns (bytes memory _data) {
        _data = abi.encode("nft", "eip155", block.chainid, _nft, _id, block.timestamp);
    }

    function mintNft(address _addr, MockERC721 _nft) internal {
        changePrank(_addr);
        _nft.mint();
    }
}
