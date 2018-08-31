package tink.state;

using tink.CoreApi;

@:forward(value)
abstract Progress<T>(State<ProgressType<T>>) to State<ProgressType<T>> {
	public inline static function trigger() {
		return new ProgressTrigger();
	}
	
	public static function make<T>(f:(Float->Void)->(T->Void)->Void):Progress<T> {
		var ret = trigger();
		f(ret.progress, ret.finish);
		return ret;
	}
	
	inline function new(progress) {
		this = progress;
	}
	
	@:to
	public function result():Future<T> {
		return this.observe()
			.getNext(null, function(v) return switch v {
				case InProgress(_): None;
				case Finished(v): Some(v);
			});
	}
	
	/**
	 * Binds a callback to the progress value (A float value from 0 to 1)
	 * Will automatically dissolve itself once a result is resolved
	 */
	public function progress(?opt, f):CallbackLink {
		var binding:CallbackLink;
		
		binding = 
			this.observe()
				.bind(opt, function(v) {
					f(switch v {
						case InProgress(v): v;
						case Finished(_): binding.dissolve(); 1;
					});
				});
				
		return binding;
	}
	
	public inline function next(f) {
		return result().next(f);
	}
	
	@:to
	public inline function observe():Observable<ProgressType<T>> {
		return this.observe();
	}
}

@:access(tink.state.Progress)
abstract ProgressTrigger<T>(State<ProgressType<T>>) from State<ProgressType<T>> to State<ProgressType<T>>{
	public inline function new() {
		this = new State(InProgress(0));
	}
	
	public function progress(v:Float) {
		switch this.value {
			case Finished(_): // do nothing
			case InProgress(current):
				// Don't allow setting progress greater than or equal to 1
				// otherwise observers will see a progress of 1 without a finished value
				if(v > current && v < 1) this.set(InProgress(v));
		}
	}
	
	public function finish(v:T) {
		switch this.value {
			case Finished(_): // do nothing
			case InProgress(current):
				this.set(Finished(v));
		}
	}
	
	@:to
	public inline function asProgress():Progress<T> {
		return new Progress(this);
	}
}

enum ProgressType<T> {
	InProgress(v:Float);
	Finished(v:T);
}