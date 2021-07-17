package issues;

import tink.state.*;

using tink.CoreApi;

@:asserts
class Issue63 {
  public function new() {}

  public function test() {
    var value = 1;
    final changed = Signal.trigger();
    final signalObservable = new Observable(() -> value, changed);
    final derivedObservable = Observable.auto(() -> signalObservable.value);

    function change(newValue) {
      value = newValue;
      changed.trigger(Noise);
    }

    var observed = -1;

    function observe() {
      return derivedObservable.bind(v -> observed = v, Scheduler.direct);
    }

    final link = observe();
    asserts.assert(observed == 1);

    change(2);
    asserts.assert(observed == 2);

    link.cancel();
    observe();
    asserts.assert(observed == 2);

    change(3);
    asserts.assert(observed == 3);
    asserts.assert(derivedObservable.value == 3);

    return asserts.done();
  }
}
