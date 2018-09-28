package ;

import tink.state.*;
import deepequal.DeepEqual.*;

using tink.CoreApi;
using DateTools;

@:asserts
class TestDate {
  
  public function new() {}
  
  public function basics() {
    var d = new ObservableDate(),
        log = [];
    
    d.becomesOlderThan(1.seconds()).bind(log.push);
    d.becomesOlderThan(10.seconds()).bind(log.push);
    
    Observable.updateAll();
    asserts.assert(compare(log, [false,false]));

    return Future.async(function (done) {
      haxe.Timer.delay(done.bind(Noise), 1100);
    }).next(function (_) {
      asserts.assert(compare(log, [false,false,true]));
      return asserts.done();
    });
  }
}