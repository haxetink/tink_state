import tink.state.*;

@:asserts
class TestProgress {
  public function new() {}
  
  public function testProgress() {
    var state = Progress.trigger();
    var progress = state.asProgress();
    
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