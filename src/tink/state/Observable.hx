package tink.state;

import tink.state.internal.*;
import tink.state.Promised;
import tink.state.Invalidatable;

using tink.CoreApi;

@:using(tink.state.Observable.ObservableTools)
abstract Observable<T>(ObservableObject<T>) from ObservableObject<T> to ObservableObject<T> {
  public var value(get, never):T;
    @:to function get_value()
      return AutoObservable.track(this);

  static public inline function untracked<T>(fn:Void->T)
    return AutoObservable.untracked(fn);

  public function bind(?options:BindingOptions<T>, cb:Callback<T>):CallbackLink
    return new Binding(this, cb, if (options != null && options.direct) null else scheduler, if (options == null) null else options.comparator).cancel;

  public inline function new(get:Void->T, changed:Signal<Noise>)
    this = new SignalObservable(get, changed);

  public function combine<A, R>(that:Observable<A>, f:T->A->R):Observable<R>
    return Observable.auto(() -> f(value, that.value));

  public function nextTime(?options:{ ?butNotNow: Bool, ?hires:Bool }, check:T->Bool):Future<T>
    return getNext(options, function (v) return if (check(v)) Some(v) else None);

  public function getNext<R>(?options:{ ?butNotNow: Bool, ?hires:Bool }, select:T->Option<R>):Future<R> {
    var ret = Future.trigger(),
        waiting = options != null && options.butNotNow;

    var link = bind({ direct: options != null && options.hires }, function (value) {
      var out = select(value);
      if (waiting)
        waiting = out != None;
      else switch out {
        case Some(value): ret.trigger(value);
        case None:
      }
    });

    ret.handle(link.cancel);

    return ret;
  }

  public function join(that:Observable<T>) {
    var lastA = null;
    return combine(that, function (a, b) {
      var ret =
        if (lastA == a) b;
        else a;

      lastA = a;
      return ret;
    });
  }

  public function map<R>(f:Transform<T, R>):Observable<R>
    return Observable.auto(() -> f.apply(value));//TODO: benchmark TransformObservable and if it's noticably faster, use it
    // return new TransformObservable(this, f);

  public function combineAsync<A, R>(that:Observable<A>, f:T->A->Promise<R>):Observable<Promised<R>>
     return Observable.auto(() -> f(value, that.value));

  public function mapAsync<R>(f:Transform<T, Promise<R>>):Observable<Promised<R>>
    return Observable.auto(() -> f.apply(this.getValue()));

  @:deprecated('use auto instead')
  public function switchSync<R>(cases:Array<{ when: T->Bool, then: Lazy<Observable<R>> } > , dfault:Lazy<Observable<R>>):Observable<R>
    return Observable.auto(() -> {
      var v = value;
      for (c in cases)
        if (c.when(v)) {
          dfault = c.then;
          break;
        }
      return dfault.get().value;
    });

  static var scheduler:Scheduler =
    #if macro
      DirectScheduler.inst;
    #else
      new BatchScheduler({
        function later(fn)
          haxe.Timer.delay(fn, 10);
        #if js
          var later =
            try
              if (js.Browser.window.requestAnimationFrame != null)
                function (fn:Void->Void)
                  js.Browser.window.requestAnimationFrame(cast fn);
              else
                throw 'nope'
            catch (e:Dynamic)
              later;
        #end

        function asap(fn)
          later(fn);
        #if js
          var asap =
            try {
              var p = js.lib.Promise.resolve(42);
              function (fn:Void->Void) p.then(cast fn);
            }
            catch (e:Dynamic)
              asap;
        #end

        function (b:BatchScheduler, isRerun:Bool) {
          (if (isRerun) later else asap)(b.progress.bind(.01));
        }
      });
    #end

  static public function schedule(f:Void->Void)
    scheduler.schedule(JustOnce.call(f));

  static public var isUpdating(default, null):Bool = false;

  @:extern static inline function performUpdate<T>(fn:Void->T) {
    var wasUpdating = isUpdating;
    isUpdating = true;
    return Error.tryFinally(fn, () -> isUpdating = wasUpdating);
  }

  static public function updatePending(maxSeconds:Float = .01)
    return !isUpdating && scheduler.progress(maxSeconds);

  static public function updateAll()
    updatePending(Math.POSITIVE_INFINITY);

  static public inline function lift<T>(o:Observable<T>) return o;

  static public function ofPromise<T>(p:Promise<T>):Observable<Promised<T>>
    return Observable.auto(() -> p);

  @:deprecated
  static public function create<T>(f, ?comparator):Observable<T>
    return new SimpleObservable(f, comparator);

  static public function auto<T>(f:Computation<T>, ?comparator):Observable<T>
    return new AutoObservable(f, comparator);

  @:noUsing static public function const<T>(value:T):Observable<T>
    return new ConstObservable(value);

  @:op(a == b)
  static function eq<T>(a:Observable<T>, b:Observable<T>):Bool
    return switch [a, b] {
      case [null, null]: true;
      case [null, _] | [_, null]: false;
      default: a.value == b.value;
    }

  @:op(a != b)
  static inline function neq<T>(a:Observable<T>, b:Observable<T>):Bool
    return !eq(a, b);

  #if tink_state.test_subscriptions
    static function subscriptionCount()
      return Subscription.liveCount;
  #end

}

