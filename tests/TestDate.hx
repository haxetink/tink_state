package ;

import tink.state.*;

using tink.CoreApi;
using DateTools;

@:asserts
class TestDate {
  
  public function new() {}
  
  public function basics() {
    var d = new ObservableDate(),
        log = [];
    
    d.becomesOlderThan(.05.seconds()).bind(log.push);
    d.becomesOlderThan(10.seconds()).bind(log.push);
    
    Observable.updateAll();
    asserts.assert(log.join(',') == 'false,false');

    return Future.async(function (done) {
      haxe.Timer.delay(done.bind(Noise), 100);
    }).next(function (_) {
      asserts.assert(log.join(',') == 'false,false,true');
      return asserts.done();
    });
  }
}