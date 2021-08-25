# Crash Course

At the heart of tink_state, there are two basic blocks, states and observables. Their simplified interfaces look like this:

```haxe
package tink.state;

abstract Observable<T> {
  public var value(get, never):T;
  public function bind(handler:Callback<T>):CallbackLink;
  static public function auto<X>(f:()->X):Observable<X>;
}

abstract State<T> to Observable<T> {
  public var value(get, set):T;
  public function new(value:T):Void;
  public function bind(handler:Callback<T>):CallbackLink;
}
```

An observable has:

- a readable `value`
- you can `bind` a callback to it, that is invoked with the new value if it updates. Calling `cancel` on the returned `CallbackLink` will undo the subscription.
- can be created passing a computation to `auto`

A state has:

- a `value` that can be read and written
- a `bind` method exactly like observables
- can be constructed with an initial value

Any state is also an observable, but not every observable is a state. One could also say that states are read-write versions of observables.

Now for an example:

```haxe
class TodoItem {
  public final done = new State(false);
  public final description = new State('');
  public function new() {}
  public function finish()
    done.value = true;
}

class TodoList {
  public final items = new State<haxe.ds.ReadOnlyArray<TodoItem>>([]);
  public function add(description) {
    var todo = new TodoItem();
    todo.description.set(description);
    items.set(items.value.concat([todo]));
    return todo;
  }

  public function iterator()
    return items.value.iterator();

  public function new() {}
}

var todoList = new TodoList();
var unfinishedTodoCount = Observable.auto(() -> {
  var unfinished = 0;
  for (todoItem in todoList)
    if (!todoItem.done.value) unfinished++;
  unfinished;
});

trace(unfinishedTodoCount.value);// 0

var laundry = todoList.add('Do the laundry'),
    groceries = todoList.add('Shop groceries'),
    dishes = todoList.add('Do the dishes');

trace(unfinishedTodoCount.value);// 3
```

Thus far, not very exciting, but let's continue the example above:

```haxe
unfinishedTodoCount.bind(count -> trace('$count items left to be done'));
  // 3 items left to be done

laundry.finish();
trace(unfinishedTodoCount.value);// 2

groceries.finish();
trace(unfinishedTodoCount.value);// 1

dishes.finish();
trace(unfinishedTodoCount.value);// 0

todoList.add('Take out the trash');
trace(unfinishedTodoCount.value);// 1
  // 1 items left to be done (hooray for grammar)
```

Now, as we see we have four updates, but only one `trace` from our binding. That is because by default, bindings are batched. In essence, when one of the sources of data for a binding is changed, the binding schedules itself to fire. Notice that at all times the `unfinishedTodoCount.value` is indeed valid.

There are ways to make bindings fire synchronously or to force running any pending bindings, but all this will be discussed at another time. This behavior is the most meaningful default. Consider a method to mark all items as done:

```haxe
function allDone(todoList:TodoList)
  for (todoItem in todoList)
    todoItem.finish();
```

Now let's assume that we're making yet another todo list app and somewhere in our code we have the following:

```haxe
unfinishedTodoCount.bind(count ->
  unfinishedTodoCountTextField.setText(switch count {
    case 1: '1 item left';
    case 0: 'no items left';
    case v: '$v items left';
  })
);
```

Even if `allDone` marks 1000 items as done, the `unfinishedTodoCountTextField` would be updated exactly once (or not at all, if all items were already done).

To summarize:

- data is stored in states
- you can use `auto` to derive new observables from those states (or other observables), who's values change when the sources change
- you can bind callbacks to states and observables, to perform batched updates if any data changes

## Observable data structures

In addition to states, tink_state also provides an `ObservableArray` and an `ObservableMap` that work very similary to `Array` and `Map`, but changes to them are tracked in bindings.

With these, the above `TodoList` could be modified like so:

```haxe
class TodoList {
  public final items = new tink.state.ObservableArray<TodoItem>();
  public function add(description) {
    var todo = new TodoItem();
    todo.description.set(description);
    items.push(todo);
    return todo;
  }

  public function iterator()
    return items.iterator();

  public function new() {}
}
```
