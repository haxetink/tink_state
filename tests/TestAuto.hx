package;

import tink.state.Promised;
import tink.state.Observable;
import tink.state.*;

using tink.CoreApi;

class SimpleState<T> extends Invalidator implements ObservableObject<T> {
  var value:T;
  var comparator:Comparator<T>;

  public function set(next:T) {
    value = next;
    fire();
  }

  public function new(value, ?comparator) {
    super();
    this.value = value;
    this.comparator = comparator;
  }

  public function getComparator()
    return comparator;

  public function getValue():T
    return value;

}

typedef StateObject<T> = SimpleState<T>;

@:forward(set)
abstract State<T>(StateObject<T>) from StateObject<T> {

  public var value(get, never):T;
    inline function get_value()
      return observe().value;

  public inline function new(value:T)
    this = new SimpleState(value);

  public inline function observe():Observable<T>
    return this;
}

@:asserts
class TestAuto {
  public function new() {}

  public function test() {
    var s1 = new State(4),
        s2 = new State(5);

    var calls = 0;
    var o = Observable.auto(function () return {
      calls++;
      s1.value + s2.value;
    });

    asserts.assert(9 == o.value);
    s1.set(10);
    asserts.assert(15 == o.value);
    s1.set(11);
    asserts.assert(16 == o.value);
    s1.set(1);
    s2.set(2);
    s2.set(3);
    asserts.assert(4 == o.value);
    var old = calls;
    asserts.assert(4 == o.value);
    asserts.assert(old == calls);
    return asserts.done();
  }

  public function testDirect() {
    var calls = 0;
    var s1 = new State(4),
        s2 = new State(5);

    var o = Observable.auto(function () {
      calls++;
      return s1.value + s2.value;
    });

    var sum = 0;

    o.bind({ direct: true }, function (v) sum = v);

    asserts.assert(sum == s1.value + s2.value);
    asserts.assert(calls == 1);

    s1.set(s1.value + 1);
    s2.set(s2.value + 1);

    asserts.assert(sum == s1.value + s2.value);
    asserts.assert(calls == 3);

    s1.set(s1.value + 1);
    s2.set(s2.value + 1);

    asserts.assert(sum == s1.value + s2.value);
    asserts.assert(calls == 5);

    return asserts.done();
  }

  public function testAsync() {
    var triggers = new Array<FutureTrigger<Outcome<Int, Error>>>();

    function trigger(value, ?pos) {
      asserts.assert(triggers.length > 0, null, pos);
      if (triggers.length > 0)
        triggers.shift().trigger(value);
    }

    function yield(value, ?pos)
      trigger(Success(value), pos);

    function fail(?pos)
      trigger(Failure(new Error('failure')), pos);

    var counter = new State(0);
    function inc()
      counter.set(counter.value + 1);

    var last = None;

    var o = Observable.auto(l -> {
      var t = new FutureTrigger();
      last = l;
      triggers.push(t);
      Promise.lift(counter.value)
        .next(c -> Promise.lift(t)
          .next(t -> { c: c, t: t })
        );
    });

    asserts.assert(o.value.match(Loading));
    asserts.assert(last.match(None));
    yield(12);
    asserts.assert(o.value.match(Done({ c: 0, t: 12 })));
    asserts.assert(last.match(None));
    inc();
    asserts.assert(o.value.match(Loading));
    asserts.assert(last.match(Some({ c: 0, t: 12 })));
    inc();
    asserts.assert(o.value.match(Loading));
    asserts.assert(last.match(Some({ c: 0, t: 12 })));
    yield(22);
    asserts.assert(o.value.match(Loading));
    asserts.assert(last.match(Some({ c: 0, t: 12 })));
    yield(42);
    asserts.assert(o.value.match(Done({ c: 2, t: 42 })));
    asserts.assert(last.match(Some({ c: 0, t: 12 })));
    inc();
    asserts.assert(o.value.match(Loading));
    asserts.assert(last.match(Some({ c: 2, t: 42 })));
    fail();
    asserts.assert(o.value.match(Failed(_)));
    asserts.assert(last.match(Some({ c: 2, t: 42 })));

    return asserts.done();
  }


  public function donotFireEqualAuto() {
    var s = new State(1 << 5);

    function inc()
      s.set(s.value + 1);

    var o = s.observe();
    var a = [];

    for (i in 0...5) {
      a[i] = -1;
      var cur = o;
      o = Observable.auto(function () {
        a[i]++;
        return cur.value >> 1;
      });
    }

    o.bind({ direct: true }, function () {});

    asserts.assert(o.value == 1);

    for (i in 0...1 << 4)
      inc();

    asserts.assert(o.value == 1);

    asserts.assert('16,8,4,2,1' == a.join(','));

    for (i in 0...1 << 4)
      inc();

    asserts.assert(o.value == 2);

    asserts.assert('32,16,8,4,2' == a.join(','));

    return asserts.done();
  }
}