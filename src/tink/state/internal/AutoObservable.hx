package tink.state.internal;

#if tink_state.debug
import tink.state.debug.Logger.inst as logger;
#end

@:callable
private abstract Computation<T>((update:T->Void)->T) {
  inline function new(f) this = f;

  @:from static function asyncWithLast<T>(f:Option<T>->Promise<T>):Computation<Promised<T>> {
    var link:CallbackLink = null,
        last = None,
        ret = Loading;
    return new Computation(update -> {
      ret = Loading;
      link.cancel();
      link = f(last).handle(o -> update(ret = switch o {
        case Success(v): last = Some(v); Done(v);
        case Failure(e): Failed(e);
      }));
      return ret;
    });
  }

  @:from static function async<T>(f:()->Promise<T>):Computation<Promised<T>>
    return asyncWithLast(_ -> f());

  @:from static function safeAsync<T>(f:()->Future<T>):Computation<Promised.Predicted<T>>
    return cast asyncWithLast(_ -> f());

  @:from static inline function withLast<T>(f:Option<T>->T):Computation<T> {
    var last = None;
    return new Computation(_ -> {
      var ret = f(last);
      last = Some(ret);
      return ret;
    });
  }

  @:from static function sync<T>(f:()->T) {
    return new Computation(_ -> f());
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

  #if tink_state.test_subscriptions
    var connected:Bool = false;
  #end

  public function new<X>(source, cur, owner:AutoObservable<X>) {
    this.source = source;
    this.last = cur;
    this.lastRev = source.getRevision();
    this.owner = owner;

    if (owner.hot) connect();
  }

  public inline function isValid()
    return source.getRevision() == lastRev;

  public inline function hasChanged():Bool {
    var nextRev = source.getRevision();
    if (nextRev == lastRev) return false;
    lastRev = nextRev;
    var before = last;
    last = Observable.untracked(source.getValue);// not sure this has to be untracked
    return !source.getComparator().eq(last, before);
  }

  public inline function reuse(value:T) {
    used = true;
    last = value;
  }

  public inline function disconnect():Void {
    #if tink_state.test_subscriptions // TODO: this probably should be removed, and tested indirectly via State.onStatusChange
      if (connected) {
        @:privateAccess AutoObservable.subscriptionCount--;
        connected = false;
      }
      else throw 'what?';
    #end
    #if tink_state.debug
      logger.disconnected(source, cast owner);
    #end
    link.cancel();
  }

  public inline function connect():Void {
    #if tink_state.test_subscriptions
      if (connected) throw 'what?';
      else {
        connected = true;
        @:privateAccess AutoObservable.subscriptionCount++;
      }
    #end
    #if tink_state.debug
      logger.connected(source, cast owner);
    #end
    this.link = source.onInvalidate(owner);
  }

  #if tink_state.debug

  #end
}

private enum abstract AutoObservableStatus(Int) {
  var Dirty;
  var Computed;
}

class AutoObservable<T> extends Invalidator
  implements Invalidatable implements Derived implements ObservableObject<T> {

  #if tink_state.test_subscriptions
    static var subscriptionCount = 0;
  #end
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

  public function new(compute, ?comparator, ?toString #if tink_state.debug , ?pos:haxe.PosInfos #end) {
    super(toString #if tink_state.debug , pos #end);
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
    if (cur != null)
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
      last = computeFor(this, () -> compute(v -> update(v)));
      sync = false;
      #if tink_state.debug
      logger.revalidated(this, false);
      #end
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