import tink.state.*;

import tink.state.Progress;

using tink.CoreApi;

@:asserts
class TestProgress {
  public function new() {}
  
  public function testProgress() {
    var state = Progress.trigger();
    var progress = state.asProgress();
    
    var p;
    progress.bind({direct: true}, function(v) p = v);
    state.progress(0.5, None);
    asserts.assert(p.value == 0.5);
    asserts.assert(p.total.match(None));
    state.finish('Done');
    progress.result().handle(function(v) {
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
    asserts.assert(p.value == 0.5);
    asserts.assert(p.total.match(None));
    state.finish('Done');
    progress.result().handle(function(v) {
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
    asserts.assert(p.value == 0.5);
    asserts.assert(p.total.match(None));
    state.finish('Done');
    progress.next(function(o) {
      asserts.assert(o.sure() == 'Done');
      return Noise;
    }).eager();
    progress.asPromise().next(function(o) {
      asserts.assert(o == 'Done');
      return Noise;
    }).eager();
    var promise:Promise<String> = progress; // ensure assignable
    progress.result().handle(function(v) {
      asserts.assert(v.match(Success('Done')));
      asserts.done();
    });
    
    return asserts;
  }
}