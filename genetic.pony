use "collections"
use "cli"
use "random"
use "time"
use "debug"

interface GeneticAlgorithmDelegate[T: Stringable ref]

	fun printOrganism(a:T)

	// generate organisms: delegate received the population index of the new organism, and a uint suitable
	// for seeding a RNG. delegete should return a newly allocated organism with assigned chromosomes.
	fun generateOrganism(idx:USize, rand:Rand): T
	
	// breed organisms: delegate is given two parents, a child, and a uint suitable for seeding a RNG.
	// delegete should fill out the chromosomes of the child with chromosomes selected from each parent,
	// along with any possible mutations which might occur.
	fun breedOrganisms(a:T, b:T, child:T, rand:Rand)
	
	// score organism: delegate is given and organism and should return a float value representing the
	// "fitness" of the organism. Higher scores must always be better scores!
	fun scoreOrganism(a:T, rand:Rand):I64
	
	// choose organism: delegate is given an organism, its fitness score, and the number of generations
	// processed so far. return true to signify this organism's answer is
	// sufficient and the genetic algorithm should stop; return false to tell the genetic algorithm to
	// keep processing.
	fun chosenOrganism(a:Stringable, score:I64, generation:U64, rand:Rand): Bool


actor GeneticAlgorithm[T: Stringable ref]
	
	var gaDelegate:GeneticAlgorithmDelegate[T]
	var rand:Rand
	
	// population size: tweak this to your needs
    let numberOfOrganisms:USize = 20
	let numberOfOrganismsMinusOne:USize = numberOfOrganisms - 1
	
	let numberOfOrganismsf:F64 = numberOfOrganisms.f64()
    
	new create(gaDelegate': GeneticAlgorithmDelegate[T] iso) =>
		Debug.out("... create GeneticAlgorithm")
		
		gaDelegate = consume gaDelegate'
		
	    (_, let t2: I64) = Time.now()
	    let tsc: U64 = @ponyint_cpu_tick[U64]()
	    rand = Rand(tsc, t2.u64())
	
	be performGenetics(msTimeout:U64, completion: {(T, I64, U64, U64)} val) =>
		// simple counter to keep track of the number of generations (parents selected to breed a child) have passed
		var numberOfGenerations:U64 = 0
		
		// Create the population arrays; one for the organism classes and another to hold the scores of said organisms
		var allOrganisms = Array[T](numberOfOrganisms)
        var allOrganismScores = Array[I64](numberOfOrganisms)
		
		// Call the delegate to generate all of the organisms in the population array; score them as well
		for i in Range[USize](0, numberOfOrganisms ) do
			let o = gaDelegate.generateOrganism(i, rand)
			allOrganisms.push(o)
			allOrganismScores.push(gaDelegate.scoreOrganism(o, rand))
		end
		
		// sort the organisms so the higher fitness are all the end of the array; it is critical
        // for performance that this array remains sorted during processing (it eliminates the need
        // to search the population for the best organism).
		ArgSort[Array[I64], I64, Array[T], T](allOrganismScores, allOrganisms)
		
		// create a new "child" organism. this is an optimization, in order to remove the need to allocate new children
        // during breeding, as designate one extra organsism as the "child".  We then shuffle this in and out of the
        // population array when required, eliminating the need for costly object allocations
        var newChild = gaDelegate.generateOrganism (0, rand)
        var newChildScore = gaDelegate.scoreOrganism (newChild, rand)
		
		var bestOrganism = newChild
		var bestOrganismScore = newChildScore
		
		let startTick = Time.millis()
		var currentTick = startTick
		
		try
		
			// continue processing unless we've processed for too long
            var finished = false
			
			while finished == false do
				
				// we use three (or four) methods of parent selection for breeding; this iterates over all of those
                for i in Range[USize](0, 3) do
				
					numberOfGenerations = numberOfGenerations + 1
				
					// Breed the best organism asexually.
					// IT IS BEST IF THE BREEDORGANISM DELEGATE CAN RECOGNIZE THIS AND FORCE A HIGHER RATE OF SINGLE CHROMOSOME MUTATION
					var a = numberOfOrganismsMinusOne
					var b = numberOfOrganismsMinusOne
					
                    if i == 0 then
                        // Breed the pretty ones together: favor choosing two parents with good fitness values
                        a = Easing.easeOutExpo (0, numberOfOrganismsf, rand.real()).usize()
                        b = Easing.easeOutExpo (0, numberOfOrganismsf, rand.real()).usize()
					end
                    if i == 1 then
                        // Breed a pretty one and an ugly one: favor one parent with a good fitness value, and another parent with a bad fitness value
                        a = Easing.easeInExpo (0, numberOfOrganismsf, rand.real()).usize()
                        b = Easing.easeOutExpo (0, numberOfOrganismsf, rand.real()).usize()
					end
					
					gaDelegate.breedOrganisms (allOrganisms(a)?, allOrganisms(b)?, newChild, rand)
					
					// record the fitness value of the newly bred child
                    newChildScore = gaDelegate.scoreOrganism (newChild, rand)
					
					// sanity check: ensure we've got a better score than the organism we are replacing
					let worstScore = allOrganismScores(0)?
                    if newChildScore > worstScore then
											
						// if we're better than the worst organism, swap the worst organism with me
						var tempChild = allOrganisms(0)?
						allOrganisms(0)? = newChild
						newChild = tempChild
						
						allOrganismScores(0)? = newChildScore
						
						// re-sort the organisms
						ArgSort[Array[I64], I64, Array[T], T](allOrganismScores, allOrganisms)
					end
					
					bestOrganism = allOrganisms(numberOfOrganismsMinusOne)?
					bestOrganismScore = allOrganismScores(numberOfOrganismsMinusOne)?
					
					//if (numberOfGenerations % 500) == 0 then
					//	Debug.out("[" + numberOfGenerations.string() + "] Best organism: " + bestOrganism.string())
					//end
					
					currentTick = Time.millis()
					
					// Check to see if we happen to already have the answer in the starting population
					if (currentTick - startTick) > msTimeout then
						finished = true
					end
			        if gaDelegate.chosenOrganism (	bestOrganism, 
													bestOrganismScore, 
													numberOfGenerations, 
													rand) == true then
						finished = true
					end
				end
			end
		else
			Debug.out("Exception occurred during breeding")
		end
		
		completion(bestOrganism, bestOrganismScore, numberOfGenerations, (currentTick - startTick))

