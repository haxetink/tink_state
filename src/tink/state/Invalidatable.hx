package tink.state;

using tink.CoreApi;

interface Invalidatable {
  function invalidate():Void;
}

class Invalidator {
  final observers = new Map<Invalidatable, Bool>();
  final list = new CallbackList();//TODO: get rid of the list ... currently it's here to guarantee stable callback order
  var used = 0;

  public function onInvalidate(i:Invalidatable):CallbackLink
    return
      if (observers[i]) null;
      else {
        observers[i] = true;
        list.add(i.invalidate) & observers.remove.bind(i);
      }

  #if debug_observables
  public function getObservers()
    return observers.keys();
  #end

  function fire()
    list.invoke(Noise);
}