// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
/**
 * @title  PushStakingProxy
 * @author Push Protocol
 * @notice Push Stakin will deal with the handling of staking initiatives by Push Protocol.
 *
 * @dev This protocol will be specifically deployed on Ethereum Blockchain and will be connected to Push Core
 *      contract in a way that the core contract handles all the funds and this contract handles the state 
 *      of stakers.
 * @Custom:security-contact https://immunefi.com/bug-bounty/pushprotocol/information/
 */
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract PushStakingProxy is TransparentUpgradeableProxy {
    constructor(
        address _logic,
        address _governance,
        address _pushChannelAdmin,
        address _core,
        address _pushTokenAddress
    )
        payable
        TransparentUpgradeableProxy(
            _logic,
            _governance,
            abi.encodeWithSignature(
                "initialize(address,address,address)",
                _pushChannelAdmin,
                _core,
                _pushTokenAddress
            )
        )
    { }
}
