package tink.state;

using tink.CoreApi;

private enum Change<T> {
  Remove(index:Int, values:Array<T>);
  Insert(index:Int, values:Array<T>);
  Update(index:Int, values:Array<T>);
}

class ObservableArray<T> extends ObservableBase<Change<T>> {
  
  var items:Array<T> = [];
  var iter:Observable<Iterator<T>>;
  var len:Observable<Int>;

  public var length(get, never):Int;
    inline function get_length() return len.value;

  public function new() {
    super();
    this.iter = observable(items.iterator, function (_, _) return true);
    this.len = observable(function () return items.length, function (_, c) return switch c {
      case Update(_, _): false;
      default: true;
    });
  }

  public function observe(index:Int) 
    return observable(function () return items[index], function (_, c) return switch c {
      case Remove(i, _) | Insert(i, _): i <= index;
      case Update(i, items): i <= index && index <= i + items.length;
    });

  public function get(index:Int) 
    return observe(index).value;

  public function set(index:Int, value:T) 
    if (items[index] != value) {
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

  public function splice(index:Int, length:Int) {
    var ret = items.splice(index, len);
    _changes.trigger(Remove(index, ret));
    return ret;
  }

  public inline function insert(pos:Int, value:T) 
    insertMany(pos, [value]);

  public function insertMany(pos:Int, values:Array<T>) {
    this.items = this.items.slice(0, pos).concat(values).concat(this.items.slice(pos + values.length));
    _changes.trigger(Insert(pos, values));
  }

  public inline function push(value:T) {
    this.insert(this.length, value);
    return items.length;
  }

  public inline function pop() 
    return splice(items.length - 1, 1)[0];

  public inline function unshift(value:T) 
    insert(0, value);

  public inline function shift() 
    return splice(0, 1)[0];  
}