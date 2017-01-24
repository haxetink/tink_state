package tink.state;

import tink.state.Observable.ObservableObject;

using tink.CoreApi;

@:forward(set)
abstract State<T>(StateObject<T>) to Observable<T> {
	
  public var value(get, never):T;
    @:to function get_value() return observe().value;
  
  public inline function new(value) 
    this = new StateObject(value);
	
  public function observe():Observable<T>
    return this;
    
  @:impl static public function toggle(s:StateObject<Bool>) {
    s.set(!s.value);
  }
  
  @:to public function toCallback():Callback<T>
    return this.set;
	
  @:from static function ofConstant<T>(value:T):State<T> 
    return new State(value);
  
}

private class StateObject<T> implements ObservableObject<T> {
  
  
  var next:Pair<T, Future<Noise>>;
  var trigger:FutureTrigger<Noise>;
  
  public function poll()
    return next;
  
  public var value(get, null):T;
    inline function get_value()
      return value;
      
  public function new(value) {
    this.value = value;
    arm();
  }
  
  function arm() {
    this.trigger = Future.trigger();
    this.next = new Pair(value, this.trigger.asFuture());    
  }
  
  public function set(value) 
    if (value != this.value) {
      this.value = value;
      var last = trigger;
      arm();
      last.trigger(Noise);
    }
}