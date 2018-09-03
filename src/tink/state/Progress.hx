package tink.state;

using tink.CoreApi;

private typedef Impl<T> = Pair<Option<Float>, State<ProgressType<T>>>;

@:forward(value)
abstract Progress<T>(Impl<T>) {
	public var total(get, never):Option<Float>;
	inline function get_total() return this.a;
	
	public inline static function trigger<T>(total):ProgressTrigger<T> {
		return new ProgressTrigger(total);
	}
	
	public static function make<T>(total:Option<Float>, f:(Float->Void)->(T->Void)->Void):Progress<T> {
		var ret = trigger(total);
		f(ret.progress, ret.finish);
		return ret;
	}
	
	inline function new(progress) {
		this = progress;
	}
	
	@:to
	public function result():Future<T> {
		return observe()
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
			observe()
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
		return this.b.observe();
	}
}

@:access(tink.state.Progress)
abstract ProgressTrigger<T>(Impl<T>) {
	public inline function new(total) {
		this = new Pair(total, new State(InProgress(0)));
	}
	
	public function progress(v:Float) {
		switch [this.b.value, this.a] {
			case [Finished(_), _]: // do nothing
			case [InProgress(current), Some(total)]:
				// Don't allow setting progress greater than or equal to `total`
				// otherwise observers will see a progress of 1 without a finished value
				if(v > current && v < total) this.b.set(InProgress(v));
			case [InProgress(current), None]:
				if(v > current) this.b.set(InProgress(v));
		}
	}
	
	public function finish(v:T) {
		switch this.b.value {
			case Finished(_): // do nothing
			case InProgress(current):
				this.b.set(Finished(v));
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