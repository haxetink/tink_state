package tink.state;

import tink.state.Observable;

using tink.CoreApi;

@:forward(set)
abstract State<T>(StateObject<T>) to Observable<T> from StateObject<T> {

  public var value(get, never):T;
    @:to function get_value() return observe().value;

  public inline function new(value, ?comparator, ?guard)
    this = new SimpleState(value, comparator, guard);

  public inline function observe():Observable<T>
    return this;

  public function transform<R>(rules:{ function read(v:T):R; function write(v:R):T; }):State<R>
    return new CompoundState(observe().map(rules.read), function (value) this.set(rules.write(value)));

  public inline function bind(?options:BindingOptions<T>, cb:Callback<T>):CallbackLink
    return observe().bind(options, cb);

  @:impl static public function toggle(s:StateObject<Bool>) {
    s.set(!s.getValue());
  }

  @:to public function toCallback():Callback<T>
    return this.set;

  static public function compound<T>(source:Observable<T>, update:T->Void, ?comparator:T->T->Bool):State<T>
    return new CompoundState(source, update, comparator);

}

private interface StateObject<T> extends ObservableObject<T> {
  function set(value:T):T;
}

private class CompoundState<T> implements StateObject<T> {

  var data:ObservableObject<T>;
  var update:T->Void;
  var comparator:Comparator<T>;

  public function new(data, set, ?comparator) {
    this.data = data;
    this.update = set;
    this.comparator = comparator;
  }

  public function isValid()
    return data.isValid();

  public function getValue()
    return data.getValue();

  public function onInvalidate(i)
    return data.onInvalidate(i);

  public function set(value) {
    update(value);//TODO: consider running comparator here
    return value;
  }

  public function getComparator()
    return this.comparator;
}

private class SimpleState<T> extends Invalidator implements StateObject<T> {

  final comparator:Comparator<T>;
  final guard:T->T;
  var value:T;
  var guardApplied:Bool;

  public function isValid()
    return true;

  public function new(value, ?comparator, ?guard) {
    super();
    this.value = value;
    this.guard = guard;
    this.comparator = comparator;
    this.guardApplied = guard == null;
  }

  public function getValue() {
    if (!this.guardApplied) {
      this.guardApplied = true;
      value = guard(value);
    }
    return value;
  }

  public function getComparator()
    return comparator;

  static inline function warn(s)
    #if js
      #if hxnodejs
        js.Node.console.warn(s);
      #else
        js.Browser.console.warn(s);
      #end
    #else
      trace('Warning: $s');
    #end

  public function set(value) {
    #if !tink_state_ignore_binding_cascade_because_I_am_a_naughty_naughty_boy
    if (Observable.isUpdating)
      warn('Updating state in a binding');
    #end

    if (guard != null) {
      getValue();
      value = guard(value);
    }

    if (!comparator.eq(value, this.value)) {
      this.value = value;
      fire();
    }
    return value;
  }
}
