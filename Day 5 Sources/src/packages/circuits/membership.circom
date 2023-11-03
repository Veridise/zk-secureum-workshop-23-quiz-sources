pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/poseidon.circom";
include "./tree.circom";
include "./set.circom";
include "./identity.circom";

template CalculateLeaf() {
    signal input commitment;
    signal input leafData;

    signal output out;

    component leafHash = Poseidon(2);
    leafHash.inputs[0] <== commitment;
    leafHash.inputs[1] <== leafData;

    out <== leafHash.out;
}

template MembershipCheck(nLevels, historySize) {
    signal input commitment;
    signal input index;
    signal input treeSiblings[nLevels];
    signal input leafData;
    signal input roots[historySize];

    component leafCalc = CalculateLeaf();
    leafCalc.commitment <== commitment;
    leafCalc.leafData <== leafData;

    component inclusionProof = MerkleTreeInclusionProof(nLevels);
    inclusionProof.leaf <== leafCalc.out;
    inclusionProof.index <== index;

    for (var i = 0; i < nLevels; i++) {
        inclusionProof.siblings[i] <== treeSiblings[i];
    }

    signal root <== inclusionProof.root;

    component historyInclusion = SetMembership(historySize);
    historyInclusion.element <== root;
    historyInclusion.set <== roots;
}

// The current Semaphore smart contracts require nLevels <= 32 and nLevels >= 16.
template Membership(nLevels, historySize) {
    signal input identityNullifier;
    signal input identityTrapdoor;
    signal input index;
    signal input treeSiblings[nLevels];

    signal input nonce;
    signal input roots[historySize];
    signal input leafData;
    signal input receiver;

    signal output nullifierHash;
    signal output identityCommitment;

    component commitment = CalculateCommitment();
    commitment.identityNullifier <== identityNullifier;
    commitment.identityTrapdoor <== identityTrapdoor;

    component check = MembershipCheck(nLevels, historySize);
    check.commitment <== commitment.out;
    check.index <== index;
    check.leafData <== leafData;

    for (var i = 0; i < nLevels; i++) {
        check.treeSiblings[i] <== treeSiblings[i];
    }

    for(var i = 0; i < historySize; i++) {
        check.roots[i] <== roots[i];
    }

    component calculateNullifierHash = CalculateNullifierHash();
    calculateNullifierHash.externalNullifier <== nonce;
    calculateNullifierHash.identityNullifier <== identityNullifier;

    nullifierHash <== calculateNullifierHash.out;
    identityCommitment <== commitment.out;
}
 

