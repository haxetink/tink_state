package tink.state.internal;

@:forward
abstract Computation<Result>(ComputationObject<Result>) from ComputationObject<Result> {

  inline function new(v)
    this = v;

  @:from static function ofAsyncWithLast<Data>(f:(last:Option<Data>)->Promise<Data>):Computation<Promised<Data>>
    return new AsyncWithLast(f);

  @:from static function ofAsync<Data>(f:()->Promise<Data>):Computation<Promised<Data>>
    return new Async(f);

  @:from static function ofSafeAsyncWithLast<Data>(f:(last:Option<Data>)->Future<Data>):Computation<Predicted<Data>>
    return new SafeAsyncWithLast(f);

  @:from static function ofSafeAsync<Data>(f:()->Future<Data>):Computation<Predicted<Data>>
    return new SafeAsync(f);

  @:from static function ofSync<Data>(f:()->Data):Computation<Data>
    return new Sync(f);

  @:from static function ofSyncWithLast<Data>(f:(last:Option<Data>)->Data):Computation<Data>
    return new SyncWithLast(f);

}

/**
 * This whole part is pretty dirty, but it's well suited to avoid having too much state in AutoObservable.
 * To avoid doing so, the computation itself is allowed to be stateful:
 *
 * - Stateless computations will return themselves when initialized with any owner.
 * - Stateful computations start out ownerless, but when initialized a second time,
 *   will return a copy of themselves with a different owner.
 *
 * There is some pretty horrible coupling going on. In particular, AutoObservable will only call sleep/wakeup
 * from its own sleep/wakup. When calling getNext, it expects the computation to arrange its internal state
 * based on whether the owner is hot or not. This is really only necessary for async computations and it's luckily
 * unified in the heavy handed generalization that is AsyncBase.
 */
private interface ComputationObject<Result> {
  function init(owner:AutoObservable<Result>):ComputationObject<Result>;
  function getNext():Result;
  function wakeup():Void;
  function sleep():Void;
}

private abstract class StatefulBase<Result> implements ComputationObject<Result> {
  var owner:AutoObservable<Result> = null;
  function new(?owner)
    this.owner = owner;

  public function init(owner:AutoObservable<Result>):ComputationObject<Result>
    return switch owner {
      case null:
        this.owner = owner;
        this;
      case _ == this.owner => true: // unlikely, but who knows ...
        this;
      default: cloneFor(owner);
    }

  abstract function cloneFor(owner:AutoObservable<Result>):ComputationObject<Result>;
  abstract public function getNext():Result;

  public function wakeup():Void {}
  public function sleep():Void {}

}

private class Async<T> extends AsyncBase<T, Error, Outcome<T, Error>, Promise<T>> {
  final get:()->Promise<T>;

  public function new(get, ?owner) {
    super(owner);
    this.get = get;
  }

  function cloneFor(owner:AutoObservable<Promised<T>>):ComputationObject<Promised<T>>
    return new Async(get, owner);

  function pull():Promise<T>
    return get();

  function wrap(raw:Outcome<T, Error>):Promised<T>
    return switch raw {
      case Success(v):
        Done(v);
      case Failure(e):
        Failed(e);
    }
}

private class AsyncWithLast<T> extends AsyncBase<T, Error, Outcome<T, Error>, Promise<T>> {
  final get:(o:Option<T>)->Promise<T>;
  var last = None;

  public function new(get, ?owner) {
    super(owner);
    this.get = get;
  }

  function cloneFor(owner:AutoObservable<Promised<T>>):ComputationObject<Promised<T>>
    return new AsyncWithLast(get, owner);

  function pull():Promise<T>
    return get(last);

  function wrap(raw:Outcome<T, Error>):Promised<T>
    return switch raw {
      case Success(v):
        last = Some(v);
        Done(v);
      case Failure(e):
        Failed(e);
    }
}

abstract private class AsyncBase<T, E, Raw, Result:Future<Raw>> extends StatefulBase<PromisedWith<T, E>> {

  var result:Result;
  var link:CallbackLink;
  var sync = false;

  abstract function pull():Result;
  abstract function wrap(raw:Raw):PromisedWith<T, E>;

  public function getNext():PromisedWith<T, E> {
    var prev = result;
    result = pull();

    if (result != prev && owner.hot) {
      link.cancel();
      listen(result);
    }

    return switch result.status {
      case Ready(v) if (v.computed):
        wrap(v.get());
      default: Loading;
    }
  }

  override function sleep()
    link.cancel();

  inline function listen(r:Result) {
    sync = true;
    link = r.handle(o -> if (!sync) owner.triggerAsync(wrap(o)));
    sync = false;
  }

  override function wakeup()
    switch result {
      case null:
      case p: listen(p);
    }
}

private class Sync<T> implements ComputationObject<T> {

  final get:()->T;

  public function new(get)
    this.get = get;

  public function init(_)
    return this;

  public function getNext():T
    return get();

  public function sleep() {}
  public function wakeup() {}
}

private class SyncWithLast<T> extends StatefulBase<T> {
  final get:Option<T>->T;
  var last = None;

  public function new(get, ?owner) {
    super(owner);
    this.get = get;
  }

  function cloneFor(owner:AutoObservable<T>):ComputationObject<T>
    return new SyncWithLast(get, owner);

  public function getNext():T {
    var ret = get(last);
    last = Some(ret);
    return ret;
  }
}


private class SafeAsync<T> extends AsyncBase<T, Noise, T, Future<T>> {
  final get:()->Future<T>;

  public function new(get, ?owner) {
    super(owner);
    this.get = get;
  }

  function cloneFor(owner:AutoObservable<Predicted<T>>):ComputationObject<Predicted<T>>
    return new SafeAsync(get, owner);

  function pull():Future<T>
    return get();

  function wrap(raw:T):Predicted<T>
    return Done(raw);
}

private class SafeAsyncWithLast<T> extends AsyncBase<T, Noise, T, Future<T>> {
  final get:(o:Option<T>)->Future<T>;
  var last = None;

  public function new(get, ?owner) {
    super(owner);
    this.get = get;
  }

  function cloneFor(owner:AutoObservable<Predicted<T>>):ComputationObject<Predicted<T>>
    return new SafeAsyncWithLast(get, owner);

  function pull():Future<T>
    return get(last);

  function wrap(raw:T):Predicted<T> {
    last = Some(raw);
    return Done(raw);
  }
}