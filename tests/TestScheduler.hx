import tink.state.*;
@:asserts
class TestScheduler {
  public function new() {}
  #if js
  public function testCycle() {
    var s1 = new State(0),
        s2 = new State(0);
    s1.observe().bind(function (v) s2.set(v + 1));
    s2.observe().bind(function (v) s1.set(v + 1));
    asserts.assert(s1.value == 0);
    asserts.assert(s2.value == 0);
    Observable.updatePending(0);
    asserts.assert(s1.value == 2);
    asserts.assert(s2.value == 1);
    Observable.updatePending(0);
    asserts.assert(s1.value == 2);
    asserts.assert(s2.value == 3);
    Observable.updatePending(0);
    asserts.assert(s1.value == 4);
    asserts.assert(s2.value == 3);
    Observable.updatePending();
    asserts.assert(Math.abs(s1.value - s2.value) == 1);
    return asserts.done();
  }

  @:include public function testPhases() {
    var s1 = new State(0),
        s2 = new State('foo'),
        s3 = new State('bar');

    var log = [];
    
    s1.observe().bind(function (v) {
      s2.set('foo($v)');
      s3.set('bar($v)');
    });

    Observable.auto(function () {
      return s2.value + s3.value;
    }).bind(log.push);

    function checkLog(expected)
      asserts.assert(log.join(',') == expected);

    checkLog('');

    Observable.updateAll();

    checkLog('foo(0)bar(0)');

    s1.set(1);

    checkLog('foo(0)bar(0)');

    Observable.updateAll();

    checkLog('foo(0)bar(0),foo(1)bar(1)');

    return asserts.done();
  }
  #end  
}