package;

import tink.state.Measurement;
#if nu
import tink.state.*;
#else
using tink.CoreApi;

interface ObservableObject<T> {
  function getValue():T;
  function getComparator():Comparator<T>;
  function onInvalidate(i:Invalidatable):CallbackLink;
}

interface Derived {
  function subscribeTo<R>(source:ObservableObject<R>, cur:R):Void;
}

typedef Invalidatable = {
  function invalidate():Void;
}

class Invalidator {
  static var counter = 0;
  var handlers = [];
  function new() {}

  public function onInvalidate(i:Invalidatable):CallbackLink {
    handlers.push(i);
    return function () if (i != null) {
      handlers.remove(i);
      i = null;
    }
  }

  function fire() {
    for (i in handlers)
      i.invalidate();
  }
}

abstract Comparator<T>(Null<(T,T)->Bool>) from (T,T)->Bool {
  public inline function eq(a:T, b:T)
    return switch this {
      case null: a == b;
      case f: f(a, b);
    }
}

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

private class SimpleObservable<T> extends Invalidator implements ObservableObject<T> {

  var _poll:Void->Measurement<T>;
  var _cache:Measurement<T> = null;
  var comparator:Comparator<T>;

  public function new(poll, ?comparator) {
    super();
    this._poll = poll;
    this.comparator = comparator;
  }

  public function getComparator()
    return comparator;

  function reset(_) {
    _cache = null;
    fire();
  }

  function poll() {
    var count = 0;

    while (_cache == null)
      if (++count == 100)
        throw "polling did not conclude after 100 iterations";
      else {
        _cache = _poll();
        _cache.becameInvalid.handle(reset);
      }

    return _cache;
  }


  public function getValue()
    return poll().value;
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

abstract Observable<T>(ObservableObject<T>) from ObservableObject<T> {

  public var value(get, never):T;
    function get_value()
      return AutoObservable.track(this);

  static public inline function untracked<T>(fn:Void->T)
    return AutoObservable.untracked(fn);

  public function bind(?options:BindingOptions<T>, cb:Callback<T>) {

    inline function update() {
      cb.invoke(untracked(get_value));
    }

    update();

    return this.onInvalidate({ invalidate: function () update() });
  }

  static public function auto<V>(compute:Void->V):Observable<V> {
    return new AutoObservable<V>(compute);
  }
}

private interface Subscription {
  function hasChanged():Bool;
  function unregister():Void;
}

private class SubscriptionTo<T> implements Subscription {

  var source:ObservableObject<T>;
  var last:T;
  var link:CallbackLink;

  public function new(source, cur, target) {
    this.source = source;
    this.last = cur;
    this.link = source.onInvalidate(target);
  }

  public function hasChanged():Bool {
    var before = last;
    last = Observable.untracked(source.getValue);
    return !source.getComparator().eq(last, before);
  }

  public function unregister():Void
    link.dissolve();
}

private class AutoObservable<T> extends Invalidator implements Derived implements ObservableObject<T> {

  static var cur:Derived;

  var compute:Void->T;
  var valid:Bool = false;
  var last:T = null;
  var subscriptions:Array<Subscription> = null;

  var comparator:Comparator<T>;

  public function getComparator()
    return comparator;

  public function new(compute, ?comparator) {
    super();
    this.compute = compute;
    this.comparator = comparator;
  }

  static public inline function computeFor<T>(o:Derived, fn:Void->T) {
    var before = cur;
    cur = o;
    var ret = fn();
    cur = before;
    return ret;
  }

  static public inline function untracked<T>(fn:Void->T)
    return computeFor(null, fn);

  static public inline function track<V>(o:ObservableObject<V>):V {
    var ret = o.getValue();
    if (cur != null)
      cur.subscribeTo(o, ret);
    return ret;
  }

  public function getValue():T {
    var count = 0;

    while (!valid)
      if (++count == 100)
        throw 'no result after 100 attempts';
      else if (subscriptions != null) {
        valid = true;

        var old = Std.string(subscriptions);

        for (s in subscriptions)
          if (s.hasChanged()) {
            valid = false;
            break;
          }

        if (!valid) {
          for (s in subscriptions)
            s.unregister();
          subscriptions = null;
        }
      }
      else {
        valid = true;
        subscriptions = [];
        last = computeFor(this, compute);
      }

    return last;
  }

  public function subscribeTo<R>(source:ObservableObject<R>, cur:R):Void
    if (valid) {
      subscriptions.push(new SubscriptionTo(source, cur, this));
    }

  public function invalidate()
    if (valid) {
      valid = false;
      fire();
    }

}

typedef BindingOptions<T> = {
  ?direct:Bool,
  ?comparator:T->T->Bool
}
#end

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