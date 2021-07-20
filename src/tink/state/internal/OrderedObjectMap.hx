package tink.state.internal;

@:forward(iterator, exists, clear)
abstract OrderedObjectMap<K:{}, V>(Impl<K, V>) {
  public var size(get, never):Int;
    inline function get_size()
      return this.count;

  public inline function new()
    this = new Impl<K, V>();

  @:op([]) public inline function get(key:K)
    return this.get(key);

  public inline function keys()
    return this.compact().iterator();

  public function iterator()
    return new ImplIterator(this);

  @:op([]) public function set(key, value) {
    if (!this.exists(key))
      this.keyOrder.push(key);
    this.set(key, value);
    return value;
  }

  public inline function remove(key)
    return this.remove(key) && this.substrac(key);

  public inline function forEach(f)
    for (k in this.compact()) f(get(k), k, (cast this:ObjectMap<K,V>));

  public inline function count()
    return this.count;

}

private class Impl<K:{}, V> extends haxe.ds.ObjectMap<K, V> {
  public final keyOrder:Array<K> = [];
  public var count:Int = 0;
  public inline function add(key:K)
    count = keyOrder.push(key);

  public function compact() {
    if (count > keyOrder.length) {
      var pos = 0;
      for (k in keyOrder)
        if (k != null)
          keyOrder[pos++] = k;
      keyOrder.resize(count);
    }
    return keyOrder;
  }

  public function subtract(key:K) {
    keyOrder[keyOrder.indexOf(key)] = null;
    count--;
    return true;
  }
}

class ImplIterator<K:{}, V> {
  final keys:Array<K>;
  final target:haxe.ds.ObjectMap<K, V>;
  var pos = 0;
  public inline function new(i:Impl<K, V>) {
    this.keys = i.compact();
    this.target = i;
  }

  public inline function hasNext()
    return pos < keys.length;

  public inline function next()
    return target.get(keys[pos++]);
}