package tink.state;

using tink.CoreApi;

@:using(tink.state.Promised.PromisedTools)
enum Promised<T> {
  Loading;
  Done(result:T);
  Failed(error:Error);
}

class PromisedTools {
  static public function next<A, B>(a:Promised<A>, f:Next<A, B>):Promise<B>
    return switch a {
      case Loading: Promise.NEVER #if (tink_core < "2" && haxe_ver >= "4.2") .next(_ -> (null:B)) #end;
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

  static public function toOption<V>(p:Promised<V>):Option<V>
    return switch p {
      case Done(data): Some(data);
      case _: None;
  }

  static public function or<V>(p:Promised<V>, l:Lazy<V>):V
    return switch p {
      case Done(v): v;
      default: l.get();
    }

  static public function orNull<V>(p:Promised<V>):Null<V>
    return switch p {
      case Done(v): v;
      default: null;
    }

  static public function all<V>(p:Iterable<Promised<V>>):Promised<Array<V>> {
    var ret = [];
    for(p in p)
      switch p {
        case Done(v): ret.push(v);
        case Loading: return Loading;
        case Failed(e): return Failed(e);
      }
    return Done(ret);
  }
}