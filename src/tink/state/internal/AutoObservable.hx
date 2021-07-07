package tink.state.internal;

#if tink_state.debug
import tink.state.debug.Logger.inst as logger;
#end

@:callable
@:access(tink.state.internal.AutoObservable)
private abstract Computation<T>((a:AutoObservable<T>,?Noise)->T) {
  inline function new(f) this = f;

  @:from static function asyncWithLast<T>(f:Option<T>->Promise<T>):Computation<Promised<T>> {
    var link:CallbackLink = null,
        last = None,
        ret = Loading;
    return new Computation((a, ?_) -> {
      ret = Loading;
      var prev = link;
      link = f(last).handle(o -> a.update(ret = switch o {
        case Success(v): last = Some(v); Done(v);
        case Failure(e): Failed(e);
      }));
      prev.cancel();
      return ret;
    });
  }

  @:from static function async<T>(f:()->Promise<T>):Computation<Promised<T>> {
    var link:CallbackLink = null,
        ret = Loading;
    return new Computation((a, ?_) -> {
      ret = Loading;
      var prev = link;
      link = f().handle(o -> a.update(ret = switch o {
        case Success(v): Done(v);
        case Failure(e): Failed(e);
      }));
      prev.cancel();
      return ret;
    });
  }

  @:from static function safeAsync<T>(f:()->Future<T>):Computation<Promised.Predicted<T>> {
    var link:CallbackLink = null,
        ret = Loading;
    return new Computation((a, ?_) -> {
      ret = Loading;
      var prev = link;
      link = f().handle(v -> a.update(ret = Done(v)));
      prev.cancel();
      return ret;
    });
  }

  @:from static inline function withLast<T>(f:Option<T>->T):Computation<T> {
    var last = None;
    return new Computation((_, ?_) -> {
      var ret = f(last);
      last = Some(ret);
      return ret;
    });
  }

  @:from static function sync<T>(f:()->T) {
    return new Computation((_, ?_) -> f());
  }
}

private typedef Subscription = SubscriptionTo<Any>;

private class SubscriptionTo<T> {

  public final source:ObservableObject<T>;
  var last:T;
  var lastRev:Revision;
  var link:CallbackLink;
  final owner:Invalidatable;

  public var used = true;

  public function new(source, cur, owner) {
    this.source = source;
    this.last = cur;
    this.lastRev = source.getRevision();
    this.owner = owner;
  }

  public inline function isValid()
    return source.getRevision() == lastRev;

  public function hasChanged():Bool {
    var nextRev = source.getRevision();
    if (nextRev == lastRev) return false;
    lastRev = nextRev;
    var before = last;
    last = source.getValue();
    return !source.getComparator().eq(last, before);
  }

  public inline function reuse(value:T) {
    used = true;
    last = value;
  }

  public inline function disconnect():Void {
    #if tink_state.debug
      logger.disconnected(source, cast owner);
    #end
    link.cancel();
  }

  public inline function connect():Void {
    #if tink_state.debug
      logger.connected(source, cast owner);
    #end
    this.link = source.onInvalidate(owner);
  }
}

private enum abstract AutoObservableStatus(Int) {
  var Dirty;
  var Computed;
}

class AutoObservable<T> extends Invalidator
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

    for (s in subscriptions)
      if (s.source.getRevision() > revision)
        return revision = new Revision();

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

  public function new(compute, ?comparator #if tink_state.debug , ?toString, ?pos:haxe.PosInfos #end) {
    super(#if tink_state.debug toString, pos #end);
    this.compute = compute;
    this.comparator = comparator;
    this.list.onfill = () -> inline heatup();
    this.list.ondrain = () -> inline cooldown();
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

  static public inline function computeFor<T>(o:Derived, fn:()->T) {
    var before = cur;
    cur = o;
    #if hotswap
      rev.value;
    #end
    var ret = fn();
    cur = before;
    return ret;
  }

  static public inline function untracked<T>(fn:()->T)
    return computeFor(null, fn);

  static public inline function track<V>(o:ObservableObject<V>):V {
    var ret = o.getValue();
    if (cur != null && o.canFire())
      cur.subscribeTo(o, ret);
    return ret;
  }

  public function getValue():T {

    function doCompute() {
      status = Computed;
      if (subscriptions != null)
        for (s in subscriptions) s.used = false;
      subscriptions = [];
      sync = true;
      last = computeFor(this, () -> compute(this));
      sync = false;
      #if tink_state.debug
      logger.revalidated(this, false);
      #end
      if (subscriptions.length == 0) dispose();
    }

    var prevSubs = subscriptions,
        count = 0;

    while (!isValid()) {
      #if tink_state.debug
      logger.revalidating(this);
      #end
      if (++count == Observable.MAX_ITERATIONS)
        throw 'no result after ${Observable.MAX_ITERATIONS} attempts';
      else if (subscriptions != null) {
        var valid = true;

        for (s in subscriptions)
          if (s.hasChanged()) {
            valid = false;
            break;
          }

        if (valid) {
          status = Computed;
          #if tink_state.debug
          logger.revalidated(this, true);
          #end
        }
        else {
          doCompute();
          if (prevSubs != null) {
            for (s in prevSubs)
              if (!s.used) {
                if (hot) s.disconnect();
                dependencies.remove(s.source);
                #if tink_state.debug
                  logger.unsubscribed(s.source, this);
                #end
              }
          }
        }
      }
      else doCompute();
    }
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
        #if tink_state.debug
          logger.subscribed(source, this);
        #end
        var sub:Subscription = cast new SubscriptionTo(source, cur, this);
        if (hot) sub.connect();
        dependencies.set(source, sub);
        subscriptions.push(sub);
      case v:
        if (!v.used) {
          v.reuse(cur);
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

private interface Derived {
  function subscribeTo<R>(source:ObservableObject<R>, cur:R):Void;
}