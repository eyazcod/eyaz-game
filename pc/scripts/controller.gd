extends RefCounted

const CLASSIC = {"jump":JOY_BUTTON_A,"dash":JOY_BUTTON_B,"bomb":JOY_BUTTON_X,"pulse":JOY_BUTTON_Y,"shield":JOY_BUTTON_LEFT_SHOULDER,"heal":JOY_BUTTON_RIGHT_SHOULDER,"pause":JOY_BUTTON_START,"parry":JOY_BUTTON_LEFT_STICK,"left":JOY_BUTTON_DPAD_LEFT,"right":JOY_BUTTON_DPAD_RIGHT,"interact":JOY_BUTTON_DPAD_UP}
const COMBAT = {"jump":JOY_BUTTON_A,"dash":JOY_BUTTON_B,"melee":JOY_BUTTON_X,"pulse":JOY_BUTTON_Y,"shield":JOY_BUTTON_LEFT_SHOULDER,"bomb":JOY_BUTTON_RIGHT_SHOULDER,"heal":JOY_BUTTON_DPAD_DOWN,"pause":JOY_BUTTON_START,"left":JOY_BUTTON_DPAD_LEFT,"right":JOY_BUTTON_DPAD_RIGHT,"interact":JOY_BUTTON_DPAD_UP}

static func configure(settings):
	var map = COMBAT if settings.pad_combat else CLASSIC
	for action in ["left","right","jump","dash","bomb","pulse","shield","heal","pause","parry","interact","fire","melee"]:
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				InputMap.action_erase_event(action,event)
		InputMap.action_set_deadzone(action,settings.pad_deadzone if action in ["left","right"] else settings.pad_trigger)
	for action in map:
		var event = InputEventJoypadButton.new()
		event.device = -1
		event.button_index = map[action]
		InputMap.action_add_event(action,event)
	var triggers = [["left",JOY_AXIS_LEFT_X,-1.0],["right",JOY_AXIS_LEFT_X,1.0],["fire",JOY_AXIS_TRIGGER_RIGHT,1.0],["parry" if settings.pad_combat else "melee",JOY_AXIS_TRIGGER_LEFT,1.0]]
	for binding in triggers:
		var event=InputEventJoypadMotion.new()
		event.device = -1
		event.axis=binding[1]; event.axis_value=binding[2]
		InputMap.action_add_event(binding[0],event)
	for binding in [["ui_left",JOY_BUTTON_DPAD_LEFT],["ui_right",JOY_BUTTON_DPAD_RIGHT],["ui_up",JOY_BUTTON_DPAD_UP],["ui_down",JOY_BUTTON_DPAD_DOWN],["ui_accept",JOY_BUTTON_A],["ui_cancel",JOY_BUTTON_B]]:
		for old_event in InputMap.action_get_events(binding[0]):
			if old_event is InputEventJoypadButton or old_event is InputEventJoypadMotion:
				InputMap.action_erase_event(binding[0],old_event)
		var event=InputEventJoypadButton.new()
		event.device=-1; event.button_index=binding[1]
		InputMap.action_add_event(binding[0],event)
	for binding in [["ui_left",JOY_AXIS_LEFT_X,-1.0],["ui_right",JOY_AXIS_LEFT_X,1.0],["ui_up",JOY_AXIS_LEFT_Y,-1.0],["ui_down",JOY_AXIS_LEFT_Y,1.0]]:
		InputMap.action_set_deadzone(binding[0],maxf(0.4,float(settings.pad_deadzone)))
		var event=InputEventJoypadMotion.new()
		event.device=-1; event.axis=binding[1]; event.axis_value=binding[2]
		InputMap.action_add_event(binding[0],event)

static func movement(sensitivity):
	var value=Input.get_axis("left","right")
	return signf(value)*pow(absf(value),1.0/float(sensitivity))

static func guide(combat):
	if combat:
		return "A / ✕ قفز · B / ○ اندفاع · X / □ ضربة · Y / △ موجة\nRT / R2 إطلاق · LT / L2 صدّ · LB / L1 درع · RB / R1 قنبلة\n↓ علاج · بوابة تلقائية · Start توقف · A تأكيد وB رجوع في القوائم"
	return "A / ✕ قفز · B / ○ اندفاع · X / □ قنبلة · Y / △ موجة\nRT / R2 إطلاق · LT / L2 ضربة · LB / L1 درع · RB / R1 علاج\nL3 صدّ · بوابة تلقائية · Start توقف · A تأكيد وB رجوع في القوائم"

