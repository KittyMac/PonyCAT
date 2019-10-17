
primitive Easing
	
	// easeInExpo will favor parents with bad fitness values
	fun easeInExpo (from:F64, to:F64, v:F64):F64 =>
	    ((to - from) * Math.pow(2, 10 * ((v / 1) - 1))) + from

	// easeOutExpo will favor parents with good fitness values
	fun easeOutExpo (from:F64, to:F64, v:F64):F64 =>
	    ((to - from) * (-Math.pow(2, -10 * (v / 1)) + 1)) + from