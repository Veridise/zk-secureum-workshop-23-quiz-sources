//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./MembershipVerifier/verifier.sol";
import "../interfaces/IMembershipVerifier.sol";

contract MembershipVerifier is IMembershipVerifier, Verifier {
    function verifyProof(
        uint256 nonce, 
        uint256 root, 
        uint256 leafData,
        address receiver,
        uint256 nullifierHash,
        uint256 commitment,
        uint256[8] calldata proof
    ) external view override {
        uint256[6] memory publicSignals;
        publicSignals[0] = nullifierHash;
        publicSignals[1] = commitment;
        publicSignals[2] = nonce;
        publicSignals[3] = root;
        publicSignals[4] = leafData;
        publicSignals[5] = uint256(uint160(receiver));

        uint256[2] memory a = [proof[0], proof[1]];
        uint256[2][2] memory b = [[proof[2], proof[3]], [proof[4], proof[5]]];
        uint256[2] memory c = [proof[6], proof[7]];

        require(verifyProof(a, b, c, publicSignals));
    }
}
