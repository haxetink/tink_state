package tink.state.internal;

interface ObservableObject<T> {
  function getValue():T;
  function getRevision():Revision;
  function isValid():Bool;
  function getComparator():Comparator<T>;
  function onInvalidate(i:Invalidatable):CallbackLink;
  #if tink_state.debug
  function getObservers():Iterator<Invalidatable>;
  function getDependencies():Iterator<Observable<Any>>;
  #end
}