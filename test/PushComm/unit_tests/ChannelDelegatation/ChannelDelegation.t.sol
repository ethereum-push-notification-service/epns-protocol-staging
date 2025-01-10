// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import { BasePushCommTest } from "../BasePushCommTest.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";

contract ChannelDelegation_Test is BasePushCommTest {
    function setUp() public override {
        BasePushCommTest.setUp();
    }

    modifier whenChannelAddsDelegate(address caller) {
        changePrank(caller);
        commProxy.addDelegate(actor.dan_push_holder);
        _;
    }

    function test_WhenDelegateIsNotAdded() external whenChannelAddsDelegate(actor.bob_channel_owner) {
        // it should add the delagate
        bool isDanDelegate = commProxy.delegatedNotificationSenders(actor.bob_channel_owner, actor.dan_push_holder);

        assertEq(isDanDelegate, true);

    }

    function test_WhenDelegateIsAlreadyAdded() external whenChannelAddsDelegate(actor.bob_channel_owner) {
        // it should not change anything
        commProxy.addDelegate(actor.dan_push_holder);
        bool isDanDelegate = commProxy.delegatedNotificationSenders(actor.bob_channel_owner, actor.dan_push_holder);

        assertEq(isDanDelegate, true);
    }

    modifier whenChannelRemovesDelegate(address caller) {
        changePrank(caller);
        commProxy.removeDelegate(actor.dan_push_holder);
        _;
    }

    function test_WhenDelegateIsAdded() external whenChannelRemovesDelegate(actor.bob_channel_owner) {
        // it should remove the delagate
        bool isDanDelegate = commProxy.delegatedNotificationSenders(actor.bob_channel_owner, actor.dan_push_holder);

        assertEq(isDanDelegate, false);
    }

    function test_WhenDelegateIsAlreadyRemoved() external whenChannelRemovesDelegate(actor.bob_channel_owner) {
        // it should not change anything
        commProxy.removeDelegate(actor.dan_push_holder);

        bool isDanDelegate = commProxy.delegatedNotificationSenders(actor.bob_channel_owner, actor.dan_push_holder);

        assertEq(isDanDelegate, false);
    }

    function test_WhenAddingDelegate_ShouldBeSubscribedToChannel() external {
        changePrank(actor.bob_channel_owner);
        commProxy.addDelegate(actor.dan_push_holder);
        bool isTonyDelegate = commProxy.delegatedNotificationSenders(actor.bob_channel_owner, actor.dan_push_holder);

        assertEq(isTonyDelegate, true);

        //Check the delegate becomes a subscriber.
        bool isSub = commProxy.isUserSubscribed(actor.bob_channel_owner, actor.dan_push_holder);
        assertEq(isSub, true);
    }

    function test_WhenRemovingDelegate_Should_UnSubscribeChannel() external {
        changePrank(actor.bob_channel_owner);
        commProxy.addDelegate(actor.dan_push_holder);

        //Check the delegate becomes a subscriber.
        bool isSub = commProxy.isUserSubscribed(actor.bob_channel_owner, actor.dan_push_holder);
        assertEq(isSub, true);

        commProxy.removeDelegate(actor.dan_push_holder);

        bool isSubAfter = commProxy.isUserSubscribed(actor.bob_channel_owner, actor.dan_push_holder);
        assertEq(isSubAfter, false);

    }
}