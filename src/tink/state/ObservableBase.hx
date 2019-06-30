package tink.state;

import tink.state.Observable;

using tink.CoreApi;

class ObservableBase<Change> {
  var _changes = new SignalTrigger<Change>();
  var changes:Signal<Change>;
  
  function new() {
    this.changes = _changes;
  }

  function observable<Ret>(ret:Void->Ret, ?when:Ret->Change->Bool):Observable<Ret> 
    return Observable.create(function () {
      var ret = ret();      
      return new Measurement(
        ret,
        (
          if (when == null) changes 
          else changes.filter(when.bind(ret), false)
        ).nextTime().map(function (_) return Noise)
      );
    });    
}

class ObservableIterator<T> implements ObservableObject<Iterator<T>> {
  
  static var TRIGGER = Some(Noise);
  
  var iterator:Void->Iterator<T>;
  var changes:Signal<Noise>;

  function new(iterator, changes) {
    this.iterator = iterator;
    this.changes = changes;
  }
  
  public static function make<T, C>(iterator:Void->Iterator<T>, changes:Signal<C>, ?trigger:C->Bool) {
    return new ObservableIterator(
      iterator,
      changes.select(function (c) return if (trigger == null || trigger(c)) TRIGGER else None)
    );
  }

  public function isValid()
    return true;

  public function poll()
    return new Measurement(
      iterator(), 
      changes.nextTime()
    );

  public function getComparator()
    return null;

}