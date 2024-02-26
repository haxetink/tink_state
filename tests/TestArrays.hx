package ;

import tink.state.*;
import tink.state.Scheduler.direct;

using Lambda;
using StringTools;
using tink.CoreApi;

@:asserts
class TestArrays {

  public function new() {}

  public function basics() {
    final a = new ObservableArray<Null<Int>>([for (i in 0...100) i]);
    var log = [];

    function clear()
      log = [];

    function getLog()
      return log.join(',').replace('undefined', '-').replace('null', '-');

    function report(name:String) return (v:Null<Int>) -> log.push('$name:$v');

    Observable.auto(() -> a.length).bind(report('l'), direct);

    a.entry(99).bind(report('99'), direct);

    asserts.assert(getLog() == 'l:100,99:99');
    clear();

    for (i in 0...10)
      a.pop();

    asserts.assert(getLog() == 'l:99,99:-,l:98,l:97,l:96,l:95,l:94,l:93,l:92,l:91,l:90');
    clear();

    for (i in 0...9)
      a.unshift(a.get(0)-1);

    asserts.assert(getLog() == 'l:91,l:92,l:93,l:94,l:95,l:96,l:97,l:98,l:99');

    clear();
    a.unshift(a.get(0)-1);
    asserts.assert(getLog() == 'l:100,99:89');
    clear();
    for (i in 0...10)
      a.push(i);

    asserts.assert(getLog() == 'l:101,l:102,l:103,l:104,l:105,l:106,l:107,l:108,l:109,l:110');

    return asserts.done();
  }

  public function issue27() {
    final arr = new ObservableArray<Bool>();
    asserts.assert(arr.length == 0);
    arr.set(0, true);
    asserts.assert(arr.length == 1);
    arr.set(10, true);
    asserts.assert(arr.length == 11);
    return asserts.done();
  }

  public function iteration() {
    var counter = 0,
        a = new ObservableArray();

    for (i in 0...10)
      a.push(i);

    for (i in a)
      counter++;

    asserts.assert(counter == a.length);

    final evenCount = a.fold((v, count) -> count + 1 - v % 2, 0);
    asserts.assert(evenCount == 5);

    var keysChanges = 0,
        valuesChanges = 0,
        iteratorChanges = 0;

    function sum(i:Iterator<Int>) {
      var ret = 0;
      for (i in i)
        ret += i;
      return ret;
    }

    Observable.auto(() -> sum(a.iterator()))
      .bind(() -> valuesChanges++, direct);

    Observable.auto(() -> sum(a.keys()))
      .bind(() -> keysChanges++, direct);

    Observable.auto(() -> {
      var first = 0;
      for (v in a) {
        first += v;
        break;
      }
      return first;
    }).bind(() -> iteratorChanges++, (_, _) -> false, direct);

    asserts.assert(iteratorChanges * valuesChanges * keysChanges == 1);

    a.set(2, 4);

    asserts.assert(iteratorChanges == valuesChanges);
    asserts.assert(keysChanges == 1);
    asserts.assert(valuesChanges == 2);

    a.set(0, 1);

    asserts.assert(iteratorChanges == valuesChanges);
    asserts.assert(keysChanges == 1);
    asserts.assert(valuesChanges == 3);

    a.pop();

    asserts.assert(iteratorChanges == valuesChanges);
    asserts.assert(keysChanges == 2);
    asserts.assert(valuesChanges == 4);

    return asserts.done();
  }

  public function clear() {
    final o = new ObservableArray<Null<Int>>([1,2,3]);

    var log = '';

    Observable.auto(() -> o.length).bind(v -> log += 'len:$v', direct);
    for(i in 0...o.length) o.entry(i).bind(v -> log += ',$i:$v', direct);
    o.clear();

    asserts.assert(log.replace('undefined', '-').replace('null', '-') == 'len:3,0:1,1:2,2:3len:0,0:-,1:-,2:-');

    return asserts.done();
  }

  public function views() {
    final a = new ObservableArray<{ final foo:Int; final bar:Int; }>([for (i in 0...100) { foo: i, bar: i % 10 }]);
    final v = a.filter(o -> o.bar == 0).sorted((o1, o2) -> o2.foo - o1.foo).reduce('', (a, b) -> '${a.foo}:$b');
    asserts.assert(v.value == '0:10:20:30:40:50:60:70:80:90:');
    a.set(11, { foo: 123, bar: 0 });
    asserts.assert(v.value == '0:10:20:30:40:50:60:70:80:90:123:');
    a.set(10, { foo: 123, bar: 1 });
    asserts.assert(v.value == '0:20:30:40:50:60:70:80:90:123:');
    return asserts.done();
  }
}
