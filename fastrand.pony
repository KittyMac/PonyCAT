use "random"

class FastRand is Random
	"""
	regular old c rand() implementation.  It just happens to be super fast
	"""
	// state
	var _x: U64

	new from_u64(x: U64 = 5489) =>
		_x = x

	new create(x: U64 = 5489, y: U64 = 0) =>
		"""
		Only x is used, y is discarded.
		"""
		_x = x

	fun ref next(): U64 =>
		_x = (_x * 1103515245) + 12345
	    (_x / 65536) % 32768

