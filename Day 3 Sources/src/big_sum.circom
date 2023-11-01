pragma circom 2.1.0;

include "./bigint.circom";

template BigSum(n_elem, n, k, p) {

  signal input ins[n_elem][k];
  signal output sum[k];

  component lts[n_elem];

  for (var i = 0; i < n_elem; i++) {
    lts[i] = BigLessThan(n, k);

    for (var j = 0; j < k; j++) {
      lts[i].a[j] <== ins[i][j];
      lts[i].b[j] <== p[j];
    }
  }

  component adds[n_elem];

  adds[0] = BigAddModP(n, k);
  for (var j = 0; j < k; j++) {
    adds[0].a[j] <== 0;
    adds[0].b[j] <== ins[0][j];
    adds[0].p[j] <== p[j];
  }

  for (var i = 1; i < n_elem; i++) {
    adds[i] = BigAddModP(n, k);

    for (var j = 0; j < k; j++) {
      adds[i].a[j] <== adds[i-1].out[j];
      adds[i].b[j] <== ins[i][j];
      adds[i].p[j] <== p[j];
    }
  }

  for (var j = 0; j < k; j++) {
    sum[j] <== adds[n_elem-1].out[j];
  }
}

component main = BigSum(3, 5, 2, [11, 0]);
