package tink.state.debug;

class Logger {
  function new() {}
  public function subscribed<X, Y>(source:Observable<X>, derived:Observable<Y>) {}
  public function unsubscribed<X, Y>(source:Observable<X>, derived:Observable<Y>) {}
  public function connected<X, Y>(source:Observable<X>, derived:Observable<Y>) {}
  public function disconnected<X, Y>(source:Observable<X>, derived:Observable<Y>) {}
  public function triggered<X>(source:Observable<X>, watcher:Invalidatable) {}
  public function revalidating<X>(source:Observable<X>) {}
  public function revalidated<X>(source:Observable<X>, reused:Bool) {}
  #if tink_state.debug
  static public var inst(default, null) = new Logger();
  static var group:LoggerGroup;

  static public function printTo(output)
    return addLogger(new StringLogger(output));

  static public function addLogger(logger) {
    if (group == null)
      inst = group = new LoggerGroup([]);

    group.loggers.push(logger);
    return logger;
  }

  static public function removeLogger(logger)
    return group != null && group.loggers.remove(logger);
  #end
}

#if tink_state.debug
class StringLogger extends Logger {
  final output:String->Void;
  public function new(output) {
    super();
    this.output = output;
  }
  override function subscribed<X, Y>(source:Observable<X>, derived:Observable<Y>)
    output('${derived.toString()} subscribed to ${source.toString()}');

  override function unsubscribed<X, Y>(source:Observable<X>, derived:Observable<Y>)
    output('${derived.toString()} unsubscribed from ${source.toString()}');

  override function connected<X, Y>(source:Observable<X>, derived:Observable<Y>)
    output('${derived.toString()} connected to ${source.toString()}');

  override function disconnected<X, Y>(source:Observable<X>, derived:Observable<Y>)
    output('${derived.toString()} disconnected from ${source.toString()}');

  override function triggered<X>(source:Observable<X>, watcher:Invalidatable)
    output('${watcher.toString()} triggered by ${source.toString()}');
}

class LoggerGroup extends Logger {
  public var loggers:Array<Logger>;
  public function new(loggers) {
    super();
    this.loggers = loggers;
  }
  override public function subscribed<X, Y>(source:Observable<X>, derived:Observable<Y>)
    for (l in loggers)
      l.subscribed(source, derived);
  override public function unsubscribed<X, Y>(source:Observable<X>, derived:Observable<Y>)
    for (l in loggers)
      l.unsubscribed(source, derived);
  override public function connected<X, Y>(source:Observable<X>, derived:Observable<Y>)
    for (l in loggers)
      l.connected(source, derived);
  override public function disconnected<X, Y>(source:Observable<X>, derived:Observable<Y>)
    for (l in loggers)
      l.disconnected(source, derived);
  override public function triggered<X>(source:Observable<X>, watcher:Invalidatable)
    for (l in loggers)
      l.triggered(source, watcher);
  override public function revalidating<X>(source:Observable<X>)
    for (l in loggers)
      l.revalidating(source);
  override public function revalidated<X>(source:Observable<X>, reused:Bool)
    for (l in loggers)
      l.revalidated(source, reused);
}
#end