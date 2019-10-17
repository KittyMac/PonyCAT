
primitive Math

	fun pow(x':F64, n':F64):F64 =>
		var x = x'
		var n = n'
	
		if n < 0 then
			x = 1 / x
			n = -n
		end
		if n == 0 then
			return 1
		end
	
		var y:F64 = 1
		while n > 1 do
			if (n % 2) == 0 then 
				x = x * x
				n = n / 2
			else
				y = x * y
				x = x * x
				n = (n - 1) / 2
			end
		end
		x * y