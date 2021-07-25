package tink.state.internal;

abstract Computation<Data, Result>(ComputationKind<Data, Result>) {

  inline function new(v)
    this = v;

  public inline function kind()
    return this;

  @:from static function ofAsyncWithLast<Data>(f:(last:Option<Data>)->Promise<Data>):Computation<Data, Promised<Data>>
    return new Computation(AsyncWithLast(f));

  @:from static function ofAsync<Data>(f:()->Promise<Data>):Computation<Data, Promised<Data>>
    return new Computation(Async(f));

  @:from static function ofSafeAsyncWithLast<Data>(f:(last:Option<Data>)->Future<Data>):Computation<Data, Predicted<Data>>
    return new Computation(SafeAsyncWithLast(f));

  @:from static function ofSafeAsync<Data>(f:()->Future<Data>):Computation<Data, Predicted<Data>>
    return new Computation(SafeAsync(f));

  @:from static function ofSync<Data>(f:()->Data):Computation<Data, Data>
    return new Computation(Sync(f));

  @:from static function ofSyncWithLast<Data>(f:(last:Option<Data>)->Data):Computation<Data, Data>
    return new Computation(SyncWithLast(f));
}

enum ComputationKind<Data, Result> {
  Sync(f:()->Data):ComputationKind<Data, Data>;
  SyncWithLast(f:(last:Option<Data>)->Data):ComputationKind<Data, Data>;
  Async(f:()->Promise<Data>):ComputationKind<Data, Promised<Data>>;
  AsyncWithLast(f:(last:Option<Result>)->Promise<Result>):ComputationKind<Data, Promised<Data>>;
  SafeAsync(f:()->Future<Result>):ComputationKind<Data, Predicted<Data>>;
  SafeAsyncWithLast(f:(last:Option<Result>)->Future<Result>):ComputationKind<Data, Predicted<Data>>;
}