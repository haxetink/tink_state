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
  inventory:Observable<Iterable<Item>>(),
  health:Observable<{ cur:Int, max: Int }>,
}

import haxe.ds.Option;

var character:Player = ...;
var nextHealthPotion = combine(
  character.inventory, 
  character.health, 
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

They are practically the same as in the introduction, except that they are abstracts. Before moving on to observables themselves, let's look at two helpers used to deal with asynchronicity and errors:

```haxe
enum Promised<T> {
  Loading;
  Done(result:T);
  Failed(error:Error);
}

abstract Transform<T, R> {
  function apply(value:T):R;
  
  @:from static private function ofNaive<T, R>(f:T->R):Transform<Promised<T>, Promised<R>>;
  @:from static private function ofExact<T, R>(f:T->R):Transform<T, R>;
}
```

The `Promised` enum is meant to represent a value that was "promised": a value resulting from an asynchronous operation. It may still be `Loading` or already `Done` or in fact the operation may have `Failed`.

The definition of a `Transform` may look somewhat intimidating. What it really means is a function that converts values of type `T` to type `V`. In fact we see that any `T->R` is such a transform. However any `T->R` can also act as a `Transform<Promised<T>, Promised<R>>`, which is done by calling the function only if the input is `Done`. If you find this a little confusing, don't worry. An example will be added shortly.

Finally, let's look at the center piece:

```haxe
abstract Observable<T> {
  
  var value(get, never):T;
      
  function combine<A, R>(that:Observable<A>, f:T->A->R):Observable<R>;
  function combineAsync<A, R>(that:Observable<A>, f:T->A->Promise<R>):Observable<Promised<R>>;
  
  function map<R>(f:Transform<T, R>):Observable<R>;
  function mapAsync<R>(f:T->Promise<R>):Observable<Promised<R>>;
  
  function measure():Measurement<T>;  
  function bind(?options:{ ?direct: Bool }, cb:Callback<T>):CallbackLink;

  static function updateAll():Void;
  static function create<T>(f:Void->Measurement<T>):Observable<T>;
  
  @:from static function auto<T>(f:Void->T):Observable<T>;
  @:from static function const<T>(value:T):Observable<T>;     
}
```

... to be continued.
