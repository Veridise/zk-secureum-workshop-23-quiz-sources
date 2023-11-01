pragma circom 2.1.0;

include "./bigint.circom";

// Count non zeros.
template NonZeros(n_elem, k) {

  signal input ins[n_elem][k];
  signal is_zero_res[n_elem];
  signal output non_zeros;

  component is_zeros[n_elem];

  var acc = 0;
  for (var i = 0; i < n_elem; i++) {
    is_zeros[i] = BigIsZero(k);

    for (var j = 0; j < k; j++) {
      is_zeros[i].in[j] <== ins[i][j];
    }

    // Just to be safe.
    is_zeros[i].out * (is_zeros[i].out - 1) === 0;

    is_zero_res[i] <-- (is_zeros[i].out == 0) ? 1 : 0;
    is_zero_res[i] * (is_zero_res[i] - 1) === 0;
    acc += is_zero_res[i];
  }

  non_zeros <== acc;
}

component main = NonZeros(3, 2);
