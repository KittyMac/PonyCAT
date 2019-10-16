use "collections"
use "cli"
use "random"
use "time"
use "debug"

interface GeneticAlgorithmDelegate[T: Any ref]

	fun printOrganism(a:T)

	// generate organisms: delegate received the population index of the new organism, and a uint suitable
	// for seeding a RNG. delegete should return a newly allocated organism with assigned chromosomes.
	fun generateOrganism(rand:Rand): T
	
	// breed organisms: delegate is given two parents, a child, and a uint suitable for seeding a RNG.
	// delegete should fill out the chromosomes of the child with chromosomes selected from each parent,
	// along with any possible mutations which might occur.
	fun breedOrganisms(a:T, b:T, child:T, rand:Rand)
	
	// score organism: delegate is given and organism and should return a float value representing the
	// "fitness" of the organism. Higher scores must always be better scores!
	//fun scoreOrganism(a:Any, rand:Rand): U64
	
	// choose organism: delegate is given an organism, its fitness score, and the number of generations
	// processed so far. return true to signify this organism's answer is
	// sufficient and the genetic algorithm should stop; return false to tell the genetic algorithm to
	// keep processing.
	//fun chosenOrganism(a:Any, score:U64, generation:U64, rand:Rand): Bool


actor GeneticAlgorithm[T: Any ref]
	
	var gaDelegate:GeneticAlgorithmDelegate[T]
	var rand:Rand
	
	// population size: tweak this to your needs
    let numberOfOrganisms:U64 = 20
    
	new create(gaDelegate': GeneticAlgorithmDelegate[T] iso) =>
		Debug.out("... create GeneticAlgorithm")
		
		gaDelegate = consume gaDelegate'
		
	    (_, let t2: I64) = Time.now()
	    let tsc: U64 = @ponyint_cpu_tick[U64]()
	    rand = Rand(tsc, t2.u64())
		
		var organismA = gaDelegate.generateOrganism(rand)
		var organismB = gaDelegate.generateOrganism(rand)
		var organismC = gaDelegate.generateOrganism(rand)
		var organismD = gaDelegate.generateOrganism(rand)
		
		gaDelegate.breedOrganisms(organismA, organismA, organismC, rand)
		
		gaDelegate.breedOrganisms(organismA, organismB, organismD, rand)
		
		gaDelegate.printOrganism(organismA)
		gaDelegate.printOrganism(organismB)
		gaDelegate.printOrganism(organismC)
		gaDelegate.printOrganism(organismD)
	

