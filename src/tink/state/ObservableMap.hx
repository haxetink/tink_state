package tink.state;

import haxe.Constraints.IMap;
import haxe.iterators.*;

@:forward
@:multiType(@:followWithAbstracts K)
abstract ObservableMap<K, V>(MapImpl<K, V>) from MapImpl<K, V> {

  public var view(get, never):ObservableMapView<K, V>;
    inline function get_view() return this;

  public function new();

  @:op([]) public function get(key)
    return
      if (AutoObservable.needsTracking(this))
        AutoObservable.currentAnnex().get(Wrappers).forSource(this).get(key).value;
      else
        this.get(key);

  @:op([]) public inline function set(index, value) {
    this.set(index, value);
    return value;
  }

  public function exists(key)
    return
      if (AutoObservable.needsTracking(this))
        AutoObservable.currentAnnex().get(Wrappers).forSource(this).exists(key).value;
      else
        this.exists(key);

  public function toMap():Map<K, V>
    return view.toMap();

  public function copy():ObservableMap<K, V>
    return view.copy();

  public function entry(key:K)
    return Observable.auto(() -> get(key));

  @:to static function toIntMap<K:Int, V>(dict:MapImpl<K, V>):MapImpl<Int, V>
    return new MapImpl<Int, V>(new Map(), IntMaps.INST);

  @:to static function toEnumValueMap<K:Int, V>(dict:MapImpl<K, V>):MapImpl<EnumValue, V>
    return new MapImpl<EnumValue, V>(new Map(), EnumValueMaps.INST);

  @:to static function toStringMap<K:String, V>(dict:MapImpl<K, V>):MapImpl<String, V>
    return new MapImpl<String, V>(new Map(), StringMaps.INST);

  @:to static function toObjectMap<K:{}, V>(dict:MapImpl<K, V>):MapImpl<{}, V>
    return new MapImpl<{}, V>(new Map(), ObjectMaps.INST);

  static public inline function of<K, V>(m:Map<K, V>):ObservableMap<K, V>
    // This runtime lookup here is messy, but I don't see what else we could do ...
    return cast new MapImpl<K, V>(m.copy(), DynamicFactory.of(m));
}

@:forward
abstract ObservableMapView<K, V>(MapView<K, V>) from MapView<K, V> {
  @:op([]) public inline function get(index)
    return this.get(index);

  public function toMap():Map<K, V>
    return cast this.copy();

  public function copy():ObservableMap<K, V>
    return new MapImpl(cast this.copy(), this.getFactory());

  public function entry(key:K)
    return Observable.auto(this.get.bind(key));
}

private interface MapView<K, V> extends ObservableObject<MapView<K, V>> {
  function copy():IMap<K, V>;
  function getFactory():MapFactory<K>;
  function exists(key:K):Bool;
  function get(key:K):Null<V>;
  function iterator():Iterator<V>;
  function keys():Iterator<K>;
  function keyValueIterator():KeyValueIterator<K, V>;
}

private class MapImpl<K, V> extends Dispatcher implements MapView<K, V> implements IMap<K, V> {

  var valid = false;
  final entries:Map<K, V>;
  final factory:MapFactory<K>;

  public function new(entries, factory) {
    super();
    this.entries = entries;
    this.factory = factory;
  }

  public function getFactory()
    return factory;

  public function observe():Observable<MapView<K, V>>
    return this;

  public function isValid():Bool
    return valid;

  public function getValue():MapView<K, V>
    return this;

  public function get(k:K):Null<V> {
    valid = true;
    return entries.get(k);
  }

  public function set(k:K, v:V):Void
    update(() -> { entries.set(k, v); null; });

  public function exists(k:K):Bool {
    valid = true;
    return entries.exists(k);
  }

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
      fire(this);
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

private interface MapFactory<K> {
  function createMap<X>():Map<K, X>;
}

private class IntMaps implements MapFactory<Int> {
  static public final INST = new IntMaps();
  function new() {}
  public function createMap<X>():Map<Int, X>
    return new Map();
}

private class StringMaps implements MapFactory<String> {
  static public final INST = new StringMaps();
  function new() {}
  public function createMap<X>():Map<String, X>
    return new Map();
}

private class ObjectMaps implements MapFactory<{}> {
  static public final INST = new ObjectMaps();
  function new() {}
  public function createMap<X>():Map<{}, X>
    return new Map();
}

private class EnumValueMaps implements MapFactory<EnumValue> {
  static public final INST = new EnumValueMaps();
  function new() {}
  public function createMap<X>():Map<EnumValue, X>
    return new Map();
}

private class DynamicFactory {
  static public function of<K, V>(m:Map<K, V>):MapFactory<K> {
    var cl:Class<Dynamic> = Type.getClass(m);
    return
      if (cl == haxe.ds.IntMap) cast IntMaps.INST;
      else if (cl == haxe.ds.StringMap) cast StringMaps.INST;
      else if (cl == haxe.ds.EnumValueMap) cast EnumValueMaps.INST;
      else cast ObjectMaps.INST;
  }
}

private class Wrappers {
  final bySource = new Map<{}, SourceWrappers<Dynamic, Dynamic>>();

  public function new(target:{}) {}

  public function forSource<K, V>(source:MapView<K, V>):SourceWrappers<K, V>
    return cast switch bySource[source] {
      case null: bySource[source] = new SourceWrappers<K, V>(source, () -> bySource.remove(source));
      case v: v;
    }
}

private class SourceWrappers<K, V> {// TODO: it's probably better to split this in two
  final dispose:()->Void;
  final source:MapView<K, V>;
  final entries:Map<K, Observable<V>>;
  final existences:Map<K, Observable<Bool>>;

  var count = 0;

  public function new(source, dispose) {
    this.source = source;
    this.dispose = dispose;
    var factory = source.getFactory();
    this.entries = factory.createMap();
    this.existences = factory.createMap();
  }

  public function get(key)
    return switch entries[key] {
      case null:
        count++;
        entries[key] = new TransformObservable(
          source,
          o -> o.get(key),
          null,
          () -> if (entries.remove(key) && (--count == 0)) dispose()
          #if tink_state.debug , () -> 'Entry for $key in ${source.toString()}' #end
        );
      case v: v;
    }

  public function exists(key)
    return switch existences[key] {
      case null:
        count++;
        existences[key] = new TransformObservable(
          source,
          o -> o.exists(key),
          null,
          () -> if (existences.remove(key) && (--count == 0)) dispose()
          #if tink_state.debug , () -> 'Existence of $key in ${source.toString()}' #end

        );
      case v: v;
    }
}