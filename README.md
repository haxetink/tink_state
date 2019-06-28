# Tinkerbell Reactive State Handling

[![Build Status](https://travis-ci.org/haxetink/tink_state.svg?branch=master)](https://travis-ci.org/haxetink/tink_state)
[![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/haxetink/public)

At the core of `tink_state` stands the notion of an "observable". There are various definitions of what that is and [ReactiveX](http://reactivex.io/) practically monopolized the meaning within the realm of programming. The result - while being a fine display of technical prowess - exhibits a complexity that often scares away developers who could hugely benefit from reactive programming. Which is quite ironic, because reactiveness promisses simplicity.

This library is an attempt to deliver on that promise. If you are familiar with ReactiveX, empty your cup: in `tink_state` an **observable is not a stream** (if you want streams, check out [`tink_streams`](https://github.com/haxetink/tink_streams/tree/pure)). Rather than providing a swiss army knife of functional programming, observables are conceived based on the fundamental meaning of the word:

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

function isFull(health)
  return health.cur >= health.max;
  
var player:Player = ...;
var nextHealthPotion = combine(
  player.inventory, 
  player.health, 
  function (inventory, health) {
    if (isFull(health)) return None;
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
2. How to efficiently react to state changes

### State

If there is "a piece of state" that you own, you can construct a `State` defined like so:

```haxe
abstract State<T> to Observable<T> {
  var value(get, never):T;
  function new(value:T):Void;
  function set(value:T):Void;
  function observe():Observable<T>; 
  
  @:to function toCallback():Callback<T>;
  @:from static private function ofConstant<T>(value:T):State<T>;
}
```

As we see, a `State` can act as an `Observable` but it also exposes a `set` function whereby you can update it. When exposing a state to the outside world it's best to expose it as an `Observable` so that you alone can update it.

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

They are practically the same as in the introduction, except that they are abstracts. With that settled, here comes the center piece:

```haxe
abstract Observable<T> {
  
  @:to var value(get, never):T;
  function measure():Measurement<T>;  
  
  function bind(?options:{ ?direct: Bool }, cb:Callback<T>):CallbackLink;
  static function updateAll():Void;  
  
  @:impl static function deliver<T>(o:Observable<Promised<T>>, initial:T):Observable<T>;
  
  static function create<T>(f:Void->Measurement<T>):Observable<T>;
  static function auto<T>(f:Computation<T>):Observable<T>;
  @:from static function const<T>(value:T):Observable<T>;     
  
  function map<R>(f:Transform<T, R>):Observable<R>;
  function mapAsync<R>(f:Transform<T, Promise<R>>):Observable<Promised<R>>;
  
  function combine<A, R>(that:Observable<A>, f:T->A->R):Observable<R>;
  function combineAsync<A, R>(that:Observable<A>, f:T->A->Promise<R>):Observable<Promised<R>>;

  function nextTime(?options:{ ?butNotNow: Bool, ?hires:Bool }, check:T->Bool):Future<T>;
}
```

Let's take it from the top. First of all, there is a convenience getter to get an observable's value directly, which really just uses the `measure` method we've already familiarized ourselves with in the introduction.

After that, things become a little more complicated, so we'll look into them step by step.

#### Binding

Using an observable's `bind` method we can create a "binding" to a callback, which gets invoked with the current value and then with the new value, when the observable changes. If you're not familiar with `tink_core`: a `CallbackLink` represents the link between a callback and the place it was registered and can be undone using its `dissolve` method. 

If we create the binding with `{ direct: true }`, then every time the observable changes, the callback is called immediately. This can be pretty inefficient though. Assume the callback is bound to an observable that combines two states and you update both of them, then the callback fires twice - once after both states were updated, but once in between. Performance considerations aside, it may also be that the callback inbetween receives non-sensical data. 

Therefore, the default behavior is to invalidate the binding and schedule an update at a later time (chosen depending on the current platform, e.g. `requestAnimationFrame` in JavaScript). Using `Observable.updateAll()` you can forcibly update all currently invalid bindings.

#### Asynchrony

Before we continue to the next methods, notice that some of them accept a plain function or `Transform` or `Computation` that produce a `Promise<R>` and finally return an `Observable<Promised<R>>`. Here is what a `Promised` value looks like:

```haxe
enum Promised<T> {
  Loading;
  Done(result:T);
  Failed(error:Error);
}
```

We want this because it `Observable<Promised<R>>` is a more handy representation of `Observable<Promised<T>>`. The latter nests two asynchronous data structures and that results in all kinds of issues. For starters, here is what we'd have to do to get data from the it:

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
  case Failed(e)://now it is loaded and failed
});
```

Not only is it more concise, it also deals with another problem: in the first case, we can get called back with a new `promise` even though the previous one did not even trigger yet. And in fact - even though unlikely - the second promise can potentially be faster than the first, which means that we'll get the result of the first after the second and so we have to keep track of order and what not. Luckily, all this is taken care of.

Using so called ["selective function"](https://haxe.org/manual/types-abstract-selective-functions.html) we can also tell an `Observable<Promised<T>>` to `deliver` on its promise by providing an `initial` value and thus giving us an `Observable<T>` that starts out with the initial value and only updates when data is successfully loaded.

##### Computation

A computation really just means something that can produce a value and `Observable.auto` consumes computations to create observables. It is defined like so:

```haxe
abstract Computation<T> {
  function perform():T;

  @:from static private function async<T>(f:Void->Promise<T>):Computation<Promised<T>>;
  @:from static private function plain<T>(f:Void->T):Computation<T>;
}
```

So we see that a plain function `Void->T` can act as a `Computation<T>`. However `Void->Promise<T>` will act as `Computation<Promised<T>>`, meaning that any *function* that returns a *promise* can act as a *computation* that produces a *promised value*. This means if we call `Observable.auto` with a function that produces a `Promise<T>`, we will get an `Observable<Promised<T>>` rather than the undesirable `Observable<Promise<T>>`.

##### Transform

The general idea of transforms is very similar to computations, except that transforms take an input and produce an output.

```haxe
abstract Transform<T, R> {
  function apply(value:T):R;

  @:from static private function naiveAsync<T, R>(f:T->Promise<R>):Transform<Promised<T>, Promise<R>>;
  @:from static private function naive<T, R>(f:T->R):Transform<Promised<T>, Promised<R>>;
  @:from static private function plain<T, R>(f:T->R):Transform<T, R>;
}
```

So a transform really just maps values of type `T` to values of type `R` and a plain `T->R` function will do. There is however a way to "lift" so called *naive* transforms as needed. What that means that a function that assumes a plain `T` will be automatically wrapped into a transform that can accept `Promised<T>`. This way you don't have to deal with errors or loading states but can operate on the actual values directly, while errors nicely propagate out of band.

Transforms are used in both `map` and `mapAsync`, the former being very much like the simple version in the introduction and the latter just being an asynchronous version to once again obtain `Observable<Promised<R>>` rather than `Observable<Promise<R>>`.

Suppose we have a translation service:

```haxe
function translate(word:String, fromLanguage:String, toLanguage:String):Promise<String>; 
```

And we have an `Observable<String>` that represents user input.

```haxe
var input:Observable<String> = ...
input
  .mapAsync(function (word:String) return translate(word, "English", "Spanish"))
  .mapAsync(function (word:String) return translate(word, "Spanish", "German"))
  .mapAsync(function (word:String) return translate(word, "German", "Russian"))
  .mapAsync(function (word:String) return translate(word, "Russian", "English"))
  .deliver("Loading ...").bind(function (v:String) trace(v));
```

As you can see, we always deal only with `String` despite the fact that `$type(input.mapAsync(function (word:String) return translate(word, "English", "Spanish")))` is actually `Observable<Promised<String>>`.

#### Awaiting the next time a condition is met

With `nextTime` you create a `Future` that triggers when the provided condition is met for the very next time. Note that if the current value meets the condition, then the future is triggered with that value, but you can set `options.butNotNow` to `true` to delay triggering until the condition turns false and then true again. 

Example:

```haxe
player.health
  .nextTime({ butNotNow: true }, function (h) return h.cur < 0)
  .handle(function () trace("You have just died!"));
```

The `options.hires` parameter is for the cases where the observable can switch very rapidly between these states, in which case direct binding is used internally.

Example:

```haxe
var s = new State(0);
var timer = new haxe.Timer(1);
timer.run = function () s.set((s.value + 1) % 1000);
s.observe().nextTime(function (value) value == 999).handle(function () trace('999!'));
```

Assuming the timer would really fire a 1000 times per second, it will be in the right state for about just one millisecond, so batched binding may never hit that interval. On states, hires binding is cheap, on combound observables this may not be the case however. Keep that in mind when deciding whether or not to use it.

#### Creation

Aside from constructing a `State`, there are three other methods of creating observables:

1. From a function that creates measurements with `Observable.create`. Under the hood this is wrapped into an object that provides some caching and other niceties.
2. From a constant with `Observable.const`. Any constant can act as an observable. It will obviously return the same measurement again and again.
3. In an automagic way, simply through calling `Observable.auto` with a `Computation<T>` that determines the new value.

##### Automagic Observables

Automagic observables work by executing the function to calculate the new value while tracking which other observables are accessed in the process. If any of those becomes in valid, the resulting observable becomes invalid too.

Here's how we might write the `nextHealthPotion` function above:

```haxe
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

###### Caveats

Everything comes with limitations and costs attached. Things to be aware of when using `Observable.auto`:

- The resulting observable only tracks changes in other observables it accesses. So for example `Observable.auto(function () { return Date.now() })` will never update.
- While they make your code much more concise, it becomes far less implicit how exactly observables are wired together. If you want to be explicit, you can always fall back to `map`/`mapAsync` and `combine`/`combineAsync`.
