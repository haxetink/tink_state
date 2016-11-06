package tink.state;

using tink.CoreApi;


private class Node {
  
  var _next:Node;
  var queue:Array<Void->Void> = [];
  var pending:Int = 0;
  var id = counter++;
  static var counter = 0;
  
  public function new() { }
  
  public function add<X>(f:Void->Future<X>) {
    return
      switch queue {
        case null:
          pending++;
          var ret = f();
          ret.handle(function () {
            pending--;
            check();
          });
          return ret;
        case a:
          var ret = Future.trigger();
          pending++;
          queue.push(function () f().handle(function (x) {
            ret.trigger(x);
            pending--;
            check();
          }));
          ret.asFuture();
      }
  }
    
  function check() {
    if (pending == 0 && _next != null)
      _next.activate();
  }
  
  function activate() {
    var old = queue;
    queue = null;
    for (f in old) f();
  }
    
  public function next() {
    if (pending == 0)
      return this;
      
    if (_next == null)
      _next = new Node();
    
    check();
    return _next;
  }
  
  static public function root() {
    var ret = new Node();
    ret.activate();
    return ret;
  }
}

class Gate { 
  
  var node:Node = Node.root();
  
  public function new() {}
  
  public function parallel<X>(f:Void->Future<X>):Future<X> {
    return node.add(f);
  }
  
  public function serial<X>(f:Void->Future<X>):Future<X> {
    node = node.next();
    var ret = node.add(f);
    node = node.next();
    return ret;
  }
  
}



/*
    function delay(name:String, ?time:Float = .0) {
      return function () return Future.async(function (cb) {
        
        if (time == 0)
          time = .2 + .2 * Math.random();
          
        js.Node.setTimeout(function () {
          trace(name);
          cb(name);
        }, Std.int(time * 1000));
      });
    }
    
    var g = new Gate();
    
    for (i in 0...5) {
      
      for (j in 0...Std.random(5)+1)
        g.serial(delay('[SERIAL] $i/$j'));
      for (j in 0...10)
        g.parallel(delay('  parallel $i/$j')).handle(function () if (j == 0) g.parallel(delay('  echo$i')));
      
    }

 */