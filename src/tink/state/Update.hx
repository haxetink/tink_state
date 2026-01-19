package tink.state;

@:observable
class Update {
  public final name:String;
  public final date = Date.now();

  final writes = new Array<Write<Dynamic>>();

  public function new(name) {
    this.name = name;
  }

  public function set<T>(state:State<T>, from:T, to:T) 
    writes.push(new Write(state, from, to));

  public function undo() {
    var l = writes.length;
    while (l --> 0) 
      writes[l].state.set(writes[l].from);
  }

  public function redo() 
    for (w in writes) w.state.set(w.to);
  
  static public function tracked(name:String, fn:()->Void) {
    final old = cur,
          nu = cur = new Update(name);
    fn();
    cur = old;
    return nu;
  }

  static var cur:Null<Update> = null;
}

private class Write<T> {
  public final state:State<T>;
  public final from:T;
  public final to:T;

  public function new(state, from, to) {
    this.state = state;
    this.from = from;
    this.to = to;
  }
}