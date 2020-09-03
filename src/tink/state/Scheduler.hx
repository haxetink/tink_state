package tink.state;

@:forward
abstract Scheduler(SchedulerObject) from SchedulerObject {
  static public final direct = new DirectScheduler();

  public inline function run(f)
    this.schedule(JustOnce.call(f));

  static public function batched(run)
    return new BatchScheduler(run);

  static public function batcher() {
    function later(fn)
      haxe.Timer.delay(fn, 10);
    #if js
      var later =
        try
          if (js.Browser.window.requestAnimationFrame != null)
            function (fn:Void->Void)
              js.Browser.window.requestAnimationFrame(cast fn);
          else
            later
        catch (e:Dynamic)
          later;
    #end

    function asap(fn)
      later(fn);
    #if js
      var asap =
        try {
          var p = js.lib.Promise.resolve(42);
          function (fn:Void->Void) p.then(cast fn);
        }
        catch (e:Dynamic)
          asap;
    #end

    return function (b:BatchScheduler, isRerun:Bool) {
      (if (isRerun) later else asap)(b.progress.bind(.01));
    }
  }
}

#if java
  typedef Schedulable = java.lang.Runnable;
#else
  interface Schedulable {
    function run():Void;
  }
#end

private class JustOnce implements Schedulable {
  var f:Void->Void;
  function new() {}

  public function run() {
    var f = f;
    this.f = null;
    pool.push(this);
    f();
  }
  static var pool = [];
  static public function call(f) {
    var ret = switch pool.pop() {
      case null: new JustOnce();
      case v: v;
    }
    ret.f = f;
    return ret;
  }
}

private interface SchedulerObject {
  function progress(maxSeconds:Float):Bool;
  function schedule(s:Schedulable):Void;
}

private class DirectScheduler implements SchedulerObject {

  public function new() {}

  public function progress(_)
    return false;

  public function schedule(s:Schedulable)
    @:privateAccess Observable.performUpdate(s.run);
}

private class BatchScheduler implements SchedulerObject {
  var queue:Array<Schedulable> = [];
  var scheduled = false;
  final run:(s:BatchScheduler, isRerun:Bool)->Void;

  public function new(run) {
    this.run = run;
  }

  inline function measure()
    return
      #if java
        Sys.cpuTime();
      #else
        haxe.Timer.stamp();
      #end

  public function progress(maxSeconds:Float)
    return @:privateAccess Observable.performUpdate(() -> {
      var end = measure() + maxSeconds;

      do {
        var old = queue;
        queue = [];
        for (o in old) o.run();
      }
      while (queue.length > 0 && measure() < end);

      if (queue.length > 0) {
        run(this, true);
        true;
      }
      else scheduled = false;
    });

  public function schedule(s:Schedulable) {
    queue.push(s);
    if (!scheduled) {
      scheduled = true;
      run(this, false);
    }
  }
}
