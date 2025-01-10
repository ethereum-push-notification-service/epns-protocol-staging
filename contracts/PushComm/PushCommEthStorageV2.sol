pragma solidity ^0.8.20;

import { CommTypes } from "../libraries/DataTypes.sol";

contract PushCommEthStorageV2 {
    /**
     * MAPPINGS *
     */
    mapping(address => CommTypes.User) public users;
    mapping(address => uint256) public nonces;
    mapping(uint256 => address) public mapAddressUsers;
    mapping(address => mapping(address => string)) public userToChannelNotifs;
    mapping(address => mapping(address => bool)) public delegatedNotificationSenders;

    /**
     * STATE VARIABLES *
     */
    address public governance;
    address public pushChannelAdmin;
    uint256 public chainID; // Unused Variable
    uint256 public usersCount;
    bool public isMigrationComplete;
    address public PushCoreAddress;
    string public chainName;
    string public constant name = "Push COMM V1";
    bytes32 public constant NAME_HASH = keccak256(bytes(name));
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
    bytes32 public constant SUBSCRIBE_TYPEHASH =
        keccak256("Subscribe(address channel,address subscriber,uint256 nonce,uint256 expiry)");
    bytes32 public constant UNSUBSCRIBE_TYPEHASH =
        keccak256("Unsubscribe(address channel,address subscriber,uint256 nonce,uint256 expiry)");
    bytes32 public constant SEND_NOTIFICATION_TYPEHASH =
        keccak256("SendNotification(address channel,address recipient,bytes identity,uint256 nonce,uint256 expiry)");
    // New State Variables
    address public PUSH_TOKEN_ADDRESS;

    mapping(bytes32 => string) public walletToPGP;
    uint256 FEE_AMOUNT;
}
