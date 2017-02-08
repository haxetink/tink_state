# Tinkerbell Reactive State Handling

At the core of `tink_state` stands the notion of an "observable". There are various definitions of what that is and [ReactiveX](http://reactivex.io/) practically monopolized the meaning within the realm of programming. The result - while being a fine display of technical prowess - exhibits a complexity that often scares away developers who could hugely benefit from reactive programming. Which is quite ironic, because reactiveness promisses simplicity.

This library is an attempt to deliver on that promise. To make things simple:

## Let's start at the very beginning

The Wikipedia offers a very simple definition of what an observable is:

> In physics, an observable is a dynamic variable that can be measured.

That's actually rather straight forward to define: 

```haxe
typedef Observable<T> = {
  function measure():T;
}
```

We wouldn't need a library to hold one trivial `typedef` of course. The main reason we have to complicate things just a little more is that we don't want to be measuring all the dynamic variables of our system all the time to figure out which ones have changed. So how about if a measurement doesn't just yield the current value, but also information about when the value becomes invalid? Let's do that:

```haxe
typedef Observable<T> = {
  function measure():Measurement<T>;
}
typedef Measurement<T> = {
  var value(default, null):T;
  var becameInvalid(default, null):Future<Noise>;
}
```

Now we're talking. If you're not familiar with `tink_core` here's a crash course in how to interpret `Future<Noise>` in this context:

> A future represents a single future event. You can register a callback that is invoked once that event occurs. If the event was in fact in the past at the time of callback registration, the callback is invoked immediately. Unlike a promise (if you are familiar with those), a future never yields an error. A future of "noise" is one where the actual event doesn't carry any particular data - just noise. In this case the future will call us back once the measurement became invalid.

What's interesting about observables is that they are first class values, so we can start defining computations on them:

```haxe
function map<In, Out>(o:Observable<In>, transform:In->Out):Observable<Out>
  return {
    measure: function () {
      var m = o.measure();
          
      return {
        value: transform(m.value),
        becameInvalid: m.becameInvalid,
      }
    }
  }
```

This way we can transform an observable of one shape into an observable of another. This makes it easier to have dependent states. Ordinarily, you would have state in one place and once that changes, some event gets dispatched, you have to intercept it and make an update on the dependent state. All kinds of things can go wrong and you wind up with invalid state because the original state and the dependent one go out of sync and what not. This is not so with observables.

While mapping allows you to transform one observable into another, sometimes you might want to combine multiple observables into a single one, which works like so:

```haxe
function combine<A, B, C>(a:Observable<A>, b:Observable<B>, combinator:A->B->C):Observable<C>
  return {
    measure: function () {
      var ma = a.measure(),
          mb = b.measure();
         
      return {
        value: combinator(ma.value, mb.value),
        becameInvalid: ma.becameInvalid || mb.becameInvalid 
        // the || operator on two futures creates a new future that triggers as soon as one of its operands trigger
      }
    }
  }
```

Et voilà, we can combine two things that change over time to one. Let's see how we might use that:

```haxe
typedef Player = {
  inventory:Observable<Iterable<Item>>,
  health:Observable<{ cur:Int, max: Int }>,
}

import haxe.ds.Option;

var player:Player = ...;
var nextHealthPotion = combine(
  player.inventory, 
  player.health, 
  function (inventory, health) {
    if (health.cur >= health.max) return None;
    for (item in inventory)
      switch Std.instance(item, HealthPotion) {
        case null:
        case v: return Some(v);
      }
    return None;
  }
);
```

So we have created `nextHealthPotion` which is an `Observable<Option<HealthPotion>>` that results in `None` when the player is at full health or has no health potion and otherwise results in the first health potion found in the inventory. A more sophisticated implementation might look for the smallest potion that fully heals the player or what not. That does not really matter. In fact the function itself may be chosen based on a choice the user makes in the game settings. Notice also, that both `map` and `combine` do create observables, but the actual value is not computed unless `measure` is called on the resulting observable.

This way we do not have to manage dependent states ourself. Instead, we use different operations to create it from the other states it depends on and we use pure functions to do it, which are easily testable in isolation. The resulting setup is far less error prone.

## The Full Picture

The above introduction leaves out a few details:

1. How to modify any state (we have only discussed how to measure it and how to operate on it)
2. How to efficiently apply state changes

### State

If there is "a piece of state" that you own, this is how you would represent it:

```haxe
abstract State<T> to Observable<T> {
  var value(get, never):T;
  function new(value:T):Void;
  function set(value:T):Void;
  function observe():Observable<T>; 
  
  @:impl static function toggle(s:StateObject<Bool>):Bool;
  
  @:to function toCallback():Callback<T>;
  @:from static private function ofConstant<T>(value:T):State<T>;
}
```


Basiscally a `State` can act as an `Observable` but it also exposes a `set` function whereby you can update it. When exposing a state to the outside world it's best to expose it as an `Observable` so that you alone can update it.

Don't let the `toggle` function freak you out. It is a so called ["selective function"](https://haxe.org/manual/types-abstract-selective-functions.html) that exists only on boolean states and allows you to write things like `flag.toggle()`.

### Observable

The actual observables that you will find in `tink_state` are conceptually the same as the simple counterpart conceived in the introduction, but they provide a few things on top:

1. **Operations:** Certainly not as many as you would find in ReactiveX. Arguably just the right amount - in particular they deal with asynchronous transformations.
2. **Caching:** Because all operations assume pure functions, the result can be cached and this is just what happens to avoid recalculating the same result every time somebody pulls an observable's value.
3. **(Batched) Binding:** Rather than measuring the observables yourself and dealing with when the measurement `becameInvalid`, observables expose a `bind` method that is *batched* by default, i.e. it collects all changes and performs bulk updates.
4. **Automagic Composition:** There is a function to very naturally compose observables that doesn't require using operations explicitly, resulting in more concise and readable code, at a slight performance cost.

Let's look at how `tink_state` actually defines observables. For starters, we have measurements:

```haxe
abstract Measurement<T> from Pair<T, Future<Noise>> {
  var value(get, never):T;
  var becameInvalid(get, never):Future<Noise>;
  function new(value, becameInvalid);
}
```

They are practically the same as in the introduction, except that they are abstracts. 

With that, let's take a look at observables:

```haxe
abstract Observable<T> {
  
  @:to var value(get, never):T;
  function measure():Measurement<T>;  
  
  function bind(?options:{ ?direct: Bool }, cb:Callback<T>):CallbackLink;
  static function updateAll():Void;  
  
  static function create<T>(f:Void->Measurement<T>):Observable<T>;
  static function auto<T>(f:Computation<T>):Observable<T>;
  @:from static function const<T>(value:T):Observable<T>;     
  
  function map<R>(f:Transform<T, R>):Observable<R>;
  function mapAsync<R>(f:Transform<T, Promise<R>>):Observable<Promised<R>>;
  
  function combine<A, R>(that:Observable<A>, f:T->A->R):Observable<R>;
  function combineAsync<A, R>(that:Observable<A>, f:T->A->Promise<R>):Observable<Promised<R>>;

}
```

Let's take it from the top. First of all, there is a convenience getter to get an observable's value directly, which really just uses the `measure` method we've already familiarized ourselves with in the introduction.

#### Binding

Using an observable's `bind` method we can create a "binding" to a callback. If you're not familiar with `tink_core`: the binding can be undone by calling the `dissolve` method of the returned `CallbackLink`. If we create the binding with `{ direct: true }`, then every time the observable changes, the callback is called immediately. The default behavior though is to invalidate the binding and schedule an update at a later time (chosen depending on the current platform). Using `Observable.updateAll()` you can forcibly update all currently invalid bindings.

#### Asynchrony

Before we go over the next function, notice that some of them accept a function that produce a `Promise<R>` return an `Observable<Promised<R>>`. Here is what a `Promised` value looks like:

```haxe
enum Promised<T> {
  Loading;
  Done(result:T);
  Failed(error:Error);
}
```

We want this because it `Observable<Promised<R>>` is a more handy representation of `Observable<Promised<T>>` - which nests two asynchronous data structures. Here is what we'd have to do to get data from it:

```haxe
o.bind(function (promise:Promise<X>) {
  //now we are loading
  promise.handle(function (o) {
    //now it is loaded
    switch o {
      case Success(d)://and succeeded
      case Failure(e)://and failed
    }
  }
});
```

Instead, we can do this:

```haxe
o.bind(function (promised:Promised<X>) switch promised {
  case Loading://now we are loading
  case Done(d)://now it is loaded and succeeded
  case Failure(e)://now it is loaded and failed
});
```

Not only is it more concise, it also deals with another problem. In the first case, we can get called back with a new `promise` even though the previous one did not even trigger yet. And in fact - even though unlikely - the second promise can potentially be faster than the first, which means that we'll get the result of the first after the second and so we have to keep track of order and what not. In the latter case all problems are taken care of.

##### Computation

Computations are used by `Observable.auto` and a computation really just means something that can produce a value. It is defined like so:

```haxe
abstract Computation<T> {
  function perform():T;

  @:from static private function async<T>(f:Void->Promise<T>):Computation<Promised<T>>;
  @:from static private function plain<T>(f:Void->T):Computation<T>;
}
```

So we see that a plain function `Void->T` can act as a `Computation<T>`. However `Void->Promise<T>` will act as `Computation<Promised<T>>`, meaning that a function that returns a promise acts as a computation that produces a promised value.

This means if we call Observable.auto with a function that produces a `Promise<T>`, we will get an `Observable<Promised<T>>` rather than the undesirable `Observable<Promise<T>>`.

##### Transform

.... to be documented. But the general idea is much like that of computations.

#### Creation

Aside from constructing a `State`, there are three other methods of creating observables:

1. From a function that creates measurements with `Observable.create`. Under the hood this is wrapped into an object that provides some caching and other niceties.
2. From a constant with `Observable.const` Any constant can act as an observable. It will obviously return the same measurement again and again.
3. In an automagic way, simply through calling `Observable.auto` with a `Computation<T>` that determines the new value.

##### Automagic Observables

Automagic observables work by executing the function to calculate the new value while tracking which other observables are accessed in the process. If any of those becomes in valid, the resulting observable becomes invalid too.

Here's how we might write the `nextHealthPotion` function above:

```
function isFull(health)
  return health.cur >= health.max;    

var nextHealthPotion = Observable.auto(function () {
  if (isFull(player.health.value)) return None;
  for (item in player.inventory.value)
    switch Std.instance(item, HealthPotion) {
      case null:
      case v: return Some(v);
    }
  return None;
}); 
```

That might not seem like a big advantage, but suppose the result should depend on some other observables:

```haxe
var nextHealthPotion = Observable.auto(function () {
  if (isFull(player.health.value)) return None;
  if (player.isStunned.value) return None;
  for (item in player.inventory.value)
    switch Std.instance(item, HealthPotion) {
      case null:
      case v: return Some(v);
    }
  return None;
}); 
```

We could get the same result by calling `combine` which is quite a bit more work than adding a line of code to your calculation.

#### Operations

There are times when you might wish to be explicit rather than to rely on `Observable.auto`.
