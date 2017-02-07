package tink.state;

import tink.state.Promised;

using tink.CoreApi;

abstract Measurement<T>(Pair<T, Future<Noise>>) from Pair<T, Future<Noise>> {
  
  public var value(get, never):T;
    inline function get_value() return this.a;

  public var becameInvalid(get, never):Future<Noise>;
    inline function get_becameInvalid() return this.b;

  public inline function new(value, becameInvalid)
    this = new Pair(value, becameInvalid);
}

abstract Observable<T>(ObservableObject<T>) from ObservableObject<T> to ObservableObject<T> {
  
  static var stack = new List();
  
  public var value(get, never):T;
  
    @:to function get_value() 
      return measure().value;
        
  public inline function new(get, changed)
    this = new SignalObservable<T>(get, changed);
    
  public function combine<A, R>(that:Observable<A>, f:T->A->R):Observable<R>
    return new SimpleObservable<R>(function () {
      var p = measure(),
          q = that.measure();
          
      return new Pair(f(p.value, q.value), p.becameInvalid.first(q.becameInvalid));
    });
    
  public function join(that:Observable<T>) {
    var lastA = null;
    return combine(that, function (a, b) {
      var ret = 
        if (lastA == a) b;
        else a;
        
      lastA = a;
      return ret;
    });
  }
  
  public function map<R>(f:Transform<T, R>):Observable<R>
    return new TransformObservable<T, R>(f, this);
  
  public function combineAsync<A, R>(that:Observable<A>, f:T->A->Promise<R>):Observable<Promised<R>>
     return combine(that, f).mapAsync(function (x) return x);
  

  public function mapAsync<R>(f:T->Promise<R>):Observable<Promised<R>> {
    var ret = new State(Loading),
        link:CallbackLink = null;

    bind(function (data) {
      link.dissolve();
      ret.set(Loading);
      link = f(data).handle(function (r) ret.set(switch r {
        case Success(v): Done(v);
        case Failure(v): Failed(v);
      }));
    });
    
    return ret;
  } 
  
  public function measure():Measurement<T> {
    var before = stack.first();
        
    stack.push(this);
    var p = this.poll();
    trace([this, before]);
    switch Std.instance(before, AutoObservable) {
      case null: 
      case v:
        p.b.handle(v.invalidate);
    }
    stack.pop();
    return p;
  }
  
  public function switchSync<R>(cases:Array<{ when: T->Bool, then: Lazy<Observable<R>> } > , dfault:Lazy<Observable<R>>):Observable<R> 
    return new SimpleObservable(function () {
      
      var p = measure();
      
      for (c in cases)
        if (c.when(p.value)) {
          dfault = c.then;
          break;
        }
        
      var p2 = dfault.get().measure();
      
      return new Pair(p2.value, p.becameInvalid.first(p2.becameInvalid));
    });
    
  public function bind(?options:{ ?direct: Bool }, cb:Callback<T>):CallbackLink
    return 
      switch options {
        case null | { direct: null | false }:
          var scheduled = false,
              active = true,
              updated:Callback<Noise> = null,
              link:CallbackLink = null;
          
          function update() 
            if (active) {
              trace('update $this');
              var next = measure();
              cb.invoke(next.value);
              scheduled = false;
              link = next.becameInvalid.handle(updated);
            }
            
          function doSchedule() {
            if (scheduled) return;
            
            scheduled = true;
            schedule(update);
          }    
          
          updated = doSchedule;
          
          doSchedule();
              
          return function () 
            if (active) {
              active = false;
              link.dissolve();
            }          
          
        default: 
          var link:CallbackLink = null;
          
          function update(_:Noise) {
            var next = measure();
            cb.invoke(next.value);
            link = next.becameInvalid.handle(update);
          }
          
          update(Noise);
          
          function () link.dissolve();          

      }
      
  static var scheduled:Array<Void->Void> = 
    #if (js || tink_runloop) 
      [];
    #else
      null;
    #end
  
  static function schedule(f:Void->Void) 
    switch scheduled {
      case null:
        f();
      case []:
        scheduled.push(f);
        #if tink_runloop
          tink.RunLoop.current.atNextStep(updateAll);
        #elseif js
          js.Browser.window.requestAnimationFrame(function (_) updateAll());
        #else
          throw 'this should be unreachable';
        #end
      case v:
        v.push(f);
    }
  
  static public function updateAll() {
    var old = scheduled;
    scheduled = null;
    
    for (o in old) o();
    
    scheduled = [];
  }  
  static public function create<T>(f):Observable<T> 
    return new SimpleObservable(f);
  
  static public function auto<T>(f:Void->T, ?pos:haxe.PosInfos):Observable<T>
    return new AutoObservable(f, pos);
  
  @:noUsing @:from static public function const<T>(value:T):Observable<T> 
    return new ConstObservable(value);
      
}

