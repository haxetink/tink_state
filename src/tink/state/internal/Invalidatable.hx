package tink.state.internal;

interface Invalidatable {
  function invalidate():Void;
  #if tink_state.debug
  @:keep function toString():String;
  #end
}