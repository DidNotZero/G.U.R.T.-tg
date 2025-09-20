#ifdef CREW_AI_FOUNDATION

#define CREW_SPEECH_MAX_LEN 160
#define CREW_SPEECH_QUEUE_LIMIT 8
#define CREW_SPEECH_FALLBACK_TEXT "..."
#define CREW_SPEECH_GLOBAL_DELAY (0.8 SECONDS)
#define CREW_SPEECH_COOLDOWN_LOCAL (1.5 SECONDS)
#define CREW_SPEECH_COOLDOWN_RADIO (2.5 SECONDS)
#define CREW_SPEECH_RESULT_DROPPED 0
#define CREW_SPEECH_RESULT_SUCCESS 1
#define CREW_SPEECH_RESULT_DEFER 2

var/static/list/crew_speech_channel_map = list(
	"common" = list(
		"cooldown" = CREW_SPEECH_COOLDOWN_RADIO,
		"cooldown_key" = "common",
		"mode_headset" = TRUE,
		"radio_extension" = null,
		"radio_channel" = RADIO_CHANNEL_COMMON,
		"radio_key" = RADIO_KEY_COMMON,
		"log_channel" = RADIO_CHANNEL_COMMON,
	),
	"med" = list(
		"cooldown" = CREW_SPEECH_COOLDOWN_RADIO,
		"cooldown_key" = "med",
		"mode_headset" = FALSE,
		"radio_extension" = RADIO_CHANNEL_MEDICAL,
		"radio_channel" = RADIO_CHANNEL_MEDICAL,
		"radio_key" = RADIO_KEY_MEDICAL,
		"log_channel" = RADIO_CHANNEL_MEDICAL,
	),
	"eng" = list(
		"cooldown" = CREW_SPEECH_COOLDOWN_RADIO,
		"cooldown_key" = "eng",
		"mode_headset" = FALSE,
		"radio_extension" = RADIO_CHANNEL_ENGINEERING,
		"radio_channel" = RADIO_CHANNEL_ENGINEERING,
		"radio_key" = RADIO_KEY_ENGINEERING,
		"log_channel" = RADIO_CHANNEL_ENGINEERING,
	),
	"sec" = list(
		"cooldown" = CREW_SPEECH_COOLDOWN_RADIO,
		"cooldown_key" = "sec",
		"mode_headset" = FALSE,
		"radio_extension" = RADIO_CHANNEL_SECURITY,
		"radio_channel" = RADIO_CHANNEL_SECURITY,
		"radio_key" = RADIO_KEY_SECURITY,
		"log_channel" = RADIO_CHANNEL_SECURITY,
	),
	"sci" = list(
		"cooldown" = CREW_SPEECH_COOLDOWN_RADIO,
		"cooldown_key" = "sci",
		"mode_headset" = FALSE,
		"radio_extension" = RADIO_CHANNEL_SCIENCE,
		"radio_channel" = RADIO_CHANNEL_SCIENCE,
		"radio_key" = RADIO_KEY_SCIENCE,
		"log_channel" = RADIO_CHANNEL_SCIENCE,
	),
	"cargo" = list(
		"cooldown" = CREW_SPEECH_COOLDOWN_RADIO,
		"cooldown_key" = "cargo",
		"mode_headset" = FALSE,
		"radio_extension" = RADIO_CHANNEL_SUPPLY,
		"radio_channel" = RADIO_CHANNEL_SUPPLY,
		"radio_key" = RADIO_KEY_SUPPLY,
		"log_channel" = RADIO_CHANNEL_SUPPLY,
	),
	"supply" = list(
		"cooldown" = CREW_SPEECH_COOLDOWN_RADIO,
		"cooldown_key" = "cargo",
		"mode_headset" = FALSE,
		"radio_extension" = RADIO_CHANNEL_SUPPLY,
		"radio_channel" = RADIO_CHANNEL_SUPPLY,
		"radio_key" = RADIO_KEY_SUPPLY,
		"log_channel" = RADIO_CHANNEL_SUPPLY,
	)
)

/// Accepts a payload from the planner gateway and queues the speech request.
/datum/ai_controller/crew_human/proc/queue_speech_from_payload(list/payload)
	if(!islist(payload))
		return FALSE
	var/message = payload["speech"]
	var/intent = payload["intent"]
	var/channel = payload["target_channel"]
	var/list/options = list()
	if(istext(payload["fallback_text"]))
		options["fallback_text"] = payload["fallback_text"]
	if(islist(payload["metadata"]))
		options["metadata"] = payload["metadata"].Copy()
	if(istext(payload["emote"]))
		options["emote"] = payload["emote"]
	return queue_speech(message, intent, channel, options)

