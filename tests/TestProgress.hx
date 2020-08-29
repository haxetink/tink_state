import tink.state.*;


using tink.CoreApi;

import tink.state.Progress;

@:asserts
class TestProgress {
  public function new() {}

  public function testProgress() {
    var state = Progress.trigger();
    var progress = state.asProgress();

    var p;
    progress.bind({direct: true}, function(v) p = v);
    state.progress(0.5, None);
    asserts.assert(p.match(InProgress({ value: 0.5, total: None })));
    state.finish('Done');
    progress.result.handle(function(v) {
      asserts.assert(v == 'Done');
      asserts.done();
    });

    return asserts;
  }

  public function testFutureProgress() {
    var state = Progress.trigger();
    var progress:Progress<String> = Future.sync(state.asProgress());

    var p;
    progress.bind({direct: true}, function(v) p = v);
    state.progress(0.5, None);
    trace(Std.string(progress.status));
    asserts.assert(p.match(InProgress({ value: 0.5, total: None })));
    state.finish('Done');
    progress.result.handle(function(v) {
      asserts.assert(v == 'Done');
      asserts.done();
    });

    return asserts;
  }

  public function testPromiseProgress() {
    var state:ProgressTrigger<String> = Progress.trigger();
    var progress:Progress<Outcome<String, Error>> = Promise.lift(state.asProgress());

    var p;
    progress.bind({direct: true}, function(v) p = v);
    state.progress(0.5, None);
    asserts.assert(p.match(InProgress({ value: 0.5, total: None })));
    state.finish('Done');
    progress.next(function(o) {
      asserts.assert(o.sure() == 'Done');
      return Noise;
    }).eager();
    progress.asPromise().next(function(o) {
      asserts.assert(o == 'Done');
      return Noise;
    }).eager();
    progress.result.handle(function(v) {
      asserts.assert(v.match(Success('Done')));
      asserts.done();
    });

    return asserts;
  }
}