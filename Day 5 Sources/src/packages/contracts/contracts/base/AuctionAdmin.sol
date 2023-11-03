//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../interfaces/IAuctionAdmin.sol";
import "./IncrementalBinaryTree.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import {PoseidonT3} from "poseidon-solidity/PoseidonT3.sol";

/// @title Semaphore groups contract.
/// @dev This contract allows you to create groups, add, remove and update members.
/// You can use getters to obtain informations about groups (root, depth, number of leaves).
abstract contract AuctionAdmin is Context, IAuctionAdmin {
    using IncrementalBinaryTree for IncrementalTreeData;

    /// @dev Gets a group id and returns the tree data.
    mapping(uint256 => IncrementalTreeData) internal merkleTrees;
    mapping(uint256 => TreeHistory) internal histories;

    /// @dev Creates a new auction by initializing the associated tree.
    function _createAuction(uint256 auctionId) internal virtual {
        if (getMerkleTreeDepth(auctionId) != 0) {
            revert AuctionAlreadyExists();
        }

        merkleTrees[auctionId].init(20, 0);
        TreeHistory storage history = histories[auctionId];
        history.front = 0;
        history.historicRoots[0] = merkleTrees[auctionId].root;

        emit AuctionInitialized(auctionId);
    }

    /// @dev Adds an identity commitment to an existing group.
    /// @param auctionId: Id of the group.
    /// @param identityCommitment: New identity commitment.
    function _addMember(uint256 auctionId, uint256 identityCommitment) internal virtual {
        if (getMerkleTreeDepth(auctionId) == 0) {
            revert AuctionDoesNotExist();
        }

        uint256 leaf = PoseidonT3.hash([identityCommitment, auctionId]);
        merkleTrees[auctionId].insert(leaf);

        uint256 merkleTreeRoot = getMerkleTreeRoot(auctionId);
        uint256 index = getNumberOfMerkleTreeLeaves(auctionId) - 1;

        TreeHistory storage history = histories[auctionId];
        history.front = (history.front + 1) % 20;
        history.historicRoots[history.front] = merkleTreeRoot;

        emit MemberAdded(auctionId, index, identityCommitment, merkleTreeRoot);
    }

    /// @dev Updates an identity commitment of an existing group. A proof of membership is
    /// needed to check if the node to be updated is part of the tree.
    /// @param auctionId: Id of the auction.
    /// @param identityCommitment: Existing identity commitment to be updated.
    /// @param newIdentityCommitment: New identity commitment.
    /// @param proofSiblings: Array of the sibling nodes of the proof of membership.
    /// @param index: Path of the proof of membership.
    function _updateMember(
        uint256 auctionId,
        uint256 identityCommitment,
        uint256 newIdentityCommitment,
        uint256[] calldata proofSiblings,
        uint256 index
    ) internal virtual {
        if (getMerkleTreeDepth(auctionId) == 0) {
            revert AuctionDoesNotExist();
        }

        uint256 oldLeaf = PoseidonT3.hash([identityCommitment, auctionId]);
        uint256 newLeaf = PoseidonT3.hash([newIdentityCommitment, auctionId]);
        merkleTrees[auctionId].update(oldLeaf, newLeaf, proofSiblings, index);

        uint256 merkleTreeRoot = getMerkleTreeRoot(auctionId);

        TreeHistory storage history = histories[auctionId];
        history.front = (history.front + 1) % 20;
        history.historicRoots[history.front] = merkleTreeRoot;

        emit MemberUpdated(auctionId, index, identityCommitment, newIdentityCommitment, merkleTreeRoot);
    }

    /// @dev Removes an identity commitment from an existing group. A proof of membership is
    /// needed to check if the node to be deleted is part of the tree.
    /// @param auctionId: Id of the auction.
    /// @param identityCommitment: Existing identity commitment to be removed.
    /// @param proofSiblings: Array of the sibling nodes of the proof of membership.
    /// @param index: Path of the proof of membership.
    function _removeMember(
        uint256 auctionId,
        uint256 identityCommitment,
        uint256[] calldata proofSiblings,
        uint256 index
    ) internal virtual {
        if (getMerkleTreeDepth(auctionId) == 0) {
            revert AuctionDoesNotExist();
        }

        uint256 leaf = PoseidonT3.hash([identityCommitment, auctionId]);
        merkleTrees[auctionId].remove(leaf, proofSiblings, index);

        uint256 merkleTreeRoot = getMerkleTreeRoot(auctionId);

        TreeHistory storage history = histories[auctionId];
        history.front = (history.front + 1) % 20;
        history.historicRoots[history.front] = merkleTreeRoot;

        emit MemberRemoved(auctionId, index, identityCommitment, merkleTreeRoot);
    }

    /// @dev See {ISemaphoreGroups-getMerkleTreeRoot}.
    function getMerkleTreeRoot(uint256 auctionId) public view virtual override returns (uint256) {
        return merkleTrees[auctionId].root;
    }

    /// @dev See {ISemaphoreGroups-getMerkleTreeDepth}.
    function getMerkleTreeDepth(uint256 auctionId) public view virtual override returns (uint256) {
        return merkleTrees[auctionId].depth;
    }

    /// @dev See {ISemaphoreGroups-getNumberOfMerkleTreeLeaves}.
    function getNumberOfMerkleTreeLeaves(uint256 auctionId) public view virtual override returns (uint256) {
        return merkleTrees[auctionId].numberOfLeaves;
    }

    function getMerkleTreeHistory(uint256 auctionId) public view virtual override returns (uint256[20] memory) {
        return histories[auctionId].historicRoots;
    }
}