private class SignalObservable<X, T> implements ObservableObject<T> {
  var valid = false;
  var value:Null<T>;
  var revision = new Revision();

  public function getRevision()
    return revision;

  final get:Void->T;

  final observers = new Map();
  final changed:Signal<Noise>;

  public function new(get, changed:Signal<Noise>) {
    this.get = get;
    this.changed = changed;
    this.changed.handle(function (_) if (valid) {
      revision = new Revision();
      valid = false;
    });
  }

  public function getValue():T
    return
      if (valid) value;
      else {
        valid = true;
        value = get();
      }

  public function isValid():Bool
    return valid;

  public function getComparator():Comparator<T>
    return null;

  public function onInvalidate(i:Invalidatable):CallbackLink
    return
      if (observers.get(i)) null;
      else {
        observers.set(i, true);
        changed.handle(i.invalidate);
      }

  #if tink_state.debug
  public function getObservers()
    return observers.keys();

  public function getDependencies()
    return [].iterator();
  #end
}

private interface Derived {
  function subscribeTo<R>(source:ObservableObject<R>, cur:R):Void;
}

interface ObservableObject<T> {
  function getValue():T;
  function getRevision():Revision;
  function isValid():Bool;
  function getComparator():Comparator<T>;
  function onInvalidate(i:Invalidatable):CallbackLink;
  #if tink_state.debug
  function getObservers():Iterator<Invalidatable>;
  function getDependencies():Iterator<Observable<Any>>;
  #end
}

interface Schedulable {
  function run():Void;
}

private class ConstObservable<T> implements ObservableObject<T> {
  final value:T;
  final revision = new Revision();

  public function getRevision()
    return revision;

  public function new(value)
    this.value = value;

  public function getValue()
    return value;

  public function isValid()
    return true;

  public function getComparator()
    return null;

  #if tink_state.debug
  public function getObservers()
    return EMPTY.iterator();

  public function getDependencies()
    return [].iterator();
  #end

  static final EMPTY = [];

  public function onInvalidate(i:Invalidatable):CallbackLink
    return null;
}

private class JustOnce implements Schedulable {
  var f:Void->Void;
  function new() {}

  public function run() {
    var f = f;
    this.f = null;
    pool.push(this);
    f();
  }
  static var pool = [];
  static public function call(f) {
    var ret = switch pool.pop() {
      case null: new JustOnce();
      case v: v;
    }
    ret.f = f;
    return ret;
  }
}

