package tink.state.debug;

class Logger {
  public function new() {}
  public function subscribed<X, Y>(source:Observable<X>, derived:Observable<Y>) {}
  public function unsubscribed<X, Y>(source:Observable<X>, derived:Observable<Y>) {}
  public function connected<X, Y>(source:Observable<X>, derived:Observable<Y>) {}
  public function disconnected<X, Y>(source:Observable<X>, derived:Observable<Y>) {}
  public function triggered<X>(source:Observable<X>, watcher:Invalidatable) {}
  public function revalidating<X>(source:Observable<X>) {}
  public function revalidated<X>(source:Observable<X>, reused:Bool) {}
  #if tink_state.debug
  static public var inst = new Logger();
  static public function printTo(output)
    inst = new StringLogger(output);
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
#end