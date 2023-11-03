pragma circom 2.0.0;


template SetMembership(length) {
  signal input element;
  signal input set[length];
  
  signal diffs[length];
  signal product[length + 1];
  product[0] <== element;

  for (var i = 0; i < length; i++) {
    diffs[i] <== set[i] - element;
    product[i + 1] <== product[i] * diffs[i];
  }

  product[length] === 0;
}