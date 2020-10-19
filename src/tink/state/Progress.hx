package tink.state;

import tink.core.Pair;
import tink.core.Progress as Plain;
import tink.core.Progress.ProgressTrigger as Trigger;
import tink.state.Observable;

@:require(tink_core >= 2)
@:forward
abstract Progress<T>(Plain<T>) from Plain<T> to Plain<T> {
  static public var INIT(default, null):ProgressValue = new Pair(0.0, None);

  static public inline function trigger<T>():ProgressTrigger<T> {
    return new ProgressTrigger();
  }

  static public function make<T>(f:(progress:(value:Float, total:Option<Float>)->Void, finish:(result:T)->Void)->CallbackLink):Progress<T>
    return Plain.make(f);

  @:from
  static inline function promise<T>(v:Promise<Progress<T>>):Progress<Outcome<T, Error>>
    return ((cast v:Promise<Plain<T>>):Plain<Outcome<T, Error>>);

  @:from
  static inline function flatten<T>(v:Promise<Progress<Outcome<T, Error>>>):Progress<Outcome<T, Error>>
    return @:privateAccess Plain.flatten(cast v);

  @:from
  static inline function future<T>(v:Future<Progress<T>>):Progress<T>
  	return ((cast v:Future<Plain<T>>):Plain<T>);

  public inline function next(f)
    return this.result.next(f);

  public inline function observe():Observable<ProgressStatus<T>>
    return switch this.result.status {
      case Ready(l): Observable.const(Finished(l.get()));
      default: new Observable(() -> this.status, this.changed.noise());
    }

  public inline function bind(#if tink_state.legacy_binding_options ?options, #end cb, ?comparator, ?scheduler)
    return observe().bind(#if tink_state.legacy_binding_options options, #end cb, comparator, scheduler);
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