package tink.state;

abstract Comparator<T>(Null<(T,T)->Bool>) from (T,T)->Bool {
  public inline function eq(a:T, b:T)
    return switch this {
      case null: a == b;
      case f: f(a, b);
    }

  inline function unpack()
    return this;

  @:op(a && b) public inline function and(that:Comparator<T>):Comparator<T>
    return switch [this, that.unpack()] {
      case [null, v] | [v, null]: v;
      case [c1, c2]: (a, b) -> c1(a, b) && c2(a, b);
    }

  @:op(a || b) public inline function or(that:Comparator<T>):Comparator<T>
    return switch [this, that.unpack()] {
      case [null, v] | [v, null]: v;
      case [c1, c2]: (a, b) -> c1(a, b) || c2(a, b);
    }
}