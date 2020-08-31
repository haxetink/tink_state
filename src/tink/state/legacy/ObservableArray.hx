package tink.state.legacy;

import tink.state.Observable;

using tink.CoreApi;

private enum Change<T> {
  Remove(index:Int, values:Array<T>);
  Insert(index:Int, values:Array<T>);
  Update(index:Int, values:Array<T>);
}

private class ValueIterator<T> implements ObservableObject<Iterator<T>> {

  var target:ObservableArray<T>;

  public function new(target)
    this.target = target;

  public function isValid()
    return true;

  public function getValue()
    return @:privateAccess target.items.iterator();

  public function onInvalidate(i:Invalidatable)
    return @:privateAccess target.changes.handle(i.invalidate);

  public function getComparator()
    return null;

  #if debug_observables
  public function getObservers()
    return [].iterator();
  #end
}

@:deprecated
class ObservableArray<T> extends ObservableBase<Change<T>> {

  var items:Array<T>;

  public var observableValues(default, null):Observable<Iterator<T>>;
  public var observableLength(default, null):Observable<Int>;

  public var length(get, never):Int;
    inline function get_length() return observableLength.value;

  public function new(?items) {
    this.items = if (items == null) [] else items;

    super();

    this.observableLength = observable(function () return this.items.length, function (_, c) return switch c {
      case Update(_, _): false;
      default: true;
    });

    this.observableValues = new ValueIterator(this);
  }

  public function values() {
    return this.observableValues.value;
  }

  public function keys() {
    return 0...this.length;
  }

  public function iterator() {
    var i = 0;
    length;//not pretty
    return {
      hasNext: function () return i < items.length,
      next: function () return observe(i++),
    }
  }

  public function observe(index:Int)
    return observable(function () return items[index], function (_, c) return @:privateAccess switch c {
      case Remove(i, { length: l }): i <= index && items.length + l > index;
      case Insert(i, { length: l }): i <= index && items.length > index;
      case Update(i, items): i <= index && index <= i + items.length;
    });

  public function toArray():Array<T>
    return observable(function () return this.items.copy());

  public function get(index:Int)
    return observe(index).value;

  public function set(index:Int, value:T)
    if (index >= items.length)
      if (index == items.length)
        insert(index, value)
      else {
        var a = [];
        a[index - items.length] = value;
        insertMany(index, a);
      }
    else if (items[index] != value) {
      items[index] = value;
      _changes.trigger(Update(index, [value]));
    }

  public function remove(item:T)
    return
      switch items.indexOf(item) {
        case -1: false;
        case v:
          splice(v, 1);
          true;
      }

  public inline function clear() {
    return splice(0, items.length);
  }

  public inline function indexOf(item:T):Int
    return items.indexOf(item);

  public function splice(index:Int, length:Int) {
    var ret = items.splice(index, length);
    if (ret.length > 0)
      _changes.trigger(Remove(index, ret));
    return ret;
  }

  public inline function insert(pos:Int, value:T)
    insertMany(pos, [value]);

  public function insertMany(pos:Int, values:Array<T>)
    if (values.length > 0) {
      this.items = this.items.slice(0, pos).concat(values).concat(this.items.slice(pos));
      _changes.trigger(Insert(pos, values));
    }

  public inline function push(value:T) {
    this.insert(items.length, value);
    return items.length;
  }

  public inline function pop()
    return splice(items.length - 1, 1)[0];

  public inline function unshift(value:T)
    insert(0, value);

  public inline function shift()
    return splice(0, 1)[0];

  public inline function join(sep:String) {
    return observable(items.join.bind(sep));
  }
}