let { observable, computed, autorun, transaction } = require('mobx');

function createTodos(count) {
  let todos = [];
  for (let i = 0; i < count; i++) {
    todos.push({
      done: false,
      description: `item ${i}`,
    });
  }
  return observable(todos);
}

function measure(name, task, repeat = 1) {
  for (let i = 0; i < repeat; i++) task();// warmup
  let start = Date.now();
  for (let i = 0; i < repeat; i++) task();
  console.log(`${name} took ${(Date.now() - start) / repeat}ms (avg. of ${repeat} runs)`);
}

measure('create 10000 todos', () => createTodos(1000), 100);

{
  let todos = createTodos(1000);

  function scheduler() {// makes a scheduler that's similar to what tink_state does
    let first = true,
        dirty = false;
    return run => {
      if (first) {
        first = false;
        run();
        return;
      }
      if (!dirty) {
        dirty = true;
        queueMicrotask(run);
      }
    }
  }

  ['direct', 'batched', 'atomic'].forEach(mode => {
    measure(`create 1000 todos, finish all [${mode}]`, () => {
      let unfinishedTodoCount = computed(() => {
        return todos.reduce((count, { done }) => done ? count : count + 1, 0);
      });

      let dispose =
        (mode == 'batched')
        ? autorun(() => unfinishedTodoCount.get(), {
            scheduler: scheduler()
          })
        : unfinishedTodoCount.observe(x => {});

      let update = (mode == 'atomic') ? transaction : f => f();
      update(() => {
        for (let item of todos)
          item.done = !item.done;
      });
      dispose();
    }, { atomic: 1000, batched: 1000, direct: 10 }[mode]);
  });
}