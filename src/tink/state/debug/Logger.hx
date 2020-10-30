package tink.state.debug;

#if tink_state.debug
class Logger {
  function new() {}
  public function subscribed<X, Y>(source:Observable<X>, derived:Observable<Y>) {}
  public function unsubscribed<X, Y>(source:Observable<X>, derived:Observable<Y>) {}
  public function connected<X, Y>(source:Observable<X>, derived:Observable<Y>) {}
  public function disconnected<X, Y>(source:Observable<X>, derived:Observable<Y>) {}
  public function triggered<X>(source:Observable<X>, watcher:Invalidatable) {}
  public function revalidating<X>(source:Observable<X>) {}
  public function revalidated<X>(source:Observable<X>, reused:Bool) {}
  public function filter(match)
    return new Filter(this, match);

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
}

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
  
  override function revalidating<X>(source:Observable<X>) 
    output('${source.toString()} revalidating');
  
  override function revalidated<X>(source:Observable<X>, reused:Bool) 
    output('${source.toString()} revalidated (reused=$reused)');
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

class Filter extends Logger {
  public var logger:Logger;
  public var match:Observable<Dynamic>->Bool;
  public function new(logger, match) {
    super();
    this.logger = logger;
    this.match = match;
  }
  override public function subscribed<X, Y>(source:Observable<X>, derived:Observable<Y>)
    if (match(source)) logger.subscribed(source, derived);
  override public function unsubscribed<X, Y>(source:Observable<X>, derived:Observable<Y>)
    if (match(source)) logger.unsubscribed(source, derived);
  override public function connected<X, Y>(source:Observable<X>, derived:Observable<Y>)
    if (match(source)) logger.connected(source, derived);
  override public function disconnected<X, Y>(source:Observable<X>, derived:Observable<Y>)
    if (match(source)) logger.disconnected(source, derived);
  override public function triggered<X>(source:Observable<X>, watcher:Invalidatable)
    if (match(source)) logger.triggered(source, watcher);
  override public function revalidating<X>(source:Observable<X>)
    if (match(source)) logger.revalidating(source);
  override public function revalidated<X>(source:Observable<X>, reused:Bool)
    if (match(source)) logger.revalidated(source, reused);
}
#end