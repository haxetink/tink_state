package ;

import haxe.unit.TestRunner;

class RunTests {

  

  static function main() {
    var runner = new TestRunner();
  
    runner.add(new TestBasic());
    runner.add(new TestAuto());
  
    travix.Logger.exit(
      if (runner.run()) 0
      else 500
    );
  }
  
}