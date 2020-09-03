package tink.state.internal;

class Binding<T> implements Invalidatable implements Scheduler.Schedulable {
  final data:ObservableObject<T>;
  final cb:Callback<T>;
  final scheduler:Scheduler;
  final comparator:Comparator<T>;
  var status = Valid;
  var last:Null<T> = null;
  final link:CallbackLink;

  public function new(data, cb, ?scheduler, ?comparator) {
    this.data = data;
    this.cb = cb;
    this.scheduler = switch scheduler {
      case null: Scheduler.direct;
      case v: v;
    }
    this.comparator = data.getComparator().or(comparator);
    link = data.onInvalidate(this);
    cb.invoke(this.last = data.getValue());
  }

  public function cancel() {
    link.cancel();
    status = Canceled;
  }

  public function invalidate()
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

        if (!comparator.eq(prev, next))
          cb.invoke(next);
    }
}

private enum abstract BindingStatus(Int) {
  var Valid;
  var Invalid;
  var Canceled;
}