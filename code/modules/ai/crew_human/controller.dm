#ifdef CREW_AI_FOUNDATION

/// Basic controller stub for human AI crew placeholders.
/datum/ai_controller/crew_human
	name = "AI Crew Human Controller"
	/// Unique identifier for logging and debugging.
	var/controller_id
	/// Next id allocator shared across all controllers.
	var/static/next_controller_id = 1
	/// Cached reference to the human pawn we expect to control.
	var/mob/living/carbon/human/controlled_human
	/// How long (in deciseconds) between debug tick messages.
	var/tick_interval = 1.5 SECONDS
	/// Next world.time value when we should emit periodic debug output.
	var/tmp/next_tick_time = 0
	/// Optional attachment context for audit trails.
	var/tmp/attach_reason = "unknown"

	New(atom/new_pawn, new_reason)
		controller_id = next_controller_id++
		if(!isnull(new_reason))
			attach_reason = new_reason
		return ..(new_pawn)

	Destroy(force)
		STOP_PROCESSING(SSai_crew, src)
		GLOB.ai_crew_controllers -= src
		controlled_human = null
		return ..()

	TryPossessPawn(atom/new_pawn)
		if(!ishuman(new_pawn))
			log_subsystem("ai_crew", "Refused to attach controller#[controller_id] to non-human [new_pawn ? new_pawn.type : "null"]")
			return AI_CONTROLLER_INCOMPATIBLE

/datum/ai_controller/crew_human/PossessPawn(atom/new_pawn)
	var/mob/living/carbon/human/new_human = new_pawn
	. = ..()
	if(QDELETED(src))
		return .
	controlled_human = new_human
	if(!(src in GLOB.ai_crew_controllers))
		GLOB.ai_crew_controllers += src
	controlled_human?.set_stat(CONSCIOUS)
	controlled_human?.update_sight()
	controlled_human?.update_pipe_vision()
	next_tick_time = world.time
	var/location = controlled_human ? AREACOORD(controlled_human) : "unknown"
	log_subsystem("ai_crew", "controller#[controller_id] attached to [controlled_human ? controlled_human.name : "unknown"] at [location] (reason=[attach_reason])")
	return .

/datum/ai_controller/crew_human/UnpossessPawn(destroy)
	var/mob/living/carbon/human/old_human = controlled_human
	GLOB.ai_crew_controllers -= src
	STOP_PROCESSING(SSai_crew, src)
	controlled_human = null
	. = ..()
	if(!QDELETED(old_human))
		old_human.set_stat(CONSCIOUS)
	return .

/datum/ai_controller/crew_human/set_ai_status(new_ai_status, additional_flags)
	var/result = ..()
	if(result == FALSE)
		return FALSE
	STOP_PROCESSING(SSai_crew, src)
	if(ai_status != AI_STATUS_OFF)
		START_PROCESSING(SSai_crew, src)
		next_tick_time = world.time
	return result

/datum/ai_controller/crew_human/on_sentience_gained()
	SIGNAL_HANDLER
	stop_controller("player login")

/datum/ai_controller/crew_human/proc/get_controller_label()
	return "crew-[controller_id]"

/datum/ai_controller/crew_human/proc/stop_controller(reason)
	if(QDELETED(src))
		return
	var/location = controlled_human ? AREACOORD(controlled_human) : "unknown"
	log_subsystem("ai_crew", "controller#[controller_id] shutting down ([reason]) at [location]")
	qdel(src)

/datum/ai_controller/crew_human/process(seconds_per_tick)
	if(!AI_CREW_ENABLED)
		stop_controller("feature disabled")
		return PROCESS_KILL
	if(QDELETED(controlled_human) || controlled_human.ai_controller != src)
		return PROCESS_KILL
	if(controlled_human.client)
		stop_controller("client present")
		return PROCESS_KILL
	if(controlled_human.ckey)
		stop_controller("ckey assigned")
		return PROCESS_KILL
	if(controlled_human.mind)
		stop_controller("mind attached")
		return PROCESS_KILL
	if(controlled_human.stat != CONSCIOUS && controlled_human.stat != DEAD)
		controlled_human.set_stat(CONSCIOUS)
	if(world.time >= next_tick_time)
		next_tick_time = world.time + tick_interval
		if(AI_CREW_DEBUG_ENABLED)
			var/location = AREACOORD(controlled_human)
			log_subsystem("ai_crew", "controller#[controller_id] tick: loc=[location] health=[controlled_human.getBruteLoss()+controlled_human.getFireLoss()] mood=[controlled_human.mob_mood ? controlled_human.mob_mood.sanity : "n/a"]")
	return

PROCESSING_SUBSYSTEM_DEF(ai_crew)
	name = "AI Crew Controllers"
	priority = FIRE_PRIORITY_NPC
	flags = SS_BACKGROUND|SS_POST_FIRE_TIMING
	wait = 1 SECONDS
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME
	stat_tag = "AIC"

/// Attaches a crew human controller to the provided human if eligible.
/proc/ai_crew_attach_controller(mob/living/carbon/human/target, attach_reason = "manual")
	if(!AI_CREW_ENABLED)
		return null
	if(QDELETED(target) || !istype(target))
		return null
	if(istype(target.ai_controller, /datum/ai_controller/crew_human))
		return target.ai_controller
	if(target.ai_controller)
		qdel(target.ai_controller)
	target.set_stat(CONSCIOUS)
	target.ckey = null
	target.mind = null
	target.last_move = world.time
	var/datum/ai_controller/crew_human/controller = new(target, attach_reason)
	return controller

/// Removes a crew human controller from the provided human, if present.
/proc/ai_crew_detach_controller(mob/living/carbon/human/target, reason = "manual")
	if(!istype(target))
		return FALSE
	var/datum/ai_controller/crew_human/controller = target.ai_controller
	if(!istype(controller))
		return FALSE
	controller.stop_controller(reason)
	return TRUE

/// Stops every active crew human controller (used when toggling the feature off).
/proc/ai_crew_detach_all_controllers(reason = "global toggle")
	for(var/datum/ai_controller/crew_human/controller as anything in GLOB.ai_crew_controllers.Copy())
		controller.stop_controller(reason)

#endif
