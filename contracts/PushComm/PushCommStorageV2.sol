pragma solidity ^0.8.20;

import { CommTypes } from "../libraries/DataTypes.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/wormhole/INttManager.sol";
import "../interfaces/wormhole/IWormholeTransceiver.sol";
import "../interfaces/wormhole/IWormholeRelayer.sol";

contract PushCommStorageV2 {
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
    uint256 public chainID; //Unused Variable
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
    IERC20 public PUSH_NTT;

    mapping(bytes32 => string) public walletToPGP;

    // WORMHOLE CROSS-CHAIN STATE VARIABLES
    INttManager public NTT_MANAGER;
    IWormholeTransceiver public WORMHOLE_TRANSCEIVER;
    IWormholeRelayer public WORMHOLE_RELAYER;

    uint16 public WORMHOLE_RECIPIENT_CHAIN; // Wormhole's Core contract recipient Chain ID

    uint256 public ADD_CHANNEL_MIN_FEES;
    uint256 public FEE_AMOUNT;
    uint256 public PROTOCOL_POOL_FEE;
    uint256 public MIN_POOL_CONTRIBUTION;
}
