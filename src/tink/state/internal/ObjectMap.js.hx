package tink.state.internal;

import js.lib.*;

@:forward(clear, size)
abstract ObjectMap<K:{}, V>(Map<K, V>) {
  public inline function new()
    this = new Map<K, V>();

  @:op([]) public inline function get(key)
    return this.get(key);

  @:op([]) public inline function set(key, value) {
    this.set(key, value);
    return value;
  }

  public inline function exists(key)
    return this.has(key);

  public function keys():Iterator<K>
    return
      try new HaxeIterator(this.keys())
      catch (e:Dynamic) {// because IE11
        var ret = [];
        forEach((_, k, _) -> ret.push(k));
        ret.iterator();
      }

  public function iterator():Iterator<V>
    return
      try new HaxeIterator(this.values())
      catch (e:Dynamic) {// because IE11
        var ret = [];
        forEach((v, _, _) -> ret.push(v));
        ret.iterator();
      }

  public inline function remove(key)
    return this.delete(key);

  public inline function forEach(f:V->K->ObjectMap<K, V>->Void)
    this.forEach(cast f);

  public inline function count()
    return this.size;
}