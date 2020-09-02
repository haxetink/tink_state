package tink.state.internal;

abstract Revision(Float) {//TODO: use Int64 where it's faster and perhaps plain Int on python
  static var counter = .0;
  static public final ZERO = new Revision();
  public inline function new()
    this = counter++;
  @:op(a < b) static function lt(a:Revision, b:Revision):Bool;
  @:op(a <= b) static function lte(a:Revision, b:Revision):Bool;
  @:op(a > b) static function gt(a:Revision, b:Revision):Bool;
  @:op(a >= b) static function gte(a:Revision, b:Revision):Bool;
  @:op(a == b) static function eq(a:Revision, b:Revision):Bool;
  @:op(a != b) static function neq(a:Revision, b:Revision):Bool;
  @:op(a * b) static inline function join(a:Revision, b:Revision):Revision
    return if (a > b) a else b;
}