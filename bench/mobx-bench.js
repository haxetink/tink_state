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

let count = 1000;
measure(`creating ${count} todos`, () => createTodos(count), 100);

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
    let unfinishedTodoCount = computed(() => {
      return todos.reduce((count, { done }) => done ? count : count + 1, 0);
    });

    let dispose =
      (mode == 'batched')
      ? autorun(() => unfinishedTodoCount.get(), {
          scheduler: scheduler()
        })
      : unfinishedTodoCount.observe(x => {});

    measure(`toggling ${todos.length} todos [${mode}]`, () => {

      let update = (mode == 'atomic') ? transaction : f => f();
      update(() => {
        for (let item of todos)
          item.done = !item.done;
      });
    }, { atomic: 1000, batched: 1000, direct: 10 }[mode]);

    dispose();
  });
}