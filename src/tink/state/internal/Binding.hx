package tink.state.internal;

class Binding<T> implements Observer implements Scheduler.Schedulable implements LinkObject {
  var data:ObservableObject<T>;
  var cb:Callback<T>;
  var scheduler:Scheduler;
  var comparator:Comparator<T>;
  var status = Valid;
  var last:Null<T> = null;

  static public function create<T>(o:ObservableObject<T>, cb, ?scheduler, comparator):CallbackLink {
    return
      if (o.canFire()) new Binding(o, cb, scheduler, comparator);
      else {
        cb.invoke(Observable.untracked(() -> o.getValue()));
        null;
      }
  }

  function new(data, cb, ?scheduler, ?comparator) {
    this.data = data;
    this.cb = cb;
    this.scheduler = switch scheduler {
      case null: Scheduler.direct;
      case v: v;
    }
    this.comparator = data.getComparator().or(comparator);
    data.subscribe(this);
    cb.invoke(this.last = Observable.untracked(() -> data.getValue()));
  }

  #if tink_state.debug
  static var counter = 0;
  final id = counter++;
  @:keep public function toString()
    return 'Binding#$id[${data.toString()}]';//TODO: position might be helpful too
  #end

  public function cancel() if (status != Canceled) {
    data.unsubscribe(this);
    status = Canceled;
  }

  public function notify(_)
    if (status == Valid) {
      status = Invalid;
      scheduler.schedule(this);
    }

  public function run()
    switch status {
      case Canceled | Valid:
      case Invalid:
        status = Valid;
        var prev = this.last,
            next = this.last = data.getValue();

        var canFire = data.canFire();
        if (!comparator.eq(prev, next))
          cb.invoke(next);

        if (!canFire) {
          cancel();
          data = null;
          cb = null;
          comparator = null;
        }
    }
}

private enum abstract BindingStatus(Int) {
  var Valid;
  var Invalid;
  var Canceled;
}