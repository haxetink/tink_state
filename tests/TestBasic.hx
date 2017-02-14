package;

import haxe.unit.TestCase;
import tink.state.Promised;
import tink.state.Observable;
import tink.state.State;

using tink.CoreApi;

class TestBasic extends TestCase {

  function test() {
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
    
    function expect(a:Array<String>, ?pos) {
      assertEquals(a.join(' --- '), log.join(' --- '), pos);
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
  }
  
}
