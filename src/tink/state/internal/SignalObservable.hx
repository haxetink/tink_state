package tink.state.internal;

import tink.core.Disposable.OwnedDisposable;

class SignalObservable<T> implements ObservableObject<T> implements OwnedDisposable {
  final snapshot = new Snapshot<T>();
  final subscription:CallbackLink;

  public function getRevision()
    return snapshot.revision;

  final get:Void->T;

  final list = new CallbackList<Noise>();
  final changed:Signal<Noise>;

  public var disposed(get, never):Bool;
    inline function get_disposed()
      return list.disposed;

  public function ondispose(d:()->Void)
    #if (tink_core >= "3") return #end list.ondispose(d);

  public function dispose() {
    subscription.cancel();
    list.dispose();
  }

  public function canFire()
    return !disposed && !changed.disposed;

  public function new(get, changed:Signal<Noise>, ?toString:(id:Int)->String #if tink_state.debug , ?pos:haxe.PosInfos #end) {
    this.get = get;
    this.changed = changed;
    final snapshot = this.snapshot;
    // The signal only gets to see the snapshot, so this observable can be collected while the signal lives.
    // Not a closure: on js, it would share its context with the closures here that capture `this`.
    subscription = changed.handle(snapshot.invalidate);
    list.onfill = () -> snapshot.list = list;
    list.ondrain = () -> snapshot.list = null;
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
      if (snapshot.valid) snapshot.value;
      else {
        snapshot.valid = true;
        snapshot.value = get();
      }

  public function isValid():Bool
    return snapshot.valid;

  public function getComparator():Comparator<T>
    return null;

  public function onInvalidate(i:Invalidatable):CallbackLink
    return
      #if tink_state.debug
        switch list.add(() -> {
          if (Std.is(this, ObservableObject))
            tink.state.debug.Logger.inst.triggered(cast this, i);
          i.invalidate();
        }) {
          case null: null;
          case link:
            observers.push(i);
            link & () -> observers.remove(i);
        }
      #else
        list.add(() -> i.invalidate());
      #end

  #if tink_state.debug
  final observers = new Array<Invalidatable>();

  public function getObservers()
    return observers.iterator();

  public function getDependencies()
    return EmptyIterator.DEPENDENCIES;
  #end
}

private class Snapshot<T> {
  public var valid = false;
  public var value:Null<T> = null;
  public var revision = Revision.ZERO;
  public var list:Null<CallbackList<Noise>> = null;

  public function new() {}

  public function invalidate(_:Noise) {
    if (valid) {
      valid = false;
      revision = new Revision();
    }
    list?.invoke(Noise);
  }
}
