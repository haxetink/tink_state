package tink.state;

import haxe.Constraints.IMap;
import haxe.iterators.*;

@:forward
abstract ObservableMap<K, V>(MapImpl<K, V>) from MapImpl<K, V> to IMap<K, V> {

  public var view(get, never):ObservableMapView<K, V>;
    inline function get_view() return this;

  public function new(init:Map<K, V>)
    this = new MapImpl(init.copy());

  @:op([]) public inline function get(index)
    return this.get(index);

  @:op([]) public inline function set(index, value) {
    this.set(index, value);
    return value;
  }

  public function toMap():Map<K, V>
    return view.toMap();

  public function copy():ObservableMap<K, V>
    return view.copy();

  public function entry(key:K)
    return Observable.auto(this.get.bind(key));
}

@:forward
abstract ObservableMapView<K, V>(MapView<K, V>) from MapView<K, V> {
  @:op([]) public inline function get(index)
    return this.get(index);

  public function toMap():Map<K, V>
    return cast this.copy();

  public function copy():ObservableMap<K, V>
    return new MapImpl(cast this.copy());

  public function entry(key:K)
    return Observable.auto(this.get.bind(key));
}

private interface MapView<K, V> extends ObservableObject<MapView<K, V>> {
  function copy():IMap<K, V>;
  function exists(key:K):Bool;
  function get(key:K):Null<V>;
  function iterator():Iterator<V>;
  function keys():Iterator<K>;
  function keyValueIterator():KeyValueIterator<K, V>;
}

private class Derived<K, V> implements MapView<K, V> {
  final o:Observable<Map<K, V>>;
  public function new(o)
    this.o = o;

  public function canFire()
    return self().canFire();

  public function getRevision()
    return self().getRevision();

  public function exists(key:K):Bool
    return o.value.exists(key);

  public function get(key:K):Null<V>
    return o.value.get(key);

  public function iterator():Iterator<V>
    return o.value.iterator();

  public function keys():Iterator<K>
    return o.value.keys();

  public function keyValueIterator():KeyValueIterator<K, V>
    return o.value.keyValueIterator();

  public function copy():IMap<K, V>
    return cast o.value.copy();

  inline function self()
    return (o:ObservableObject<Map<K, V>>);

  public function getValue()
    return this;

  public function isValid()
    return self().isValid();

  public function onInvalidate(i)
    return self().onInvalidate(i);

  function neverEqual(a, b)
    return false;

  public function getComparator()
    return neverEqual;

  #if tink_state.debug
  public function getObservers()
    return self().getObservers();

  public function getDependencies()
    return self().getDependencies();

  @:keep public function toString()
    return 'ObservableMapView#${o.value.toString()}';
  #end
}

private class MapImpl<K, V> extends Invalidator implements MapView<K, V> implements IMap<K, V> {

  var valid = false;
  var entries:Map<K, V>;

  public function new(entries:Map<K, V>) {
    super();
    this.entries = entries;
  }

  public function observe():Observable<MapView<K, V>>
    return this;

  public function isValid():Bool
    return valid;

  public function getValue():MapView<K, V>
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

  #if tink_state.debug
  @:keep override
  #end
  public function toString():String
    return 'ObservableMap' #if tink_state.debug + '#$id' #end + calc(() -> entries.toString());

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
    AutoObservable.track(this);
    return f();
  }

  #if tink_state.debug
  public function getDependencies()
    return EmptyIterator.DEPENDENCIES;
  #end
}