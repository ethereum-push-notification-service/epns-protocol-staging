pragma solidity ^0.8.20;

interface IPUSH {
    function born() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function resetHolderWeight(address holder) external;
    function holderWeight(address) external view returns (uint256);
    function returnHolderUnits(address account, uint256 atBlock) external view returns (uint256);
    function setHolderDelegation(address delegate, bool value) external ;
    // ----------- Additional Functions for NTT Support ------------- //

    // NOTE: the `mint` method is not present in the standard ERC20 interface.
    /// @notice Mints `_amount` tokens to `_account`, only callable by the minter.
    /// @param account The address to receive the minted tokens.
    /// @param amount The amount of tokens to mint.
    function mint(address account, uint256 amount) external;

    // NOTE: the `setMinter` method is not present in the standard ERC20 interface.
    /// @notice Sets a new minter address, only callable by the contract owner.
    /// @param newMinter The address of the new minter.
    function setMinter(address newMinter) external;

    // NOTE: NttTokens in `burn` mode require the `burn` method to be present.
    //       This method is not present in the standard ERC20 interface, but is
    //       found in the `ERC20Burnable` interface.
    function burn(uint256 amount) external;
}
