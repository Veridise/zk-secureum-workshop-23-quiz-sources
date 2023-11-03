// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./interfaces/IAuction.sol";
import "./interfaces/IBidVerifier.sol";
import "./base/AuctionAdmin.sol";
import "./base/AuctionEscrow.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract Auction is IAuction, AuctionAdmin, AuctionEscrow, IERC721Receiver {
    using IncrementalBinaryTree for IncrementalTreeData;
    IBidVerifier public bidVerifier;
    IERC721 nft;

    /// @dev Gets a group id and returns the group parameters.
    mapping(uint256 => AuctionState) internal auctions;

    /// @dev Checks if the group admin is the transaction sender.
    /// @param auctionId: Id of the group.
    modifier onlyAuctionAdmin(uint256 auctionId) {
        if (auctions[auctionId].admin != _msgSender()) {
            revert CallerIsNotAuctionAdmin();
        }
        _;
    }

    modifier duringBidding(uint256 auctionId) {
        require(block.timestamp >= auctions[auctionId].auctionStart);
        require(block.timestamp < auctions[auctionId].auctionStart + auctions[auctionId].auctionDuration);
        _;
    }

    modifier duringReveal(uint256 auctionId) {
        require(block.timestamp >= auctions[auctionId].auctionStart + auctions[auctionId].auctionDuration);
        require(block.timestamp < auctions[auctionId].auctionStart + auctions[auctionId].auctionDuration + 1 weeks);
        _;
    }

    modifier afterAuction(uint256 auctionId) {
        require(block.timestamp >= auctions[auctionId].auctionStart + auctions[auctionId].auctionDuration + 1 weeks);
        _;
    }

    /// @dev Initializes the Semaphore verifier used to verify the user's ZK proofs.
    /// @param _verifier: Semaphore verifier address.
    constructor(address _token, address _nft, address _membershipVerifier, IBidVerifier _verifier) AuctionEscrow(_token, _membershipVerifier) {
        bidVerifier = _verifier;
        nft = IERC721(_nft);
    }

    /// @dev See {ISemaphore-createGroup}.
    function createAuction(
        uint256 auctionId,
        address admin,
        uint256 duration,
        uint256 tokenId
    ) external override {
        _createAuction(auctionId);

        auctions[auctionId].admin = admin;
        auctions[auctionId].auctionStart = block.timestamp + 1 days;
        auctions[auctionId].auctionDuration = duration;
        auctions[auctionId].tokenId = tokenId;
        auctions[auctionId].bids.init(20, 0);

        nft.safeTransferFrom(msg.sender, address(this), tokenId);

        emit AuctionCreated(auctionId, tokenId, admin, duration);
    }

    function getStartTimestamp(uint256 auctionId) view external returns (uint256) {
        return auctions[auctionId].auctionStart;
    }

    function getRevealTimestamp(uint256 auctionId) view external returns (uint256) {
        return auctions[auctionId].auctionStart + auctions[auctionId].auctionDuration;
    }

    function getAuctionCompleteTimestamp(uint256 auctionId) view external returns (uint256) {
        return auctions[auctionId].auctionStart + auctions[auctionId].auctionDuration + 1 weeks;
    }

    /// @dev See {ISemaphore-updateGroupAdmin}.
    function updateAuctionAdmin(uint256 auctionId, address newAdmin) external override onlyAuctionAdmin(auctionId) {
        auctions[auctionId].admin = newAdmin;

        emit AuctionAdminUpdated(auctionId, _msgSender(), newAdmin);
    }

    /// @dev See {ISemaphore-addMember}.
    function addMember(uint256 auctionId, uint256 identityCommitment) external override onlyAuctionAdmin(auctionId) {
        _addMember(auctionId, identityCommitment);
    }

    /// @dev See {ISemaphore-addMembers}.
    function addMembers(uint256 auctionId, uint256[] calldata identityCommitments)
        external
        override
        onlyAuctionAdmin(auctionId)
    {
        for (uint256 i = 0; i < identityCommitments.length; ) {
            _addMember(auctionId, identityCommitments[i]);

            unchecked {
                ++i;
            }
        }
    }

    /// @dev See {ISemaphore-updateMember}.
    function updateMember(
        uint256 groupId,
        uint256 identityCommitment,
        uint256 newIdentityCommitment,
        uint256[] calldata proofSiblings,
        uint256 index
    ) external override onlyAuctionAdmin(groupId) {
        _updateMember(groupId, identityCommitment, newIdentityCommitment, proofSiblings, index);
    }

    /// @dev See {ISemaphore-removeMember}.
    function removeMember(
        uint256 groupId,
        uint256 identityCommitment,
        uint256[] calldata proofSiblings,
        uint256 index
    ) external override onlyAuctionAdmin(groupId) {
        _removeMember(groupId, identityCommitment, proofSiblings, index);
    }

    function bid(
        uint256 auctionId,
        uint256 nonce,
        uint256 balIndex,
        uint256 nullifierHash,
        uint256 balLeaf,
        uint256 bidLeaf,
        uint256 newBalLeaf,
        uint256[] calldata balSiblings,
        uint256[20] calldata history,
        uint256[8] calldata proof
    ) duringBidding(auctionId) external override {
        {
            uint256 merkleTreeDepth = getMerkleTreeDepth(auctionId);

            if (merkleTreeDepth == 0) {
                revert AuctionDoesNotExist();
            }

            if (auctions[auctionId].nullifierHashes[nullifierHash]) {
                revert SameNillifierUsedTwice(); 
            }

            auctions[auctionId].nullifierHashes[nullifierHash] = true;

            //in case this is using an older history, validate that it still has the current root
            bool hasRoot = false;
            for(uint i = 0; i < history.length; i++) {
                if(history[i] == getMerkleTreeRoot(auctionId)) {
                    hasRoot = true;
                }
            }

            require(hasRoot);
        }

        bidVerifier.verifyProof(nonce, history, escrowTree.root, balIndex, nullifierHash, bidLeaf, newBalLeaf, proof);
        
        _setBal(balIndex, balLeaf, newBalLeaf, balSiblings);

        uint256 ind = auctions[auctionId].bids.numberOfLeaves;
        auctions[auctionId].bids.insert(bidLeaf);
        emit Bid(auctionId, nullifierHash, ind, bidLeaf);
    }

    function reveal(uint256 auctionId, uint256 nonce, uint256 bidAmt, address receiver, uint256 commitment, uint256 nullifier, uint256[8] calldata proof) duringReveal(auctionId) external {
        require(bidAmt > auctions[auctionId].winningAmt);
        if (auctions[auctionId].nullifierHashes[nullifier]) {
            revert SameNillifierUsedTwice(); 
        }
        auctions[auctionId].nullifierHashes[nullifier] = true;

        membershipVerifier.verifyProof(nonce, auctions[auctionId].bids.root, bidAmt, receiver, nullifier, commitment, proof);

        auctions[auctionId].winningLeaf = _balanceHash(commitment, bidAmt);
        auctions[auctionId].winner = receiver;
        auctions[auctionId].winningAmt = bidAmt;
        emit Reveal(auctionId, nullifier, commitment, bidAmt);
    }

    function refund(uint256 auctionId, uint256 amount, uint256 commitment, uint256 bidIndex, uint256[] calldata bidSiblings, uint256 escrowBal, uint256[] calldata escrowSiblings) afterAuction(auctionId) external {
        uint256 leaf = _balanceHash(commitment, amount);
        uint256 zeroBalLeaf = _balanceHash(commitment, 0);
        require(leaf != auctions[auctionId].winningLeaf);

        auctions[auctionId].bids.update(leaf, zeroBalLeaf, bidSiblings, bidIndex);
        _depositToExisting(commitment, escrowBal, amount, escrowSiblings);
        emit Refund(auctionId, commitment, amount);
    }

    function distribute(uint256 auctionId) afterAuction(auctionId) afterAuction(auctionId) external {
        nft.safeTransferFrom(address(this), auctions[auctionId].winner, auctions[auctionId].tokenId);
        uint256 amt = auctions[auctionId].winningAmt;
        auctions[auctionId].winningAmt = 0;
        require(token.transfer(auctions[auctionId].admin, amt));
        emit Distribute(auctionId, auctions[auctionId].tokenId, auctions[auctionId].winner, amt);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
