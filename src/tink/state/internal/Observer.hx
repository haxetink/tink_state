package tink.state.internal;

interface Observer {
  function notify<R>(from:ObservableObject<R>):Void;
  #if tink_state.debug
  @:keep function toString():String;
  #end
}