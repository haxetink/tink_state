package ;

import tink.state.*;

using tink.CoreApi;
using StringTools;

@:asserts
class TestArrays {
  
  public function new() {}
  
  public function basics() {
    var a = new ObservableArray([for (i in 0...100) i]);
    var log = [];

    function clear()
      log = [];

    function getLog()
      return log.join(',').replace('undefined', '-').replace('null', '-');

    function report(name:String) return function (v:Int) log.push('$name:$v');

    a.observableLength.bind({ direct: true }, report('l'));
    a.observe(99).bind({ direct: true }, report('99'));

    asserts.assert(getLog() == 'l:100,99:99');
    clear();

    for (i in 0...10)
      a.pop();

    asserts.assert(getLog() == 'l:99,99:-,l:98,l:97,l:96,l:95,l:94,l:93,l:92,l:91,l:90');
    clear();

    for (i in 0...9)
      a.unshift(a.get(0)-1);    
    
    asserts.assert(getLog() == 'l:91,l:92,l:93,l:94,l:95,l:96,l:97,l:98,l:99');

    clear();
    a.unshift(a.get(0)-1);    
    asserts.assert(getLog() == '99:89,l:100');//It's a good question why exactly this happens out of order
    clear();
    for (i in 0...10)
      a.push(i);

    asserts.assert(getLog() == 'l:101,l:102,l:103,l:104,l:105,l:106,l:107,l:108,l:109,l:110');

    return asserts.done();
  }
}