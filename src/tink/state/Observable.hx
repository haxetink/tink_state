package tink.state;

import tink.state.Promised;

using tink.CoreApi;

abstract Observable<T>(ObservableObject<T>) from ObservableObject<T> to ObservableObject<T> {
  public var value(get, never):T;
    @:to function get_value()
      return AutoObservable.track(this);

  static public inline function untracked<T>(fn:Void->T)
    return AutoObservable.untracked(fn);

  public function bind(?options:BindingOptions<T>, cb:Callback<T>):CallbackLink
    return new Binding(this, cb, if (options != null && options.direct) null else scheduler, if (options == null) null else options.comparator).cancel;

  public inline function new(get:Void->T, changed:Signal<Noise>)
    this = create(function () return new Measurement(get(), changed.nextTime()));

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

    ret.handle(link.dissolve);

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
    return Observable.auto(() -> f.apply(value));

  public function combineAsync<A, R>(that:Observable<A>, f:T->A->Promise<R>):Observable<Promised<R>>
     return Observable.auto(() -> f(value, that.value));

  public function mapAsync<R>(f:Transform<T, Promise<R>>):Observable<Promised<R>>
    return Observable.auto(() -> f.apply(this.getValue()));

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

  static inline function lift<T>(o:Observable<T>) return o;

  @:impl static public function deliver<T>(o:ObservableObject<Promised<T>>, initial:T):Observable<T>
    return lift(o).map(function (p) return switch p {
      case Done(v): initial = v;
      default: initial;
    });

  @:impl static public function flatten<T>(o:ObservableObject<Observable<T>>)
    return Observable.auto(() -> lift(o).value.value);

  static public function ofPromise<T>(p:Promise<T>):Observable<Promised<T>>
    return Observable.auto(() -> p);

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

}


interface Derived {
  function subscribeTo<R>(source:ObservableObject<R>, cur:R):Void;
}

interface ObservableObject<T> {
  function getValue():T;
  function getComparator():Comparator<T>;
  function onInvalidate(i:Invalidatable):CallbackLink;
}

interface Invalidatable {
  function invalidate():Void;
}

interface Schedulable {
  function run():Void;
}

private class ConstObservable<T> implements ObservableObject<T> {
  final value:T;

  public function new(value)
    this.value = value;

  public function getValue()
    return value;

  public function getComparator()
    return null;

  public function onInvalidate(i:Invalidatable):CallbackLink
    return null;
}

private class PlainSchedulable implements Schedulable {
  final f:Void->Void;
  public function new(f)
    this.f = f;
  public function run()
    f();
}


class Invalidator {
  var list = new CallbackList();
  function new() {}

  public function onInvalidate(i:Invalidatable):CallbackLink
    return list.add(i.invalidate);//TODO: optimize away this indirection

  function fire()
    list.invoke(Noise);
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

interface Scheduler {
  function progress(maxSeconds:Float):Bool;
  function schedule(s:Schedulable):Void;
}

private class Binding<T> implements Invalidatable implements Schedulable {
  final data:ObservableObject<T>;
  final cb:Callback<T>;
  final scheduler:Scheduler;
  final comparator:Comparator<T>;
  var status = Fresh;
  var last:Null<T> = null;
  var link:CallbackLink;

  public function new(data, cb, ?scheduler, ?comparator) {
    this.data = data;
    this.cb = cb;
    this.scheduler = switch scheduler {
      case null: DirectScheduler.inst;
      case v: v;
    }
    this.comparator = data.getComparator().or(comparator);
    this.scheduler.schedule(this);
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
      case Fresh:

        data.onInvalidate(this);
        status = Valid;
        cb.invoke(this.last = data.getValue());

      case Invalid:
        status = Valid;
        var prev = this.last,
            next = this.last = data.getValue();

        if (!comparator.eq(prev, next))
          cb.invoke(next);
    }
}

private enum abstract BindingStatus(Int) {
  var Fresh;
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
      else false;
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
        last = None;
    return new Computation((update, ?_) -> {
      link.dissolve();
      link = f(last).handle(o -> update(switch o {
        case Success(v): last = Some(v); Done(v);
        case Failure(e): Failed(e);
      }));
      return Loading;
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
    last = Observable.untracked(source.getValue);// not sure this has to be untracked
    return !source.getComparator().eq(last, before);
  }

  public function unregister():Void
    link.dissolve();
}

private class AutoObservable<T> extends Invalidator
  implements Invalidatable implements Derived implements ObservableObject<T> {

  static var cur:Derived;

  var compute:Computation<T>;
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
        last = computeFor(this, () -> compute(update));
      }

    return last;
  }

  function update(value) {
    last = value;
    fire();
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