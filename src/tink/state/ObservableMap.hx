package tink.state;

import haxe.Constraints.IMap;
import tink.state.Invalidatable;
import tink.state.Observable;
import haxe.iterators.*;

@:forward
abstract ObservableMap<K, V>(MapImpl<K, V>) from MapImpl<K, V> to IMap<K, V> {
  public function new(init:Map<K, V>)
    this = new MapImpl(init.copy());

  @:op([]) public inline function get(index)
    return this.get(index);

  @:op([]) public inline function set(index, value) {
    this.set(index, value);
    return value;
  }

  public function toMap():Map<K, V>
    return cast this.copy();

  public function copy():ObservableMap<K, V>
    return new MapImpl(cast this.copy());

  public function entry(key:K)
    return Observable.auto(this.get.bind(key));
}

private typedef Self<K, V> = Iterable<V> & KeyValueIterable<K, V>;

private class MapImpl<K, V> extends Invalidator implements ObservableObject<Self<K, V>> implements IMap<K, V> {

  var valid = false;
  var entries:Map<K, V>;

  public function new(entries:Map<K, V>)
    this.entries = entries;

  public function observe():Observable<Self<K, V>>
    return this;

  public function isValid():Bool
    return valid;

  public function getValue():Self<K, V>
    return this;

  public function get(k:K):Null<V>
    return calc(() -> entries.get(k));

  public function set(k:K, v:V):Void
    update(() -> { entries.set(k, v); null; });

  public function exists(k:K):Bool
    return calc(() -> entries.exists(k));

  public function remove(k:K):Bool
    return update(() -> entries.remove(k));

  public function keys():Iterator<K>
    return calc(() -> entries.keys());

  public function iterator():Iterator<V>
    return calc(() -> entries.iterator());

  public function keyValueIterator():KeyValueIterator<K, V>
    return calc(() -> entries.keyValueIterator());

  public function copy():IMap<K, V>
    return cast calc(() -> entries.copy());

  public function toString():String
    return calc(() -> entries.toString());

  public function clear():Void
    update(() -> { entries.clear(); null; });

  function neverEqual(a, b)
    return false;

  public function getComparator()
    return neverEqual;

  @:extern inline function update<T>(fn:Void->T) {
    var ret = fn();
    if (valid) {
      valid = false;
      fire();
    }
    return ret;
  }

  @:extern inline function calc<T>(f:Void->T) {
    valid = true;
    observe().value;
    return f();
  }
}