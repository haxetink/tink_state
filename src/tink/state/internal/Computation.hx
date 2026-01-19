package tink.state.internal;

@:callable
@:access(tink.state.internal.AutoObservable)
abstract Computation<T>((a:AutoObservable<T>,?Noise)->T) {
  inline function new(f) this = f;

  @:from static function asyncWithLast<T>(f:Option<T>->Promise<T>):Computation<Promised<T>> {
    var link:CallbackLink = null,
        last = None,
        ret = Loading;
    return new Computation((a, ?_) -> {
      a.waiting = true;
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
      a.waiting = true;
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
      a.waiting = true;
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
