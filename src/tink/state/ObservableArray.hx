package tink.state;

import tink.state.Invalidatable;
import tink.state.Observable;
import haxe.iterators.*;

@:forward
abstract ObservableArray<T>(ArrayImpl<T>) from ArrayImpl<T> {

  @:deprecated public var observableValues(get, never):Observable<ArrayIterator<T>>;
    function get_observableValues()
      return Observable.auto(() -> this.iterator());

  @:deprecated public var observableLength(get, never):Observable<Int>;
    function get_observableLength()
      return Observable.auto(() -> this.length);

  public inline function new(?init:Array<T>)
    this = new ArrayImpl(switch init {
      case null: [];
      case v: v.copy();
    });

  public function entry(index)
    return Observable.auto(() -> this.get(index));

  @:deprecated('use iterator instead')
  public function values()
    return this.iterator();

  public function keys()
    return 0...this.length;

  @:op([]) public inline function get(index)
    return this.get(index);

  @:op([]) public inline function set(index, value)
    return this.set(index, value);

  @:from static public function fromArray<T>(a:Array<T>):ObservableArray<T>
    return new ArrayImpl(a.copy());

  @:from static public function fromVector<T>(v:haxe.ds.Vector<T>):ObservableArray<T>
    return new ArrayImpl(v.toArray());

  @:from static public function fromIterable<T>(i:Iterable<T>):ObservableArray<T>
    return new ArrayImpl(Lambda.array(i));
}

private typedef Self<T> = Iterable<T> & KeyValueIterable<Int, T> & { var length(get, never):Int; }

private class ArrayImpl<T> extends Invalidator implements ObservableObject<Self<T>> {

  var valid = false;
  var entries:Array<T>;

  public var length(get, never):Int;
    function get_length()
      return calc(() -> entries.length);

  public function new(entries)
    this.entries = entries;

  public function replace(values:Array<T>)
    update(() -> { entries = values.copy(); });

  public function prepend(values:Array<T>)
    update(() -> { entries = values.concat(entries); });

  public function append(values:Array<T>)
    update(() -> { entries = entries.concat(values); });

  public function sort(fn:T->T->Int)
    update(() -> { entries.sort(fn); null; });

  public function resize(size:Int)
    update(() -> { entries.resize(0); null; });

  public inline function clear()
    resize(0);

  public function push(v:T)
    return update(() -> entries.push(v));

  public function pop()
    return update(() -> entries.pop());

  public function unshift(v:T)
    return update(() -> entries.push(v));

  public function shift()
    return update(() -> entries.pop());

  @:extern inline function update<T>(fn:Void->T) {
    var ret = fn();
    if (valid) {
      valid = false;
      fire();
    }
    return ret;
  }

  public function get(index:Int)
    return calc(() -> entries[index]);

  public function set(index:Int, value:T)
    return update(() -> entries[index] = value);

  public function observe():Observable<Iterable<T>>
    return this;

  public function isValid():Bool
    return valid;

  public function getValue():Self<T>
    return this;

  public function iterator():ArrayIterator<T>
    return calc(entries.iterator);

  public function keyValueIterator():ArrayKeyValueIterator<T>
    return calc(entries.keyValueIterator);

  @:extern inline function calc<T>(f:Void->T) {
    valid = true;
    observe().value;
    return f();
  }

  function eq(a, b)
    return false;

  public function getComparator()
    return eq;
}
