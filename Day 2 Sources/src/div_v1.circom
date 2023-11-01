template div() {
    signal input x1;
    signal input x2;
    signal output o;  
    o <-- x1 / x2;  
    o * x2 === x1;
}

component main = div();