package tink.state;

import tink.state.Observable;
import tink.core.Progress as Plain;
import tink.core.Progress.ProgressTrigger as Trigger;
import tink.core.Callback;

using tink.CoreApi;

// @:forward(result, bind)
@:require(tink_core >= 2)
@:forward
abstract Progress<T>(Plain<T>) from Plain<T> to Plain<T> {
  static public var INIT(default, null):ProgressValue = new Pair(0.0, None);

  static public inline function trigger<T>():ProgressTrigger<T> {
    return new ProgressTrigger();
  }

  static public function make<T>(f:(progress:(value:Float, total:Option<Float>)->Void, finish:(result:T)->Void)->CallbackLink):Progress<T>
    return Plain.make(f);

  // @:impl
  // public static inline function asPromise<T>(p:ProgressObject<Outcome<T, Error>>):Promise<T>
  // 	return p.result();

  @:from
  static inline function promise<T>(v:Promise<Progress<T>>):Progress<Outcome<T, Error>>
    return ((v:Promise<Plain<T>>):Plain<Outcome<T, Error>>);

  @:from
  static inline function flatten<T>(v:Promise<Progress<Outcome<T, Error>>>):Progress<Outcome<T, Error>>
    return @:privateAccess Plain.flatten(v);

  @:from
  static inline function future<T>(v:Future<Progress<T>>):Progress<T>
  	return ((v:Future<Plain<T>>):Plain<T>);

  public inline function next(f)
    return this.result.next(f);

  public inline function observe():Observable<ProgressStatus<T>>
    return switch this.result.status {
      case Ready(l): Observable.const(Finished(l.get()));
      default: new Observable(() -> this.status, new Signal(fire -> this.listen(function (_) fire(Noise)) & this.handle(function (_) fire(Noise))));
    }

  public inline function bind(?options, cb)
    return observe().bind(options, cb);
}

typedef ProgressValue = tink.core.Progress.ProgressValue;
typedef ProgressStatus<T> = tink.core.Progress.ProgressStatus<T>;
@:deprecated typedef ProgressType<T> = ProgressStatus<T>;

@:forward
abstract ProgressTrigger<T>(Trigger<T>) from Trigger<T> to Trigger<T> {
  public inline function new()
    this = new Trigger();

  public inline function asProgress():Progress<T> {
    return this.asProgress();
  }
}