package;

import tink.state.*;

@:asserts
class TestAuto {
  public function new() {}
  
  public function test() {
    var s1 = new State(4),
        s2 = new State(5);
    
    var calls = 0;
    var o = Observable.auto(function () return { 
      calls++;
      s1.value + s2.value; 
    });
    
    asserts.assert(9 == o.value);
    s1.set(10);
    asserts.assert(15 == o.value);
    s1.set(11);
    asserts.assert(16 == o.value);
    s1.set(1);
    s2.set(2);
    s2.set(3);
    asserts.assert(4 == o.value);
    var old = calls;
    asserts.assert(4 == o.value);
    asserts.assert(old == calls);
    return asserts.done();
  }

  public function testDirect() {
    var calls = 0;
    var s1 = new State(4),
        s2 = new State(5);
    var o = Observable.auto(function () {
      calls++;
      return s1.value + s2.value;
    });
    
    var sum = 0;
    
    o.bind({ direct: true }, function (v) sum = v);
    
    asserts.assert(sum == s1.value + s2.value);
    asserts.assert(calls == 1);
    
    s1.set(s1.value + 1);
    s2.set(s2.value + 1);
    
    asserts.assert(sum == s1.value + s2.value);
    asserts.assert(calls == 3);

    s1.set(s1.value + 1);
    s2.set(s2.value + 1);
    
    asserts.assert(sum == s1.value + s2.value);
    asserts.assert(calls == 5);    
    
    return asserts.done();
  }

  // @:include
  public function donotFireEqualAuto() {
    var s = new State(1 << 5);

    function inc()
      s.set(s.value + 1);

    var o = s.observe();
    var a = [];

    for (i in 0...5) {
      a[i] = -1;
      var cur = o;
      o = Observable.auto(function () {
        a[i]++;
        return cur.value >> 1;
      });
    }

    o.bind({ direct: true}, function () {});

    for (i in 0...s.value >> 1) 
      inc();
    
    asserts.assert('16,8,4,2,1' == a.join(','));
  
    return asserts.done();
  }  
}