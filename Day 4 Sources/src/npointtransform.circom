pragma circom 2.0.7;


// input: n 2d points
// output: n 2d points
template nPointTransforms(n) {
    signal input in[n][2];
    signal output out[n][2];

    for (var i = 0; i < n; i++) {
        out[i][0] <-- (1 + in[i][1]) / (1 - in[i][1]);
        out[i][1] <-- out[i][0] / in[i][0];


        out[i][0] * (1-in[i][1]) === (1 + in[i][1]);
        out[i][1] * in[i][0] === out[i][0];
         
    }
}

component main {public [in]} = nPointTransforms(5);
