package;

import tink.state.Promised;
import tink.state.*;

using tink.CoreApi;

@:asserts
class TestBasic {
  
  public function new() {}

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
    
    function expect(a:Array<String>, ?pos:haxe.PosInfos) {
      asserts.assert(a.join(' --- ') == log.join(' --- '), pos);
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
    return asserts.done();
  }
  
  public function testNextTime() {
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

    asserts.assert(fired == 1);
    
    set(4);
    
    asserts.assert(fired == 3);
    
    set(5);

    asserts.assert(fired == 4);

    set(4);
    set(5);

    asserts.assert(fired == 4);

    return asserts.done();
  }
}
