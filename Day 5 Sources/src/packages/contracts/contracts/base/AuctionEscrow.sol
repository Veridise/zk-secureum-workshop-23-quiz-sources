//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./IncrementalBinaryTree.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IMembershipVerifier.sol";

import {PoseidonT3} from "poseidon-solidity/PoseidonT3.sol";

abstract contract AuctionEscrow {
    using IncrementalBinaryTree for IncrementalTreeData;

    mapping(uint256 => bool) usedNullifiers;
    mapping(uint256 => uint256) commitmentInd;
    IncrementalTreeData internal escrowTree;
    IERC20 token;
    IMembershipVerifier membershipVerifier;

    event Deposit(uint256 commitment, uint256 curBal, uint256 amount, uint256 index);
    event Withdraw(uint256 commitment, uint256 curBal, uint256 amount, uint256 index);

    constructor(address _token, address _membershipVerifier) {
        token = IERC20(_token);
        escrowTree.init(20, 0);
        membershipVerifier = IMembershipVerifier(_membershipVerifier);
    }

    function _balanceHash(uint256 commitment, uint256 amount) internal pure returns (uint256) {
        return PoseidonT3.hash([commitment, amount]);
    }

    function deposit(uint256 commitment, uint256 amount) public {
        require(commitmentInd[commitment] == 0);
        commitmentInd[commitment] = escrowTree.numberOfLeaves;
        uint256 bal = _balanceHash(commitment, amount);
        escrowTree.insert(bal);
        require(token.transferFrom(msg.sender, address(this), amount));
        emit Deposit(commitment, 0, amount, commitmentInd[commitment]);
    }

    function deposit(uint256 commitment, uint256 curBal, uint256 amount, uint256[] calldata escrowSiblings) external {
        if(commitmentInd[commitment] == 0) {
            deposit(commitment, amount);
            return;
        }
        
        _depositToExisting(commitment, curBal, amount, escrowSiblings);
        require(token.transferFrom(msg.sender, address(this), amount));
        emit Deposit(commitment, curBal, amount, commitmentInd[commitment]);
    }

    function withdraw(uint256 nonce, uint256 curBal, uint256 amount, address receiver, uint256 commitment, uint256 nullifier, uint256[] calldata escrowSiblings, uint256[8] calldata proof) external {
        require(commitmentInd[commitment] != 0);
        require(!usedNullifiers[nullifier]);
        usedNullifiers[nullifier] = true;

        membershipVerifier.verifyProof(nonce, escrowTree.root, curBal, receiver, nullifier, commitment, proof);

        uint256 oldLeaf = _balanceHash(commitment, curBal);
        uint256 newLeaf = _balanceHash(commitment, curBal - amount);
        escrowTree.update(oldLeaf, newLeaf, escrowSiblings, commitmentInd[commitment]);
        require(token.transfer(receiver, amount));
        emit Withdraw(commitment, curBal, amount, commitmentInd[commitment]);
    }

    function _depositToExisting(uint256 commitment, uint256 curBal, uint256 amount, uint256[] calldata escrowSiblings) internal {
        uint256 ind = commitmentInd[commitment];
        uint256 prevBal = _balanceHash(commitment, curBal);
        uint256 bal = _balanceHash(commitment, curBal + amount);
        escrowTree.update(prevBal, bal, escrowSiblings, ind);
    }

    function _setBal(uint256 ind, uint256 oldBal, uint256 newBal, uint256[] calldata proofSiblings) internal {
        escrowTree.update(oldBal, newBal, proofSiblings, ind);
    }
}