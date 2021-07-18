package ;

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
}