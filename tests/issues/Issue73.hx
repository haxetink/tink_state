package issues;

import tink.state.internal.AutoObservable;
import tink.state.*;

@:asserts
class Issue73 {
  public function new() {}
  public function test() {

    var log = '';

    final s1 = new State(2, (active) -> log += (if (active) '+' else '-') + '1'),
          s2 = new State(3, (active) -> log += (if (active) '+' else '-') + '2');

    final sum = Observable.auto(() -> s1.value + s2.value),
          product = Observable.auto(() -> s1.value * s2.value);

    final a = new AutoObservable(() -> product.value - sum.value);

    (a:Observable<Int>).bind(() -> {});

    asserts.assert(log == '+1+2');
    asserts.assert(a.getValue() == 1);

    a.swapComputation(() -> product.value + sum.value);

    asserts.assert(log == '+1+2');
    asserts.assert(a.getValue() == 11);

    a.swapComputation(() -> product.value);

    asserts.assert(a.getValue() == 6);
    asserts.assert(log == '+1+2');

    a.swapComputation(() -> s1.value);

    asserts.assert(a.getValue() == 2);
    asserts.assert(log == '+1+2-2');

    return asserts.done();
  }
}