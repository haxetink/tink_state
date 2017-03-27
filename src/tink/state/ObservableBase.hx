package tink.state;

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
        ).next().map(function (_) return Noise)
      );
    });    
}