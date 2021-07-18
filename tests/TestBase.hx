package ;

import haxe.macro.Expr;
#if !macro
@:autoBuild(TestBase.build())
#end
class TestBase {
  public function new() {}
  macro function assert(_, e) {
    return macro @:pos(e.pos) assertions.yield(Data(tink.unit.Assert.assert($e)));
  }
  static macro function build():Array<Field> {
    function hasDescribe(m:Metadata) {
      return Lambda.exists(m, m -> m.name == ':describe');
    }
    return [for (f in haxe.macro.Context.getBuildFields())
      switch f {
        case { kind: FFun(fun), meta: hasDescribe(_) => true }: 
          fun.expr = macro {
            final assertions = new tink.streams.Accumulator<tink.testrunner.Assertion>();
            function done() assertions.yield(End);
            ${fun.expr};
            return assertions;
          };
          f;
        default: f;
      }
    ];
  }
}