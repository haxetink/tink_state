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
    var count = 1000;
    measure('creating ${count} todos', () -> makeTodos(count), 100);

    var todos = makeTodos(count);
    for (mode in ['direct', 'batched', 'atomic']) {
      var unfinishedTodoCount = Observable.auto(() -> {
        var sum = 0;
        for (t in todos)
          if (!t.done.value) sum++;
        sum;
      });

      var watch = unfinishedTodoCount.bind(_ -> {}, if (mode == 'batched') null else Scheduler.direct);

      measure('toggling ${todos.length} todos [$mode]', () -> {

        function update()
          for (t in todos)
            t.done.value = !t.done.value;

        if (mode == 'atomic')
          Scheduler.atomically(update);
        else
          update();

        if (mode == 'batched')
          Observable.updateAll();


      }, switch mode {
        case 'atomic': 1000;
        case 'batched': 1000;
        default: 10;
      });

      watch.cancel();
    }
  }

  static function measure(name, f:()->Void, ?repeat = 1) {
    f();
    var old = haxe.Log.trace;
    haxe.Log.trace = (_, ?_) -> {}
    for (i in 0...repeat - 1) f();
    var start = Date.now().getTime();
    for (i in 0...repeat) f();
    haxe.Log.trace = old;
    #if sys
      Sys.println
    #elseif js
      js.Browser.console.log
    #else
      trace
    #end
      ('$name: ${(Date.now().getTime() - start) / repeat}ms (avg. of ${repeat} runs)');
  }
}