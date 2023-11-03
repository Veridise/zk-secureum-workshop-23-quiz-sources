pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";
include "./tree.circom";
include "./set.circom";
include "./identity.circom";
include "./membership.circom";

// The current Semaphore smart contracts require nLevels <= 32 and nLevels >= 16.
template Bid(nLevels, historySize) {
    signal input identityNullifier;
    signal input identityTrapdoor;
    signal input auctionIndex;
    signal input auctionTreeSiblings[nLevels];
    signal input balanceTreeSiblings[nLevels];
    signal input auctionId;
    signal input balance;
    signal input bid;

    signal input nonce;
    signal input auctionRoots[historySize];
    signal input balanceRoot;
    signal input balanceIndex;

    signal output nullifierHash;
    signal output bidAmount;
    signal output newBalance;

    component commitment = CalculateCommitment();
    commitment.identityNullifier <== identityNullifier;
    commitment.identityTrapdoor <== identityTrapdoor;

    component auctionMember = MembershipCheck(nLevels, historySize);
    auctionMember.commitment <== commitment.out;
    auctionMember.index <== auctionIndex;
    auctionMember.leafData <== auctionId;
    
    for (var i = 0; i < nLevels; i++) {
        auctionMember.treeSiblings[i] <== auctionTreeSiblings[i];
    }

    for(var i = 0; i < historySize; i++) {
        auctionMember.roots[i] <== auctionRoots[i];
    }

    component balanceMember = MembershipCheck(nLevels, 1);
    balanceMember.commitment <== commitment.out;
    balanceMember.index <== balanceIndex;
    balanceMember.leafData <== balance;

    for (var i = 0; i < nLevels; i++) {
        balanceMember.treeSiblings[i] <== balanceTreeSiblings[i];
    }

    balanceMember.roots[0] <== balanceRoot;

    component balCheck = LessEqThan(252);
    balCheck.in[0] <== bid;
    balCheck.in[1] <== balance;

    component amountCalc = CalculateLeaf();
    amountCalc.commitment <== commitment.out;
    amountCalc.leafData <== bid;
    bidAmount <== amountCalc.out;

    component newBalCalc = CalculateLeaf();
    newBalCalc.commitment <== commitment.out;
    newBalCalc.leafData <== balance - bid;
    newBalance <== newBalCalc.out;

    component calculateNullifierHash = CalculateNullifierHash();
    calculateNullifierHash.externalNullifier <== nonce;
    calculateNullifierHash.identityNullifier <== identityNullifier;

    nullifierHash <== calculateNullifierHash.out;
}