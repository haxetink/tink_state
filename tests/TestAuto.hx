package;

import tink.state.*;

class TestAuto extends TestBase {
  @:describe("")
  public function test() {
    var s1 = new State(4),
        s2 = new State(5);
    
    var calls = 0;
    var o = Observable.auto(function () return { 
      calls++;
      s1.value + s2.value; 
    });
    
    assert(9 == o.value);
    s1.set(10);
    assert(15 == o.value);
    s1.set(11);
    assert(16 == o.value);
    s1.set(1);
    s2.set(2);
    s2.set(3);
    assert(4 == o.value);
    var old = calls;
    assert(4 == o.value);
    assert(old == calls);
    done();
  }
}