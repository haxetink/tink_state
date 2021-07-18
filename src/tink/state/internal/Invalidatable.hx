package tink.state.internal;

import tink.core.Disposable.OwnedDisposable;

interface Invalidatable {
  function invalidate():Void;
  #if tink_state.debug
  @:keep function toString():String;
  #end
}

class Invalidator implements OwnedDisposable {
  var revision = new Revision();
  final observers = new ObjectMap<Invalidatable, Invalidatable>();
  final list = new CallbackList();//TODO: get rid of the list ... currently primarily here to guarantee stable callback order
  #if tink_state.debug
  static var counter = 0;
  final id = counter++;
  final _toString:()->String;
  @:keep public function toString()
    return Observable.untracked(_toString);
  #end
  var used = 0;
  function new(#if tink_state.debug ?toString:(id:Int)->String, ?pos:haxe.PosInfos #end) {
    #if tink_state.debug
      this._toString = switch toString {
        case null: () -> Type.getClassName(Type.getClass(this)) + '#$id(${pos.fileName}:${pos.lineNumber})';
        case v: v.bind(id);
      }
    #end
  }

  public var disposed(get, never):Bool;
    inline function get_disposed()
      return list.disposed;

  public function ondispose(d:()->Void)
    list.ondispose(d);

  function retain() {}
  function release() {}

  public inline function dispose() {
    list.dispose();
    observers.clear();
  }

  public function canFire()
    return !disposed;

  public function getRevision()
    return revision;

  public function onInvalidate(i:Invalidatable):CallbackLink
    return
      if (observers.exists(i) || list.disposed) null;
      else {
        observers[i] = i;
        list.add(
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
    return observers.iterator();
  #end

  function fire() {
    revision = new Revision();
    list.invoke(Noise);
  }
}