pragma solidity ^0.8.20;
pragma experimental ABIEncoderV2;

import {BasePushStaking} from "../BasePushStaking.t.sol";

contract BaseWalletSharesStaking is BasePushStaking {
    function setUp() public virtual override {
        BasePushStaking.setUp();
    }

    /**
     * @notice Modifier that validates share invariants before and after the execution of the wrapped function.
     * @dev Ensures that the total wallet shares remain consistent and checks the sum of individual wallet shares.
     */
    modifier validateShareInvariants() {
        uint256 walletSharesBeforeExecution = pushStaking.WALLET_TOTAL_SHARES();
        _;
        _validateWalletSharesSum();
        _validateEpochShares();
    }

    // VALIDATION FUNCTIONS

    /**
     * @notice Validates that the total wallet shares are equal to the sum of individual wallet shares.
     * @dev Ensures that the sum of shares for the foundation and other actors is consistent with the total wallet shares.
     */
    function _validateWalletSharesSum() internal {
        uint256 walletTotalShares = pushStaking.WALLET_TOTAL_SHARES();
        (uint256 foundationWalletShares, , ) = pushStaking.walletShareInfo(
            actor.admin
        );
        (uint256 bobWalletShares, , ) = pushStaking.walletShareInfo(
            actor.bob_channel_owner
        );
        (uint256 aliceWalletShares, , ) = pushStaking.walletShareInfo(
            actor.alice_channel_owner
        );
        (uint256 charlieWalletShares, , ) = pushStaking.walletShareInfo(
            actor.charlie_channel_owner
        );
        (uint256 tonyWalletShares, , ) = pushStaking.walletShareInfo(
            actor.tony_channel_owner
        );

        uint256 totalSharesSum = foundationWalletShares +
            bobWalletShares +
            aliceWalletShares +
            charlieWalletShares +
            tonyWalletShares;
        assertEq(walletTotalShares, totalSharesSum,"wallet Share Sum");
    }

    /**
     * @notice Verifies that epochToTotalShares in any epoch remain less than equal to total
     */
    function _validateEpochShares() internal {
        uint256 walletTotalShares = pushStaking.WALLET_TOTAL_SHARES();
        for (uint256 i=genesisEpoch; i<=getCurrentEpoch(); ) {
            assertLe(pushStaking.epochToTotalShares(i), walletTotalShares, "Epoch Shares");
            unchecked {
                i++;
            }
        }
    }
}
