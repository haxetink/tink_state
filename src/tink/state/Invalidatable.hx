package tink.state;

using tink.CoreApi;

interface Invalidatable {
  function invalidate():Void;
}

class Invalidator {
  final observers = new Map<Invalidatable, Bool>();

  public function onInvalidate(i:Invalidatable):CallbackLink
    return
      if (observers[i]) null;
      else {
        observers[i] = true;
        observers.remove.bind(i);
      }

  public function getObservers()
    return observers.keys();

  function fire()
    for (i in observers.keys()) i.invalidate();
}