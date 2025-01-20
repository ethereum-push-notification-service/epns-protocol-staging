<h1 align="center">
    <a href="https://push.org/#gh-light-mode-only">
    <img width='20%' height='10%' src="https://res.cloudinary.com/drdjegqln/image/upload/v1686227557/Push-Logo-Standard-Dark_xap7z5.png">
    </a>
    <a href="https://push.org/#gh-dark-mode-only">
    <img width='20%' height='10%' src="https://res.cloudinary.com/drdjegqln/image/upload/v1686227558/Push-Logo-Standard-White_dlvapc.png">
    </a>
</h1>

<p align="center">
  <i align="center">Push Protocol is a web3 communication network, enabling cross-chain notifications, messaging, video, and NFT chat for dapps, wallets, and services.🚀</i>
</p>

<h4 align="center">

  <a href="https://discord.gg/pushprotocol">
    <img src="https://img.shields.io/badge/discord-7289da.svg?style=flat-square" alt="discord">
  </a>
  <a href="https://twitter.com/pushprotocol">
    <img src="https://img.shields.io/badge/twitter-18a1d6.svg?style=flat-square" alt="twitter">
  </a>
  <a href="https://www.youtube.com/@pushprotocol">
    <img src="https://img.shields.io/badge/youtube-d95652.svg?style=flat-square&" alt="youtube">
  </a>
</h4>

# Push Protocol Smart Contracts

Welcome to the repository for the smart contracts of the Push Protocol. This repository contains the core code that powers our decentralized communication network. The Push Protocol is a web3 communication protocol that enables cross-chain notifications and messaging for decentralized applications (dApps), wallets, and services.

Our smart contracts are the backbone of the Push Protocol, enabling the functionality that allows for on-chain and off-chain communication via user wallet addresses. This is done in an open, gasless, multichain, and platform-agnostic fashion.

In this repository, you will find the contracts that handle various aspects of the Push Protocol, from channel creation and verification to notification sending and subscription handling. We also provide a suite of tests to ensure the robustness and security of our contracts.

We invite you to explore, contribute, and help us build the future of web3 communication.



---

