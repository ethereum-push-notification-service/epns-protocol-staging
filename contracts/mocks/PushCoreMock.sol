pragma solidity ^0.8.20;

/**
 * @title  PushCore v2.5
 * @author Push Protocol
 * @notice Push Core is the main protocol that deals with the imperative
 *         features and functionalities like Channel Creation, pushChannelAdmin etc.
 *
 * @dev This protocol will be specifically deployed on Ethereum Blockchain while the Communicator
 *      protocols can be deployed on Multiple Chains.
 *      The Push Core is more inclined towards the storing and handling the Channel related functionalties.
 *
 */
import { CoreTypes } from "../libraries/DataTypes.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    PausableUpgradeable, Initializable
} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import { PushCoreV3 } from "./../PushCore/PushCoreV3.sol";

contract PushCoreMock is PushCoreV3 {
    using SafeERC20 for IERC20;

    event AddChannel(address indexed channel, CoreTypes.ChannelType indexed channelType, bytes identity);

    /* ***************
        INITIALIZER
    *************** */

    function initialize(
        address _pushChannelAdmin,
        address _pushTokenAddress,
        address _wethAddress,
        address _uniswapRouterAddress,
        address _lendingPoolProviderAddress,
        address _daiAddress,
        address _aDaiAddress,
        uint256 _referralCode
    )
        public
        initializer
        returns (bool success)
    {
        // setup addresses
        pushChannelAdmin = _pushChannelAdmin;
        governance = _pushChannelAdmin; // Will be changed on-Chain governance Address later
        // daiAddress = _daiAddress;
        aDaiAddress = _aDaiAddress;
        WETH_ADDRESS = _wethAddress;
        REFERRAL_CODE = _referralCode;
        PUSH_TOKEN_ADDRESS = _pushTokenAddress;
        UNISWAP_V2_ROUTER = _uniswapRouterAddress;
        lendingPoolProviderAddress = _lendingPoolProviderAddress;

        FEE_AMOUNT = 10 ether; // PUSH Amount that will be charged as Protocol Pool Fees
        MIN_POOL_CONTRIBUTION = 50 ether; // Channel's poolContribution should never go below MIN_POOL_CONTRIBUTION
        ADD_CHANNEL_MIN_FEES = 50 ether; // can never be below MIN_POOL_CONTRIBUTION

        ADJUST_FOR_FLOAT = 10 ** 7;
        // groupLastUpdate = block.number;
        // groupNormalizedWeight = ADJUST_FOR_FLOAT; // Always Starts with 1 * ADJUST FOR FLOAT

        // Create Channel
        success = true;
    }

    function setPushTokenAddress(address _pushAddress) external {
        PUSH_TOKEN_ADDRESS = _pushAddress;
    }

    // for testing channelUpdateCounter migration
    function oldUpdateChannelMeta(bytes calldata _newIdentity, uint256 _amount) external whenNotPaused {
        IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(msg.sender, address(this), _amount);
        _updateChannelMeta(msg.sender, _newIdentity, _amount);
    }

    function _updateChannelMeta(address _channel, bytes memory _newIdentity, uint256 _amount) internal {
        uint256 updateCounter = oldChannelUpdateCounter[_channel] + 1;
        oldChannelUpdateCounter[_channel] = updateCounter;
        channels[_channel].channelUpdateBlock = block.number;
    }
}
