pragma circom 2.1.0;

template FibCircuit(n) {
  signal output out;

  if (n == 0) {
    out <== 0;
  }
  else if (n == 1) {
    out <-- 0;
    out === 1;
  }
  else {

    var a = 0;
    var b = 1;
    var nFib;

    for (var i = 2; i <= n; i++) {
      nFib = a + b;
      a = b;
      b = nFib;
    }

    out <== nFib;
  }
}
