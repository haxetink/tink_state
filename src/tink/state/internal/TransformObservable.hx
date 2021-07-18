package tink.state.internal;

class TransformObservable<In, Out> implements ObservableObject<Out> {

  var lastSeenRevision:Revision = cast -1.0;
  var last:Out = null;
  final transform:Transform<In, Out>;
  final source:ObservableObject<In>;
  final comparator:Comparator<Out>;
  var dispose:()->Void;
  #if tink_state.debug
  final _toString:()->String;
  #end

  public function new(source, transform, ?comparator, ?dispose #if tink_state.debug , toString #end) {
    this.source = source;
    this.transform = transform;
    this.comparator = comparator;
    this.dispose = switch dispose {
      case null: noop;
      case v: v;
    }
    #if tink_state.debug
    this._toString = toString;
    #end
  }

  public function getRevision()
    return source.getRevision();

  public function isValid()
    return lastSeenRevision == source.getRevision();

  #if tink_state.debug
    final observers = new ObjectMap<Invalidatable, Invalidatable>();

    public function onInvalidate(i)
      return switch observers[i] {
        case null:
          observers[i] = i;
          source.onInvalidate(i) & () -> observers.remove(i);
        default: null;
      }

    public function getObservers()
      return observers.iterator();

    public function getDependencies()
      return [cast source].iterator();

    public function toString():String
      return _toString();
  #else
    public function onInvalidate(i)
      return source.onInvalidate(i);
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

  var retainCount = 0;
  function retain() retainCount++;
  function release()
    if (--retainCount == 0) dispose();

  static function noop() {}
}