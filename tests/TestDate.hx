package ;

import deepequal.DeepEqual.*;
import tink.state.*;

using DateTools;
using tink.CoreApi;

@:asserts
class TestDate {

  public function new() {}

  public function basics() {
    final d = new ObservableDate(),
        log = [];

    var watch = d.becomesOlderThan(1.seconds()).bind(log.push);
    watch &= d.becomesOlderThan(10.seconds()).bind(log.push);

    Observable.updateAll();
    asserts.assert(compare([false,false], log));

    return Future.delay(1100, Noise).next(_ -> {
      asserts.assert(compare([false,false,true], log));
      watch.cancel();
      return asserts.done();
    });
  }
}
