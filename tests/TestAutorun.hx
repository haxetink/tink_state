import tink.state.Scheduler.direct;
import tink.state.*;

@:asserts
class TestAutorun {
  public function new() {}
  public function test() {
    var s = new State(0);
    var log = [];
    Observable.autorun(() -> {
      log.push('before ${s.value}');
      if (s.value < 2)
        s.value += 1;
      log.push('after ${s.value}');
    }, direct);
    asserts.assert(log.join(' - ') == 'before 0 - after 1 - before 1 - after 2 - before 2 - after 2');
    return asserts.done();
  }
}