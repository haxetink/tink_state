package tink.state.internal;

@:allow(tink.state.internal)
interface ObservableObject<T> {
  private function retain():Void;
  private function release():Void;
  function getValue():T;
  function getRevision():Revision;
  function isValid():Bool;
  function getComparator():Comparator<T>;
  function subscribe(i:Invalidatable):Void;
  function unsubscribe(i:Invalidatable):Void;
  function canFire():Bool;
  #if tink_state.debug
  function getObservers():Iterator<Invalidatable>;
  function getDependencies():Iterator<Observable<Any>>;
  @:keep function toString():String;
  #end
}