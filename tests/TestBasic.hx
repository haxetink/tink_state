package;

import tink.state.Observable;
import tink.state.*;

using tink.CoreApi;

@:asserts
class TestBasic {

  public function new() {}

  public function donotFireEqual() {
    var s = new State(0),
        sLog = [];
    var watch = s.observe().bind({ direct: true, comparator: function (_, _) return true }, sLog.push);

    var o1Log = [],
        o1 = Observable.auto(function () {
          return s.value >> 8;
        });
    var o2Log = [],
        o2 = Observable.auto(function () {
          return s.value;
        });
    watch &= o1.bind({ direct: true }, o1Log.push);
    watch &= o2.bind({ direct: true }, o2Log.push);

    asserts.assert(sLog.join(',') == '0');
    asserts.assert(o1Log.join(',') == '0');
    asserts.assert(o2Log.join(',') == '0');

    s.set(1 << 4);
    s.set(0);
    s.set(1 << 8);

    asserts.assert(sLog.join(',') == '0');
    asserts.assert(o1Log.join(',') == '0,1');
    asserts.assert(o2Log.join(',') == '0,16,0,256');

    watch.cancel();

    return asserts.done();
  }

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
    var watch = combined.bind({ direct: true }, function (x) switch x {
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
    watch.cancel();
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

  var nil:Observable<Int>;
  public function eqConst() {
    var value = 'foobar';
    var o:Observable<String> = Observable.const(value);

    asserts.assert(value == o);

    asserts.assert(nil == null);

    var o1 = Observable.const("foo"),
        o2 = Observable.const("foo");

    asserts.assert(o1 == o1, 'are equal');
    asserts.assert(o1 == o2, 'are equal');
    asserts.assert(o1 == 'foo', 'equals const');
    asserts.assert('foo' == o2, 'const equals');
    asserts.assert(o1 != 'bar', 'not equals const');
    asserts.assert(!(o1 != 'foo'), 'not not equals const');
    asserts.assert('bar' != o2, 'not const equals');
    asserts.assert(!('foo' != o2), 'not not const equals');

    return asserts.done();
  }
}
