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
	fun chosenOrganism(a:Stringable, score:I64, rand:Rand): Bool





actor GeneticProcessor[T: Stringable ref]
	// Genetic processors are told to process for a number of generations, given
	// a best organism to include in their pool and then returning their new best organism.
	// The GeneticCoordinator keeps the processors working, passing in the latest best
	// organism until the solution is found
	
	let gaDelegate:GeneticAlgorithmDelegate[T]
	var rand:Rand
	
	// population size: tweak this to your needs
    let numberOfOrganisms:USize = 20
	let numberOfOrganismsMinusOne:USize = numberOfOrganisms - 1
	
	let numberOfOrganismsf:F64 = numberOfOrganisms.f64()
		
	// Create the population arrays; one for the organism classes and another to hold the scores of said organisms
	var allOrganisms:Array[T] = Array[T](numberOfOrganisms)
    var allOrganismScores:Array[I64] = Array[I64](numberOfOrganisms)
	
    var newChild:T
    var newChildScore:U64
	
	new create(gaDelegate': GeneticAlgorithmDelegate[T] val) =>
		
		gaDelegate = gaDelegate'
		
	    (_, let t2: I64) = Time.now()
	    let tsc: U64 = @ponyint_cpu_tick[U64]()
	    rand = Rand(tsc, t2.u64())
		
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
	    newChild = gaDelegate.generateOrganism (0, rand)
	    newChildScore = gaDelegate.scoreOrganism (newChild, rand)
		
	
	be performGenetics(maxGenerations:U64, coordinator:GeneticCoordinator[T]) =>
	
		var bestOrganism = newChild
		var bestOrganismScore = newChildScore
	
	
		try
	
			for n in Range[USize](0, maxGenerations) do
			
				// we use three (or four) methods of parent selection for breeding; this iterates over all of those
	            for i in Range[USize](0, 3) do
						
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
				
			        if gaDelegate.chosenOrganism (	bestOrganism, 
													bestOrganismScore, 
													rand) == true then
													
						let sendableOrganism = recover bestOrganism end
						coordinator.processResult(this, sendableOrganism, bestOrganismScore, true)
						return
					end
				end
			end
		else
			Debug.out("Exception occurred during breeding")
		end
		
		coordinator.processResult(this, bestOrganism, bestOrganismScore, false)
		

actor GeneticCoordinator[T: Stringable ref]
	
	let gaDelegate:GeneticAlgorithmDelegate[T]
	var numberOfProcessors:U64
	var numberOfGenerations:U64 = 0
	let completion:{(T, I64, U64, U64)} val
	
	var bestOrganism:(T | None) = None
	var bestOrganismScore:(U64 | None) = None
	
	let numberOfGenerationsPerProcessor:U64 = 500
	
	let startTick:U64 = Time.millis()
    let msTimeout:U64
	
	new create(	numberOfProcessors':U64,
				msTimeout':U64,
				gaDelegate': GeneticAlgorithmDelegate[T] val,
				completion': {(T, I64, U64, U64)} val ) =>
		
		numberOfProcessors = numberOfProcessors'
		gaDelegate = gaDelegate'
		completion = completion'
		msTimeout = msTimeout'
		
		// if numberOfProcessors is 0 then use the number of available cpus
		if numberOfProcessors == 0 then
			numberOfProcessors = 1
		end
		
	    bestOrganism = None
	    bestOrganismScore = None
		
		for i in Range[USize](0, numberOfProcessors) do
			GeneticProcessor(gaDelegate).performGenetics(500, this)
		end
		
		
	
	be processResult(processor:GeneticProcessor[T], newBestOrganism:T iso, newBestScore:U64 val, isFinished:Bool) =>
		
		// Called by a processor when they've finished processing.  We need to 
		// 1. Check if we found the solution or are over time.  If we are, we end
		// 2. Check if the best organism is better than the previous best, if it is store it
		// 2. Tell the processor to continue processing, giving it the best known organism
		var finished = false
		
		numberOfGenerations = numberOfGenerations + numberOfGenerationsPerProcessor
		
		if (bestOrganismScore == None) or (newBestScore > bestOrganismScore) then
			bestOrganism = newBestOrganism
			bestOrganismScore = newBestScore
			
			//if (numberOfGenerations % 500) == 0 then
			//	Debug.out("[" + numberOfGenerations.string() + "] Best organism: " + bestOrganism.string())
			//end
			
		end
		
		// If we're over time, then we should end early
		if ((Time.millis() - startTick) > msTimeout) or isFinished then
			completion(bestOrganism, bestOrganismScore, numberOfGenerations, (Time.millis() - startTick))
		else
			processor.performGenetics(500)
		end
		

