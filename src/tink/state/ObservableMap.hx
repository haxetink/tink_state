package tink.state;

import tink.state.ObservableBase;

using tink.CoreApi;

@:structInit private class Update<K, V> {
  public #if haxe4 final #else var #end key #if !haxe4 (default, never) #end:K;
  public #if haxe4 final #else var #end from #if !haxe4 (default, never) #end:Option<V>;
  public #if haxe4 final #else var #end to #if !haxe4 (default, never) #end:Option<V>;
}

class ObservableMap<K, V> implements haxe.Constraints.IMap<K, V> extends ObservableBase<Update<K, V>> {

  var map:Map<K, V>;

  public var observableKeys(default, null):Observable<Iterator<K>>;
  public var observableValues(default, null):Observable<Iterator<V>>;

  var asString:Observable<String>;

  public function new(initial) {

    super();
    this.map = initial;

    this.observableKeys = ObservableIterator.make(
      map.keys,
      changes,
      function (c) return switch [c.from, c.to] {
        case [Some(_), Some(_)]: false;
        default: true;
      }
    );

    this.observableValues = ObservableIterator.make(
      map.iterator,
      changes
    );

    this.asString = observable(map.toString);
  }

  public function observe(key:K):Observable<Null<V>>
    return observable(map.get.bind(key), function (_, c) return c.key == key);

  public inline function get(key:K):Null<V>
    return observe(key).value;

  public function set(key:K, value:V)
    switch map[key] {
      case unchanged if (value == unchanged):
      case old:
        var from = if (map.exists(key)) Some(old) else None;
        map[key] = value;
        _changes.trigger({ key: key, from: from, to: Some(value) });
    }

  public function remove(key:K):Bool
    return
      if (map.exists(key)) {
        var from = Some(map[key]);
        map.remove(key);
        _changes.trigger({ key: key, from: from, to: None });
        true;
      }
      else false;

  public function exists(key:K):Bool {
    return observable(map.exists.bind(key), function (exists, c) return exists == (c.to == None));
  }

  public inline function iterator():Iterator<V>
    return observableValues.value;

  public inline function keyValueIterator():Iterator<{key:K, value:V}> {
    var keys = keys();
    return {
      hasNext: keys.hasNext,
      next: function () {
        var key = keys.next();
        return {
          key: key,
          value: get(key)
        }
      }
    }
  }

  public inline function keys():Iterator<K>
    return observableKeys.value;

  public inline function toString():String
    return asString.value;

	public inline function clear():Void {
		 for (key in map.keys())
      map.remove(key);
	}

  public function copy()
    return new ObservableMap(this.map);
}