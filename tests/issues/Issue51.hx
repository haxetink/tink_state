package issues;

import tink.state.*;

using tink.CoreApi;

@:asserts
class Issue51 {
  public function new() {}

  public function testNested() {
    final baseMap = new ObservableMap<Int, Entity>();

    function query(key:String) {
      final entityQueries = {
        final cache = new Map<Int, Pair<Entity, Observable<Bool>>>();
        Observable.auto(() -> {
          for (id => entity in baseMap)
            if (!cache.exists(id))
              cache.set(id, new Pair(entity, Observable.auto(() -> entity.subMap.exists(key))));

          final deleted = [for (id in cache.keys()) if (!baseMap.exists(id)) id];

          for (id in deleted)
            cache.remove(id);

          cache;
        },
          (_, _) -> false // we're always returning the same map, so the comparator must always yield false
        );
      }

      return Observable.auto(() -> [for (p in entityQueries.value) if (p.b) p.a]);
    }

    // in the following test, `result` should contain entities whose subMap contains a 'foo' key

    final list = query('foo');
    var result = null;
    list.bind(v -> result = v, Scheduler.direct);

    asserts.assert(!result.map(e -> e.id).contains(0));
    asserts.assert(!query('foo').value.map(e -> e.id).contains(0)); // fresh query

    final entity0 = new Entity(0);
    final entity1 = new Entity(1);
    Scheduler.atomically(() -> {
      entity0.subMap.set('foo', entity1);
      baseMap.set(0, entity0);
      baseMap.set(1, entity1);
    });

    asserts.assert(result.map(e -> e.id).contains(0));
    asserts.assert(query('foo').value.map(e -> e.id).contains(0)); // fresh query

    final entity2 = new Entity(2);
    Scheduler.atomically(() -> {
      baseMap.set(2, entity2);
      entity0.subMap.remove('foo');
    });

    asserts.assert(!result.map(e -> e.id).contains(0));
    asserts.assert(!query('foo').value.map(e -> e.id).contains(0)); // fresh query

    Scheduler.atomically(() -> {
      entity0.subMap.set('foo', entity1);
    });

    asserts.assert(result.map(e -> e.id).contains(0));
    asserts.assert(query('foo').value.map(e -> e.id).contains(0)); // fresh query

    return asserts.done();
  }
}

private class Entity {
  public final id:Int;
  public final subMap:ObservableMap<String, Entity> = new ObservableMap();

  public function new(id) {
    this.id = id;
  }

  public function toString() {
    return '$id';
  }
}
