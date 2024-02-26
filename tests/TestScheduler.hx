import tink.state.*;
@:asserts
class TestScheduler {
  public function new() {}

  public function testCycle() {
    final s1 = new State(0),
        s2 = new State(0);

    final l1 = s1.observe().bind(v -> s2.set(v + 1)),
        l2 = s2.observe().bind(v -> s1.set(v + 1));

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
    final before = s1.value;
    l1.cancel();
    l2.cancel();
    Observable.updatePending();
    asserts.assert(Math.abs(s1.value - s2.value) == 1);
    asserts.assert(before == s1.value);
    return asserts.done();
  }

  public function testPhases() {
    final s1 = new State(0),
        s2 = new State('foo'),
        s3 = new State('bar');

    final log = [];

    var watch = s1.observe().bind(v -> {
      s2.set('foo($v)');
      s3.set('bar($v)');
    });

    watch &= Observable.auto(() -> {
      return s2.value + s3.value;
    }).bind(log.push);

    function checkLog(expected, ?pos:haxe.PosInfos)
      asserts.assert(log.join(',') == expected, null, pos);

    checkLog('foo(0)bar(0)');

    s1.set(1);

    checkLog('foo(0)bar(0)');

    Observable.updateAll();

    checkLog('foo(0)bar(0),foo(1)bar(1)');

    watch.cancel();

    return asserts.done();
  }

  public function testAtomic() {
    final s = new State(0);
    var cur = 0;
    s.observe().bind(v -> cur = v, Scheduler.direct);

    Scheduler.atomically(() -> {
      s.set(1);
      asserts.assert(s.value == 1);
      asserts.assert(cur == 0);
      Scheduler.atomically(() -> s.set(2));
      asserts.assert(s.value == 1);
      asserts.assert(cur == 0);
      Scheduler.atomically(() -> s.set(3), true);
      asserts.assert(s.value == 3);
      asserts.assert(cur == 0);
    });
    asserts.assert(cur == 2);

    return asserts.done();
  }
}
