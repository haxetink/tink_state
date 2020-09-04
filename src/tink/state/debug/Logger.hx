package tink.state.debug;

class Logger {
  public function new() {}
  public function subscribed<X, Y>(source:Observable<X>, derived:Observable<Y>) {}
  public function unsubscribed<X, Y>(source:Observable<X>, derived:Observable<Y>) {}
  public function connected<X, Y>(source:Observable<X>, derived:Observable<Y>) {}
  public function disconnected<X, Y>(source:Observable<X>, derived:Observable<Y>) {}
  public function triggered<X>(source:Observable<X>, watcher:Invalidatable) {}
  static public var inst = new Logger();
}