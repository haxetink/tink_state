package;

import tink.state.Promised;
import tink.state.Observable;
import tink.state.State;

using tink.CoreApi;

class TestBasic extends TestBase {
  @:describe("")
  public function test() {
    var ta = Signal.trigger(),
        tb = Signal.trigger(),
        sa = new State(5),
        sb = new State('foo');
    
    ta.asSignal().handle(sa);
    tb.asSignal().handle(sb);
  
    var queue = [];
      
    function next() 
      switch queue.shift() {
        case null:
        case v: 
          v();
      }
      
    var combined = sa.observe().combineAsync(sb, function (a, b):Promise<String> {
      return Future.async(function (cb) { 
        queue.push(cb.bind('$a $b'));
      });
    });
    
    var log = [];
    combined.bind({ direct: true }, function (x) switch x {
      case Done(v): log.push(v);
      default:
    });
    
    function expect(a:Array<String>) {
      assert(a.join(' --- ') == log.join(' --- '));
      log = [];
    }
    
    expect([]);
    next();
    expect(['5 foo']);
    
    sa.set(4);
    tb.trigger('yo');
    
    expect([]);
    next();
    expect([]);
    next();
    
    expect(['4 yo']);
    done();
  }
  
  @:describe("") public function testNextTime() {
    var s = new State(5);
    var o = s.observe();

    var fired = 0;
    function await(f:Future<Int>)
      f.handle(function () fired++);

    function set(value:Int) {
      s.set(value);
      Observable.updateAll();
    }

    await(o.nextTime({ hires: true, butNotNow: true }, function (x) return x == 5));
    await(o.nextTime({ hires: true, }, function (x) return x == 5));
    await(o.nextTime({ hires: true, butNotNow: true }, function (x) return x == 4));
    await(o.nextTime({ hires: true, }, function (x) return x == 4));
    
    Observable.updateAll();

    assert(fired == 1);
    
    set(4);
    
    assert(fired == 3);
    
    set(5);

    assert(fired == 4);

    set(4);
    set(5);

    assert(fired == 4);

    done();
  }
}