abstract Comparator<T>(Null<(T,T)->Bool>) from (T,T)->Bool {
  public inline function eq(a:T, b:T)
    return switch this {
      case null: a == b;
      case f: f(a, b);
    }

  inline function unpack()
    return this;

  public inline function and(that:Comparator<T>):Comparator<T>
    return switch [this, that.unpack()] {
      case [null, v] | [v, null]: v;
      case [c1, c2]: (a, b) -> c1(a, b) && c2(a, b);
    }

  public inline function or(that:Comparator<T>):Comparator<T>
    return switch [this, that.unpack()] {
      case [null, v] | [v, null]: v;
      case [c1, c2]: (a, b) -> c1(a, b) || c2(a, b);
    }
}

private class SimpleObservable<T> extends Invalidator implements ObservableObject<T> {

  var _poll:Void->Measurement<T>;
  var _cache:Measurement<T> = null;
  var comparator:Comparator<T>;

  public function new(poll, ?comparator) {
    this._poll = poll;
    this.comparator = comparator;
  }

  public function isValid()
    return _cache != null;

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

  #if tink_state.debug
  public function getDependencies()
    return [].iterator();
  #end
}

private interface Scheduler {
  function progress(maxSeconds:Float):Bool;
  function schedule(s:Schedulable):Void;
}

private class Binding<T> implements Invalidatable implements Schedulable {
  final data:ObservableObject<T>;
  final cb:Callback<T>;
  final scheduler:Scheduler;
  final comparator:Comparator<T>;
  var status = Valid;
  var last:Null<T> = null;
  final link:CallbackLink;

  public function new(data, cb, ?scheduler, ?comparator) {
    this.data = data;
    this.cb = cb;
    this.scheduler = switch scheduler {
      case null: DirectScheduler.inst;
      case v: v;
    }
    this.comparator = data.getComparator().or(comparator);
    link = data.onInvalidate(this);
    cb.invoke(this.last = data.getValue());
  }

  public function cancel() {
    link.cancel();
    status = Canceled;
  }

  public function invalidate()
    if (status == Valid) {
      status = Invalid;
      scheduler.schedule(this);
    }

  public function run()
    switch status {
      case Canceled | Valid:
      case Invalid:
        status = Valid;
        var prev = this.last,
            next = this.last = data.getValue();

        if (!comparator.eq(prev, next))
          cb.invoke(next);
    }
}

private enum abstract BindingStatus(Int) {
  var Valid;
  var Invalid;
  var Canceled;
}

private class DirectScheduler implements Scheduler {
  static public final inst = new DirectScheduler();

  function new() {}

  public function progress(_)
    return false;

  public function schedule(s:Schedulable)
    @:privateAccess Observable.performUpdate(s.run);
}

private class BatchScheduler implements Scheduler {
  var queue:Array<Schedulable> = [];
  var scheduled = false;
  final run:(s:BatchScheduler, isRerun:Bool)->Void;

  public function new(run) {
    this.run = run;
  }

  inline function measure()
    return
      #if java
        Sys.cpuTime();
      #else
        haxe.Timer.stamp();
      #end

  public function progress(maxSeconds:Float)
    return @:privateAccess Observable.performUpdate(() -> {
      var end = measure() + maxSeconds;

      do {
        var old = queue;
        queue = [];
        for (o in old) o.run();
      }
      while (queue.length > 0 && measure() < end);

      if (queue.length > 0) {
        run(this, true);
        true;
      }
      else scheduled = false;
    });

  public function schedule(s:Schedulable) {
    queue.push(s);
    if (!scheduled) {
      scheduled = true;
      run(this, false);
    }
  }
}

