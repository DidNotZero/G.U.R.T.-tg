#ifdef CREW_AI_FOUNDATION

/mob/living/carbon/human/ai_crew_speech_test
	var/list/captured_speech

/mob/living/carbon/human/ai_crew_speech_test/say(message, bubble_type, list/spans = list(), sanitize = TRUE, datum/language/language, ignore_spam = FALSE, forced, filterproof = FALSE, message_range = 7, datum/saymode/saymode, list/message_mods = list())
	captured_speech = list(
		"message" = message,
		"mods" = islist(message_mods) ? message_mods.Copy() : null,
		"forced" = forced,
	)
	return ..()

/datum/unit_test/ai_crew_speech
	var/original_flag

/datum/unit_test/ai_crew_speech/Run()
	original_flag = CONFIG_GET(flag/ai_crew_enabled)
	CONFIG_SET(flag/ai_crew_enabled, TRUE)

	var/list/setup = setup_controller(TRUE)
	var/mob/living/carbon/human/ai_crew_speech_test/human = setup["human"]
	var/datum/ai_controller/crew_human/controller = setup["controller"]
	TEST_ASSERT(controller.queue_speech("Med evac inbound", "radio", "med"), "Expected radio speech to queue with headset present")
	controller.process_speech_queue()
	var/list/captured = human.captured_speech
	TEST_ASSERT(islist(captured), "Controller should record emitted speech")
	TEST_ASSERT_EQUAL(captured["message"], "Med evac inbound", "Unexpected speech payload for medical channel")
	var/list/mods = captured["mods"]
	TEST_ASSERT(islist(mods) && mods[RADIO_EXTENSION] == RADIO_CHANNEL_MEDICAL, "Medical emission should target the medical radio channel")
	TEST_ASSERT(!controller.was_last_line_fallback(), "Fallback flag should remain clear when radio succeeds")
	cleanup_controller(controller, human)
	controller = null
	human = null

	setup = setup_controller(FALSE)
	human = setup["human"]
	controller = setup["controller"]
	TEST_ASSERT(controller.queue_speech("Need backup", "radio", "med", list("fallback_text" = "Fallback local")), "Expected fallback queue to succeed")
	controller.process_speech_queue()
	captured = human.captured_speech
	TEST_ASSERT(islist(captured), "Fallback emission should still record speech")
	mods = captured["mods"]
	TEST_ASSERT(!islist(mods) || !mods[RADIO_EXTENSION], "Fallback emission should not include a radio extension")
	TEST_ASSERT(controller.was_last_line_fallback(), "Fallback flag should be set when channel is missing")
	TEST_ASSERT_EQUAL(captured["message"], "Fallback local", "Fallback emission should use provided fallback text")
	cleanup_controller(controller, human)
	controller = null
	human = null

	setup = setup_controller(TRUE)
	human = setup["human"]
	controller = setup["controller"]
	var/long_text = ""
	for(var/i in 1 to 220)
		long_text += "A"
	TEST_ASSERT(controller.queue_speech(long_text, "ic", "local"), "Expected long local message to queue")
	controller.process_speech_queue()
	captured = human.captured_speech
	TEST_ASSERT(islist(captured), "Long message should record speech")
	TEST_ASSERT(length_char(captured["message"]) <= 160, "Speech output should respect the 160 character cap")
	TEST_ASSERT(controller.was_last_line_fallback(), "Length trimming should mark the fallback flag")
	cleanup_controller(controller, human)
	controller = null
	human = null

/datum/unit_test/ai_crew_speech/proc/setup_controller(equip_med_headset = FALSE)
	var/mob/living/carbon/human/ai_crew_speech_test/human = allocate(/mob/living/carbon/human/ai_crew_speech_test)
	human.name = "AI Crew Speech Subject"
	if(equip_med_headset)
		equip_medical_headset(human)
	var/datum/ai_controller/crew_human/controller = ai_crew_attach_controller(human, "unit test")
	TEST_ASSERT(istype(controller), "Controller attachment failed during setup")
	controller.set_ai_status(AI_STATUS_ON)
	human.captured_speech = null
	return list("human" = human, "controller" = controller)

/datum/unit_test/ai_crew_speech/proc/equip_medical_headset(mob/living/carbon/human/human)
	if(human.ears)
		human.dropItemToGround(human.ears)
	if(human.ears_extra)
		human.dropItemToGround(human.ears_extra)
	var/obj/item/radio/headset/headset_med/headset = new(human)
	var/equipped = human.equip_to_slot_or_del(headset, ITEM_SLOT_EARS_LEFT, TRUE)
	TEST_ASSERT(equipped, "Failed to equip medical headset during setup")
	TEST_ASSERT(human.ears == headset, "Medical headset not present in primary ear slot")
	headset.set_broadcasting(TRUE)
	headset.set_listening(TRUE)
	headset.recalculateChannels()
	TEST_ASSERT(islist(headset.channels), "Headset channels list missing after equip")
	TEST_ASSERT(!isnull(headset.channels[RADIO_CHANNEL_MEDICAL]), "Headset missing medical channel")

/datum/unit_test/ai_crew_speech/proc/cleanup_controller(datum/ai_controller/crew_human/controller, mob/living/carbon/human/human)
	if(human)
		ai_crew_detach_controller(human, "unit test cleanup")
		QDEL_NULL(human)

/datum/unit_test/ai_crew_speech/Destroy()
	CONFIG_SET(flag/ai_crew_enabled, original_flag)
	return ..()

#endif
