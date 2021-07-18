package tink.state;

import haxe.Constraints.IMap;
import haxe.iterators.*;

@:forward
@:multiType(@:followWithAbstracts K)
abstract ObservableMap<K, V>(MapImpl<K, V>) {

  public var view(get, never):ObservableMapView<K, V>;
    inline function get_view() return this;

  public function new();

  @:op([]) public inline function get(index)
    return this.get(index);

  @:op([]) public inline function set(index, value) {
    this.set(index, value);
    return value;
  }

  public function toMap():Map<K, V>
    return view.toMap();

  // public function copy():ObservableMap<K, V>
  //   return view.copy();

  public function entry(key:K)
    return Observable.auto(this.get.bind(key));

  @:to static function toIntMap<K:Int, V>(dict:MapImpl<K, V>):MapImpl<Int, V>
    return new MapImpl<Int, V>(new Map(), new Map(), new Map());

  @:to static function toStringMap<K:String, V>(dict:MapImpl<K, V>):MapImpl<String, V>
    return new MapImpl<String, V>(new Map(), new Map(), new Map());

  @:to static function toObjectMap<K:{}, V>(dict:MapImpl<K, V>):MapImpl<{}, V>
    return new MapImpl<{}, V>(new Map(), new Map(), new Map());

  extern static public inline function of<K, V>(m:Map<K, V>):ObservableMap<K, V>
    return cast new MapImpl<K, V>(m.copy(), new Map(), new Map());

}

@:forward
abstract ObservableMapView<K, V>(MapView<K, V>) from MapView<K, V> {
  @:op([]) public inline function get(index)
    return this.get(index);

  public function toMap():Map<K, V>
    return cast this.copy();

  // public function copy():ObservableMap<K, V>
  //   return new MapImpl(cast this.copy(), null);

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

private class MapImpl<K, V> extends Invalidator implements MapView<K, V> implements IMap<K, V> {

  var valid = false;
  final entries:Map<K, V>;
  final observableEntries:Map<K, Observable<V>>;
  final observableExistences:Map<K, Observable<Bool>>;

  public function new(entries, observableEntries, observableExistences) {
    super();
    this.entries = entries;
    this.observableEntries = observableEntries;
    this.observableExistences = observableExistences;
  }

  public function observe():Observable<MapView<K, V>>
    return this;

  public function isValid():Bool
    return valid;

  public function getValue():MapView<K, V>
    return this;

  function transformed<X>(cache:Map<K, Observable<X>>, key:K, f:()->X #if tink_state.debug , name:String #end)
    return
      if (AutoObservable.needsTracking(this)) {
        var wrapper = switch cache[key] {
          case null:
            cache[key] = new TransformObservable(
              this,
              _ -> {
                valid = true;
                f();
              },
              null,
              () -> cache.remove(key)
              #if tink_state.debug , () -> '$name ${this.toString()}' #end
            );
          case v: v;
        }
        wrapper.value;
      }
      else f();

  public function get(k:K):Null<V>
    return transformed(observableEntries, k, () -> entries.get(k) #if tink_state.debug , 'Entry for $k in' #end);

  public function set(k:K, v:V):Void
    update(() -> { entries.set(k, v); null; });

  public function exists(k:K):Bool
    return transformed(observableExistences, k, () -> entries.exists(k) #if tink_state.debug , 'Existance of $k in' #end);

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