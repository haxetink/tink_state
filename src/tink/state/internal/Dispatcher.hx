package tink.state.internal;

import tink.core.Disposable;

class Dispatcher extends SimpleDisposable {
  var revision = new Revision();
  final observers = new OrderedObjectMap<Observer, Observer>();
  final onStatusChange:(watched:Bool)->Void;
  static function noop(_) {}
  #if tink_state.debug
  static var counter = 0;
  final id = counter++;
  final _toString:()->String;
  @:keep public function toString()
    return Observable.untracked(_toString);
  #end
  var used = 0;
  function new(?onStatusChange #if tink_state.debug , ?toString:(id:Int)->String, ?pos:haxe.PosInfos #end) {
    super(() -> observers.clear());
    this.onStatusChange = switch onStatusChange {
      case null: noop;
      case v: v;
    }
    #if tink_state.debug
      this._toString = switch toString {
        case null: () -> Type.getClassName(Type.getClass(this)) + '#$id(${pos.fileName}:${pos.lineNumber})';
        case v: v.bind(id);
      }
    #end
  }

  function retain() {}
  function release() {}

  public function canFire()
    return !disposed;

  public function getRevision()
    return revision;

  public function subscribe(i:Observer) {
    if (observers.exists(i) || disposed) null;
    var wasEmpty = observers.size == 0;
    observers[i] = i;
    if (wasEmpty) onStatusChange(true);
  }

  public function unsubscribe(i:Observer) {
    observers.remove(i);
    if (observers.size == 0) onStatusChange(false);
  }

  #if tink_state.debug
  public function getObservers()
    return observers.iterator();
  #end

  function fire<R>(from:ObservableObject<R>) {
    revision = new Revision();
    for (v in observers) {
      #if tink_state.debug
      tink.state.debug.Logger.inst.triggered(from, v);
      #end
      v.notify(from);
    }
  }
}