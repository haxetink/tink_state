package tink.state;

import tink.state.Promised;

using tink.CoreApi;

abstract Observable<T>(ObservableObject<T>) from ObservableObject<T> to ObservableObject<T> {
  
  static var stack = new List<ObservableObject<Dynamic>>();
  
  public var value(get, never):T;
  
    @:to function get_value() 
      return measure().value;
        
  public inline function new(get:Void->T, changed:Signal<Noise>)
    this = create(function () return new Measurement(get(), changed.nextTime()));
    
  public function combine<A, R>(that:Observable<A>, f:T->A->R):Observable<R>
    return new SimpleObservable<R>(function () {
      var p = measure(),
          q = that.measure();
          
      return new Measurement(f(p.value, q.value), p.becameInvalid.first(q.becameInvalid));
    });

  public function nextTime(?options:{ ?butNotNow: Bool, ?hires:Bool }, check:T->Bool):Future<T> 
    return getNext(options, function (v) return if (check(v)) Some(v) else None);

  public function getNext<R>(?options:{ ?butNotNow: Bool, ?hires:Bool }, select:T->Option<R>):Future<R> {
    var ret = Future.trigger(),
        waiting = options != null && options.butNotNow;

    var link = bind({ direct: options != null && options.hires }, function (value) {
      var out = select(value);
      if (waiting) 
        waiting = out != None;
      else switch out {
        case Some(value): ret.trigger(value);
        case None:
      }
    });

    ret.handle(link.dissolve);

    return ret;
  }  
    
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
    return create(function () {
      var m = measure();
      return new Measurement(f.apply(m.value), m.becameInvalid);
    });
  
  public function combineAsync<A, R>(that:Observable<A>, f:T->A->Promise<R>):Observable<Promised<R>>
     return combine(that, f).mapAsync(function (x) return x);  

  public function mapAsync<R>(f:Transform<T, Promise<R>>):Observable<Promised<R>> 
    return map(f).map(ofPromise).flatten();
  
  public function measure():Measurement<T> {
    var before = stack.first();
        
    stack.push(this);
    var p = this.poll();
    
    switch Std.instance(before, AutoObservable) {
      case null: 
      case v:
        v.subscribe(p.becameInvalid);
        // p.becameInvalid.handle(v.invalidate);
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
      
      return new Measurement(p2.value, p.becameInvalid.first(p2.becameInvalid));
    });
    
  public function bind(?options:BindingOptions<T>, cb:Callback<T>):CallbackLink {
    var cb:Callback<T> = 
      switch options {
        case null | { comparator: null }: cb;
        case { comparator: equal }:
          var isFirst = true,
              last = null;
          function (data) {
            if (isFirst) {
              isFirst = false;
              cb.invoke(data);
            }
            else if (!equal(last, data)) 
              cb.invoke(data);
            last = data;
          }
        }    

    return 
      switch options {
        case null | { direct: null | false }:
          var scheduled = false,
              active = true,
              updated:Callback<Noise> = null,
              link:CallbackLink = null;
          
          function update() 
            if (active) {
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
  }

  static var scheduled:Array<Void->Void> = 
    #if (js || tink_runloop || (haxe_ver >= 3.3)) 
      [];
    #else
      null;
    #end

  #if js
    static var hasRAF:Bool = untyped __js__("typeof window != 'undefined' && 'requestAnimationFrame' in window");
  #end

  static function schedule(f:Void->Void) 
    switch scheduled {
      case null:
        f();
      case v:
        v.push(f);
        scheduleUpdate();
    }
  static var isScheduled = false;
  static function scheduleUpdate() if (!isScheduled) {
    isScheduled = true;
    #if tink_runloop
      tink.RunLoop.current.atNextStep(scheduledRun);
    #elseif js
      if (hasRAF)
        js.Browser.window.requestAnimationFrame(function (_) scheduledRun());
      else
        Callback.defer(scheduledRun);
    #elseif (haxe_ver >= 3.3)
      Callback.defer(scheduledRun);
    #else
      throw 'this should be unreachable';
    #end  
  }
  static function scheduledRun() {
    isScheduled = false;
    updatePending();
  }

  static public function updatePending(maxSeconds:Float = .01) {
    inline function measure() return
      #if java
        Sys.cpuTime();
      #else
        haxe.Timer.stamp();
      #end

    var end = measure() + maxSeconds;
    do {
      var old = scheduled;
      scheduled = [];
      for (o in old) o();
      
    } 
    while (scheduled.length > 0 && measure() < end);
    return 
      if (scheduled.length > 0) {
        scheduleUpdate();
        true;
      }
      else false;
  }
  
  static public function updateAll() 
    updatePending(Math.POSITIVE_INFINITY);
  
  static inline function lift<T>(o:Observable<T>) return o;

  @:impl static public function deliver<T>(o:ObservableObject<Promised<T>>, initial:T):Observable<T>
    return lift(o).map(function (p) return switch p {
      case Done(v): initial = v;
      default: initial;
    });

  @:impl static public function flatten<T>(o:ObservableObject<Observable<T>>) 
    return create(function () {
      var m = lift(o).measure();
      var m2 = m.value.measure();
      return new Measurement(m2.value, m.becameInvalid || m2.becameInvalid);
    });
  static var counter = 0;
  static public function ofPromise<T>(p:Promise<T>):Observable<Promised<T>> {
    if (p == null) 
      throw 'Expected Promise but got null';

    var value = Loading,
        becameInvalid = Lazy.ofFunc(p.map.bind(function (_) return Noise));
    
    return create(function () {
      if (p != null) {
        p.handle(function (o) {
          value = switch o {
            case Success(v): Done(v);
            case Failure(e): Failed(e);
          }
          becameInvalid = ConstObservable.NEVER;
        });
      }
      return new Measurement(value, becameInvalid);
    });
  }

  static public function create<T>(f):Observable<T> 
    return new SimpleObservable(f);
  
  static public function auto<T>(f:Computation<T>):Observable<T>
    return new AutoObservable(f);
  
  @:noUsing static public function const<T>(value:T):Observable<T> 
    return new ConstObservable(value);      

  static public function untracked<T>(f:Void->T) {//TODO: consider inlining
    stack.push(null);
    return Error.tryFinally(f, stack.pop);
  }

  @:op(a == b) 
  static function eq<T>(a:Observable<T>, b:Observable<T>):Bool 
    return switch [a, b] {
      case [null, null]: true;
      case [null, _] | [_, null]: false;
      default: a.value == b.value;
    }

  @:op(a != b) 
  static inline function neq<T>(a:Observable<T>, b:Observable<T>):Bool 
    return !eq(a, b);

}

typedef BindingOptions<T> = { 
  ?direct:Bool, 
  ?comparator:T->T->Bool 
}

abstract Computation<T>({ f: Void->T }) {
  inline function new(f) 
    this = { f: f };

  public inline function perform() 
    return this.f();

  @:from static function async<T>(f:Void->Promise<T>):Computation<Promised<T>> {//Something tells me this is rather inefficient ...
    var o = Observable.auto(new Computation(f)).map(Observable.ofPromise);
    return function () return o.value.value;
  }

  @:from static inline function plain<T>(f:Void->T):Computation<T>
    return new Computation(f);
}

private class SimpleObservable<T> implements ObservableObject<T> {
  
  var _poll:Void->Measurement<T>;
  var cache:Measurement<T>;
  
  function resetCache(_) cache = null;
  
  public function poll() {
    var count = 0,
        last = null;
    while (cache == null) {
      var cache = cache = _poll();
      if (last == cache) 
        throw 'Polling loops on the same value';
      
      last = cache;
      cache.becameInvalid.handle(resetCache);

      if (count++ >= 100)
        throw 'Polling not concluded after 100 iterations';      
    }
    return cache;
  }
  
  public function new(f) 
    this._poll = f;  
}

abstract Transform<T, R>(T->R) {
  inline function new(f) 
    this = f;

  public inline function apply(value:T):R 
    return this(value);

  @:from static function naiveAsync<T, R>(f:T->Promise<R>):Transform<Promised<T>, Promise<R>> 
    return new Transform(function (p:Promised<T>):Promise<R> return switch p {
      case Failed(e): e;
      case Loading: new Future(function (_) return null);
      case Done(v): f(v);
    });

  @:from static function naive<T, R>(f:T->R):Transform<Promised<T>, Promised<R>> 
    return new Transform(function (p) return switch p {
      case Failed(e): Failed(e);
      case Loading: Loading;
      case Done(v): Done(f(v));
    });
  
  @:from static function plain<T, R>(f:T->R):Transform<T, R>
    return new Transform(f);
}

interface ObservableObject<T> {
  function poll():Measurement<T>;
}

class ConstObservable<T> implements ObservableObject<T> {
  
  static public var NEVER = new Future<Noise>(function (_) return null);
  
  public var m(default, null):Measurement<T>;
  
  public function poll()
    return this.m;
  
  public function new(value)
    this.m = new Measurement(value, NEVER);
}

private class AutoObservable<T> extends SimpleObservable<T> {
  
  var trigger:FutureTrigger<Noise>;
  var subscriptions = new Map<Future<Noise>, CallbackLink>();
  
  public function new(comp:Computation<T>)
    super(function () {
      //for (l in subscriptions) l.dissolve();//TODO: consider adding this although it might be overkill
      this.subscriptions = new Map();
      this.trigger = Future.trigger();
      return new Measurement(comp.perform(), this.trigger.asFuture());
    });

  public function subscribe(change:Future<Noise>) {
    if (!subscriptions.exists(change)) 
      subscriptions[change] = change.handle(trigger.trigger);
  }
  // public function invalidate() 
  //   trigger.trigger(Noise);  
}
