package tink.state.internal;

interface Invalidatable {
  function invalidate():Void;
  #if tink_state.debug
  @:keep function toString():String;
  #end
}

class Invalidator {
  var revision = new Revision();
  final observers = new ObjectMap<Invalidatable, Bool>();
  final list = new CallbackList();//TODO: get rid of the list ... currently primarily here to guarantee stable callback order
  #if tink_state.debug
  static var counter = 0;
  final id = counter++;
  final _toString:()->String;
  @:keep public function toString()
    return Observable.untracked(_toString);
  #end
  var used = 0;
  function new(?toString:(id:Int)->String #if tink_state.debug , ?pos:haxe.PosInfos #end) {
    #if tink_state.debug
      this._toString = switch toString {
        case null: () -> Type.getClassName(Type.getClass(this)) + '#$id(${pos.fileName}:${pos.lineNumber})';
        case v: v.bind(id);
      }
    #end
  }

  public function getRevision()
    return revision;

  public function onInvalidate(i:Invalidatable):CallbackLink
    return
      if (observers.get(i)) null;
      else {
        observers.set(i, true);
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
    return observers.keys();
  #end

  function fire() {
    revision = new Revision();
    list.invoke(Noise);
  }
}