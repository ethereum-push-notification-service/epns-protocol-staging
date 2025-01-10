pragma solidity ^0.8.20;

interface IPushCoreStaking {
    function sendFunds(address _user, uint256 _amount) external;

    function HOLDER_FEE_POOL() external view returns (uint256);
    function WALLET_FEE_POOL() external view returns (uint256);
}