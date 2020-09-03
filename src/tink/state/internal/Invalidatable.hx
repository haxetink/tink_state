package tink.state.internal;

interface Invalidatable {
  function invalidate():Void;
}

class Invalidator {
  var revision = new Revision();
  final observers = new ObjectMap<Invalidatable, Bool>();
  final list = new CallbackList();//TODO: get rid of the list ... currently primarily here to guarantee stable callback order
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

  #if tink_state.debug
  public function getObservers()
    return observers.keys();
  #end

  function fire() {
    revision = new Revision();
    list.invoke(Noise);
  }
}