package tink.state.internal;

@:allow(tink.state.internal)
interface ObservableObject<T> {
  private function retain():Void;
  private function release():Void;
  function getValue():T;
  function getRevision():Revision;
  function isValid():Bool;
  function getComparator():Comparator<T>;
  function subscribe(i:Observer):Void;
  function unsubscribe(i:Observer):Void;
  function canFire():Bool;
  #if tink_state.debug
  function getObservers():Iterator<Observer>;
  function getDependencies():Iterator<Observable<Any>>;
  @:keep function toString():String;
  #end
}