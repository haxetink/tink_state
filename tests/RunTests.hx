package ;

import tink.testrunner.*;
import tink.unit.*;

class RunTests {

  static function main() {
    Runner.run(TestBatch.make([
      new TestBasic(),
      new TestDate(),
      new TestAuto(),
      new TestAutorun(),
      new TestMaps(),
      new TestArrays(),
      new TestScheduler(),
      new TestProgress(),
      new issues.Issue51(),
      new issues.Issue60(),
      new issues.Issue61(),
      new issues.Issue63(),
    ])).handle(Runner.exit);
  }
}