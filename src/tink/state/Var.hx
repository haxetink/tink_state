package tink.state;

@:forward
abstract Var<T>(Observable<T>) from Observable<T> to Observable<T> {
  
  @:from static function ofConst<T>(value:T):Var<T>
    return Observable.const(value);

  @:op(a == b) static function equals<T>(a:Var<T>, b:Var<T>):Bool
    return switch [a, b] {
      case [null, null]: true;
      case [v, null] | [null, v]: v.value == null;
      default: a.value == b.value;
    }

  @:op(a != b) static inline function nequals<T>(a:Var<T>, b:Var<T>):Bool
    return !equals(a, b);  
}