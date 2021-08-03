package;

import tink.state.Scheduler.direct;
import tink.state.*;

using tink.CoreApi;

@:asserts
class TestBasic {

  public function new() {}

  public function donotFireEqual() {
    final s = new State(0),
        sLog = [];
    var watch = s.observe().bind(sLog.push, (_, _) -> true, direct);

    final o1Log = [],
        o1 = Observable.auto(() -> {
          return s.value >> 8;
        });
    final o2Log = [],
        o2 = Observable.auto(() -> {
          return s.value;
        });
    watch &= o1.bind(o1Log.push, direct);
    watch &= o2.bind(o2Log.push, direct);

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
    final ta = Signal.trigger(),
        tb = Signal.trigger(),
        sa = new State(5),
        sb = new State('foo');

    ta.asSignal().handle(sa);
    tb.asSignal().handle(sb);

    final queue = [];

    function next()
      switch queue.shift() {
        case null:
        case v:
          v();
      }

    final combined = sa.observe().combineAsync(sb, (a, b) -> Promise.irreversible((resolve, reject) -> queue.push(resolve.bind('$a $b'))));

    var log = [];
    final watch = combined.bind(x -> switch x {
      case Done(v): log.push(v);
      default:
    }, direct);

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
    final s = new State(5);
    final o = s.observe();

    var fired = 0;
    function await(f:Future<Int>)
      f.handle(() -> fired++);

    function set(value:Int) {
      s.set(value);
      Observable.updateAll();
    }

    await(o.nextTime({ hires: true, butNotNow: true }, x -> x == 5));
    await(o.nextTime({ hires: true, }, x -> x == 5));
    await(o.nextTime({ hires: true, butNotNow: true }, x -> x == 4));
    await(o.nextTime({ hires: true, }, x -> x == 4));

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
    final value = 'foobar';
    final o:Observable<String> = Observable.const(value);

    asserts.assert(value == o);

    asserts.assert(nil == null);

    final o1 = Observable.const("foo"),
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