private class TransformObservable<T, R> implements ObservableObject<R> {
  
  var transform:Transform<T, R>;
  var source:ObservableObject<T>;
  
  public function new(transform, source) {
    this.transform = transform;
    this.source = source;
  }
  
  public function poll():Pair<R, Future<Noise>> {
    var p = source.poll();
    return new Pair(transform(p.a), p.b);
  }
  
}

private class SimpleObservable<T> implements ObservableObject<T> {
  
  var _poll:Void->Pair<T, Future<Noise>>;
  var cache:Pair<T, Future<Noise>>;
  
  function resetCache(_) cache = null;
  
  public function poll() {
    if (cache == null) {
      cache = _poll();
      cache.b.handle(resetCache);
    }
    return cache;
  }
  
  public function new(f) 
    this._poll = f;
  
}

@:callable
abstract Transform<T, R>(T->R) {
  
  @:from static function ofNaive<T, R>(f:T->R):Transform<Promised<T>, Promised<R>> 
    return function (p) return switch p {
      case Failed(e): Failed(e);
      case Loading: Loading;
      case Done(v): Done(f(v));
    }
  
  @:from static function ofExact<T, R>(f:T->R):Transform<T, R>
    return cast f;
}

interface ObservableObject<T> {
  function poll():Pair<T, Future<Noise>>;
}

private class ConstObservable<T> implements ObservableObject<T> {
  
  static var NEVER = new Future<Noise>(function (_) return null);
  
  var p:Pair<T, Future<Noise>>;
  
  public function poll():Pair<T, Future<Noise>>
    return this.p;
  
  public function new(value)
    this.p = new Pair(value, NEVER);
}

private class AutoObservable<T> extends SimpleObservable<T> {
  
  var trigger:FutureTrigger<Noise>;
  var pos:haxe.PosInfos;
  
  public function new(getValue:Void->T, ?pos:haxe.PosInfos) {
    this.pos = pos;
    super(function () {
      haxe.Log.trace("recalculate", pos);
      this.trigger = Future.trigger();
      return new Pair(getValue(), this.trigger.asFuture());
    });
  }
  
  @:keep public function toString() {
    return 'Auto@${pos.fileName}:${pos.lineNumber}';
  }

  public function invalidate() {
    haxe.Log.trace("invalidate", pos);
    trigger.trigger(Noise);
  }
  
}

private class SignalObservable<T> implements ObservableObject<T> {
  
  var getValue:Void->T;
  var changed:Signal<Noise>;
  
  var cache:Pair<T, Future<Noise>>;
  
  function resetCache(_) cache = null;
  
  public function poll() {
    if (cache == null) {
      cache = new Pair(getValue(), changed.next());
      cache.b.handle(resetCache);
    }
    return cache;
  }
  
  public function new(getValue, changed:Signal<Noise>) {
    this.getValue = getValue;
    this.changed = changed;
  }
    
}
