package tink.state.internal;

@:forward(iterator, exists, clear)
abstract OrderedObjectMap<K:{}, V>(Impl<K, V>) {
  public var size(get, never):Int;
    inline function get_size()
      return this.keyCount;

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
      this.add(key);
    this.set(key, value);
    return value;
  }

  public inline function remove(key)
    return this.remove(key) && this.subtract(key);

  public inline function forEach(f)
    for (k in this.compact()) f(get(k), k, (cast this:ObjectMap<K,V>));

  public inline function count()
    return this.keyCount;

}

private class Impl<K:{}, V> extends haxe.ds.ObjectMap<K, V> {
  public final keyOrder:Array<K> = [];
  public var keyCount:Int = 0;
  public inline function add(key:K) {
    keyOrder.push(key);
    keyCount++;
  }

  public function compact() {
    if (keyCount < keyOrder.length) {
      var pos = 0;
      for (k in keyOrder)
        if (k != null)
          keyOrder[pos++] = k;
      keyOrder.resize(keyCount);
    }
    return keyOrder;
  }

  public function subtract(key:K) {
    keyOrder[keyOrder.indexOf(key)] = null;
    keyCount--;
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