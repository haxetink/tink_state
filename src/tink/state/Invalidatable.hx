package tink.state;

import tink.state.internal.Revision;
using tink.CoreApi;

interface Invalidatable {
  function invalidate():Void;
}

class Invalidator {
  var revision = new Revision();
  final observers = new Map<Invalidatable, Bool>();
  final list = new CallbackList();//TODO: get rid of the list ... currently it's here to guarantee stable callback order
  var used = 0;

  public function getRevision()
    return revision;

  public function onInvalidate(i:Invalidatable):CallbackLink
    return
      if (observers.get(i)) null;
      else {
        observers.set(i, true);
        list.add(i.invalidate) & observers.remove.bind(i);
      }

  #if debug_observables
  public function getObservers()
    return observers.keys();
  #end

  function fire() {
    revision = new Revision();
    list.invoke(Noise);
  }
}