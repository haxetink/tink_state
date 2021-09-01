package ;

import tink.state.internal.ObjectMap;
import tink.state.Scheduler.direct;
import tink.state.*;

using tink.CoreApi;

@:asserts
class TestMaps {

  public function new() {}

  public function testEntries() {
    final o = ObservableMap.of([5 => 0, 6 => 0]);

    var a = [];

    function report(k:Int) return (v:Int) -> a.push('$k:$v');

    var watch:CallbackLink = [
      o.entry(5).bind(report(5), direct),
      o.entry(6).bind(report(6), direct),
    ];

    o.set(5, 1);
    o.set(5, 2);
    o.set(5, 3);
    o.set(4, 3);

    asserts.assert('5:0,6:0,5:1,5:2,5:3' == a.join(','));

    o.set(6, 1);
    o.set(6, 1);
    o.set(6, 2);

    asserts.assert('5:0,6:0,5:1,5:2,5:3,6:1,6:2' == a.join(','));

    a = [];
    watch.cancel();

    watch = [
      o.entry(5).bind(report(5)),
      o.entry(6).bind(report(6)),
    ];

    o.set(5, 1);
    o.set(5, 2);
    o.set(5, 3);
    o.set(4, 3);

    asserts.assert('5:3,6:2' == a.join(','));

    o.set(6, 1);
    o.set(6, 1);
    o.set(6, 2);

    asserts.assert('5:3,6:2' == a.join(','));

    Observable.updateAll();

    asserts.assert('5:3,6:2' == a.join(','));

    o.set(5, 6);
    o.set(6, 5);

    asserts.assert('5:3,6:2' == a.join(','));

    Observable.updateAll();

    asserts.assert('5:3,6:2,5:6,6:5' == a.join(','));

    watch.cancel();
    return asserts.done();
  }

  public function testIterators() {
    final map = new ObservableMap<String, String>();
    map.set('key', 'value');

    var count = 0;
    for(key in map.keys()) count++;
    for(key in map.keys()) count++;
    for(value in map.iterator()) count++;
    for(value in map.iterator()) count++;

    asserts.assert(count == 4);

    final counts = [];

    final watch = Observable.auto(() -> {
      var counter = 0;
      for (i in [map.keys(), map.iterator()])
        for (x in i) counter++;
      return counter;
    }).bind(counts.push);

    Observable.updateAll();
    asserts.assert(counts.join(',') == '2');

    map.set('key2', 'value');

    Observable.updateAll();
    asserts.assert(counts.join(',') == '2,4');

    map.set('key3', 'value');

    Observable.updateAll();
    asserts.assert(counts.join(',') == '2,4,6');

    watch.cancel();

    return asserts.done();
  }

  public function of() {
    ObservableMap.of(new haxe.ds.IntMap()).set(1, 'foo');
    ObservableMap.of(new haxe.ds.StringMap()).set('1', 'foo');
    ObservableMap.of([{ foo: 213 } => '123']).set({ foo: 123 }, 'foo');

    return asserts.done();
  }

  public function issue49() {
    var o = ObservableMap.of([1 => 2]),
        computations = 0;


    final sum = Observable.auto(() -> {
      computations++;
      var ret = 0;
      if (o.exists(2)) ret += o[2];
      if (o.exists(3)) ret += o[3];
      return ret;
    });

    asserts.assert(sum.value == 0);
    asserts.assert(computations == 1);

    asserts.assert(sum.value == 0);
    asserts.assert(computations == 1);

    o[5] = 5;

    asserts.assert(sum.value == 0);
    asserts.assert(computations == 1);

    o[2] = 2;

    asserts.assert(sum.value == 2);
    asserts.assert(computations == 2);

    o[3] = 3;

    asserts.assert(sum.value == 5);
    asserts.assert(computations == 3);

    o[4] = 4;
    o.remove(5);

    asserts.assert(sum.value == 5);
    asserts.assert(computations == 3);

    o.remove(2);
    asserts.assert(sum.value == 3);
    asserts.assert(computations == 4);

    return asserts.done();
  }
}