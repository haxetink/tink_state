package tink.state;

import tink.state.Observable;

using tink.CoreApi;

@:forward(result, bind)
abstract Progress<T>(ProgressObject<T>) from ProgressObject<T> {
	public static var INIT(default, null):ProgressValue = new Pair(0.0, None);
	
	public inline static function trigger<T>():ProgressTrigger<T> {
		return new ProgressTrigger();
	}
	
	public static function make<T>(f:(Float->Option<Float>->Void)->(T->Void)->Void):Progress<T> {
		var ret = trigger();
		f(ret.progress, ret.finish);
		return ret;
	}
	
	public inline function asFuture():Future<T> {
		return this.result();
	}
	
	@:impl
	public static inline function asPromise<T>(p:ProgressObject<Outcome<T, Error>>):Promise<T>
		return p.result();
	
	@:from
	static inline function promise<T>(v:Promise<Progress<T>>):Progress<Outcome<T, Error>> {
		return new PromiseProgress(v);
	}
	
	@:from
	static inline function flatten<T>(v:Promise<Progress<Outcome<T, Error>>>):Progress<Outcome<T, Error>> {
		return new FlattenProgress(v);
	}
	
	@:from
	static inline function future<T>(v:Future<Progress<T>>):Progress<T> {
		return new FutureProgress(v);
	}
	
	public inline function next(f) {
		return asFuture().next(f);
	}
	
	@:to
	public inline function observe():Observable<ProgressType<T>> {
		return this.observe();
	}
}

class ProgressTrigger<T> extends ProgressBase<T> {
	var state:State<ProgressType<T>>;
	var _result:Future<T>;
	
	public function new() {
		state = new State(InProgress(Progress.INIT));
	}
	
	public function progress(v:Float, total:Option<Float>) {
		switch state.value {
			case Finished(_): // do nothing
			case InProgress(current):
				if(
					current.value != v || 
					switch [current.total, total] {
						case [Some(t1), Some(t2)]: t1 != t2;
						case [None, None]: false;
						case _: true;
					}
				) state.set(InProgress(new Pair(v, total)));
		}
	}
	
	public function finish(v:T) {
		switch state.value {
			case Finished(_): // do nothing
			case InProgress(_):
				state.set(Finished(v));
		}
	}
	
	override function result():Future<T> {
		if(_result == null) {
			_result = observe()
				.getNext(null, function(v) return switch v {
					case InProgress(_): None;
					case Finished(v): Some(v);
				});
		}
		return _result;
	}
	
	override function observe():Observable<ProgressType<T>> {
		return state.observe();
	}
	
	public inline function asProgress():Progress<T> {
		return this;
	}
}

class FutureProgress<T> extends ProgressBase<T> {
	var future:Future<Progress<T>>;
	var state:State<ProgressType<T>>;
	
	public function new(future)
		this.future = future;
		
	
	override function result():Future<T> {
		return future.flatMap(function(p) return p.result());
	}
	
	override function observe():Observable<ProgressType<T>> {
		if(state == null) {
			state = new State(InProgress(Progress.INIT));
			future.handle(function(p) p.observe().bind({direct: true}, state.set));
		}
		return state.observe();
	}
}

class PromiseProgress<T> extends ProgressBase<Outcome<T, Error>> {
	var promise:Promise<Progress<T>>;
	var state:State<ProgressType<Outcome<T, Error>>>;
	
	public function new(promise)
		this.promise = promise;
		
	
	override function result():Future<Outcome<T, Error>> {
		return promise.next(function(p) return p.result());
	}
	
	override function observe():Observable<ProgressType<Outcome<T, Error>>> {
		if(state == null) {
			state = new State(InProgress(Progress.INIT));
			promise.handle(function(o) switch o {
				case Success(p): p.observe().bind({direct: true}, function(v) state.set(switch v {
					case InProgress(v): InProgress(v);
					case Finished(v): Finished(Success(v));
				}));
				case Failure(e): state.set(Finished(Failure(e)));
			});
		}
		return state.observe();
	}
}

class FlattenProgress<T> extends ProgressBase<Outcome<T, Error>> {
	var promise:Promise<Progress<Outcome<T, Error>>>;
	var state:State<ProgressType<Outcome<T, Error>>>;
	
	public function new(promise)
		this.promise = promise;
		
	
	override function result():Future<Outcome<T, Error>> {
		return promise.next(function(p) return p.result());
	}
	
	override function observe():Observable<ProgressType<Outcome<T, Error>>> {
		if(state == null) {
			state = new State(InProgress(Progress.INIT));
			promise.handle(function(o) switch o {
				case Success(p): p.observe().bind({direct: true}, state.set);
				case Failure(e): state.set(Finished(Failure(e)));
			});
		}
		return state.observe();
	}
}

interface ProgressObject<T> {
	function result():Future<T>;
	function bind(?opt:BindingOptions<ProgressValue>, f:Callback<ProgressValue>):CallbackLink;
	function observe():Observable<ProgressType<T>>;
}

class ProgressBase<T> implements ProgressObject<T> {
	public function result():Future<T> {
		throw 'not implemented';
	}
	
	public function bind(?opt:BindingOptions<ProgressValue>, f:Callback<ProgressValue>):CallbackLink {
		var binding:CallbackLink;
		
		var opt:BindingOptions<ProgressType<T>> = switch opt {
			case null: null;
			case o: {
				direct: o.direct,
				comparator: 
					if(o.comparator == null)
						null
					else 
						function(v1, v2) return switch [v1, v2] {
							case [InProgress(p1), InProgress(p2)]: o.comparator(p1, p2);
							case _: false;
						}
			}
		}
		
		binding = 
			observe()
				.bind(opt, function(v) switch v {
					case InProgress(p): f.invoke(p);
					case Finished(_): binding.dissolve();
				});
				
		return binding;
	}
	
	public function observe():Observable<ProgressType<T>> {
		throw 'not implemented';
	}
	
}

abstract ProgressValue(Pair<Float, Option<Float>>) from Pair<Float, Option<Float>> {
	public var value(get, never):Float;
	public var total(get, never):Option<Float>;
	
	public inline function new(value, total)
		this = new Pair(value, total);
	
	/**
	 * Normalize to 0-1 range
	 */
	public inline function normalize():Option<UnitInterval>
		return total.map(function(v) return value / v);
		
	inline function get_value() return this.a;
	inline function get_total() return this.b;
}

abstract UnitInterval(Float) from Float to Float {
	public function toPercentageString(dp:Int) {
		var m = Math.pow(10, dp);
		var v = Math.round(this * m * 100) / m;
		var s = Std.string(v);
		return switch s.indexOf('.') {
			case -1: s + '.' + StringTools.lpad('', '0', dp) + '%';
			case i if(s.length - i > dp): s.substr(0, dp + i + 1) + '%';
			case i: StringTools.rpad(s, '0', i + dp + 1) + '%';
		}
	}
}

enum ProgressType<T> {
	InProgress(v:ProgressValue);
	Finished(v:T);
}