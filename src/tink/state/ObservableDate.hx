package tink.state;

import tink.state.Observable;
using tink.CoreApi;
using DateTools;

class ObservableDate implements ObservableObject<Bool> {

  static var PASSED = Observable.const(true);

  var _observable:ObservableObject<Bool>;

  public var date(default, null):Date;
  public var passed(get, never):Bool;
    inline function get_passed():Bool
      return _observable.getValue();

  public function isValid()
    return _observable.isValid();

  public function getValue()
    return _observable.getValue();

  public function onInvalidate(i)
    return _observable.onInvalidate(i);

  public function new(?date:Date) {

    if (date == null)
      date = Date.now();

    this.date = date;

    var now = Date.now().getTime(),
      stamp = date.getTime();

    var passed = now >= stamp;

    _observable =
      if (passed) PASSED;
      else {
        var state = new State(false);
        haxe.Timer.delay(function () state.set(true), Std.int(stamp - now));
        state;
      }
  }

  #if debug_observables
  public function getObservers()
    return [].iterator();
  #end

  public function observe():Observable<Bool>
    return _observable;

  public function isOlderThan(msecs:Float):Bool
    return becomesOlderThan(msecs).value;

  public function becomesOlderThan(msecs:Float):Observable<Bool>
    return
      if (Date.now().getTime() > date.getTime() + msecs) PASSED;
      else new ObservableDate(this.date.delta(msecs)).observe();

  public function getComparator()
    return null;
}
