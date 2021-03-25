package tink.state.internal;

class EmptyIterator<X> {
  #if tink_state.debug
  static public final OBSERVERS = new EmptyIterator<Invalidatable>();
  static public final DEPENDENCIES = new EmptyIterator<Observable<Any>>();
  #end
  public function new() {}
  public function hasNext()
    return false;

  public function next():X
    throw 'cannot call next on EmptyIterator';
}