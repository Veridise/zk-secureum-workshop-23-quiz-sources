//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

/// @title AuctionAdmin contract interface.
interface IAuctionAdmin {
    struct TreeHistory {
        uint256[20] historicRoots;
        uint256 front;
    }

    error AuctionDoesNotExist();
    error AuctionAlreadyExists();

    /// @dev Emitted when a new group is created.
    /// @param auctionId: Id of the group.
    event AuctionInitialized(uint256 indexed auctionId);

    /// @dev Emitted when a new identity commitment is added.
    /// @param auctionId: Group id of the group.
    /// @param index: Identity commitment index.
    /// @param identityCommitment: New identity commitment.
    /// @param merkleTreeRoot: New root hash of the tree.
    event MemberAdded(uint256 indexed auctionId, uint256 index, uint256 identityCommitment, uint256 merkleTreeRoot);

    /// @dev Emitted when an identity commitment is updated.
    /// @param auctionId: Group id of the group.
    /// @param index: Identity commitment index.
    /// @param identityCommitment: Existing identity commitment to be updated.
    /// @param newIdentityCommitment: New identity commitment.
    /// @param merkleTreeRoot: New root hash of the tree.
    event MemberUpdated(
        uint256 indexed auctionId,
        uint256 index,
        uint256 identityCommitment,
        uint256 newIdentityCommitment,
        uint256 merkleTreeRoot
    );

    /// @dev Emitted when a new identity commitment is removed.
    /// @param auctionId: Group id of the group.
    /// @param index: Identity commitment index.
    /// @param identityCommitment: Existing identity commitment to be removed.
    /// @param merkleTreeRoot: New root hash of the tree.
    event MemberRemoved(uint256 indexed auctionId, uint256 index, uint256 identityCommitment, uint256 merkleTreeRoot);

    /// @dev Returns the last root hash of a group.
    /// @param auctionId: Id of the group.
    /// @return Root hash of the group.
    function getMerkleTreeRoot(uint256 auctionId) external view returns (uint256);

    /// @dev Returns the depth of the tree of a group.
    /// @param auctionId: Id of the group.
    /// @return Depth of the group tree.
    function getMerkleTreeDepth(uint256 auctionId) external view returns (uint256);

    /// @dev Returns the number of tree leaves of a group.
    /// @param auctionId: Id of the group.
    /// @return Number of tree leaves.
    function getNumberOfMerkleTreeLeaves(uint256 auctionId) external view returns (uint256);

    function getMerkleTreeHistory(uint256 auctionId) external view returns (uint256[20] memory);
}
