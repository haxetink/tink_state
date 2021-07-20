package tink.state.internal;

class SignalObservable<T> implements ObservableObject<T> {
  var valid = false;
  var value:Null<T>;
  var revision = new Revision();

  public function getRevision()
    return revision;

  final get:Void->T;

  final observers = new Map();
  final changed:Signal<Noise>;

  public function canFire()
    return #if (tink_core >= "2") !changed.disposed #else true #end;

  public function new(get, changed:Signal<Noise>, ?toString:(id:Int)->String #if tink_state.debug , ?pos:haxe.PosInfos #end) {
    this.get = get;
    this.changed = changed;
    this.changed.handle(_ -> if (valid) {
      #if tink_state.debug
      for (i in observers.keys())
        tink.state.debug.Logger.inst.triggered(this, i);
      #end
      revision = new Revision();
      valid = false;
    });
    #if tink_state.debug
      this._toString = switch toString {
        case null: id -> 'SignalObservable#$id(${pos.fileName}:${pos.lineNumber})';
        case v: v;
      }
    #end
  }

  #if tink_state.debug
  static var counter = 0;
  var id = counter++;
  final _toString:(id:Int)->String;
  @:keep public function toString()
    return _toString(id);
  #end

  public function getValue():T
    return
      if (valid) value;
      else {
        valid = true;
        value = get();
      }

  public function isValid():Bool
    return valid;

  public function getComparator():Comparator<T>
    return null;

  function retain() {}
  function release() {}

  public function subscribe(i:Observer)
    if (!observers.exists(i)) observers[i] = changed.handle(() -> i.notify(this));

  public function unsubscribe(i:Observer) {
    switch observers[i] {
      case null:
      case v:
    }
  }

  #if tink_state.debug
  public function getObservers()
    return observers.keys();

  public function getDependencies()
    return EmptyIterator.DEPENDENCIES;
  #end
}