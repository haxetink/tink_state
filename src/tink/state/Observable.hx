package tink.state;

private typedef BindingOptions<T> = Deprecated<{
  ?direct:Bool,
  ?comparator:T->T->Bool,
}>;

@:forward
abstract Deprecated<T>(T) {
  @:deprecated
  @:from static function of<X>(v:X):Deprecated<X>
    return cast v;
}

/**
  Common representation of a piece of observable state. It can be read using the `value` property
  and bound to listen for changes using the `bind` method.

  For the writable variant, see `State`.
**/
#if tink_state.debug
  @:forward(toString)
#end
@:using(tink.state.Observable.ObservableTools)
abstract Observable<T>(ObservableObject<T>) from ObservableObject<T> to ObservableObject<T> {
  public static var MAX_ITERATIONS = 100;

  /**
    Current value of this Observable. Depending on the nature of an underlying object, accessing
    this property may trigger recomputation of the value.

    If accessed from within `Observable.auto` computation, this observable will be tracked for changes
    by the interested auto-observable.
  **/
  public var value(get, never):T;
    @:to function get_value()
      return AutoObservable.track(this);

  static public inline function untracked<T>(fn:Void->T)
    return AutoObservable.untracked(fn);

  /**
    Bind a given `callback` to listen for changes of this observable. Returned `CallbackLink`
    object can be used to cancel the binding.

    The `callback` will be directly invoked with the current value for the first time and then
    will be invoked each time the binding is triggered by a value change.

    Note that the subsequent invokations of callbacks are done in batches, meaning that changed
    values are collected during an execution frame and are scheduled for processing at the end of
    the frame (the exact scheduling mechanism depends the platform).

    It is also doesn't matter how many times the value was changed before the callback is invoked,
    it will only be called once per batch if the final value is different from the previous one.

    You can customize this behaviour by passing a different `scheduler` and `comparator` instances
    to this function.
  **/
  public function bind(
    #if tink_state.legacy_binding_options ?options:BindingOptions<T>, #end
    callback:Callback<T>, ?comparator:Comparator<T>, ?scheduler:Scheduler
  ):CallbackLink {
    #if tink_state.legacy_binding_options
      if (options != null) {
        comparator = options.comparator;
        if (options.direct) scheduler = Scheduler.direct;
      }
    #end
    if (scheduler == null)
      scheduler = Observable.scheduler;
    return Binding.create(this, callback, scheduler, comparator);
  }

  public inline function new(get:Void->T, changed:Signal<Noise>, ?toString #if tink_state.debug , ?pos:haxe.PosInfos #end)
    this = new SignalObservable(get, changed, toString #if tink_state.debug , pos #end);

  public function combine<A, R>(that:Observable<A>, f:T->A->R):Observable<R>
    return Observable.auto(() -> f(value, that.value));

  /**
   * Be careful with `butNotNow`, its semantics are a bit counter-intuitive:
   * If the condition returns true for the current value, it will skip the current value,
   * then all future values as long as the condition keeps returning true,
   * then the first and all consecutive future values for which the condition returns false.
   * Example: If the condition is `v -> v > 0`, and the values sequence is [ 0, 10, 20, -1, -2, 42 ],
   * the future will resolve to 42.
   */
  public function nextTime(?options:{ ?butNotNow: Bool, ?hires:Bool }, ?condition:T->Bool):Future<T>
    return
      if (condition == null) {
        var i = 0;
        getNext({ butNotNow: true, hires: options?.hires ?? false }, v -> if (i++ == 0) None else Some(v));
      }
      else getNext(options, v -> if (condition(v)) Some(v) else None);

  // Be careful with `butNotNow`, its semantics has the same peculiarity as when using `nextTime`, see the comments above.
  public function getNext<R>(?options:{ ?butNotNow: Bool, ?hires:Bool }, select:T->Option<R>):Future<R> {
    var ret = Future.trigger(),
        waiting = options?.butNotNow;

    var link = bind(value -> {
      var out = select(value);
      if (waiting)
        waiting = out != None;
      else switch out {
        case Some(value): ret.trigger(value);
        case None:
      }
    }, if (options?.hires) Scheduler.direct else null);

    ret.handle(link.cancel);

    return ret;
  }

  public function join(that:Observable<T>) {
    var lastA = null;
    return combine(that, (a, b) -> {
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
    return Observable.auto(() -> f.apply(value));

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
      Scheduler.direct;
    #else
      Scheduler.batched(Scheduler.batcher());
    #end

  static public inline function schedule(f:Void->Void)
    scheduler.run(f);

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

  static function ignore(i:Int) {}

  /**
    Invoke the given `callback` and track all its observable value access in the same way `Observable.auto` does.

    When any of the tracked values changes, the callback will be scheduled to run again, in same way as `bind`,
    you can customize scheduling by passing a different `scheduler`.

    Returned `CallbackLink` object can be used to cancel the binding.
  **/
  static public function autorun(callback:()->Void, ?scheduler):CallbackLink {
    var i = 0;
    return auto(() -> {
      callback();
      i++;
    }).bind(ignore, null, scheduler);
  }

  @:deprecated
  static public function create<T>(f, ?comparator #if tink_state.debug , ?toString, ?pos:haxe.PosInfos #end):Observable<T>
    return new SimpleObservable(f, comparator #if tink_state.debug , toString, pos #end);

  /**
    Create a computed observable from a given `compute` function. The computation will be invoked when
    the observable value is first read and its result will be cached for subsequent reads.

    Accessing other Observable values within computation function will be automatically tracked and if any of
    the tracked Observable values are changed, cached value will be invalided and bindings will be triggered.

    Note that if a given computation function returns `tink.core.Promise` or `tink.core.Future`, special handling
    will take place and the type of the observable value will become `tink.state.Promised` or `tink.State.Promised.Predicted`
    respectively. The future/promise will be automatically handled to update the value of this Observable.
  **/
  @:noUsing static public inline function auto<T>(compute, ?comparator #if tink_state.debug , ?toString, ?pos:haxe.PosInfos #end):Observable<T>
    return new AutoObservable<T>(compute, comparator #if tink_state.debug , toString, pos #end);

  /**
    Create a constant Observable object from a value. Const observables are lightweight objects
    that will never invalidate and will always simply return the value passed to this constructor.
  **/
  @:noUsing static public inline function const<T>(value:T #if tink_state.debug , ?toString, ?pos:haxe.PosInfos #end):Observable<T>
    return new ConstObservable(value #if tink_state.debug , toString, pos #end);

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

  #if tink_state.debug
    public function dependencyTree():DependencyTree
      return new DependencyTree(cast this);
  #end

}

#if tink_state.debug
  class DependencyTree {

    public final source:Observable<Dynamic>;
    public final dependencies:haxe.ds.ReadOnlyArray<DependencyTree>;

    public function new(source:ObservableObject<Dynamic>) {
      this.source = source;
      this.dependencies = [for (dep in source.getDependencies()) dep.dependencyTree()];
    }

    function print(prefix:String, buf:StringBuf) {

      buf.add(prefix);
      buf.add(source.toString());

      prefix += '  ';
      for (d in dependencies) {
        buf.add('\n');
        d.print(prefix, buf);
      }
    }

    public function toString() {
      var buf = new StringBuf();
      print('', buf);
      return buf.toString();
    }
  }
#end

private class ConstObservable<T> implements ObservableObject<T> {
  final value:T;
  final revision = new Revision();

  public function getRevision()
    return revision;

  public function canFire()
    return true;

  public function new(value, ?toString:()->String #if tink_state.debug , ?pos:haxe.PosInfos #end) {
    this.value = value;
    #if tink_state.debug
    this._toString =
      switch toString {
        case null: () -> 'Constant[$value](${pos.fileName}:${pos.lineNumber}';
        case v: v;
      }
    #end
  }

  public function getValue()
    return value;

  public function isValid()
    return true;

  public function getComparator():Comparator<T>
    return null;

  #if tink_state.debug
  final _toString:()->String;
  public function toString()
    return _toString();

  public function getObservers()
    return EmptyIterator.OBSERVERS;

  public function getDependencies()
    return EmptyIterator.DEPENDENCIES;
  #end

  public function onInvalidate(i:Invalidatable):CallbackLink
    return null;
}

private class SimpleObservable<T> extends Invalidator implements ObservableObject<T> {

  var _poll:Void->Measurement<T>;
  var _cache:Measurement<T> = null;
  var comparator:Comparator<T>;

  public function new(poll, ?comparator #if tink_state.debug , ?toString, ?pos #end) {
    super(#if tink_state.debug toString, pos #end);
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
      if (++count == Observable.MAX_ITERATIONS)
        throw 'polling did not conclude after ${Observable.MAX_ITERATIONS} iterations';
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
    return EmptyIterator.DEPENDENCIES;
  #end
}

@:access(tink.state.Observable)
class ObservableTools {

  static public function deliver<T, E>(o:Observable<Promised.PromisedWith<T, E>>, initial:T, ?failed:Error->T->T):Observable<T>
    return Observable.lift(o).map(p -> switch p {
      case Done(v): initial = v;
      case Loading: initial;
      case Failed(e): if (failed != null) initial = failed(e, initial) else initial;
    });

  static public function flatten<T>(o:Observable<Observable<T>>)
    return Observable.auto(() -> Observable.lift(o).value.value);

}