/// Queues a speech entry so the controller can emit it under cooldown constraints.
/datum/ai_controller/crew_human/proc/queue_speech(message, intent = "ic", target_channel = "local", list/options)
	if(!AI_CREW_ENABLED)
		return FALSE
	if(ai_status == AI_STATUS_OFF)
		return FALSE
	if(!istype(controlled_human))
		return FALSE
	if(!istext(message))
		return FALSE
	var/raw_text = strip_html(message)
	raw_text = trim(raw_text)
	if(!length(raw_text))
		return FALSE
	var/was_trimmed = length_char(raw_text) > CREW_SPEECH_MAX_LEN
	var/sanitized = copytext_char(raw_text, 1, CREW_SPEECH_MAX_LEN + 1)
	if(!length(sanitized))
		return FALSE
	var/requested_intent = istext(intent) ? lowertext(intent) : "ic"
	var/requested_channel = istext(target_channel) ? lowertext(target_channel) : "local"
	var/list/options_copy = islist(options) ? options.Copy() : list()
	var/list/entry = list(
		"text" = sanitized,
		"intent" = requested_intent,
		"target_channel" = requested_channel,
		"created_at" = world.time,
		"available_time" = options_copy["available_time"] && isnum(options_copy["available_time"]) ? max(world.time, options_copy["available_time"]) : world.time,
	)
	if(was_trimmed)
		entry["was_trimmed"] = TRUE
	if(istext(options_copy["fallback_text"]))
		entry["fallback_text"] = options_copy["fallback_text"]
	if(islist(options_copy["metadata"]))
		entry["metadata"] = options_copy["metadata"].Copy()
	if(options_copy["force_local"])
		entry["force_local"] = TRUE
	LAZYINITLIST(speech_queue)
	if(length(speech_queue) >= CREW_SPEECH_QUEUE_LIMIT)
		var/list/dropped = speech_queue[1]
		speech_queue.Cut(1, 2)
		ai_crew_log("speech queue trimmed", list(
			"controller" = get_controller_label(),
			"removed_intent" = islist(dropped) ? dropped["intent"] : null,
			"removed_channel" = islist(dropped) ? dropped["target_channel"] : null,
		), TRUE)
	speech_queue += list(entry)
	if(AI_CREW_DEBUG_ENABLED)
		ai_crew_log("speech queued", list(
			"controller" = get_controller_label(),
			"intent" = requested_intent,
			"channel" = requested_channel,
			"length" = length_char(sanitized),
		), TRUE)
	return TRUE

/// Processes one pending speech entry if cooldown and timing requirements allow.
/datum/ai_controller/crew_human/proc/process_speech_queue()
	if(!AI_CREW_ENABLED)
		return
	if(ai_status == AI_STATUS_OFF)
		return
	if(!islist(speech_queue) || !length(speech_queue))
		return
	if(!istype(controlled_human))
		LAZYCLEARLIST(speech_queue)
		return
	var/list/entry = speech_queue[1]
	if(!islist(entry))
		speech_queue.Cut(1, 2)
		return
	if(!isnum(entry["available_time"]))
		entry["available_time"] = world.time
	if(next_speech_time && world.time < next_speech_time)
		entry["available_time"] = max(entry["available_time"], next_speech_time)
		return
	if(entry["available_time"] > world.time)
		return
	var/result = deliver_speech_entry(entry)
	if(result == CREW_SPEECH_RESULT_DEFER)
		speech_queue[1] = entry
		return
	speech_queue.Cut(1, 2)
	if(result == CREW_SPEECH_RESULT_DROPPED && !length(speech_queue))
		clear_fallback_flag()

