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
    #if js
    if (Weak.supported) Weak.registry.register(this, handleWeakly(this, changed));
    else
    #end
    this.changed.handle(_ -> markChanged());
    #if tink_state.debug
      this._toString = switch toString {
        case null: id -> 'SignalObservable#$id(${pos.fileName}:${pos.lineNumber})';
        case v: v;
      }
    #end
  }

  #if js
  // The handler is never cancelled, so holding the observable strongly would keep it alive as long as the signal.
  // Static, so the closure cannot share a context with one that captures `this`.
  static function handleWeakly<T>(o:SignalObservable<T>, changed:Signal<Noise>):CallbackLink {
    final self = new js.lib.WeakRef(o);
    return changed.handle(_ -> switch self.deref() {
      case null:
      case o: o.markChanged();
    });
  }
  #end

  function markChanged()
    if (valid) {
      revision = new Revision();
      valid = false;
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

  public function onInvalidate(i:Invalidatable):CallbackLink
    // TODO: this largely duplicates Invalidatable.onInvalidate
    return
      if (observers.get(i)) null;
      else {
        observers.set(i, true);
        changed.handle(
          #if tink_state.debug
            _ -> {
              if (Std.is(this, ObservableObject))
                tink.state.debug.Logger.inst.triggered(cast this, i);
              i.invalidate();
            }
          #else
            _ -> i.invalidate()
          #end
        ) & () -> observers.remove(i);
      }

  #if tink_state.debug
  public function getObservers()
    return observers.keys();

  public function getDependencies()
    return EmptyIterator.DEPENDENCIES;
  #end
}

#if js
private class Weak {
  static public final supported:Bool = js.Syntax.typeof(js.Lib.global.WeakRef) != 'undefined' && js.Syntax.typeof(js.Lib.global.FinalizationRegistry) != 'undefined';
  static public final registry:FinalizationRegistry<CallbackLink> = if (supported) new FinalizationRegistry((link:CallbackLink) -> link.cancel()) else null;
}

@:native('FinalizationRegistry')
private extern class FinalizationRegistry<H> {
  function new(cleanup:H->Void);
  function register(target:{}, held:H):Void;
}
#end
