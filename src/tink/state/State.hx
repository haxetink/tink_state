package tink.state;

import tink.state.Observable;

using tink.CoreApi;

@:forward(set)
abstract State<T>(StateObject<T>) to Observable<T> from StateObject<T> {

  public var value(get, never):T;
    @:to function get_value() return observe().value;

  public inline function new(value, ?isEqual, ?guard)
    this = new SimpleState(value, isEqual, guard);

  public inline function observe():Observable<T>
    return this;

  public function transform<R>(rules:{ function read(v:T):R; function write(v:R):T; }):State<R>
    return new CompoundState(observe().map(rules.read), function (value) this.set(rules.write(value)));

  public inline function bind(?options:BindingOptions<T>, cb:Callback<T>):CallbackLink
    return observe().bind(options, cb);

  @:impl static public function toggle(s:StateObject<Bool>) {
    s.set(!s.poll().value);
  }

  @:to public function toCallback():Callback<T>
    return this.set;

}

private interface StateObject<T> extends ObservableObject<T> {
  function set(value:T):Void;
}

private class CompoundState<T> implements StateObject<T> {

  var data:ObservableObject<T>;
  var update:T->Void;
  var comparator:Null<T->T->Bool>;

  public function new(data, set, ?comparator) {
    this.data = data;
    this.update = set;
    this.comparator = comparator;
  }

  public function isValid()
    return data.isValid();

  public function poll()
    return data.poll();

  public function set(value)
    update(value);

  public function getComparator()
    return this.comparator;
}

private class SimpleState<T> implements StateObject<T> {

  var next:Measurement<T>;
  var trigger:FutureTrigger<Noise>;
  var isEqual:Null<T->T->Bool>;
  var guard:T->T;

  public function isValid()
    return true;

  public function poll() {
    if (next == null) {
      if (guard != null)
        value = guard(value);
      arm();
    }
    return next;
  }

  var value:T;

  public function new(value, ?isEqual, ?guard) {
    this.guard = guard;
    this.isEqual = isEqual;
    this.value = value;
  }

  function arm() {
    this.trigger = Future.trigger();
    this.next = new Measurement(value, this.trigger);
  }

  inline function differs(a, b)
    return if (isEqual == null) a != b else !isEqual(a, b);

  public function getComparator()
    return isEqual;

  public function set(value) {
    if (guard != null) {
      if (next == null)
        this.value = guard(this.value);
      value = guard(value);
    }
    if (differs(value, this.value)) {
      this.value = value;
      var last = trigger;
      arm();
      if (last != null)
        last.trigger(Noise);
    }
  }
}
