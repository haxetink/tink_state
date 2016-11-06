package tink.state;

import tink.state.Observable.ObservableObject;

using tink.CoreApi;

@:forward(value, set)
abstract State<T>(StateObject<T>) to Observable<T> {
	
  public inline function new(value) 
    this = new StateObject(value);
	
  public inline function observe():Observable<T>
    return this;
  
  @:to public function toCallback():Callback<T>
    return this.set;
	
  @:from static function ofConstant<T>(value:T):State<T> 
    return new State(value);
  
}

private class StateObject<T> implements ObservableObject<T> {

  public var value(get, null):T;
    inline function get_value()
      return value;
    
  public var changed(get, never):Signal<Noise>;
    inline function get_changed()
      return _changed.asSignal();
    
  var _changed:SignalTrigger<Noise> = Signal.trigger();  
      
  public function new(value) 
    this.value = value;
  
  public function set(value) 
    if (value != this.value) {
      this.value = value;
      this._changed.trigger(Noise);
    }
}