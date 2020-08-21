package tink.state;

import tink.state.Observable;
import tink.state.Invalidatable;

using tink.CoreApi;

@:forward(set)
abstract State<T>(StateObject<T>) to Observable<T> from StateObject<T> {

  public var value(get, never):T;
    @:to function get_value() return observe().value;

  public inline function new(value, ?comparator, ?guard)
    this = switch guard {
      case null: new SimpleState(value, comparator);
      case f: new GuardedState(value, guard, comparator);
    }

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

  public function getObservers()
    return data.getObservers();

  public function set(value) {
    update(value);//TODO: consider running comparator here
    return value;
  }

  public function getComparator()
    return this.comparator;
}

private class GuardedState<T> extends SimpleState<T> {
  final guard:T->T;
  var guardApplied = false;

  public function new(value, guard, ?comparator) {
    super(value, comparator);
    this.guard = guard;
  }

  override function getValue():T
    return
      if (!guardApplied) applyGuard();
      else value;

  @:extern inline function applyGuard():T {
    this.guardApplied = true;
    return value = guard(value);
  }

  override function set(value:T):T {
    if (guardApplied)
      applyGuard();
    return super.set(guard(value));
  }
}

private class SimpleState<T> extends Invalidator implements StateObject<T> {

  final comparator:Comparator<T>;
  var value:T;

  public function isValid()
    return true;

  public function new(value, ?comparator) {
    this.value = value;
    this.comparator = comparator;
  }

  public function getValue()
    return value;

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

    if (!comparator.eq(value, this.value)) {
      this.value = value;
      fire();
    }
    return value;
  }
}
