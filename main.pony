use "collections"
use "random"
use "debug"
use "time"
use "cli"

class Organism
	var content:String ref
	let size:USize
	
	new create(size': USize) =>
		size = size'
		content = recover String end
	
	fun eq(other: Organism box): Bool =>
		content == other.content
	
	fun string():String => 
		let output = recover String(size) end
		try
			for i in Range[USize](0, size) do
				output.push(content(i)?)
			end
		end
		output
	
	fun ref copy(other:Organism) =>
		content.clear()
		try
			for i in Range[USize](0, size) do
				content.push(other.content(i)?)
			end
		end
	
	fun ref randomizeAll(characters: String, rand: Rand) =>
		content.clear()
		try
			for i in Range[USize](0, size) do
				let c = characters(rand.usize() % characters.size())?
				content.push(c)
			end
		end
	
	fun ref randomizeOne(characters: String, rand: Rand) =>
		try
			let i = rand.usize() % size
			let c = characters(rand.usize() % characters.size())?
			content(i)? = c
		end



class CAT
	var size: USize
	var target: String = "SUPERCALIFRAGILISTICEXPIALIDOCIOUS"
	var characters: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

	new iso create(size': USize) =>
		size = size'		
		
		Debug.out("... create CAT of size " + size.string())
		
	fun generateOrganism(rand: Rand) : Organism => 
		let o = Organism(size)
		o.randomizeAll(characters, rand)
		Debug.out(o.string())
		o
	
	fun breedOrganisms(a:Organism, b:Organism, child:Organism, rand:Rand) =>
		"""
		Breed organisms delegate needs to breed two organisms together and put their chromosomes into the child
	    in some manner. We have two ways we breed:
	    1) If we are breeding someone asexually, we simply give them a high chance of a single mutation (we assume they're close to perfect and should only be tweaked a little)
	    2) If we are breeding two distinct individuals, choose some chromosomes randomly from each parent, and have a small chance to mutate any chromosome
		"""
		
		if a == b then
            // breed an organism with itself; this is optimized as we generally want a higher chance to singly mutate something
            // think of this as we almost have the perfect organism, we just want to tweak one thing
			child.copy(a)
			child.randomizeOne(characters, rand)
			
			Debug.out(child.string())
		end
		/*
		 else {
    
            // breed two organisms, we'll do this by randomly choosing chromosomes from each parent, with the odd-ball mutation
            for i in 0..<targetString.count {
                let t = prng.getRandomNumberf()
                if (t < 0.45) {
                    child [i] = organismA [i];
                } else if (t < 0.9) {
                    child [i] = organismB [i];
                } else {
                    child [i] = prng.getRandomObjectFromArray(allCharacters)
                }
            }
        }*/
		

actor Main
	new create(_env: Env) =>
		
		let cs =
		try
			CommandSpec.leaf(
				"PonyCAT", 
				"A quick experiment with genetic algorithms in Pony", 
				[ 
					OptionSpec.u64("n", "size of string to generate" where short' = 'n', default' = 50)
					OptionSpec.u64("j", "amount of parallelism" where short' = 'j', default' = 1)
				], 
				[  ]
			)?.>add_help()?
		else
			_env.exitcode(-1)
			return
		end

		let cmd =
			match CommandParser(cs).parse(_env.args, _env.vars)
			| let c: Command => c
			| let ch: CommandHelp =>
				ch.print_help(_env.out)
				_env.exitcode(0)
				return
			| let se: SyntaxError =>
				_env.out.print(se.string())
				_env.exitcode(1)
				return
			end
	
		let numThreads = cmd.option("j").u64()
		let sizeOfTarget = cmd.option("n").u64()
				
		Debug.out("")
		Debug.out("Using " + numThreads.string() + " threads")
		Debug.out("Target string size of " + sizeOfTarget.string() + " characters")
		Debug.out("")
		
		let cat = CAT(sizeOfTarget.usize())
		var ga = GeneticAlgorithm[Organism](consume cat)
		Debug.out("Main is done")
			
		/*
	let upper = cmd.option("upper").bool()
	let words = cmd.arg("words").string_seq()
	for word in words.values() do
		env.out.write(if upper then word.upper() else word end + " ")
	end
	env.out.print("")
		*/
	

