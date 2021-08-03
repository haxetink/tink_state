package tink.state.internal;

#if tink_state.debug
import tink.state.debug.Logger.inst as logger;
#end
import tink.core.Annex;

@:allow(tink.state.internal)
class AutoObservable<T> extends Dispatcher
  implements Observer implements Derived implements ObservableObject<T> {

  static var cur:Derived;

  #if hotswap
    static var rev = new State(0);
    static function onHotswapLoad() {
      rev.set(rev.value + 1);
    }
  #end
  public var hot(default, null) = false;
  final annex:Annex<{}>;
  var status = Dirty;
  var last:T = null;
  var subscriptions:Array<Subscription>;
  var dependencies = new ObjectMap<ObservableObject<Dynamic>, Subscription>();

  final comparator:Comparator<T>;
  var computation:Computation<T>;

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

  public function getAnnex()
    return annex;

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

  public function new(computation:Computation<T>, ?comparator #if tink_state.debug , ?toString, ?pos:haxe.PosInfos #end) {
    super(active -> if (active) wakeup() else sleep() #if tink_state.debug , toString, pos #end);
    this.computation = computation.init(this);
    this.comparator = comparator;
    this.annex = new Annex<{}>(this);
  }

  function wakeup() {
    computation.wakeup();
    hot = true;
    if (subscriptions != null)
      for (s in subscriptions) s.connect();
    getValue();
    getRevision();
  }

  function sleep() {
    computation.sleep();
    hot = false;
    if (subscriptions != null)
      for (s in subscriptions) s.disconnect();
  }

  static public function computeFor<T>(o:Derived, fn:()->T) {
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
    return inline computeFor(null, fn);

  static public inline function needsTracking<V>(o:ObservableObject<V>):Bool
    return switch cur {
      case null: false;
      case v: !v.isSubscribedTo(o);
    }

  static public function currentAnnex()
    return switch cur {
      case null: null;
      case v: v.getAnnex();
    }

  static public inline function track<V>(o:ObservableObject<V>):V {
    var ret = o.getValue();
    if (cur != null && o.canFire())
      cur.subscribeTo(o, ret);
    return ret;
  }

  function triggerAsync(v:T) {
    last = v;
    fire(this);
  }

  public function getValue():T {

    function doCompute() {
      status = Computed;
      var prevSubs = subscriptions;
      if (prevSubs != null)
        for (s in prevSubs) s.used = false;
      subscriptions = [];
      last = computeFor(this, () -> computation.getNext());

      #if tink_state.debug
      logger.revalidated(this, false);
      #end

      if (prevSubs != null)
        for (s in prevSubs)
          if (!s.used) {
            #if tink_state.debug
              logger.unsubscribed(s.source, this);
            #end
            dependencies.remove(s.source);
            if (hot) s.disconnect();
            s.release();
          }

      if (subscriptions.length == 0) dispose();
    }

    var count = 0;

    while (!isValid()) {
      #if tink_state.debug
      logger.revalidating(this);
      #end
      var prevSubs = subscriptions;

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
        else doCompute();
      }
      else doCompute();
    }
    return last;
  }

  public function subscribeTo<R>(source:ObservableObject<R>, cur:R):Void
    switch dependencies.get(source) {
      case null:
        #if tink_state.debug
          logger.subscribed(source, this);
        #end
        var sub:Subscription = new Subscription(source, cur, this);
        source.retain();
        if (hot) sub.connect();
        dependencies.set(source, sub);
        subscriptions.push(sub);
      case v:
        if (!v.used) {
          v.reuse(cur);
          subscriptions.push(v);
        }
    }

  public function isSubscribedTo<R>(source:ObservableObject<R>)
    return switch dependencies.get(source) {
      case null: false;
      case s: s.used;
    }

  public function notify<R>(from:ObservableObject<R>)
    if (status == Computed) {
      status = Dirty;
      fire(this);
    }

  #if tink_state.debug
  public function getDependencies()
    return cast dependencies.keys();
  #end
}

private interface Derived {
  function getAnnex():Annex<{}>;
  function isSubscribedTo<R>(source:ObservableObject<R>):Bool;
  function subscribeTo<R>(source:ObservableObject<R>, cur:R):Void;
}


private class Subscription {

  public final source:ObservableObject<Dynamic>;
  var last:Any;
  var lastRev:Revision;
  final owner:Observer;

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

  public inline function reuse(value:Any) {
    used = true;
    last = value;
  }

  public inline function disconnect():Void {
    #if tink_state.debug
      logger.disconnected(source, cast owner);
    #end
    source.unsubscribe(owner);
  }

  public inline function connect():Void {
    #if tink_state.debug
      logger.connected(source, cast owner);
    #end
    source.subscribe(owner);
  }

  public inline function release() {
    source.release();
  }
}

private enum abstract AutoObservableStatus(Int) {
  var Dirty;
  var Computed;
}