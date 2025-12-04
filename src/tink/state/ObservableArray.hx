package tink.state;

import haxe.iterators.*;

@:forward(
  observableLength, length, iterator, keyValueIterator, push, pop, shift, unshift, sort, reduce, clear,
  replace, prepend, append, sort, resize, splice, remove
)
abstract ObservableArray<T>(ArrayImpl<T>) from ArrayImpl<T> to Observable<ArrayView<T>> to Iterable<T> {

  public var observableValues(get, never):Observable<ArrayView<T>>;
    function get_observableValues()
      return this;

  public var view(get, never):ObservableArrayView<T>;
    inline function get_view()
      return this;

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

  public inline function select<R>(f:T->Array<R>)
    return view.select(f);

  public inline function map<R>(f:T->R)
    return view.map(f);

  public inline function filter(f:T->Bool)
    return view.filter(f);

  public inline function sorted(c)
    return view.sorted(c);

  public inline function reduce<R>(init:R, f:T->R->R):Observable<R>
    return view.reduce(init, f);

  public inline function count(f:T->Bool):Observable<Int>
    return view.count(f);

  public function copy():ObservableArray<T>
    return new ArrayImpl(this.copy());

  public function toArray():Array<T>
    return this.copy();

  @:from static public function fromArray<T>(a:Array<T>):ObservableArray<T>
    return new ArrayImpl(a.copy());

  @:from static public function fromVector<T>(v:haxe.ds.Vector<T>):ObservableArray<T>
    return new ArrayImpl(v.toArray());

  @:from static public function fromIterable<T>(i:Iterable<T>):ObservableArray<T>
    return new ArrayImpl(Lambda.array(i));
}

@:forward
abstract ObservableArrayView<T>(ArrayView<T>) from ArrayView<T> {
  public function keys()
    return 0...this.length;

  @:op([]) public inline function get(index)
    return this.get(index);

  public function toArray():Array<T>
    return this.copy();

  public function copy():ObservableArray<T>
    return new ArrayImpl(this.copy());

  public function reduce<R>(init:R, f:T->R->R):Observable<R>
    return Observable.auto(() -> {
      var ret = init;
      for (x in this)
        ret = f(x, ret);
      ret;
    });

  public function count(f:T->Bool):Observable<Int>
    return Observable.auto(() -> {
      var ret = 0;
      for (x in this)
        if (f(x)) ret++;
      ret;
    });

  inline function derive<R>(f:Void->Array<R>):ObservableArrayView<R>
    return new DerivedView<R>(Observable.auto(f));

  public function select<R>(f:T->Array<R>)
    return derive(() -> [for (i in this) for (o in f(i)) o]);

  public function map<R>(f:T->R)
    return derive(() -> [for (i in this) f(i)]);

  public function filter(f:T->Bool)
    return derive(() -> [for (i in this) if (f(i)) i]);

  public function sorted(f)
    return derive(() -> {
      var a = this.copy();
      a.sort(f);
      a;
    });

}

private interface ArrayView<T> extends ObservableObject<ArrayView<T>> {
  var length(get, never):Int;
  function copy():Array<T>;
  function get(index:Int):T;
  function iterator():ArrayIterator<T>;
  function keyValueIterator():ArrayKeyValueIterator<T>;
}

private class ArrayImpl<T> extends Invalidator implements ArrayView<T> {

  var valid = false;
  var entries:Array<T>;
  final observableLength:Observable<Int>;

  public var length(get, never):Int;
    function get_length()
      return calc(() -> entries.length);

  public function new(entries) {
    super(#if tink_state.debug id -> 'ObservableArray#$id${this.entries.toString()}' #end);
    this.entries = entries;
    this.observableLength = new TransformObservable(this, _ -> this.entries.length, null #if tink_state.debug , () -> 'length of ${toString()}' #end);
  }

  public function replace(values:Array<T>)
    update(() -> { entries = values.copy(); });

  public function prepend(values:Array<T>)
    update(() -> { entries = values.concat(entries); });

  public function append(values:Array<T>)
    update(() -> { entries = entries.concat(values); });

  public function sort(fn:T->T->Int)
    update(() -> { entries.sort(fn); null; });

  public function resize(size:Int)
    update(() -> { entries.resize(size); null; });

  public function splice(pos, len)
    return update(() -> entries.splice(pos, len));

  public function remove(value:T) {
    return switch entries.indexOf(value) {
      case -1: false;
      case i: splice(i, 1); true;
    }
  }

  #if tink_state.debug
  public function getDependencies()
    return EmptyIterator.DEPENDENCIES;
  #end

  public inline function clear()
    resize(0);

  public function push(v:T)
    return update(() -> entries.push(v));

  public function pop()
    return update(() -> entries.pop());

  public function unshift(v:T)
    return update(() -> { entries.unshift(v); entries.length; });

  public function shift()
    return update(() -> entries.shift());

  public function get(index:Int)
    return calc(() -> entries[index]);

  public function set(index:Int, value:T)
    return update(() -> entries[index] = value);

  public function observe():Observable<ArrayView<T>>
    return this;

  public function isValid():Bool
    return valid;

  public function getValue():ArrayView<T>
    return this;

  public function iterator():ArrayIterator<T>
    return calc(() -> entries.iterator());

  public function keyValueIterator():ArrayKeyValueIterator<T>
    return calc(() -> entries.keyValueIterator());

  function neverEqual(a, b)
    return false;

  public function getComparator():Comparator<ArrayView<T>>
    return neverEqual;

  public function copy()
    return calc(() -> entries.copy());

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
}

private class DerivedView<T> implements ArrayView<T> {

  public var length(get, never):Int;
    function get_length()
      return o.value.length;

  final o:Observable<Array<T>>;

  public function getRevision()
    return self().getRevision();

  public function canFire()
    return self().canFire();

  public function new(o)
    this.o = o;

  public function get(index:Int)
    return o.value[index];

  inline function self()
    return (o:ObservableObject<Array<T>>);

  #if tink_state.debug
  public function getObservers()
    return self().getObservers();

  public function getDependencies()
    return [(cast o:Observable<Any>)].iterator();

  @:keep public function toString()
    return 'ObservableArrayView${o.value.toString()}';

  #end

  public function getValue():ArrayView<T>
    return this;

  public function isValid()
    return self().isValid();

  public function onInvalidate(i)
    return self().onInvalidate(i);

  public function copy()
    return o.value.copy();

  function neverEqual(a, b)
    return false;

  public function getComparator():Comparator<ArrayView<T>>
    return neverEqual;

  public function iterator()
    return o.value.iterator();

  public function keyValueIterator()
    return o.value.keyValueIterator();

}