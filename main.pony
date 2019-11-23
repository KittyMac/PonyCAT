use "collections"
use "random"
use "debug"
use "time"
use "cli"

// Options: SplitMix64, XorShift128Plus, XorOshiro128Plus, XorOshiro128StarStar, MT
// and FastRand
type SharedRand is FastRand


class Organism
	var content:String ref
	let size:USize
	
	new ref create_ref(size': USize) =>
		size = size'
		content = recover String(size) end
	
	new val create_val(content': String iso) =>
		content = consume content'
		size = content.size()
	
	fun eq(other: Organism box): Bool =>
		content == other.content
	
	fun string(): String iso^ =>
		content.clone()
	
	fun ref copy(other:Organism box) =>
		content.clear()
		try
			for i in Range[USize](0, size) do
				content.push(other.content(i)?)
			end
		end
	
	fun ref randomizeAll(characters: String, rand: SharedRand) =>
		content.clear()
		try
			for i in Range[USize](0, size) do
				let c = characters(rand.usize() % characters.size())?
				content.push(c)
			end
		end
	
	fun ref randomizeOne(characters: String, rand: SharedRand) =>
		try
			let i = rand.usize() % size
			let c = characters(rand.usize() % characters.size())?
			content(i)? = c
		end



class val CAT
	var size: USize
	var target: String = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed sodales velit et velit viverra, porta porta ligula sollicitudin. Pellentesque commodo eu nunc finibus mollis. Proin sit amet volutpat sem. Quisque sit amet auctor risus. Duis porta elit vestibulum velit gravida fermentum. Sed lacinia ornare odio, ut vestibulum lacus hendrerit vitae. Suspendisse egestas, ex ut tincidunt mattis, mauris ligula placerat nisi, vel lacinia elit ex feugiat ex. Sed urna lorem, eleifend id maximus sit amet, dictum eu nisi. Nunc consectetur libero gravida ultricies hendrerit. In volutpat mollis eros id rhoncus. Etiam sagittis dapibus neque at condimentum."
	var characters: String = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!#$%&\\'()*+,-./:;?@[\\\\]^_`{|}~ \\t\\n\\r\\x0b\\x0c"

	new val create(size': USize) =>
		size = size'
		
		if size >= target.size() then
			size = target.size()
		end
		
		target = target.substring(0, size.isize())
		
		Debug.out("... create CAT of size " + size.string())
	
	fun printOrganism(a:Organism) =>
		Debug.out(a.string())
		
	fun generateOrganism(idx:USize, rand: SharedRand) : Organism => 
		let o = Organism.create_ref(size)
		o.randomizeAll(characters, rand)
		o
	
	fun cloneOrganism(a:Organism box): Organism val =>
		Organism.create_val(a.string())
		
	fun breedOrganisms(a:Organism box, b:Organism box, child:Organism, rand:SharedRand) =>
		"""
		Breed organisms delegate needs to breed two organisms together and put their chromosomes into the child
	    in some manner. We have two ways we breed:
	    1) If we are breeding someone asexually, we simply give them a high chance of a single mutation (we assume they're close to perfect and should only be tweaked a little)
	    2) If we are breeding two distinct individuals, choose some chromosomes randomly from each parent, and have a small chance to mutate any chromosome
		"""
		if a is b then
            // breed an organism with itself; this is optimized as we generally want a higher chance to singly mutate something
            // think of this as we almost have the perfect organism, we just want to tweak one thing
			child.copy(a)
			child.randomizeOne(characters, rand)
		else
			// breed two organisms, we'll do this by randomly choosing chromosomes from each parent, with the odd-ball mutation
			try
				for i in Range[USize](0, target.size() ) do
	                let t = rand.u32() % 100
	                if t < 45 then
	                    child.content(i)? = a.content(i)?
	                elseif (t < 90) then
	                    child.content(i)? = b.content(i)?
	                else
						let c = characters(rand.usize() % characters.size())?
	                    child.content(i)? = c
					end
				end
			end
		end
	
	fun scoreOrganism(a:Organism box, rand:SharedRand):I64 =>
		var score:I64 = 0
        var diff:I64 = 0
		try
			for i in Range[USize](0, target.size() ) do
	            diff = (target(i)? - a.content(i)?).i64()
	            score = score + (diff * diff)
			end
		end
        -score
	
	fun chosenOrganism(a:Organism box, score:I64, rand:SharedRand): Bool =>
		//(score == 0)
		false



actor Main
	new create(_env: Env) =>
		
		let cs =
		try
			CommandSpec.leaf(
				"PonyCAT", 
				"A quick experiment with genetic algorithms in Pony", 
				[ 
					OptionSpec.u64("n", "size of string to generate" where short' = 'n', default' = 5000)
					OptionSpec.u64("j", "number of processing actors" where short' = 'j', default' = @ponyint_cpu_count[U32]().u64())
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
	
		let numProcessors = cmd.option("j").u64()
		let sizeOfTarget = cmd.option("n").u64()
				
		Debug.out("")
		Debug.out("Using " + numProcessors.string() + " processing actors")
		Debug.out("Target string size of " + sizeOfTarget.string() + " characters")
		Debug.out("")
		
		let cat = CAT(sizeOfTarget.usize())
		var ga = GeneticCoordinator(numProcessors.usize(), 5000, cat, {(bestOrganism: Organism box, bestScore: I64, numberOfGenerations:USize, runTimeInMS:U64)(out = _env.out) =>
			out.print("[" + bestScore.string() + "] Best organism: " + bestOrganism.string())
			out.print("Done in " + runTimeInMS.string() + "ms and " + numberOfGenerations.string() + " generations")
		} val)			
	
	 	fun @runtime_override_defaults(rto: RuntimeOptions) =>
			//rto.ponyanalysis= true
			rto.ponynoscale = true
			rto.ponynoblock = true
			//rto.ponygcinitial = 0
			//rto.ponygcfactor = 1.0

