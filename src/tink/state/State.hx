package tink.state;

import tink.state.Observable.ObservableObject;

using tink.CoreApi;

@:forward(set)
abstract State<T>(StateObject<T>) to Observable<T> {
	
  public var value(get, never):T;
    @:to function get_value() return observe().value;
  
  public inline function new(value, ?isEqual) 
    this = new SimpleState(value, isEqual);
	
  public inline function observe():Observable<T>
    return this;

  static public function wire<T>(data:Observable<T>, update:T->Void)
    return new CompoundState(data, update);
    
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

  public function new(data, set) {
    this.data = data;
    this.update = set;
  }

  public function poll()
    return data.poll();

  public function set(value)
    update(value);
}

private class SimpleState<T> implements StateObject<T> {
  
  var next:Measurement<T>;
  var trigger:FutureTrigger<Noise>;
  var isEqual:T->T->Bool;
  
  public function poll()
    return next;
  
  public var value(get, null):T;
    inline function get_value()
      return value;
      
  public function new(value, ?isEqual) {
    this.value = value;
    this.isEqual = switch isEqual {
      case null: function (a, b) return a == b;
      case v: v;
    }
    arm();
  }
  
  function arm() {
    this.trigger = Future.trigger();
    this.next = new Measurement(value, this.trigger);    
  }
  
  public function set(value) 
    if (!isEqual(value, this.value)) {
      this.value = value;
      var last = trigger;
      arm();
      last.trigger(Noise);
    }
}
