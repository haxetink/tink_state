package ;

import haxe.unit.TestCase;
import haxe.unit.TestRunner;
import tink.state.Observable;
import tink.state.State;

using tink.CoreApi;

class RunTests extends TestCase {

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
	combined.bind(function (x) switch x {
		case Done(v): log.push(v);
		default:
	});
	
	function expect(a:Array<String>) {
		assertEquals(a.join(' --- '), log.join(' --- '));
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

  static function main() {
    var runner = new TestRunner();
  
    runner.add(new RunTests());
  
    travix.Logger.exit(
      if (runner.run()) 0
      else 500
    );
  }
  
}