@:callable
private abstract Computation<T>((T->Void)->?Noise->T) {
  inline function new(f) this = f;

  @:from static function asyncWithLast<T>(f:Option<T>->Promise<T>):Computation<Promised<T>> {
    var link:CallbackLink = null,
        last = None,
        ret = Loading;
    return new Computation((update, ?_) -> {
      ret = Loading;
      link.cancel();
      link = f(last).handle(o -> update(ret = switch o {
        case Success(v): last = Some(v); Done(v);
        case Failure(e): Failed(e);
      }));
      return ret;
    });
  }


  @:from static function async<T>(f:Void->Promise<T>):Computation<Promised<T>>
    return asyncWithLast(_ -> f());

  @:from static inline function withLast<T>(f:Option<T>->T):Computation<T> {
    var last = None;
    return new Computation((_, ?_) -> {
      var ret = f(last);
      last = Some(ret);
      return ret;
    });
  }

  @:from static function sync<T>(f:Void->T) {
    return new Computation((_, ?_) -> f());
  }
}

typedef Subscription = SubscriptionTo<Any>;

private class SubscriptionTo<T> {

  public final source:ObservableObject<T>;
  var last:T;
  var lastRev:Revision;
  var link:CallbackLink;
  final owner:Invalidatable;

  public var used = true;

  #if tink_state.test_subscriptions
    static public var liveCount(default, null) = 0;
  #end
  var connected:Bool = false;

  public function new<X>(source, cur, owner:AutoObservable<X>) {
    this.source = source;
    this.last = cur;
    this.lastRev = source.getRevision();
    this.owner = owner;

    if (owner.hot) connect();
  }

  public function isValid()
    return source.getRevision() == lastRev;

  public function hasChanged():Bool {
    var nextRev = source.getRevision();
    if (nextRev == lastRev) return false;
    lastRev = nextRev;
    var before = last;
    last = Observable.untracked(source.getValue);// not sure this has to be untracked
    return !source.getComparator().eq(last, before);
  }

  public function disconnect():Void {
    if (connected) {
      #if tink_state.test_subscriptions
        liveCount--;
      #end
      connected = false;
    }
    #if tink_state.test_subscriptions
      else throw 'what?';
    #end
    link.cancel();
  }

  public function connect():Void {
    if (connected)
      #if tink_state.test_subscriptions
        throw 'what?';
      #else
        return;
      #end
    connected = true;
    #if tink_state.test_subscriptions
      liveCount++;
    #end
    this.link = source.onInvalidate(owner);
  }
}

private enum abstract AutoObservableStatus(Int) {
  var Dirty;
  var Computed;
}

