package;

import tink.state.Scheduler.direct;
import tink.state.Promised;
import tink.state.Observable;
import tink.state.*;

using tink.CoreApi;

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

    var watch = o.bind(function (v) sum = v, direct);

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

    watch.cancel();

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

    var watch = o.bind(function () {}, direct);

    asserts.assert(o.value == 1);

    for (i in 0...1 << 4)
      inc();

    asserts.assert(o.value == 1);

    asserts.assert('16,8,4,2,1' == a.join(','));

    for (i in 0...1 << 4)
      inc();

    asserts.assert(o.value == 2);

    asserts.assert('32,16,8,4,2' == a.join(','));

    watch.cancel();

    return asserts.done();
  }

  public function selfInvalidating() {
    var s1 = new State(0),
        s2 = new State(0);

    var o = Observable.auto(() -> {
      if (s1.value < 10) s1.value += 1;
      if (s2.value < 10) s2.value += 1;
      s1.value + s2.value;
    });

    asserts.assert(s1.value == 0);
    asserts.assert(s2.value == 0);

    asserts.assert(o.value == 20);

    asserts.assert(s1.value == 10);
    asserts.assert(s2.value == 10);

    return asserts.done();
  }

  public function testSubs() {
    #if tink_state.test_subscriptions
    function count()
      return @:privateAccess Observable.subscriptionCount();

    var initial = count();//it's possible other tests leave behind subscriptions ... should probably warn in that case
    #end

    var liveCount = 0;
    function watch(alive:Bool)
      if (alive) liveCount++;
      else liveCount--;

    var states = [for (i in 0...10) new State(i, watch)];
    var select = new State([for (i in 0...states.length) i % 3 == 0]);

    function add() {
      var ret = 0;
      for (i => s in select.value)
        if (s) ret += states[i].value;
      return ret;
    }

    var selectedCount = select.observe().map(a -> Lambda.count(a, x -> x));

    var result = 0;
    var watch = Observable.auto(add).bind(x -> result = x, direct);

    function check(?pos:haxe.PosInfos) {
      #if tink_state.test_subscriptions
      asserts.assert(selectedCount.value + 1 + initial == count());
      #end
      asserts.assert(liveCount == selectedCount.value);
    }
    asserts.assert(result == 18);
    check();

    for (i in 0...10) {
      select.set([for (i in 0...states.length) Math.random() > .5]);
      asserts.assert(result == add());
      check();
    }

    watch.cancel();

    return asserts.done();
  }
}