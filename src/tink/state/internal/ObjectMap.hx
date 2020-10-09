package tink.state.internal;

@:forward(keys, exists)
abstract ObjectMap<K:{}, V>(haxe.ds.ObjectMap<K, V>) {
  public inline function new()
    this = new haxe.ds.ObjectMap<K, V>();

  @:op([]) public inline function get(key)
    return this.get(key);

  @:op([]) public inline function set(key, value) {
    this.set(key, value);
    return value;
  }

  public inline function remove(key)
    return this.remove(key);

  public inline function forEach(f)
    for (k => v in this) f(v, k, (cast this:ObjectMap<K,V>));

}