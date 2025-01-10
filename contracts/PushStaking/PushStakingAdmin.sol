// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract PushStakingAdmin is ProxyAdmin {
    constructor() ProxyAdmin() { }
}
