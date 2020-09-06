package tink.state;

using tink.CoreApi;

@:deprecated
abstract Measurement<T>(Pair<T, Future<Noise>>) {

  public var value(get, never):T;
    inline function get_value() return this.a;

  public var becameInvalid(get, never):Future<Noise>;
    inline function get_becameInvalid() return this.b;

  public inline function new(value, becameInvalid)
    this = new Pair(value, becameInvalid);
}