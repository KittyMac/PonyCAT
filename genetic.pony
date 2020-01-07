use "collections"
use "cli"
use "random"
use "time"
use "debug"

interface GeneticAlgorithmDelegate

	fun printOrganism(a:Organism)

	// generate organisms: delegate received the population index of the new organism, and a uint suitable
	// for seeding a RNG. delegete should return a newly allocated organism with assigned chromosomes.
	fun generateOrganism(idx:USize, rand:SharedRand): Organism
	
	// breed organisms: delegate is given two parents, a child, and a uint suitable for seeding a RNG.
	// delegete should fill out the chromosomes of the child with chromosomes selected from each parent,
	// along with any possible mutations which might occur.
	fun breedOrganisms(a:Organism box, b:Organism box, child:Organism, rand:SharedRand)
	
	// score organism: delegate is given and organism and should return a float value representing the
	// "fitness" of the organism. Higher scores must always be better scores!
	fun scoreOrganism(a:Organism box, rand:SharedRand):I64
	
	// choose organism: delegate is given an organism, its fitness score, and the number of generations
	// processed so far. return true to signify this organism's answer is
	// sufficient and the genetic algorithm should stop; return false to tell the genetic algorithm to
	// keep processing.
	fun chosenOrganism(a:Organism box, score:I64, rand:SharedRand): Bool
	
	// return a copy of an organism
	fun cloneOrganism(a:Organism box): Organism val




