package tink.state.internal;

#if tink_state.debug
import tink.state.debug.Logger.inst as logger;
#end
import tink.core.Annex;

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

private enum abstract AutoObservableStatus(Int) {
  var Dirty;
  var Computed;
}

private typedef Source = ObservableObject<Dynamic>;
class AutoObservable<T> extends Dispatcher
  implements Observer implements Derived implements ObservableObject<T> {

  static var cur:Derived;

  var compute:Computation<T>;
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
  var sources:Array<Source>;
  var lastValues = new ObjectMap<Source, Dynamic>();
  var lastRevisions = new ObjectMap<Source, Revision>();

  var comparator:Comparator<T>;

  override function getRevision() {
    if (hot)
      return revision;
    if (sources == null)
      getValue();

    for (s in sources)
      if (s.getRevision() > lastRevisions[s])
        return revision = new Revision();

    return revision;
  }

  public function getAnnex()
    return annex;

  function subsValid() {
    if (sources == null)
      return false;

    for (s in sources)
      if (s.getRevision() != lastRevisions[s])
        return false;

    return true;
  }

  public function isValid()
    return status != Dirty && (hot || subsValid());

  public function getComparator()
    return comparator;

  public function new(compute, ?comparator #if tink_state.debug , ?toString, ?pos:haxe.PosInfos #end) {
    super(active -> if (active) wakeup() else sleep() #if tink_state.debug , toString, pos #end);
    this.compute = compute;
    this.comparator = comparator;
    this.annex = new Annex<{}>(this);
  }

  inline function connect(s:Source) {
    #if tink_state.debug
      logger.connected(s, this);
    #end
    s.subscribe(this);
  }

  inline function disconnect(s:Source):Void {
    #if tink_state.debug
      logger.disconnected(s, this);
    #end
    s.unsubscribe(this);
  }

  function wakeup() {
    getValue();
    getRevision();
    if (sources != null)
      for (s in sources) connect(s);
    hot = true;
  }


  function sleep() {
    hot = false;
    if (sources != null)
      for (s in sources) disconnect(s);
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

  public function getValue():T {

    function doCompute() {
      status = Computed;
      if (sources != null)
        lastValues.clear();// TODO: this might actually cause some churn ... who knows
      sources = [];
      sync = true;
      last = computeFor(this, () -> compute(this));
      sync = false;
      #if tink_state.debug
      logger.revalidated(this, false);
      #end
      if (sources.length == 0) dispose();
    }

    var prevSources = sources,
        count = 0;

    while (!isValid()) {
      #if tink_state.debug
      logger.revalidating(this);
      #end
      if (++count == Observable.MAX_ITERATIONS)
        throw 'no result after ${Observable.MAX_ITERATIONS} attempts';
      else if (sources != null) {
        var valid = true;

        for (s in sources)
          if (hasChanged(s)) {
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
          if (prevSources != null) {
            for (s in prevSources)
              if (!isUsed(s)) {
                if (hot) disconnect(s);
                lastRevisions.remove(s);
                s.release();
                #if tink_state.debug
                  logger.unsubscribed(s, this);
                #end
              }
          }
        }
      }
      else doCompute();
    }
    return last;
  }

  public function hasChanged<R>(s:ObservableObject<R>):Bool {
    var nextRev = s.getRevision();
    if (nextRev == lastRevisions[s]) return false;
    lastRevisions[s] = nextRev;
    var before:R = lastValues[s];
    var last = s.getValue();
    lastValues[s] = last;
    return !s.getComparator().eq(last, before);
  }

  var sync = true;

  function update(value) if (!sync) {
    last = value;
    fire(this);
  }

  inline function isUsed(s:Source)
    return lastValues.exists(s);

  public function subscribeTo<R>(source:ObservableObject<R>, cur:R):Void
    switch lastRevisions[source] {
      case null:
        #if tink_state.debug
          logger.subscribed(source, this);
        #end
        lastRevisions[source] = source.getRevision();
        lastValues[source] = cur;
        source.retain();
        if (hot) connect(source);
        sources.push(source);
      case v:
        if (!isUsed(source)) {
          lastValues[source] = cur;
          sources.push(source);
        }
    }

  public function isSubscribedTo<R>(source:ObservableObject<R>)
    return isUsed(source);

  public function notify(from)
    if (status == Computed) {
      status = Dirty;
      fire(this);
    }

  #if tink_state.debug
  public function getDependencies()
    return sources.iterator();
  #end
}

private interface Derived {
  function getAnnex():Annex<{}>;
  function isSubscribedTo<R>(source:ObservableObject<R>):Bool;
  function subscribeTo<R>(source:ObservableObject<R>, cur:R):Void;
}