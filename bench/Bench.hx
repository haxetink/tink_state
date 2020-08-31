import tink.state.*;

class Bench {
  static function main() {
    function makeTodos(count) {
      var todos = new ObservableArray();
      for (i in 0...count)
        todos.push({
          done: new State(false),
          description: new State('')
        });
      return todos;
    }
    // measure('create 100000 todos', () -> makeTodos(100000));

    for (batched in [false, true])
      measure('create 1000 todos, finish all [${batched ? 'batched' : 'direct'}]', () -> {
        var todos = makeTodos(1000);

        var unfinishedTodoCount = todos.reduce(0, (t, sum) -> if (t.done.value) sum else sum + 1);

        unfinishedTodoCount.bind({ direct: !batched }, function (x) {});

        for (i in 0...todos.length) {
          todos[Std.random(todos.length)].done.value = true;
        }

        if (batched)
          Observable.updateAll();
      }, if (batched) 10 else 1);

  }

  static function measure(name, f:()->Void, ?repeat = 1) {
    var start = Date.now().getTime();
    for (i in 0...repeat) f();
    js.Browser.console.log('$name: ${(Date.now().getTime() - start) / repeat}ms');
  }
}