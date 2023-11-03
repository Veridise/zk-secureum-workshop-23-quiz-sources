//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IBidVerifier {
    /// @dev Verifies whether a bid proof is valid.
    function verifyProof(
        uint256 nonce, 
        uint256[20] calldata auctionRoots, 
        uint256 balanceRoot, 
        uint256 balIndex,
        uint256 nullifierHash,
        uint256 bidAmount,
        uint256 newBalance,
        uint256[8] calldata proof
    ) external view;
}
