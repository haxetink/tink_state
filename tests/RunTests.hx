package ;

import haxe.unit.TestRunner;

class RunTests {

  static function main() 
    tink.testrunner.Runner.run(tink.unit.TestBatch.make([
      new TestMaps(),
      new TestAuto(),
      new TestArrays(),
    ]))
      .handle(function(result) {
        travix.Logger.exit(result.summary().failures.length);
      });
  
}