/// Attempts to emit the provided entry, returning a status flag.
/datum/ai_controller/crew_human/proc/deliver_speech_entry(list/entry)
	var/mob/living/carbon/human/human = controlled_human
	if(!istype(human) || QDELETED(human))
		return CREW_SPEECH_RESULT_DROPPED
	if(human.ai_controller != src)
		return CREW_SPEECH_RESULT_DROPPED
	var/original_text = entry["text"]
	if(!istext(original_text))
		return CREW_SPEECH_RESULT_DROPPED
	var/text = strip_html(original_text)
	text = trim(text)
	var/original_length = length_char(text)
	if(!length(text))
		return CREW_SPEECH_RESULT_DROPPED
	if(original_length > CREW_SPEECH_MAX_LEN)
		text = copytext_char(text, 1, CREW_SPEECH_MAX_LEN + 1)
	var/requested_intent = istext(entry["intent"]) ? entry["intent"] : "ic"
	requested_intent = lowertext(requested_intent)
	var/requested_channel = istext(entry["target_channel"]) ? lowertext(entry["target_channel"]) : "local"
	var/list/context = entry["force_local"] ? build_speech_context("ic", "local") : build_speech_context(requested_intent, requested_channel)
	var/fallback_used = FALSE
	var/list/fallback_reasons = list()
	if(entry["was_trimmed"])
		fallback_used = TRUE
		fallback_reasons += "length_cap"
	else if(original_length > CREW_SPEECH_MAX_LEN)
		fallback_used = TRUE
		fallback_reasons += "length_cap"
	switch(context["delivery_kind"])
		if("fallback", "unsupported")
			fallback_used = TRUE
			if(context["fallback_reason"])
				fallback_reasons += context["fallback_reason"]
			text = get_fallback_text(entry)
			context = build_speech_context("ic", "local")
		if("radio")
			if(!can_emit_to_radio(context))
				fallback_used = TRUE
				fallback_reasons += "no_channel_access"
				text = get_fallback_text(entry)
				context = build_speech_context("ic", "local")
	if(!length(text))
		text = get_fallback_text(entry)
		fallback_used = TRUE
		fallback_reasons += "empty_text"
	var/list/message_mods = islist(context["message_mods"]) ? context["message_mods"] : list()
	var/list/cooldowns = speech_channel_cooldowns
	var/cooldown_key = context["cooldown_key"]
	if(!cooldown_key)
		cooldown_key = "local"
	var/next_allowed = islist(cooldowns) ? cooldowns[cooldown_key] : null
	if(isnum(next_allowed) && next_allowed > world.time)
		entry["available_time"] = next_allowed
		return CREW_SPEECH_RESULT_DEFER
	human.say(text, null, null, TRUE, null, TRUE, "crew_ai", TRUE, null, null, message_mods)
	if(fallback_used)
		set_fallback_flag(TRUE)
	else
		clear_fallback_flag()
	var/cooldown_duration = isnum(context["cooldown"]) ? max(1, context["cooldown"]) : CREW_SPEECH_COOLDOWN_LOCAL
	LAZYINITLIST(speech_channel_cooldowns)
	speech_channel_cooldowns[cooldown_key] = world.time + cooldown_duration
	next_speech_time = world.time + CREW_SPEECH_GLOBAL_DELAY
	var/list/log_data = list(
		"controller" = get_controller_label(),
		"mob" = human ? human.real_name : null,
		"intent_requested" = requested_intent,
		"intent_resolved" = context["delivery_kind"],
		"channel_requested" = requested_channel,
		"channel_resolved" = context["log_channel"],
		"fallback" = fallback_used,
		"fallback_reasons" = length(fallback_reasons) ? jointext(fallback_reasons, ",") : null,
		"text" = text,
		"queue_age_ds" = world.time - (entry["created_at"] || world.time),
	)
	if(islist(entry["metadata"]))
		log_data["metadata"] = entry["metadata"].Copy()
	ai_crew_log("speech emitted", log_data)
	return CREW_SPEECH_RESULT_SUCCESS

/// Builds a context object describing how to emit a requested intent/channel pair.
/datum/ai_controller/crew_human/proc/build_speech_context(intent, channel)
	var/list/context = list(
		"delivery_kind" = "local",
		"cooldown" = CREW_SPEECH_COOLDOWN_LOCAL,
		"cooldown_key" = "local",
		"message_mods" = list(),
		"log_channel" = "Local",
		"radio_extension" = null,
		"mode_headset" = FALSE,
	)
	if(intent == "radio")
		var/list/definition = resolve_speech_channel(channel)
		if(!islist(definition))
			context["delivery_kind"] = "fallback"
			context["fallback_reason"] = "invalid_channel"
			return context
		var/list/mods = list()
		if(definition["mode_headset"])
			mods[MODE_HEADSET] = TRUE
		if(definition["radio_extension"])
			mods[RADIO_EXTENSION] = definition["radio_extension"]
		if(definition["radio_key"])
			mods[RADIO_KEY] = definition["radio_key"]
		context["delivery_kind"] = "radio"
		context["cooldown"] = definition["cooldown"]
		context["cooldown_key"] = definition["cooldown_key"]
		context["message_mods"] = mods
		context["log_channel"] = definition["log_channel"]
		context["radio_extension"] = definition["radio_extension"]
		context["mode_headset"] = definition["mode_headset"]
		return context
	if(intent == "emote")
		context["delivery_kind"] = "unsupported"
		context["fallback_reason"] = "emote_intent"
		return context
	return context

