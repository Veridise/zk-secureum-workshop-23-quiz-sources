//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../base/IncrementalBinaryTree.sol";

/// @title Semaphore contract interface.
interface IAuction {
    error CallerIsNotAuctionAdmin();
    error SameNillifierUsedTwice();

    /// It defines all the group parameters, in addition to those in the Merkle tree.
    struct AuctionState {
        address admin;
        uint256 auctionStart;
        uint256 auctionDuration;
        uint256 tokenId;
        mapping(uint256 => bool) nullifierHashes;
        IncrementalTreeData bids;
        uint256 winningLeaf;
        uint256 winningAmt;
        address winner;
    }

    event AuctionCreated(uint256 indexed auctionId, uint256 indexed tokenId, address admin, uint256 duration);
    event AuctionAdminUpdated(uint256 indexed auctionId, address indexed oldAdmin, address indexed newAdmin);
    event AuctionDurationUpdated(uint256 indexed auctionId, uint256 oldDuration, uint256 newDuration);
    event Bid(uint256 indexed auctionId, uint256 nullifier, uint256 bidInd, uint256 bidLeaf);
    event Reveal(uint256 indexed auctionId, uint256 nullifier, uint256 commitment, uint256 bid);
    event Refund(uint256 indexed auctionId, uint256 commitment, uint256 bid);
    event Distribute(uint256 indexed auctionId, uint256 tokenId, address winner, uint256 winningBid);

    function bid(
        uint256 auctionId,
        uint256 nonce,
        uint256 commitment,
        uint256 nullifierHash,
        uint256 balLeaf,
        uint256 bidLeaf,
        uint256 newBalLeaf,
        uint256[] calldata balSiblings,
        uint256[20] calldata history,
        uint256[8] calldata proof
    ) external;

    /// @dev Creates a new group. Only the admin will be able to add or remove members.
    /// @param auctionId: Id of the group.
    /// @param admin: Admin of the group.
    function createAuction(
        uint256 auctionId,
        address admin,
        uint256 duration,
        uint256 tokenId
    ) external;

    /// @dev Updates the group admin.
    /// @param groupId: Id of the group.
    /// @param newAdmin: New admin of the group.
    function updateAuctionAdmin(uint256 groupId, address newAdmin) external;

    /// @dev Adds a new member to an existing group.
    /// @param groupId: Id of the group.
    /// @param identityCommitment: New identity commitment.
    function addMember(uint256 groupId, uint256 identityCommitment) external;

    /// @dev Adds new members to an existing group.
    /// @param groupId: Id of the group.
    /// @param identityCommitments: New identity commitments.
    function addMembers(uint256 groupId, uint256[] calldata identityCommitments) external;

    /// @dev Updates an identity commitment of an existing group. A proof of membership is
    /// needed to check if the node to be updated is part of the tree.
    /// @param groupId: Id of the group.
    /// @param identityCommitment: Existing identity commitment to be updated.
    /// @param newIdentityCommitment: New identity commitment.
    /// @param proofSiblings: Array of the sibling nodes of the proof of membership.
    /// @param index: Path of the proof of membership.
    function updateMember(
        uint256 groupId,
        uint256 identityCommitment,
        uint256 newIdentityCommitment,
        uint256[] calldata proofSiblings,
        uint256 index
    ) external;

    /// @dev Removes a member from an existing group. A proof of membership is
    /// needed to check if the node to be removed is part of the tree.
    /// @param groupId: Id of the group.
    /// @param identityCommitment: Identity commitment to be removed.
    /// @param proofSiblings: Array of the sibling nodes of the proof of membership.
    /// @param index: Path of the proof of membership.
    function removeMember(
        uint256 groupId,
        uint256 identityCommitment,
        uint256[] calldata proofSiblings,
        uint256 index
    ) external;
}
