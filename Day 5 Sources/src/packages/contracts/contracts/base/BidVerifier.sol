//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./BidVerifier/verifier.sol";
import "../interfaces/IBidVerifier.sol";

contract BidVerifier is IBidVerifier, Verifier {
    function verifyProof(
        uint256 nonce, 
        uint256[20] calldata auctionRoots, 
        uint256 balanceRoot, 
        uint256 balIndex,
        uint256 nullifierHash,
        uint256 bidAmount,
        uint256 newBalance,
        uint256[8] calldata proof
    ) external view override {
        uint256[26] memory publicSignals;
        publicSignals[0] = nullifierHash;
        publicSignals[1] = bidAmount;
        publicSignals[2] = newBalance;

        publicSignals[3] = nonce;
        for(uint i = 0; i < 20; i++) {
            publicSignals[i + 4] = auctionRoots[i];
        }
        publicSignals[24] = balanceRoot;
        publicSignals[25] = balIndex;

        uint256[2] memory a = [proof[0], proof[1]];
        uint256[2][2] memory b = [[proof[2], proof[3]], [proof[4], proof[5]]];
        uint256[2] memory c = [proof[6], proof[7]];

        require(verifyProof(a, b, c, publicSignals));
    }
}
