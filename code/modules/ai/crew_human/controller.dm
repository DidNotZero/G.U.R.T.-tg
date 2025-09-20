#ifdef CREW_AI_FOUNDATION

/// Basic controller stub for human AI crew placeholders.
/datum/ai_controller/crew_human
	blackboard = list(
		BB_CREW_PERSONA = null,
		BB_CREW_TRAITS = list(),
		BB_CREW_TONE = null,
		BB_CREW_TALK_BUDGET = list(),
		BB_CREW_LAST_HEARD = list(),
		BB_CREW_ZONE = null,
		BB_CREW_GOAL = null,
		BB_CREW_NAVPATH = list(),
		BB_CREW_INTENT = null,
		BB_CREW_TARGET_CHANNEL = null,
		BB_CREW_FALLBACK_FLAG = FALSE,
	)
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
			ai_crew_log("refused controller attach", list(
				"controller" = controller_id,
				"target_type" = new_pawn ? new_pawn.type : "null",
			), TRUE)
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
	ai_crew_log("controller attached", list(
		"controller" = controller_id,
		"mob" = controlled_human ? controlled_human.name : "unknown",
		"loc" = location,
		"reason" = attach_reason,
	))
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
	ai_crew_log("controller shutdown", list(
		"controller" = controller_id,
		"reason" = reason,
		"loc" = location,
	))
	qdel(src)

/// Returns a shallow copy of persona metadata for external consumers.
/datum/ai_controller/crew_human/proc/get_persona()
	var/list/persona = blackboard[BB_CREW_PERSONA]
	if(!islist(persona))
		return null
	return persona.Copy()

/// Writes persona metadata to the blackboard.
/datum/ai_controller/crew_human/proc/set_persona(list/persona)
	if(!islist(persona))
		clear_blackboard_key(BB_CREW_PERSONA)
		return
	override_blackboard_key(BB_CREW_PERSONA, persona.Copy())

/// Returns a copy of the configured trait list.
/datum/ai_controller/crew_human/proc/get_traits()
	var/list/traits = blackboard[BB_CREW_TRAITS]
	if(!islist(traits))
		return list()
	return traits.Copy()

/// Persists persona traits to the blackboard.
/datum/ai_controller/crew_human/proc/set_traits(list/traits)
	if(!islist(traits))
		override_blackboard_key(BB_CREW_TRAITS, list())
		return
	override_blackboard_key(BB_CREW_TRAITS, traits.Copy())

/// Returns the current tone hint (serious|dry|light).
/datum/ai_controller/crew_human/proc/get_tone()
	var/tone = blackboard[BB_CREW_TONE]
	return istext(tone) ? tone : null

/// Stores the tone hint value on the blackboard.
/datum/ai_controller/crew_human/proc/set_tone(tone)
	if(isnull(tone) || !istext(tone))
		clear_blackboard_key(BB_CREW_TONE)
		return
	set_blackboard_key(BB_CREW_TONE, tone)

/// Returns a copy of the cadence budgeting structure.
/datum/ai_controller/crew_human/proc/get_talk_budget()
	var/list/budget = blackboard[BB_CREW_TALK_BUDGET]
	if(!islist(budget))
		return list()
	return budget.Copy()

/// Replaces the cadence budgeting structure on the blackboard.
/datum/ai_controller/crew_human/proc/set_talk_budget(list/budget)
	if(!islist(budget))
		override_blackboard_key(BB_CREW_TALK_BUDGET, list())
		return
	override_blackboard_key(BB_CREW_TALK_BUDGET, budget.Copy())

/// Returns the rolling buffer of recently heard lines (newest last).
/datum/ai_controller/crew_human/proc/get_last_heard()
	var/list/heard = blackboard[BB_CREW_LAST_HEARD]
	if(!islist(heard))
		return list()
	return heard.Copy()

/// Pushes a new entry onto the heard buffer, trimming to the configured limit.
/datum/ai_controller/crew_human/proc/push_last_heard(entry)
	var/list/payload
	if(islist(entry))
		var/list/entry_list = entry
		payload = entry_list.Copy()
	else
		payload = list("message" = entry)
	if(isnull(payload["timestamp"]))
		payload["timestamp"] = world.time
	LAZYINITLIST(blackboard[BB_CREW_LAST_HEARD])
	blackboard[BB_CREW_LAST_HEARD] += list(payload)
	while(length(blackboard[BB_CREW_LAST_HEARD]) > BB_CREW_LAST_HEARD_MAX_ENTRIES)
		blackboard[BB_CREW_LAST_HEARD].Cut(1, 2)

/// Clears all tracked heard entries.
/datum/ai_controller/crew_human/proc/clear_last_heard()
	override_blackboard_key(BB_CREW_LAST_HEARD, list())

/// Returns the identifier for the pawn's current navigation zone.
/datum/ai_controller/crew_human/proc/get_zone()
	var/zone = blackboard[BB_CREW_ZONE]
	return istext(zone) ? zone : null

/// Updates the current navigation zone identifier.
/datum/ai_controller/crew_human/proc/set_zone(zone)
	if(isnull(zone) || !istext(zone))
		clear_blackboard_key(BB_CREW_ZONE)
		return
	set_blackboard_key(BB_CREW_ZONE, zone)

