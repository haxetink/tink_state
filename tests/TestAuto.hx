package;

import haxe.unit.TestCase;
import tink.state.Promised;
import tink.state.Observable;
import tink.state.State;

using tink.CoreApi;

class TestAuto extends TestCase {
  function test() {
    var s1 = new State(4),
        s2 = new State(5);
    
    var calls = 0;
    var o = Observable.auto(function () return { 
      calls++;
      s1.value + s2.value; 
    });
    
    assertEquals(9, o.value);
    s1.set(10);
    assertEquals(15, o.value);
    s1.set(11);
    assertEquals(16, o.value);
    s1.set(1);
    s2.set(2);
    s2.set(3);
    assertEquals(4, o.value);
    var old = calls;
    assertEquals(4, o.value);
    assertEquals(old, calls);
  }
}