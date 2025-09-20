#ifdef CREW_AI_FOUNDATION

/// Component that listens for speech signals on the controlled human and records them on the controller blackboard.
/datum/component/ai_crew_perception
	dupe_mode = COMPONENT_DUPE_UNIQUE

	/// Controller that owns this perception feed.
	var/datum/ai_controller/crew_human/controller

/datum/component/ai_crew_perception/Initialize(datum/ai_controller/crew_human/new_controller)
	if(!ishuman(parent))
		return COMPONENT_INCOMPATIBLE
	controller = new_controller
	return ..()

/datum/component/ai_crew_perception/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOVABLE_HEAR, PROC_REF(on_hear))
	return ..()

/datum/component/ai_crew_perception/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_MOVABLE_HEAR)
	controller = null
	return ..()

/// Updates the owning controller without reallocating the component.
/datum/component/ai_crew_perception/proc/set_controller(datum/ai_controller/crew_human/new_controller)
	controller = new_controller

/// Signal handler that normalizes heard speech/radio lines into blackboard entries.
/datum/component/ai_crew_perception/proc/on_hear(datum/source, list/hearing_args)
	SIGNAL_HANDLER

	if(!AI_CREW_ENABLED)
		return

	var/datum/ai_controller/crew_human/current_controller = controller
	if(!istype(current_controller))
		return
	if(QDELETED(current_controller))
		controller = null
		return
	if(current_controller.controlled_human != parent)
		return
	if(current_controller.ai_status == AI_STATUS_OFF)
		return

	var/raw_message = hearing_args[HEARING_RAW_MESSAGE]
	if(!istext(raw_message) || !length(raw_message))
		return

	var/atom/movable/speaker = hearing_args[HEARING_SPEAKER]
	var/datum/language/message_language = hearing_args[HEARING_LANGUAGE]
	var/radio_freq = hearing_args[HEARING_RADIO_FREQ]
	var/radio_name = hearing_args[HEARING_RADIO_FREQ_NAME]
	var/radio_color = hearing_args[HEARING_RADIO_FREQ_COLOR]
	var/list/spans = hearing_args[HEARING_SPANS]
	var/list/message_mods = hearing_args[HEARING_MESSAGE_MODE]

	var/plain_text = raw_message
	if(istext(raw_message))
		plain_text = strip_html(raw_message)
	if(!length(plain_text))
		plain_text = raw_message

	var/mob/mob_speaker = ismob(speaker) ? speaker : null
	var/list/entry = list(
		"kind" = radio_freq ? "radio" : "local",
		"text" = plain_text,
		"raw" = raw_message,
		"speaker_name" = speaker ? speaker.name : null,
		"speaker_ref" = speaker ? REF(speaker) : null,
		"speaker_type" = speaker ? "[speaker.type]" : null,
		"speaker_ckey" = mob_speaker ? mob_speaker.ckey : null,
		"speaker_loc" = speaker ? AREACOORD(speaker) : null,
		"language_name" = message_language ? message_language.name : null,
		"language_ref" = message_language ? "[message_language.type]" : null,
		"radio_frequency" = radio_freq,
		"radio_name" = radio_name,
		"radio_color" = radio_color,
		"range" = hearing_args[HEARING_RANGE],
	)

	if(islist(spans) && length(spans))
		entry["spans"] = spans.Copy()

	if(islist(message_mods) && length(message_mods))
		if(message_mods[WHISPER_MODE])
			entry["whisper_mode"] = message_mods[WHISPER_MODE]
		if(message_mods[MODE_CUSTOM_SAY_EMOTE])
			entry["emote"] = message_mods[MODE_CUSTOM_SAY_EMOTE]
		if(message_mods[MODE_CUSTOM_SAY])
			entry["custom_verb"] = message_mods[MODE_CUSTOM_SAY]
		if(message_mods[RADIO_EXTENSION])
			entry["radio_extension"] = message_mods[RADIO_EXTENSION]
		if(message_mods[SAY_MOD_VERB])
			entry["say_verb"] = message_mods[SAY_MOD_VERB]

	current_controller.push_last_heard(entry)

	if(AI_CREW_DEBUG_ENABLED)
		ai_crew_log("perceived line", list(
			"controller" = current_controller.get_controller_label(),
			"kind" = entry["kind"],
			"speaker" = entry["speaker_name"],
			"text" = entry["text"],
		), TRUE)

#endif