private class AutoObservable<T> extends Invalidator
  implements Invalidatable implements Derived implements ObservableObject<T> {

  static var cur:Derived;

  var compute:Computation<T>;
  #if hotswap
    static var rev = new State(0);
    static function onHotswapLoad() {
      rev.set(rev.value + 1);
    }
  #end
  public var hot(default, null) = false;
  var status = Dirty;
  var last:T = null;
  var subscriptions:Array<Subscription>;
  var dependencies = new ObjectMap<ObservableObject<Dynamic>, Subscription>();

  var comparator:Comparator<T>;

  override function getRevision() {
    if (hot)
      return revision;
    if (subscriptions == null)
      getValue();
    var max = Revision.ZERO;
    for (s in subscriptions)
      max *= s.source.getRevision();
    if (max > revision)
      revision = new Revision();

    return revision;
  }

  function subsValid() {
    if (subscriptions == null)
      return false;

    for (s in subscriptions)
      if (!s.isValid())
        return false;

    return true;
  }

  public function isValid()
    return status != Dirty && (hot || subsValid());

  public function getComparator()
    return comparator;

  public function new(compute, ?comparator) {
    this.compute = compute;
    this.comparator = comparator;
    this.list.onfill = heatup;
    this.list.ondrain = cooldown;
  }

  function heatup() {
    getValue();
    getRevision();
    if (subscriptions != null)
      for (s in subscriptions) s.connect();
    hot = true;
  }

  function cooldown() {
    hot = false;
    if (subscriptions != null)
      for (s in subscriptions) s.disconnect();
  }

  static public inline function computeFor<T>(o:Derived, fn:Void->T) {
    var before = cur;
    cur = o;
    #if hotswap
      rev.value;
    #end
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

    inline function doCompute() {
      status = Computed;
      if (subscriptions != null)
        for (s in subscriptions) s.used = false;
      subscriptions = [];
      sync = true;
      last = computeFor(this, () -> compute(update));
      sync = false;
    }

    var prevSubs = subscriptions,
        count = 0;

    while (!isValid())
      if (++count == 100)
        throw 'no result after 100 attempts';
      else if (subscriptions != null) {
        var valid = true;

        for (s in subscriptions)
          if (s.hasChanged()) {
            valid = false;
            break;
          }

        if (valid) status = Computed;
        else {
          doCompute();
          if (prevSubs != null) {
            for (s in prevSubs)
              if (!s.used) {
                if (hot) s.disconnect();
                dependencies.remove(s.source);
              }
          }
        }
      }
      else doCompute();

    return last;
  }

  var sync = true;

  function update(value) if (!sync) {
    last = value;
    fire();
  }

  public function subscribeTo<R>(source:ObservableObject<R>, cur:R):Void
    switch dependencies.get(source) {
      case null:
        var sub:Subscription = cast new SubscriptionTo(source, cur, this);
        dependencies.set(source, sub);
        subscriptions.push(sub);
      case v:
        if (!v.used) {
          v.used = true;
          subscriptions.push(v);
        }
    }

  public function invalidate()
    if (status == Computed) {
      status = Dirty;
      fire();
    }

  #if tink_state.debug
  public function getDependencies()
    return cast dependencies.keys();
  #end
}

typedef BindingOptions<T> = {
  ?direct:Bool,
  ?comparator:T->T->Bool
}

abstract Transform<T, R>(T->R) {
  inline function new(f)
    this = f;

  public inline function apply(value:T):R
    return this(value);

  @:from static function naiveAsync<T, R>(f:T->Promise<R>):Transform<Promised<T>, Promise<R>>
    return new Transform(function (p:Promised<T>):Promise<R> return switch p {
      case Failed(e): e;
      case Loading: new Future(function (_) return null);
      case Done(v): f(v);
    });

  @:from static function naive<T, R>(f:T->R):Transform<Promised<T>, Promised<R>>
    return new Transform(function (p) return switch p {
      case Failed(e): Failed(e);
      case Loading: Loading;
      case Done(v): Done(f(v));
    });

  @:from static function plain<T, R>(f:T->R):Transform<T, R>
    return new Transform(f);
}

// private class TransformObservable<In, Out> implements ObservableObject<Out> {

//   var lastSeenRevision = -1;
//   var last:Out = null;
//   var transform:Transform<In, Out>;
//   var source:ObservableObject<In>;

//   public function new(source, transform) {
//     this.source = source;
//     this.transform = transform;
//   }

//   public function getRevision()
//     return source.getRevision();

//   public function isValid()
//     return lastSeenRevision == source.getRevision();

//   public function onInvalidate(i)
//     return source.onInvalidate(i);

//   #if tink_state.debug
//   public function getObservers()
//     return source.getObservers();
//   public function getDependencies()
//     return [(cast source:Observable<Any>)].iterator();
//   #end

//   public function getValue() {
//     var rev = source.getRevision();
//     if (rev > lastSeenRevision) {
//       lastSeenRevision = rev;
//       last = transform.apply(source.getValue());
//     }
//     return last;
//   }

//   public function getComparator()
//     return null;
// }

@:access(tink.state.Observable)
class ObservableTools {

  static public function deliver<T>(o:Observable<Promised<T>>, initial:T):Observable<T>
    return Observable.lift(o).map(function (p) return switch p {
      case Done(v): initial = v;
      default: initial;
    });

  static public function flatten<T>(o:Observable<Observable<T>>)
    return Observable.auto(() -> Observable.lift(o).value.value);

}