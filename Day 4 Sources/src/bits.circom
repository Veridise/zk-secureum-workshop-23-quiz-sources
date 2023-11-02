pragma circom 2.0.7;

template Bits(n) {
    signal input in;
    signal output out[n];
    var lc = 0;
    var e2 = 1;
    for (var i = 0; i < n; i++) {
        out[i] <-- (in >> i) & 1;
        lc += out[i] * e2;
        e2 = e2 + e2;
    }
    in === lc;
}
component main = Bits(3);