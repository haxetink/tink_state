package;

import tink.state.*;

using tink.CoreApi;

@:asserts
class TestSignalObservable {
  public function new() {}

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

  public function releasedWhenDroppedWhileTheSignalLives() {
    final gc = collector();
    if (gc == null) {
      asserts.assert(true, 'no way to force a collection on this target');
      return asserts.done();
    }

    final changed = Signal.trigger();
    final kept = new Observable(() -> 1, changed);

    function handlers()
      return @:privateAccess changed.handlers.length;

    // finalizers run in a later task after a collection, so collect and wait a few times
    var attempts = 0;
    function check() {
      gc();
      haxe.Timer.delay(() ->
        if (handlers() > 1 && ++attempts < 20) check();
        else {
          asserts.assert(handlers() == 1);
          asserts.assert(kept.value == 1);
          asserts.done();
        }, 10);
    }

    // node keeps the targets of WeakRefs created while the main script runs, so create them in a later task
    haxe.Timer.delay(() -> {
      for (i in 0...100) new Observable(() -> i, changed).value;
      asserts.assert(handlers() == 101);
      check();
    }, 0);

    return asserts;
  }

  static function collector():Null<()->Void>
    return
      #if nodejs
        try {
          js.Lib.require('v8').setFlagsFromString('--expose-gc');
          js.Lib.require('vm').runInNewContext('gc');
        }
        catch (e:Dynamic) null;
      #else
        null;
      #end
}
