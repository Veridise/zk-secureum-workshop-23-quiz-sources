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

// Also borrowed from circom lib: https://github.com/iden3/
//
// Sets signal out to 1 if in[0] < in[1] and to 0 otherwise
// Warning: It assumes that both signals of in
template LessThan(n) {
  assert(n <= 252);
  signal input in[2];
  signal output out;

  component n2b = Num2Bits(n+1);

  n2b.in <== in[0]+ (1<<n) - in[1];

  out <== 1-n2b.out[n];
}

// Sets signal out to 1 if in[0] < in[1] and to 0 otherwise.
template RangeCheck() {
  signal input in[2];
  signal output out;

  component n2b = Num2Bits(8);
  n2b.in <== in[1];

  component lt = LessThan(8);
  lt.in[0] <== in[0];
  lt.in[1] <== in[1];

  out <== lt.out;
}

component main = RangeCheck();
