let { observable, computed, autorun } = require('mobx');

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
  let start = Date.now();
  for (let i = 0; i < repeat; i++) task();
  console.log(`${name} took ${(Date.now() - start) / repeat}ms`);
}

measure('create 100000 todos', () => createTodos(100000));

measure('create 1000 todos, finish all', () => {
  let todos = createTodos(1000);
  let unfinishedTodoCount = computed(() => {
    return todos.reduce((count, { done }) => done ? count : count + 1, 0);
  });

  unfinishedTodoCount.observe(x => {});

  for (let item of todos)
    item.done = true;

});