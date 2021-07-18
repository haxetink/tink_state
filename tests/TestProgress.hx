import tink.state.*;

import tink.state.Scheduler.direct;

using tink.CoreApi;

import tink.state.Progress;

@:asserts
class TestProgress {
  public function new() {}

  public function testProgress() {
    final state = Progress.trigger();
    final progress = state.asProgress();

    var p;
    final watch = progress.bind(v -> p = v, direct);
    state.progress(0.5, None);
    asserts.assert(p.match(InProgress({ value: 0.5, total: None })));
    state.finish('Done');
    progress.result.handle(v -> {
      asserts.assert(v == 'Done');
      asserts.done();
    });

    watch.cancel();

    return asserts;
  }

  public function testFutureProgress() {
    final state = Progress.trigger();
    final progress:Progress<String> = Future.sync(state.asProgress());

    var p;
    final watch = progress.bind(v -> p = v, direct);
    state.progress(0.5, None);

    asserts.assert(p.match(InProgress({ value: 0.5, total: None })));
    state.finish('Done');
    progress.result.handle(v -> {
      asserts.assert(v == 'Done');
      asserts.done();
    });

    watch.cancel();

    return asserts;
  }

  public function testPromiseProgress() {
    final state:ProgressTrigger<String> = Progress.trigger();
    final progress:Progress<Outcome<String, Error>> = Promise.lift(state.asProgress());

    var p;
    final watch = progress.bind(v -> p = v, direct);
    state.progress(0.5, None);
    asserts.assert(p.match(InProgress({ value: 0.5, total: None })));
    state.finish('Done');
    progress.next(o -> {
      asserts.assert(o.sure() == 'Done');
      return Noise;
    }).eager();
    progress.asPromise().next(o -> {
      asserts.assert(o == 'Done');
      return Noise;
    }).eager();
    progress.result.handle(v -> {
      asserts.assert(v.match(Success('Done')));
      asserts.done();
    });

    watch.cancel();

    return asserts;
  }
}