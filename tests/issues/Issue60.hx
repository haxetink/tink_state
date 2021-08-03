package issues;

import tink.state.State;
import tink.state.Observable;
using tink.CoreApi;

@:asserts
class Issue60 {
  public function new() {}
  public function test() {
    var counter = new State(0),
        triggers = [],
        futures = [];

    function load() {
      var value = counter.value;
      var trigger = new FutureTrigger<Noise>();
      var future = new Future(fire -> trigger.handle(() -> fire(value)));

      // there's probably no need for arrays here, but whatever
      triggers.push(trigger);
      futures.push(future);

      return future;
    }

    function progress()
      asserts.assert(triggers[triggers.length - 1].trigger(Noise));

    function status()
      return futures[futures.length - 1].status;

    final o = Observable.auto(load);

    function eager() {
      return o.bind(function () {});
    }

    var binding = eager();

    asserts.assert(o.value.match(Loading));
    asserts.assert(status().match(Awaited));

    progress();

    asserts.assert(o.value.match(Done(0)));
    asserts.assert(status().match(Ready(_)));

    counter.value++;

    asserts.assert(o.value.match(Loading));
    asserts.assert(status().match(Awaited));

    progress();

    asserts.assert(o.value.match(Done(1)));
    asserts.assert(status().match(Ready(_)));

    counter.value++;

    asserts.assert(o.value.match(Loading));
    asserts.assert(status().match(Awaited));

    binding.cancel();

    asserts.assert(o.value.match(Loading));
    asserts.assert(status().match(Suspended));

    binding = eager();

    asserts.assert(o.value.match(Loading));
    asserts.assert(status().match(Awaited));

    progress();

    asserts.assert(o.value.match(Done(2)));
    asserts.assert(status().match(Ready(_)));

    return asserts.done();
  }
}