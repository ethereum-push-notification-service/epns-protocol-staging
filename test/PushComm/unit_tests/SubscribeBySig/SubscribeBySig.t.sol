pragma solidity ^0.8.0;

import { BasePushCommTest } from "../BasePushCommTest.t.sol";

contract SubscribeBySig_Test is BasePushCommTest {
    function setUp() public override {
        BasePushCommTest.setUp();
    }

    modifier whenUserSubscribesWith712Sig() {
        _;
    }

    function test_RevertWhen_MaliciousUser_ReplaysA712Signature() public whenUserSubscribesWith712Sig {
        bytes32 DOMAIN_SEPARATOR = getDomainSeparator();
        SubscribeUnsubscribe memory _subscribeUnsubscribe = SubscribeUnsubscribe(
            actor.bob_channel_owner,
            actor.alice_channel_owner,
            commProxy.nonces(actor.alice_channel_owner),
            block.timestamp + 1000
        );
        bytes32 structHash = getSubscribeStructHash(_subscribeUnsubscribe, SUBSCRIBE_TYPEHASH);
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeys[actor.alice_channel_owner], digest);

        commProxy.subscribeBySig(
            actor.bob_channel_owner,
            actor.alice_channel_owner,
            commProxy.nonces(actor.alice_channel_owner),
            block.timestamp + 1000,
            v,
            r,
            s
        );
        uint256 oldNonce = commProxy.nonces(actor.alice_channel_owner) - 1;
        changePrank(actor.charlie_channel_owner);
        vm.expectRevert();
        commProxy.subscribeBySig(
            actor.bob_channel_owner, actor.alice_channel_owner, oldNonce, block.timestamp + 1000, v, r, s
        );
    }

    function test_RevertWhen_AnExpired712SignatureIsPassed() public whenUserSubscribesWith712Sig {
        bytes32 DOMAIN_SEPARATOR = getDomainSeparator();
        SubscribeUnsubscribe memory _subscribeUnsubscribe = SubscribeUnsubscribe(
            actor.bob_channel_owner,
            actor.alice_channel_owner,
            commProxy.nonces(actor.alice_channel_owner),
            block.timestamp - 10
        );
        bytes32 structHash = getSubscribeStructHash(_subscribeUnsubscribe, SUBSCRIBE_TYPEHASH);
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeys[actor.alice_channel_owner], digest);
        uint256 Nonce = commProxy.nonces(actor.alice_channel_owner);
        changePrank(actor.charlie_channel_owner);

        vm.expectRevert();
        commProxy.subscribeBySig(
            actor.bob_channel_owner, actor.alice_channel_owner, Nonce, block.timestamp - 10, v, r, s
        );
    }

    function test_WhenThe712SignIsCorrect() public whenUserSubscribesWith712Sig {
        bytes32 DOMAIN_SEPARATOR = getDomainSeparator();
        SubscribeUnsubscribe memory _subscribeUnsubscribe = SubscribeUnsubscribe(
            actor.bob_channel_owner,
            actor.alice_channel_owner,
            commProxy.nonces(actor.alice_channel_owner),
            block.timestamp + 100
        );
        bytes32 structHash = getSubscribeStructHash(_subscribeUnsubscribe, SUBSCRIBE_TYPEHASH);
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeys[actor.alice_channel_owner], digest);
        vm.expectEmit(true, true, false, false);
        emit Subscribe(actor.bob_channel_owner, actor.alice_channel_owner);
        commProxy.subscribeBySig(
            actor.bob_channel_owner,
            actor.alice_channel_owner,
            commProxy.nonces(actor.alice_channel_owner),
            block.timestamp + 100,
            v,
            r,
            s
        );
    }

    modifier whenAContractSubscribesWith1271Sign() {
        _;
    }

    function test_RevertWhen_MaliciousUserReplays_1271Sig() public whenAContractSubscribesWith1271Sign {
        bytes32 DOMAIN_SEPARATOR = getDomainSeparator();
        SubscribeUnsubscribe memory _subscribeUnsubscribe = SubscribeUnsubscribe(
            actor.bob_channel_owner,
            address(verifierContract),
            commProxy.nonces(address(verifierContract)),
            block.timestamp + 100
        );
        bytes32 structHash = getSubscribeStructHash(_subscribeUnsubscribe, SUBSCRIBE_TYPEHASH);
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeys[actor.tim_push_holder], digest);
        vm.expectEmit(true, true, false, false);
        emit Subscribe(actor.bob_channel_owner, address(verifierContract));
        commProxy.subscribeBySig(
            actor.bob_channel_owner,
            address(verifierContract),
            commProxy.nonces(address(verifierContract)),
            block.timestamp + 100,
            v,
            r,
            s
        );
        uint256 oldNonce = commProxy.nonces(address(verifierContract)) - 1;

        changePrank(actor.charlie_channel_owner);
        vm.expectRevert();
        commProxy.subscribeBySig(
            actor.bob_channel_owner, address(verifierContract), oldNonce, block.timestamp + 100, v, r, s
        );
    }

    function test_RevertWhen_AnExpired1271SigIsPassed() public whenAContractSubscribesWith1271Sign {
        bytes32 DOMAIN_SEPARATOR = getDomainSeparator();
        SubscribeUnsubscribe memory _subscribeUnsubscribe = SubscribeUnsubscribe(
            actor.bob_channel_owner,
            address(verifierContract),
            commProxy.nonces(address(verifierContract)),
            block.timestamp - 100
        );
        bytes32 structHash = getSubscribeStructHash(_subscribeUnsubscribe, SUBSCRIBE_TYPEHASH);
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeys[actor.tim_push_holder], digest);
        uint256 Nonce = commProxy.nonces(address(verifierContract));

        changePrank(actor.charlie_channel_owner);
        vm.expectRevert();
        commProxy.subscribeBySig(
            actor.bob_channel_owner, address(verifierContract), Nonce, block.timestamp - 100, v, r, s
        );
    }

    function test_WhenThe1271SignIsCorrect() public whenAContractSubscribesWith1271Sign {
        bytes32 DOMAIN_SEPARATOR = getDomainSeparator();
        SubscribeUnsubscribe memory _subscribeUnsubscribe = SubscribeUnsubscribe(
            actor.bob_channel_owner,
            address(verifierContract),
            commProxy.nonces(address(verifierContract)),
            block.timestamp + 100
        );
        bytes32 structHash = getSubscribeStructHash(_subscribeUnsubscribe, SUBSCRIBE_TYPEHASH);
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeys[actor.tim_push_holder], digest);
        vm.expectEmit(true, true, false, false);
        emit Subscribe(actor.bob_channel_owner, address(verifierContract));
        commProxy.subscribeBySig(
            actor.bob_channel_owner,
            address(verifierContract),
            commProxy.nonces(address(verifierContract)),
            block.timestamp + 100,
            v,
            r,
            s
        );
    }

    function test_WhenUsersUnsubscribeWith712Sig() public {
        //Alice subscribes to bob's channel to check the unsubscribe function
        changePrank(actor.alice_channel_owner);
        commProxy.subscribe(actor.bob_channel_owner);

        bytes32 DOMAIN_SEPARATOR = getDomainSeparator();
        SubscribeUnsubscribe memory _subscribeUnsubscribe = SubscribeUnsubscribe(
            actor.bob_channel_owner,
            actor.alice_channel_owner,
            commProxy.nonces(actor.alice_channel_owner),
            block.timestamp + 100
        );
        bytes32 structHash = getSubscribeStructHash(_subscribeUnsubscribe, UNSUBSCRIBE_TYPEHASH);
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeys[actor.alice_channel_owner], digest);
        vm.expectEmit(true, true, false, false);
        emit Unsubscribe(actor.bob_channel_owner, actor.alice_channel_owner);
        commProxy.unsubscribeBySig(
            actor.bob_channel_owner,
            actor.alice_channel_owner,
            commProxy.nonces(actor.alice_channel_owner),
            block.timestamp + 100,
            v,
            r,
            s
        );
    }

    function test_WhenAContractUnsubscribesWith1271Sig() public {
        // it Allow contract to optout using 1271 support

        //The contract subscribes to a channel
        bytes32 DOMAIN_SEPARATOR = getDomainSeparator();
        SubscribeUnsubscribe memory _subscribeUnsubscribe = SubscribeUnsubscribe(
            actor.bob_channel_owner,
            address(verifierContract),
            commProxy.nonces(address(verifierContract)),
            block.timestamp + 100
        );
        bytes32 structHash = getSubscribeStructHash(_subscribeUnsubscribe, SUBSCRIBE_TYPEHASH);
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeys[actor.tim_push_holder], digest);
        vm.expectEmit(true, true, false, false);
        emit Subscribe(actor.bob_channel_owner, address(verifierContract));
        commProxy.subscribeBySig(
            actor.bob_channel_owner,
            address(verifierContract),
            commProxy.nonces(address(verifierContract)),
            block.timestamp + 100,
            v,
            r,
            s
        );

        //check the unsubscribe function
        bytes32 DOMAIN_SEPARATOR1 = getDomainSeparator();
        SubscribeUnsubscribe memory _subscribeUnsubscribe1 = SubscribeUnsubscribe(
            actor.bob_channel_owner,
            address(verifierContract),
            commProxy.nonces(address(verifierContract)),
            block.timestamp + 100
        );
        bytes32 structHash1 = getSubscribeStructHash(_subscribeUnsubscribe1, UNSUBSCRIBE_TYPEHASH);
        bytes32 digest1 = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR1, structHash1));
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(privateKeys[actor.tim_push_holder], digest1);
        vm.expectEmit(true, true, false, false);
        emit Unsubscribe(actor.bob_channel_owner, address(verifierContract));
        commProxy.unsubscribeBySig(
            actor.bob_channel_owner,
            address(verifierContract),
            commProxy.nonces(address(verifierContract)),
            block.timestamp + 100,
            v1,
            r1,
            s1
        );
    }
}