/// Returns a copy of the active high-level goal payload.
/datum/ai_controller/crew_human/proc/get_goal()
	var/list/goal = blackboard[BB_CREW_GOAL]
	if(!islist(goal))
		return null
	return goal.Copy()

/// Replaces the stored goal payload on the blackboard.
/datum/ai_controller/crew_human/proc/set_goal(list/goal)
	if(!islist(goal))
		clear_blackboard_key(BB_CREW_GOAL)
		return
	override_blackboard_key(BB_CREW_GOAL, goal.Copy())

/// Clears the active goal payload entirely.
/datum/ai_controller/crew_human/proc/clear_goal()
	clear_blackboard_key(BB_CREW_GOAL)

/// Returns a copy of the current navigation path step list.
/datum/ai_controller/crew_human/proc/get_navpath()
	var/list/path = blackboard[BB_CREW_NAVPATH]
	if(!islist(path))
		return list()
	return path.Copy()

/// Stores a new navigation path list on the blackboard.
/datum/ai_controller/crew_human/proc/set_navpath(list/path)
	if(!islist(path))
		override_blackboard_key(BB_CREW_NAVPATH, list())
		return
	override_blackboard_key(BB_CREW_NAVPATH, path.Copy())

/// Clears the cached navigation path.
/datum/ai_controller/crew_human/proc/clear_navpath()
	override_blackboard_key(BB_CREW_NAVPATH, list())

/// Returns the last recorded speech intent (ic|radio|emote).
/datum/ai_controller/crew_human/proc/get_intent()
	var/intent = blackboard[BB_CREW_INTENT]
	return istext(intent) ? intent : null

/// Records a new speech intent on the blackboard.
/datum/ai_controller/crew_human/proc/set_intent(intent)
	if(isnull(intent) || !istext(intent))
		clear_blackboard_key(BB_CREW_INTENT)
		return
	set_blackboard_key(BB_CREW_INTENT, intent)

/// Returns the currently targeted radio channel.
/datum/ai_controller/crew_human/proc/get_target_channel()
	var/channel = blackboard[BB_CREW_TARGET_CHANNEL]
	return istext(channel) ? channel : null

/// Updates the radio channel target.
/datum/ai_controller/crew_human/proc/set_target_channel(channel)
	if(isnull(channel) || !istext(channel))
		clear_blackboard_key(BB_CREW_TARGET_CHANNEL)
		return
	set_blackboard_key(BB_CREW_TARGET_CHANNEL, channel)

/// TRUE when the most recent speech line was a fallback.
/datum/ai_controller/crew_human/proc/was_last_line_fallback()
	return !!blackboard[BB_CREW_FALLBACK_FLAG]

/// Sets the fallback flag on the blackboard.
/datum/ai_controller/crew_human/proc/set_fallback_flag(flag)
	set_blackboard_key(BB_CREW_FALLBACK_FLAG, !!flag)

/// Clears the fallback flag.
/datum/ai_controller/crew_human/proc/clear_fallback_flag()
	set_blackboard_key(BB_CREW_FALLBACK_FLAG, FALSE)

/// Builds a debug-friendly snapshot of the blackboard contents.
/datum/ai_controller/crew_human/proc/get_blackboard_debug_entries()
	var/list/entries = list()
	for(var/key in blackboard)
		var/value = blackboard[key]
		entries += list(list(
			"key" = key,
			"type" = ai_crew_debug_type(value),
			"summary" = ai_crew_debug_format_value(value),
			"length" = islist(value) ? length(value) : null,
		))
	return entries

/// Returns a structured payload consumed by the admin inspector UI.
/datum/ai_controller/crew_human/proc/get_inspector_payload()
	var/list/payload = list(
		"id" = controller_id,
		"label" = get_controller_label(),
		"attach_reason" = attach_reason,
		"ai_status" = ai_status,
		"tick_interval_ds" = tick_interval,
		"next_tick_time" = next_tick_time,
	)
	var/mob/living/carbon/human/human = controlled_human
	payload["mob_name"] = human ? human.name : null
	payload["mob_ref"] = human ? REF(human) : null
	payload["mob_stat"] = human ? human.stat : null
	payload["loc"] = human ? AREACOORD(human) : CREW_BB_VALUE_EMPTY
	payload["blackboard"] = get_blackboard_debug_entries()
	return payload

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
			ai_crew_log("controller tick", list(
				"controller" = controller_id,
				"loc" = location,
				"brute" = controlled_human.getBruteLoss(),
				"burn" = controlled_human.getFireLoss(),
				"mood" = controlled_human.mob_mood ? controlled_human.mob_mood.sanity : null,
			), TRUE)
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

/// Writes an entry to the AI Crew-specific log category.
/proc/ai_crew_log(message, list/data, debug_only = FALSE)
	if(debug_only && !AI_CREW_DEBUG_ENABLED)
		return
	if(isnull(data))
		data = list()
	logger.Log(LOG_CATEGORY_AI_CREW, message, data)

#endif
