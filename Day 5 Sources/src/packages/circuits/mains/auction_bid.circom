pragma circom 2.0.0;

include "../bid.circom";

component main {public [nonce, auctionRoots, balanceRoot, balanceIndex]} = Bid(20, 20);