package tink.state;

using tink.CoreApi;

enum Promised<T> {
  Loading;
  Done(result:T);
  Failed(error:Error);
}

class PromisedTools {
  static public function next<A, B>(a:Promised<A>, f:Next<A, B>):Promise<B>
    return switch a {
      case Loading: Promise.NEVER;
      case Failed(e): e;
      case Done(a): f(a);
    }
    
  static public function map<A, B>(a:Promised<A>, f:A->B):Promised<B>
    return switch a {
      case Loading: Loading;
      case Failed(e): Failed(e);
      case Done(a): Done(f(a));
    }
    
  static public function flatMap<A, B>(a:Promised<A>, f:A->Promised<B>):Promised<B>
    return switch a {
      case Loading: Loading;
      case Failed(e): Failed(e);
      case Done(a): f(a);
    }
}