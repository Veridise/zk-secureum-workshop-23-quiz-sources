pragma circom 2.1.0;

// Borrowed from circom lib: https://github.com/iden3/circomlib
// Performs the following:
//  - Sets array out to the bit representation of input signal `in`.
//  - Ensures that signal in fits in n bits.
//
// It can be used to perfom range checks for signals.
template Num2Bits(n) {
  signal input in;
  signal output out[n];
  var lc1=0;

  var e2=1;
  for (var i = 0; i<n; i++) {
    out[i] <-- (in >> i) & 1;
    out[i] * (out[i] -1 ) === 0;
    lc1 += out[i] * e2;
    e2 = e2+e2;
  }

  lc1 === in;
}

template IsOdd(n) {
  signal input in;
  signal output out;

  // Check that in fits in n bits
  component rc = Num2Bits(n);
  rc.in <== in;

  if (n == 1) {
    out <-- in;
  }
  else {
    out <-- in & 1;
    out * (out - 1) === 0;
  }
}
