package;

import tink.state.*;

using tink.CoreApi;

@:asserts
class TestSignalObservable {
  public function new() {}

  public function collectedWhileTheSignalLives() {
    #if nodejs
    final gc:Null<()->Void> =
      try {
        js.Lib.require('v8').setFlagsFromString('--expose-gc');
        js.Lib.require('vm').runInNewContext('gc');
      }
      catch (e:Dynamic) null;

    if (gc != null) {
      final changed = Signal.trigger();
      final kept = new Observable(() -> -1, changed);
      final refs = [];
      // node keeps the targets of WeakRefs alive until the task that created them ends
      haxe.Timer.delay(() -> {
        for (i in 0...100) {
          final o = new Observable(() -> i, changed);
          if (o.value != i) asserts.fail('wrong value');
          if (i % 2 == 0) o.bind(_ -> {}, Scheduler.direct).cancel();
          refs.push(new js.lib.WeakRef((o:tink.state.internal.ObservableObject<Int>)));
        }
        haxe.Timer.delay(() -> {
          gc();
          haxe.Timer.delay(() -> {
            gc();
            asserts.assert(refs.filter(r -> r.deref() != null).length == 0);
            asserts.assert(kept.value == -1);
            asserts.done();
          }, 10);
        }, 0);
      }, 0);
      return asserts;
    }
    #end
    asserts.assert(true, 'no way to force a collection on this target');
    return asserts.done();
  }

  public function updatesWhileObserved() {
    var value = 1;
    final changed = Signal.trigger();
    final o = new Observable(() -> value, changed);
    final log = [];
    o.bind(v -> log.push(v), Scheduler.direct);
    value = 2;
    changed.trigger(Noise);
    value = 3;
    changed.trigger(Noise);
    asserts.assert(log.join(',') == '1,2,3');
    return asserts.done();
  }

  public function catchesUpWhenObservedAgain() {
    var value = 1;
    final changed = Signal.trigger();
    final o = new Observable(() -> value, changed);
    final log = [];
    o.bind(v -> log.push('first:$v'), Scheduler.direct).cancel();
    value = 2;
    changed.trigger(Noise);
    o.bind(v -> log.push('second:$v'), Scheduler.direct);
    asserts.assert(log.join(',') == 'first:1,second:2');
    return asserts.done();
  }

  public function catchesUpThroughAuto() {
    var value = 1;
    final changed = Signal.trigger();
    final o = new Observable(() -> value, changed);
    final derived = Observable.auto(() -> o.value * 10);
    final log = [];
    derived.bind(v -> log.push('first:$v'), Scheduler.direct).cancel();
    value = 2;
    changed.trigger(Noise);
    derived.bind(v -> log.push('second:$v'), Scheduler.direct);
    asserts.assert(log.join(',') == 'first:10,second:20');
    return asserts.done();
  }

  // from https://github.com/haxetink/tink_state/pull/90
  public function cachesUntilTheSignalFires() {
    var calls = 0,
        value = 1;
    final changed = Signal.trigger();
    final o = new Observable(() -> { calls++; value; }, changed);

    asserts.assert(o.value == 1);
    value = 2;
    asserts.assert(o.value == 1);
    asserts.assert(calls == 1);

    changed.trigger(Noise);
    asserts.assert(o.value == 2);
    asserts.assert(calls == 2);

    return asserts.done();
  }

  public function observedThroughTwoPaths() {
    var value = 1;
    final changed = Signal.trigger();
    final o = new Observable(() -> value, changed);
    final forwarded = State.compound(o, _ -> {});
    final both = new State(true);
    final derived = Observable.auto(() -> if (both.value) o.value + forwarded.value else forwarded.value);
    final log = [];
    derived.bind(v -> log.push(v), Scheduler.direct);
    both.set(false);
    value = 2;
    changed.trigger(Noise);
    asserts.assert(log.join(',') == '2,1,2');
    return asserts.done();
  }

  public function deadSignal() {
    final changed = Signal.trigger();
    final o = new Observable(() -> 1, changed);
    changed.dispose();
    final log = [];
    o.bind(v -> log.push(v), Scheduler.direct);
    asserts.assert(log.join(',') == '1');
    asserts.assert(!(o:tink.state.internal.ObservableObject<Int>).canFire());
    return asserts.done();
  }
}
