pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/poseidon.circom";

template Decider() {
    signal input in[2];
    signal input s;
    signal output out[2];

    out[0] <== (in[1] - in[0])*s + in[0];
    out[1] <== (in[0] - in[1])*s + in[1];
}

template MerkleTreeInclusionProof(nLevels) {
    signal input leaf;
    signal input index;
    signal input siblings[nLevels];

    signal output root;

    component hashers[nLevels];
    component deciders[nLevels];

    signal indices[nLevels];
    signal hashes[nLevels + 1];
    hashes[0] <== leaf;

    for (var i = 0; i < nLevels; i++) {
        hashers[i] = Poseidon(2);
        deciders[i] = Decider();

        indices[i] <-- (index & (1 << i) == 0) ? 0 : 1;
        indices[i] * (1 - indices[i]) === 0;

        deciders[i].in[0] <== hashes[i];
        deciders[i].in[1] <== siblings[i];
        deciders[i].s <== indices[i];

        hashers[i].inputs[0] <== deciders[i].out[0];
        hashers[i].inputs[1] <== deciders[i].out[1];

        hashes[i + 1] <== hashers[i].out;
    }

    root <== hashes[nLevels];
}
