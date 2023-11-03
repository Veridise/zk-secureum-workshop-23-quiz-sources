//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IMembershipVerifier {
    /// @dev Verifies whether a Membership proof is valid.
    function verifyProof(
        uint256 nonce, 
        uint256 root, 
        uint256 leafData,
        address receiver,
        uint256 nullifierHash,
        uint256 commitment,
        uint256[8] calldata proof
    ) external view;
}
