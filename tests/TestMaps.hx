package ;

import tink.state.*;

using tink.CoreApi;

class TestMaps extends TestBase {
  @:describe("basic test")
  public function testEntries() {
    var o = new ObservableMap([5 => 0, 6 => 0]);

    var a = [];

    function report(k:Int) return function (v:Int) a.push('$k:$v');

    var unlink:CallbackLink = [
      o.observe(5).bind({ direct: true }, report(5)),
      o.observe(6).bind({ direct: true }, report(6)),
    ];

    o.set(5, 1);
    o.set(5, 2);
    o.set(5, 3);
    o.set(4, 3);

    assert('5:0,6:0,5:1,5:2,5:3' == a.join(','));

    o.set(6, 1);
    o.set(6, 1);
    o.set(6, 2);

    assert('5:0,6:0,5:1,5:2,5:3,6:1,6:2' == a.join(','));

    a = [];
    unlink.dissolve();
    
    o.observe(5).bind(report(5));
    o.observe(6).bind(report(6));
    
    o.set(5, 1);
    o.set(5, 2);
    o.set(5, 3);
    o.set(4, 3);

    assert('' == a.join(','));

    o.set(6, 1);
    o.set(6, 1);
    o.set(6, 2);

    assert('' == a.join(','));

    Observable.updateAll();    
    
    assert('5:3,6:2' == a.join(','));

    done();
  }
}