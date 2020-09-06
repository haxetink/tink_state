package tink.state.internal;

class TransformObservable<In, Out> implements ObservableObject<Out> {

  var lastSeenRevision = -1;
  var last:Out = null;
  var transform:Transform<In, Out>;
  var source:ObservableObject<In>;

  public function new(source, transform) {
    this.source = source;
    this.transform = transform;
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
    return [(cast source:Observable<Any>)].iterator();
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
    return null;
}