## 📚 Table of Contents
- [Smart Contract Address](#smart-contract-addresses)
- [Modules](#-modules)
- [Getting Started/Installation](#getting-started)
- [Resources](#resources)
- [Contributing](#contributing)


## Smart Contract Addresses 

Contract addresses for Ethereum Mainnet. 

| Contract Name | Contract Address |
| ------------- | ---------------- |
| Push Token | [0xf418588522d5dd018b425E472991E52EBBeEEEEE](https://etherscan.io/address/0xf418588522d5dd018b425E472991E52EBBeEEEEE) |
| EPNS CoreV1.5 | [0x66329Fdd4042928BfCAB60b179e1538D56eeeeeE](https://etherscan.io/address/0x66329Fdd4042928BfCAB60b179e1538D56eeeeeE) |
| EPNS CommV1.5 | [0xb3971BCef2D791bc4027BbfedFb47319A4AAaaAa](https://etherscan.io/address/0xb3971BCef2D791bc4027BbfedFb47319A4AAaaAa) |

Contract addresses for Ethereum Goerli Testnet.

| Contract Name | Contract Address |
| ------------- | ---------------- |
| Push Token | [0x2b9bE9259a4F5Ba6344c1b1c07911539642a2D33](https://goerli.etherscan.io/address/0x2b9bE9259a4F5Ba6344c1b1c07911539642a2D33) |
| EPNS CoreV1.5 | [0xd4E3ceC407cD36d9e3767cD189ccCaFBF549202C](https://goerli.etherscan.io/address/0xd4E3ceC407cD36d9e3767cD189ccCaFBF549202C) |
| EPNS CommV1.5 | [0xb3971BCef2D791bc4027BbfedFb47319A4AAaaAa](https://goerli.etherscan.io/address/0xb3971BCef2D791bc4027BbfedFb47319A4AAaaAa) |


Contract addresses for Ethereum Sepolia Testnet.

| Contract Name | Contract Address |
| ------------- | ---------------- |
| Push Token | [0x37c779a1564DCc0e3914aB130e0e787d93e21804](https://sepolia.etherscan.io/address/0x37c779a1564DCc0e3914aB130e0e787d93e21804) |
| EPNS CoreV1.5 | [0x9d65129223451fbd58fc299C635Cd919BaF2564C](https://sepolia.etherscan.io/address/0x9d65129223451fbd58fc299C635Cd919BaF2564C#code) |
| EPNS CommV1.5 | [0x0C34d54a09CFe75BCcd878A469206Ae77E0fe6e7](https://sepolia.etherscan.io/address/0x0c34d54a09cfe75bccd878a469206ae77e0fe6e7) |

You can find addresses for other networks over at our <a href="https://docs.push.org/developers/developer-tooling/push-smart-contracts/epns-contract-addresses">Docs</a>  

## 🧩 Modules

<details closed><summary>Epnscomm</summary>

| File                    | Summary                                                                                                                                                                                                                                                                                                                                                                                                                                                    | Module                                     |
|:------------------------|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:-------------------------------------------|
| EPNSCommV1.sol          | This code is the implementation of the EPNS Communicator protocol, which is a communication layer between end users and the EPNS Core Protocol. It allows users to subscribe to channels, unsubscribe from channels, and send notifications to specific recipients or all subscribers of a channel.|
|                         ||                                            |
| EPNSCommStorageV1_5.sol | This Solidity code defines a contract for storing and managing user data in the Ethereum Push Notification Service (EPNS) protocol. It includes a User struct for organizing data about users and several mappings that track user and channel subscriptions. The contract also includes state variables for governance, user count, and more.                                                                                                             | contracts/EPNSComm/EPNSCommStorageV1_5.sol |
| EPNSCommAdmin.sol       | This code snippet is a Solidity contract that extends the ProxyAdmin contract from the OpenZeppelin library. Its main functionality is to serve as a proxy administrator for a smart contract system, allowing the updating and upgrading of contracts in the system, while maintaining the same deployment address and keeping the contract functionalities intact. The SPDX-License-Identifier is also included, specifying the open-source MIT license. | contracts/EPNSComm/EPNSCommAdmin.sol       |
| EPNSCommProxy.sol       | The provided Solidity contract is an implementation of a transparent upgradeable proxy using the OpenZeppelin library. It takes in parameters for the contract's logic, governance address, push-channel admin address, and chain name as part of its constructor function. Upon initialization, the contract transparently proxies its functionality, allowing future upgrades and modifications without breaking functionality or requiring migrations.  | contracts/EPNSComm/EPNSCommProxy.sol       |
| EPNSCommV1_5.sol        | This code defines the storage contract for the EPNS Communicator protocol version 1.5. It includes the user struct and mappings to track user details, subscriptions, notification settings, and delegated notification senders. It also includes state variables for governance, push channel admin, chain ID, user count, migration status, EPNS Core address, chain name, and type hashes for various types of transactions. | contracts/EPNSComm/EPNSCommV1_5.sol        |
|                         ||                                            |

</details>

<details closed><summary>Epnscore</summary>

| File                    | Summary                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | Module                                     |
|:------------------------|:-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:-------------------------------------------|
| EPNSCoreV1.sol          | The code is a smart contract implementation called "EPNSCoreV1" for a decentralized notification protocol. It includes functionalities such as creating and managing channels, channel verification, depositing and withdrawing funds, and fair share ratio calculations for distributing rewards. | contracts/EPNSCore/EPNSCoreV1.sol          |
|                         ||                                            |
| EPNSCoreProxy.sol       | The code defines a contract EPNSCoreProxy that extends the TransparentUpgradeableProxy to enable transparent and secure upgrades. It uses the constructor to set various parameters, such as logic contract, governance address, WETH and DAI addresses, and initialization parameters by encoding values using abi.encodeWithSignature().                                                                                                                                                 | contracts/EPNSCore/EPNSCoreProxy.sol       |
| EPNSCoreStorageV2.sol   | The provided code defines a contract called EPNSCoreStorageV2 that has three state variables. It defines two types of byte32 hash constants and mappings for nonces, channel update counters and rewards claimed by addresses for channel creation. It specifies the Solidity compiler version to be used as greater than or equal to 0.6.0 and less than 0.7.0.                                                                                                                           | contracts/EPNSCore/EPNSCoreStorageV2.sol   |
| EPNSCoreAdmin.sol       | The code defines a contract called EPNSCoreAdmin that imports "ProxyAdmin" from the "@openzeppelin/contracts/proxy/" package. The contract defines no behavior of its own and essentially acts as a forwarding service that allows an admin to upgrade other contacts via a proxy. It is licensed under MIT.                                                                                                                                                                               | contracts/EPNSCore/EPNSCoreAdmin.sol       | 
| TempStorage.sol         | The provided code is for a Solidity smart contract called TempStorage, which serves as a temporary storage for channels whose poolContribution and weight have been updated. It uses a mapping data structure to keep track of updated channels and has two functions that allow users to check if a channel has been adjusted and to mark a channel as adjusted, respectively. The constructor function sets the Core_Address of the contract and requires that it be a non-zero address. | contracts/EPNSCore/TempStorage.sol         |
| EPNSCoreStorageV1_5.sol | This Solidity contract defines the storage layout for an Ethereum Push Notification Service (EPNS). It includes various enums, constants, mappings, and state variables to keep track of channels created by users, historical data, fair share ratios, fee calculations, and more.                                                                                                                                                                                                        | contracts/EPNSCore/EPNSCoreStorageV1_5.sol |

</details>


---

## Getting Started


### 🖥 Installation

1. Clone the push-smart-contracts repository:
```sh
git clone https://github.com/ethereum-push-notification-service/push-smart-contracts
```

2. Change to the project directory:
```sh
cd push-smart-contracts
```

3. Install the dependencies:
```sh
forge install
```

### 🧪 Build the project:
```sh
forge build 
```
### Testing with Foundry

#### Prerequisites
Ensure you have Foundry installed. If not, install it via:
```sh
curl -L https://foundry.paradigm.xyz | bash
foundryup

```
### Running Tests

1. Running all tests:
```sh
forge test
```

2. Run specific tests:
```sh
forge test --match-contract <ContractName>
forge test --match-test <TestFunctionName>
```

3. Enable detailed output:
```sh
forge test -vvvv
```

### Example Test File Structure
Tests should be placed in the test/ directory and follow this structure:
```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Your contract name} from "../src/YourContract.sol";

contract YourContractTest is Test {
    YourContract yourContract;

    function setUp() public {
        yourContract = new YourContract();
    }

    function testExample() public {
        assertEq(yourContract.someFunction(), expectedValue);
    }
}
```

### Makefile Integration

To streamline development, we recommend using a Makefile for common tasks:

```
.PHONY: install build test clean

install:
	@forge install

build:
	@forge build

test:
	@forge test -vvvv

clean:
	@rm -rf out cache
```

### Run commands like this:

```
make install  # Install dependencies
make build    # Build contracts
make test     # Run tests with verbose output
make clean    # Clean build artifacts
```


---

## Resources
- **[Website](https://push.org)** To checkout our Product.
- **[Docs](https://push.org/docs/)** For comprehensive documentation.
- **[Blog](https://medium.com/push-protocol)** To learn more about our partners, new launches, etc.
- **[Discord](https://discord.gg/pushprotocol)** for support and discussions with the community and the team.
- **[GitHub](https://github.com/push-protocol)** for source code, project board, issues, and pull requests.
- **[Twitter](https://twitter.com/pushprotocol)** for the latest updates on the product and published blogs.


## Contributing

Push Protocol is an open source Project. We firmly believe in a completely transparent development process and value any contributions. We would love to have you as a member of the community, whether you are assisting us in bug fixes, suggesting new features, enhancing our documentation, or simply spreading the word. 

- Bug Report: Please create a bug report if you encounter any errors or problems while utilising the Push Protocol.
- Feature Request: Please submit a feature request if you have an idea or discover a capability that would make development simpler and more reliable.
- Documentation Request: If you're reading the Push documentation and believe that we're missing something, please create a docs request.


Read how you can contribute <a href="https://github.com/ethereum-push-notification-service/push-smart-contracts/blob/master/contributing.md">HERE</a>

<br />
Not sure where to start? Join our discord and we will help you get started!

<a href="https://discord.gg/pushprotocol" title="Join Our Community"><img src="https://www.freepnglogos.com/uploads/discord-logo-png/playerunknown-battlegrounds-bgparty-15.png" width="200" alt="Discord" /></a>

## License
Check out our License <a href='https://github.com/ethereum-push-notification-service/push-smart-contracts/blob/master/license-v1'>HERE </a>



