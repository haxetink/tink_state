package ;

import tink.state.*;

using tink.CoreApi;

@:asserts
class TestMaps {

  public function new() {}

  public function testEntries() {
    var o = new ObservableMap([5 => 0, 6 => 0]);

    var a = [];

    function report(k:Int) return function (v:Int) a.push('$k:$v');

    var unlink:CallbackLink = [
      o.observe(5).bind({ direct: true }, report(5)),
      o.observe(6).bind({ direct: true }, report(6)),
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
    unlink.dissolve();

    o.observe(5).bind(report(5));
    o.observe(6).bind(report(6));

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

    return asserts.done();
  }

  public function testIterators() {
    var map = new ObservableMap<String, String>(new Map());
    map.set('key', 'value');

    var count = 0;
    for(key in map.keys()) count++;
    for(key in map.keys()) count++;
    for(value in map.iterator()) count++;
    for(value in map.iterator()) count++;

    asserts.assert(count == 4);

    var counts = [];

    Observable.auto(function () {
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

    return asserts.done();
  }
}