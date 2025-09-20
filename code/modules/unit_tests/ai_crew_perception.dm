#ifdef CREW_AI_FOUNDATION

/datum/unit_test/ai_crew_perception
	var/original_flag
	var/mob/living/carbon/human/listener
	var/datum/ai_controller/crew_human/test_controller

/datum/unit_test/ai_crew_perception/Run()
	original_flag = CONFIG_GET(flag/ai_crew_enabled)
	CONFIG_SET(flag/ai_crew_enabled, TRUE)

	listener = allocate(/mob/living/carbon/human/consistent)
	listener.name = "LISTENER"
	var/datum/client_interface/mock_client = new()
	listener.mock_client = mock_client
	mock_client.mob = listener

	test_controller = ai_crew_attach_controller(listener, "unit test")
	TEST_ASSERT(istype(test_controller), "Expected controller attachment to succeed")
	test_controller.set_ai_status(AI_STATUS_ON)

	var/mob/living/carbon/human/speaker = allocate(/mob/living/carbon/human/consistent)
	speaker.name = "SPEAKER"

	listener.Hear("Hello there", speaker, /datum/language/common, "Hello there", null, null, null, list(), list(), MESSAGE_RANGE)

	var/list/heard = test_controller.get_last_heard()
	TEST_ASSERT_EQUAL(length(heard), 1, "Expected a single perception entry")
	var/list/local_entry = heard[1]
	TEST_ASSERT_EQUAL(local_entry["kind"], "local", "Incorrect perception kind for local speech")
	TEST_ASSERT_EQUAL(local_entry["text"], "Hello there", "Unexpected stored text for local speech")
	TEST_ASSERT_EQUAL(local_entry["speaker_name"], speaker.name, "Speaker name missing on local entry")
	TEST_ASSERT(local_entry["timestamp"], "Perception entry should include a timestamp")

	listener.Hear("Common ping", speaker, /datum/language/common, "Common ping", FREQ_COMMON, "Common", null, list(), list(), MESSAGE_RANGE)

	heard = test_controller.get_last_heard()
	TEST_ASSERT_EQUAL(length(heard), 2, "Expected two perception entries after radio line")
	var/list/radio_entry = heard[2]
	TEST_ASSERT_EQUAL(radio_entry["kind"], "radio", "Radio line should be tagged as radio")
	TEST_ASSERT_EQUAL(radio_entry["radio_frequency"], FREQ_COMMON, "Stored radio frequency mismatch")
	TEST_ASSERT_EQUAL(radio_entry["radio_name"], "Common", "Stored radio channel name mismatch")

	test_controller.clear_last_heard()

	var/total_lines = BB_CREW_LAST_HEARD_MAX_ENTRIES + 3
	for(var/i in 1 to total_lines)
		listener.Hear("Line [i]", speaker, /datum/language/common, "Line [i]", null, null, null, list(), list(), MESSAGE_RANGE)

	heard = test_controller.get_last_heard()
	TEST_ASSERT_EQUAL(length(heard), BB_CREW_LAST_HEARD_MAX_ENTRIES, "Ring buffer should trim to the configured maximum")
	var/list/oldest_entry = heard[1]
	TEST_ASSERT_EQUAL(oldest_entry["text"], "Line 4", "Oldest buffer entry should be the fourth generated line after trimming")
	var/list/newest_entry = heard[heard.len]
	TEST_ASSERT_EQUAL(newest_entry["text"], "Line [total_lines]", "Newest buffer entry should be the most recent line")

	ai_crew_detach_controller(listener, "unit test cleanup")
	test_controller = null
	listener = null

/datum/unit_test/ai_crew_perception/Destroy()
	if(listener)
		ai_crew_detach_controller(listener, "unit test cleanup")
	CONFIG_SET(flag/ai_crew_enabled, original_flag)
	return ..()

#endif
