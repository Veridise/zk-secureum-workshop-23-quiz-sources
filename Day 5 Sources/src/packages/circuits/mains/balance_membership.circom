pragma circom 2.0.0;

include "../membership.circom";

component main {public [nonce, roots, leafData, receiver]} = Membership(20, 1);