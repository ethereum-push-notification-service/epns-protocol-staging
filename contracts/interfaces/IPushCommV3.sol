pragma solidity ^0.8.20;

interface IPushCommV3 {
    /* *****************************

       EVENTS

    ***************************** */
    /// @notice emits whenever a new delegate is added
    event AddDelegate(address channel, address delegate);
    /// @notice emits whenever any delegate is removed
    event RemoveDelegate(address channel, address delegate);
    /// @notice emits whenever an address subscribes to any channel
    event Subscribe(address indexed channel, address indexed user);
    /// @notice emits whenever an address unsubscribes from any channel
    event Unsubscribe(address indexed channel, address indexed user);
    /// @notice emits whenever public key is broadcasted internally
    event PublicKeyRegistered(address indexed owner, bytes publickey);
    /// @notice emits whenever a notification is sent
    /// @param channel notification sender
    /// @param recipient notification receiver(interpreted in the backend)
    /// @param identity metadata of the notification
    event SendNotification(address indexed channel, address indexed recipient, bytes identity);
    /// @notice emits whenever a user opts for notification settings
    event UserNotifcationSettingsAdded(address _channel, address _user, uint256 _notifID, string _notifSettings);
    /// @notice emits whenever alias is added for any channel
    event ChannelAlias(
        string _chainName,
        uint256 indexed _chainID,
        address indexed _channelOwnerAddress,
        string _ethereumChannelAddress
    );

    event RemoveChannelAlias(
        string _chainName, uint256 indexed _chainID, address indexed _channelOwnerAddress, string _baseChannelAddress
    );
        ///@notice emits whenever a Wallet or NFT is linked OR unlinked to a PGP hash
    event UserPGPRegistered(string indexed PgpHash, address indexed wallet, string chainName, uint256 chainID);
    event UserPGPRegistered(
        string indexed PgpHash, address indexed nft, uint256 nftId, string chainName, uint256 chainID
    );

    event UserPGPRemoved(string indexed PgpHash, address indexed wallet, string chainName, uint256 chainID);
    event UserPGPRemoved(string indexed PgpHash, address indexed nft, uint256 nftId, string chainName, uint256 chainID);

    /* *****************************

        READ-ONLY FUNCTIONS  

    ***************************** */

    /// @notice Helper function to check if User is Subscribed to a Specific Address
    /// @param _channel address of the channel that the user is subscribing to
    /// @param _user address of the Subscriber
    /// @return True if User is actually a subscriber of a Channel
    function isUserSubscribed(address _channel, address _user) external view returns (bool);

    /* *****************************

        STATE-CHANGING FUNCTIONS  

    ***************************** */

    function verifyChannelAlias(string memory _channelAddress) external;

    /// @notice External Subscribe Function that allows users to Diretly interact with the Base Subscribe function
    ///  @dev   Subscribes the caller of the function to a particular Channel
    ///         - Takes into Consideration the "msg.sender"
    ///  @param _channel address of the channel that the user is subscribing to
    function subscribe(address _channel) external;

    /// @notice Allows users to subscribe a List of Channels at once
    /// @param _channelList array of addresses of the channels that the user wishes to Subscribe
    function batchSubscribe(address[] calldata _channelList) external;