/// Returns channel metadata for a given crew token.
/datum/ai_controller/crew_human/proc/resolve_speech_channel(channel)
	if(!istext(channel))
		return null
	var/lower = lowertext(channel)
	var/list/definition = crew_speech_channel_map[lower]
	if(!islist(definition))
		return null
	return definition.Copy()

/// TRUE when the controlled pawn can transmit on the requested radio context.
/datum/ai_controller/crew_human/proc/can_emit_to_radio(list/context)
	var/mob/living/carbon/human/human = controlled_human
	if(!istype(human))
		return FALSE
	if(context["mode_headset"] && crew_has_transmit_headset(human))
		return TRUE
	var/radio_extension = context["radio_extension"]
	if(istext(radio_extension) && crew_has_radio_channel(human, radio_extension))
		return TRUE
	if(context["mode_headset"])
		return crew_has_transmit_headset(human)
	return FALSE

/// Returns TRUE if the human has an active headset or radio implant for Common.
/datum/ai_controller/crew_human/proc/crew_has_transmit_headset(mob/living/carbon/human/human)
	if(!istype(human))
		return FALSE
	var/list/devices = list(human.ears, human.ears_extra)
	for(var/obj/item/radio/headset/headset in devices)
		if(!istype(headset))
			continue
		if(QDELETED(headset))
			continue
		if(!headset.is_on())
			continue
		if(!headset.broadcasting)
			continue
		return TRUE
	if(islist(human.implants))
		for(var/obj/item/implant/radio/implant in human.implants)
			if(!istype(implant))
				continue
			if(QDELETED(implant))
				continue
			if(implant.radio && implant.radio.is_on())
				return TRUE
	return FALSE

/// Returns TRUE if the human can transmit on the supplied encrypted channel.
/datum/ai_controller/crew_human/proc/crew_has_radio_channel(mob/living/carbon/human/human, channel)
	if(!istype(human) || !istext(channel))
		return FALSE
	if(islist(human.implants))
		for(var/obj/item/implant/radio/implant in human.implants)
			if(!istype(implant))
				continue
			var/obj/item/radio/internal_radio = implant.radio
			if(!internal_radio || QDELETED(internal_radio))
				continue
			if(!internal_radio.is_on())
				continue
			if(islist(internal_radio.channels) && !isnull(internal_radio.channels[channel]))
				return TRUE
	var/list/devices = list(human.ears, human.ears_extra)
	for(var/obj/item/radio/headset/headset in devices)
		if(!istype(headset))
			continue
		if(QDELETED(headset))
			continue
		if(!headset.is_on())
			continue
		if(!headset.broadcasting)
			continue
		if(islist(headset.channels) && !isnull(headset.channels[channel]))
			return TRUE
	for(var/obj/item/radio/radio_device in human.held_items)
		if(!istype(radio_device))
			continue
		if(QDELETED(radio_device))
			continue
		if(!radio_device.is_on())
			continue
		if(!radio_device.broadcasting)
			continue
		if(islist(radio_device.channels) && !isnull(radio_device.channels[channel]))
			return TRUE
	return FALSE

/// Provides a sanitized fallback payload when the requested line cannot be sent.
/datum/ai_controller/crew_human/proc/get_fallback_text(list/entry)
	var/fallback_text = entry && istext(entry["fallback_text"]) ? entry["fallback_text"] : CREW_SPEECH_FALLBACK_TEXT
	fallback_text = strip_html(fallback_text)
	fallback_text = trim(copytext_char(fallback_text, 1, CREW_SPEECH_MAX_LEN + 1))
	if(!length(fallback_text))
		fallback_text = CREW_SPEECH_FALLBACK_TEXT
	return fallback_text

#undef CREW_SPEECH_MAX_LEN
#undef CREW_SPEECH_QUEUE_LIMIT
#undef CREW_SPEECH_FALLBACK_TEXT
#undef CREW_SPEECH_GLOBAL_DELAY
#undef CREW_SPEECH_COOLDOWN_LOCAL
#undef CREW_SPEECH_COOLDOWN_RADIO
#undef CREW_SPEECH_RESULT_DROPPED
#undef CREW_SPEECH_RESULT_SUCCESS
#undef CREW_SPEECH_RESULT_DEFER

#endif
