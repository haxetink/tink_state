import tink.state.*;

@:asserts
class TestProgress {
  public function new() {}
  
  public function testProgress() {
    var state = Progress.trigger(Some(1.0));
    var progress = state.asProgress();
    
    asserts.assert(progress.total.match(Some(1.0)));
    var p = 0.;
    progress.progress({direct: true}, function(v) p = v);
    state.progress(0.5);
    asserts.assert(p == 0.5);
    state.finish('Done');
    asserts.assert(p == 1);
    progress.result().handle(function(v) {
      asserts.assert(v == 'Done');
      asserts.done();
    });
    
    var state = Progress.trigger(None);
    var progress = state.asProgress();
    
    asserts.assert(progress.total.match(None));
    var p = 0.;
    progress.progress({direct: true}, function(v) p = v);
    state.progress(0.5);
    asserts.assert(p == 0.5);
    state.finish('Done');
    asserts.assert(p == 1);
    progress.result().handle(function(v) {
      asserts.assert(v == 'Done');
      asserts.done();
    });
    return asserts;
  }
}