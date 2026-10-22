package ;

import tink.testrunner.*;
import tink.testrunner.Suite;
import tink.unit.*;

using tink.CoreApi;

class RunTests {

  static function main() {
    final batch:Batch = TestBatch.make([
      new TestBasic(),
      new TestDate(),
      new TestAuto(),
      new TestAutorun(),
      new TestMaps(),
      new TestArrays(),
      new TestScheduler(),
      new TestProgress(),
      new TestSignalObservable(),
      new issues.Issue51(),
      new issues.Issue61(),
      new issues.Issue63(),
    ]);
    Runner.run([for (suite in batch.suites) (new FreshStack(suite):Suite)]).handle(Runner.exit);
  }
}

/**
  The runner chains the cases synchronously, so the stack grows with every one of them. Once it is deep enough,
  tink_core's stack overflow guard defers callbacks (at depth 100 on python), and bindings that a test expects to
  fire synchronously don't. Starting each case from a deferred call keeps the stack shallow on every target.
**/
class FreshStack implements SuiteObject {
  public var info:SuiteInfo;
  public var cases:Array<Case>;
  final suite:Suite;

  public function new(suite:Suite) {
    this.suite = suite;
    this.info = suite.info;
    this.cases = suite.cases;
  }

  public function setup()
    return suite.setup();

  public function before():Promise<Noise>
    return new Future<Noise>(resume -> {
      Callback.defer(() -> resume(Noise));
      null;
    }).flatMap(_ -> suite.before());

  public function after()
    return suite.after();

  public function teardown()
    return suite.teardown();
}
