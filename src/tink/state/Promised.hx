package tink.state;

using tink.CoreApi;

enum Promised<T> {
  Loading;
  Done(result:T);
  Failed(error:Error);
}

class PromisedTools {
  public static function next<A, B>(a:Promised<A>, f:Next<A, B>):Promise<B>
    return switch a {
      case Loading: Promise.NEVER;
      case Failed(e): e;
      case Done(a): f(a);
    }
}