actor GeneticProcessor
	// Genetic processors are told to process for a number of generations, given
	// a best organism to include in their pool and then returning their new best organism.
	// The GeneticCoordinator keeps the processors working, passing in the latest best
	// organism until the solution is found
	
	let processorID:USize
	let msTimeout:U64
	let startTick:U64 = Time.millis()

	let gaDelegate:GeneticAlgorithmDelegate val
	var rand:SharedRand

	// population size: tweak this to your needs
    let numberOfOrganisms:USize = 20
	let numberOfOrganismsMinusOne:USize = numberOfOrganisms - 1

	let numberOfOrganismsf:F64 = numberOfOrganisms.f64()
	
	// Create the population arrays; one for the organism classes and another to hold the scores of said organisms
	var allOrganisms:Array[Organism] = Array[Organism](numberOfOrganisms)
    var allOrganismScores:Array[I64] = Array[I64](numberOfOrganisms)

    var newChild:Organism
    var newChildScore:I64
	
	fun _tag():USize => 2
	
	new create(processorID':USize, msTimeout':U64, gaDelegate': GeneticAlgorithmDelegate val) =>
	
		processorID = processorID'
		msTimeout = msTimeout'
		gaDelegate = gaDelegate'
	
	    (_, let t2: I64) = Time.now()
	    let tsc: U64 = @ponyint_cpu_tick[U64]()
	    rand = SharedRand(tsc, t2.u64())
	
		// Call the delegate to generate all of the organisms in the population array; score them as well
		for i in Range[USize](0, numberOfOrganisms ) do
			let o = gaDelegate.generateOrganism(i, rand)
			allOrganisms.push(o)
			allOrganismScores.push(gaDelegate.scoreOrganism(o, rand))
		end
	
		// sort the organisms so the higher fitness are all the end of the array; it is critical
	    // for performance that this array remains sorted during processing (it eliminates the need
	    // to search the population for the best organism).
		ArgSort[Array[I64], I64, Array[Organism], Organism](allOrganismScores, allOrganisms)
	
		// create a new "child" organism. this is an optimization, in order to remove the need to allocate new children
	    // during breeding, as designate one extra organsism as the "child".  We then shuffle this in and out of the
	    // population array when required, eliminating the need for costly object allocations
	    newChild = gaDelegate.generateOrganism (0, rand)
	    newChildScore = gaDelegate.scoreOrganism (newChild, rand)
	
	
	be performGenetics(sharedBestOrganism:Organism val, coordinator:GeneticCoordinator) =>
		var bestOrganism = newChild
		var bestOrganismScore = newChildScore
		var generationsConsumed:USize = 0

		try
			
			// incorporate the best organism being shared between processors
			allOrganisms(0)?.copy(sharedBestOrganism)
			allOrganismScores(0)? = gaDelegate.scoreOrganism (sharedBestOrganism, rand)

			// re-sort the organisms
			ArgSort[Array[I64], I64, Array[Organism], Organism](allOrganismScores, allOrganisms)

			while (Time.millis() - startTick) < msTimeout do
			
				// we use three (or four) methods of parent selection for breeding; this iterates over all of those
	            for i in Range[USize](0, 3) do
				
					generationsConsumed = generationsConsumed + 1
					
					// Breed the best organism asexually.
					// IT IS BEST IF THE BREEDORGANISM DELEGATE CAN RECOGNIZE THIS AND FORCE A HIGHER RATE OF SINGLE CHROMOSOME MUTATION
					var parentA:Organism box = allOrganisms(numberOfOrganismsMinusOne)?
					var parentB:Organism box = parentA
			
	                if i == 0 then
	                    // Breed the pretty ones together: favor choosing two parents with good fitness values
	                    parentA = allOrganisms( Easing.easeOutExpo (0, numberOfOrganismsf, rand.real()).usize() )?
	                    parentB = allOrganisms( Easing.easeOutExpo (0, numberOfOrganismsf, rand.real()).usize() )?
					end
	                if i == 1 then
	                    // Breed a pretty one and an ugly one: favor one parent with a good fitness value, and another parent with a bad fitness value
	                    parentA = allOrganisms( Easing.easeInExpo (0, numberOfOrganismsf, rand.real()).usize() )?
	                    parentB = allOrganisms( Easing.easeOutExpo (0, numberOfOrganismsf, rand.real()).usize() )?
					end
			
					gaDelegate.breedOrganisms (parentA, parentB, newChild, rand)
			
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
						ArgSort[Array[I64], I64, Array[Organism], Organism](allOrganismScores, allOrganisms)
					end
			
					if allOrganismScores(numberOfOrganismsMinusOne)? > bestOrganismScore then
						bestOrganism = allOrganisms(numberOfOrganismsMinusOne)?
						bestOrganismScore = allOrganismScores(numberOfOrganismsMinusOne)?
						coordinator.processResult(this, gaDelegate.cloneOrganism(bestOrganism), bestOrganismScore, generationsConsumed, false)
						return
					end
			
			        if gaDelegate.chosenOrganism (	bestOrganism, 
													bestOrganismScore, 
													rand) == true then
						coordinator.processResult(this, gaDelegate.cloneOrganism(bestOrganism), bestOrganismScore, generationsConsumed, true)
						return
					end
				end
			end
		else
			Debug.out("Exception occurred during breeding")
		end
		
		coordinator.processResult(this, gaDelegate.cloneOrganism(bestOrganism), bestOrganismScore, generationsConsumed, true)

actor GeneticCoordinator
	
	let gaDelegateVal:GeneticAlgorithmDelegate val
	var numberOfProcessors:USize
	var numberOfGenerations:USize = 0
	let completionVal:{(Organism box, I64, USize, U64)} val
	
	var bestOrganism:Organism val
	var bestOrganismScore:I64
	
	var numProcessorsNotFinished:USize = 0
	var didSendResults:Bool = false
		
	let startTick:U64 = Time.millis()
    let msTimeout:U64
	
	fun _tag():USize => 1
	fun _batch():USize => 1_000_000
	fun _priority():USize => 1
	
	new create(	numberOfProcessors':USize,
				msTimeout':U64,
				gaDelegateVal': GeneticAlgorithmDelegate val,
				completionVal': {(Organism box, I64, USize, U64)} val ) =>
		
		numberOfProcessors = numberOfProcessors'
		gaDelegateVal = gaDelegateVal'
		completionVal = completionVal'
		msTimeout = msTimeout'
		
		if numberOfProcessors == 0 then
			numberOfProcessors = 1
		end
		
	    bestOrganism = recover val gaDelegateVal.generateOrganism(0, SharedRand) end
	    bestOrganismScore = gaDelegateVal.scoreOrganism(bestOrganism, SharedRand)
		
		numProcessorsNotFinished = numberOfProcessors
		for i in Range[USize](0, numberOfProcessors) do
			GeneticProcessor(i, msTimeout, gaDelegateVal).performGenetics(bestOrganism, this)
		end
		
		
	
	be processResult(processor:GeneticProcessor, newBestOrganism:Organism val, newBestScore:I64 val, generationsConsumed:USize, isFinished:Bool) =>
		
		// Called by a processor when they've finished processing.  We need to 
		// 1. Check if we found the solution or are over time.  If we are, we end
		// 2. Check if the best organism is better than the previous best, if it is store it
		// 2. Tell the processor to continue processing, giving it the best known organism		
		numberOfGenerations = numberOfGenerations + generationsConsumed
		
		if newBestScore > bestOrganismScore then
			bestOrganism = newBestOrganism
			bestOrganismScore = newBestScore
		end
		
		// if we're benchmarking, then make sure to allow all processors to
		// send us their last result so that we can accurately tally the total
		// number of generations processed in the time limit
		if isFinished then
			if numProcessorsNotFinished > 0 then
				numProcessorsNotFinished = numProcessorsNotFinished - 1
				if (numProcessorsNotFinished == 0) and (didSendResults == false) then
					didSendResults = true
					completionVal(bestOrganism, bestOrganismScore, numberOfGenerations, (Time.millis() - startTick))
				end
			end
		else
			processor.performGenetics(bestOrganism, this)
		end
		

