package tink.state.internal;

class TransformObservable<In, Out> implements ObservableObject<Out> {

  var lastSeenRevision:Revision = cast -1.0;
  var last:Out = null;
  final transform:Transform<In, Out>;
  final source:ObservableObject<In>;
  final comparator:Comparator<Out>;
  #if tink_state.debug
  final _toString:()->String;
  #end

  public function new(source, transform, ?comparator #if tink_state.debug , toString #end) {
    this.source = source;
    this.transform = transform;
    this.comparator = comparator;
    #if tink_state.debug
    this._toString = toString;
    #end
  }

  public function getRevision()
    return source.getRevision();

  public function isValid()
    return lastSeenRevision == source.getRevision();

  public function onInvalidate(i)
    return source.onInvalidate(i);

  #if tink_state.debug
  public function getObservers()
    return source.getObservers();

  public function getDependencies()
    return [cast source].iterator();

  public function toString():String
    return _toString();
  #end

  public function getValue() {
    var rev = source.getRevision();
    if (rev > lastSeenRevision) {
      lastSeenRevision = rev;
      last = transform.apply(source.getValue());
    }
    return last;
  }

  public function getComparator()
    return comparator;

  public function canFire():Bool
    return source.canFire();
}