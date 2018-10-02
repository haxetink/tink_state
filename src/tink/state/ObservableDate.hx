package tink.state;

using tink.CoreApi;
using DateTools;

class ObservableDate implements Observable.ObservableObject<Bool> {

	static var PASSED = new Measurement(true, cast Future.NEVER);

	public var date(default, null):Date;
	public var passed(get, never):Bool;
		inline function get_passed():Bool
			return observe().value;
	
	public function isValid()
		return true;

	var _measurement:Measurement<Bool>;
	
	public function new(?date:Date) {

		if (date == null) 
			date = Date.now();

		this.date = date;

		var now = Date.now().getTime(),
			stamp = date.getTime();

		var passed = now >= stamp;

		_measurement = 
			if (passed) PASSED;
			else new Measurement(
				false,
				Future.async(function (done) 
					haxe.Timer.delay(function () {
						_measurement = PASSED;
						done(Noise);
					}, Std.int(stamp - now))
				)
			);
	}

	public function observe():Observable<Bool>
		return this;

	public function isOlderThan(msecs:Float):Bool
		return becomesOlderThan(msecs).value;

	public function becomesOlderThan(msecs:Float):Observable<Bool>
		return 
			// if (Date.now().getTime() > date.getTime() + msecs) Observable.const(true);
			// else 
			new ObservableDate(this.date.delta(msecs));

	public function poll()
		return _measurement;
}
