package tink.state.internal;

abstract Revision(Float) {//TODO: use Int64 where it's faster and perhaps plain Int on python
  static public inline var ZERO:Revision = cast .0;
  static var counter:Float;
  #if !eval
  static function __init__()
    counter = .0;
  #end

  public function new() {
    #if eval if (Math.isNaN(counter)) counter = .0; #end
    this = counter+=1.0;
  }

  @:op(a < b) static function lt(a:Revision, b:Revision):Bool;
  @:op(a <= b) static function lte(a:Revision, b:Revision):Bool;
  @:op(a > b) static function gt(a:Revision, b:Revision):Bool;
  @:op(a >= b) static function gte(a:Revision, b:Revision):Bool;
  @:op(a == b) static function eq(a:Revision, b:Revision):Bool;
  @:op(a != b) static function neq(a:Revision, b:Revision):Bool;
  @:op(a * b) static inline function join(a:Revision, b:Revision):Revision
    return if (a > b) a else b;
}