    /// @notice Subscribe Function through Meta TX
    /// @dev Takes into Consideration the Sign of the User
    /// Inludes EIP1271 implementation: Standard Signature Validation Method for Contracts
    function subscribeBySig(
        address channel,
        address subscriber,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external;

    /// @notice Allows PushCore contract to call the Base Subscribe function whenever a User Creates his/her own
    /// Channel.
    ///         This ensures that the Channel Owner is subscribed to imperative Push Channels as well as his/her own
    /// Channel.
    /// @dev    Only Callable by the PushCore. This is to ensure that Users should only able to Subscribe for their own
    /// addresses.
    ///         The caller of the main Subscribe function should Either Be the USERS themselves(for their own addresses)
    /// or the PushCore contract
    /// @param _channel address of the channel that the user is subscribing to
    /// @param _user address of the Subscriber of a Channel

    function subscribeViaCore(address _channel, address _user) external;

    /// @notice Allows PushCore contract to call the Base UnSubscribe function whenever a User Destroys his/her
    /// TimeBound Channel.
    ///         This ensures that the Channel Owner is unSubscribed from the imperative Push Channels as well as his/her
    /// own Channel.
    ///        NOTE-If they don't unsubscribe before destroying their Channel, they won't be able to create the Channel
    /// again using the same Wallet Address.
    /// @dev    Only Callable by the PushCore.
    /// @param _channel address of the channel being unsubscribed
    /// @param _user address of the UnSubscriber of a Channel

    function unSubscribeViaCore(address _channel, address _user) external;

    /// @notice External Unsubcribe Function that allows users to directly unsubscribe from a particular channel
    /// @dev UnSubscribes the caller of the function from the particular Channel.
    ///    Takes into Consideration the "msg.sender"
    /// @param _channel address of the channel that the user is unsubscribing to

    function unsubscribe(address _channel) external;

    /// @notice Allows users to unsubscribe from a List of Channels at once
    /// @param _channelList array of addresses of the channels that the user wishes to Unsubscribe

    function batchUnsubscribe(address[] calldata _channelList) external;

    /// @notice Unsubscribe Function through Meta TX
    /// @dev Takes into Consideration the Signer of the transactioner
    ///      Inludes EIP1271 implementation: Standard Signature Validation Method for Contracts

    function unsubscribeBySig(
        address channel,
        address subscriber,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external;

    /// @notice Allows a Channel Owner to ADD a Delegate for sending Notifications
    ///         Delegate shall be able to send Notification on the Channel's Behalf
    /// @dev    This function will be only be callable by the Channel Owner from the PushCore contract.
    /// NOTE:   Verification of whether or not a Channel Address is actually the owner of the Channel, will be done via
    /// the PUSH NODES.
    ///@param _delegate address of the delegate who is allowed to Send Notifications

    function addDelegate(address _delegate) external;

    /// @notice Allows a Channel Owner to Remove a Delegate's Permission to Send Notification
    /// @dev    This function will be only be callable by the Channel Owner from the PushCore contract.
    /// NOTE:   Verification of whether or not a Channel Address is actually the owner of the Channel, will be done via
    /// the PUSH NODES.
    /// @param _delegate address of the delegate who is allowed to Send Notifications

    function removeDelegate(address _delegate) external;

    /// @notice Allows a Channel Owners, Delegates as well as Users to send Notifications
    /// @dev Emits out notification details once all the requirements are passed.
    /// @param _channel address of the Channel
    /// @param _recipient address of the reciever of the Notification
    /// @param _identity Info about the Notification

    function sendNotification(address _channel, address _recipient, bytes memory _identity) external returns (bool);

    /// @notice Meta transaction function for Sending Notifications
    /// @dev   Allows the Caller to Simply Sign the transaction to initiate the Send Notif Function
    ///        Inludes EIP1271 implementation: Standard Signature Validation Method for Contracts
    /// @return bool returns whether or not send notification credentials was successful.

    function sendNotifBySig(
        address _channel,
        address _recipient,
        address _signer,
        bytes calldata _identity,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
        returns (bool);

    /// @notice  Allows Users to Create and Subscribe to a Specific Notication Setting for a Channel.
    /// @dev     Updates the userToChannelNotifs mapping to keep track of a User's Notification Settings for a Specific
    /// Channel
    ///          Deliminated Notification Settings string contains -> Decimal Representation Notif Settings +
    ///          Notification Settings
    ///          For instance, for a Notif Setting that looks like -> 3+1-0+2-0+3-1+4-98
    ///              3 -> Decimal Representation of the Notification Options selected by the User
    ///
    ///          For Boolean Type Notif Options
    ///          1-0 -> 1 stands for Option 1 - 0 Means the user didn't choose that Notif Option.
    ///          3-1 stands for Option 3      - 1 Means the User Selected the 3rd boolean Option
    ///
    ///         For SLIDER TYPE Notif Options
    ///          2-0 -> 2 stands for Option 2 - 0 is user's Choice
    ///          4-98-> 4 stands for Option 4 - 98is user's Choice
    ///
    /// @param   _channel - Address of the Channel for which the user is creating the Notif settings
    /// @param   _notifID- Decimal Representation of the Options selected by the user
    /// @param   _notifSettings - Deliminated string that depicts the User's Notifcation Settings

    function changeUserChannelSettings(address _channel, uint256 _notifID, string calldata _notifSettings) external;
}
