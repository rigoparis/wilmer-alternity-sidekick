extends RouteScene
## Reuses the full editor while keeping NPC writes in the owning campaign.

func preferred_presentation() -> int:
	return UiRouter.Presentation.PAGE

func title() -> String:
	return "NPC sheet"

var _props: Dictionary = {}
var _doc: CharacterDoc
var _store: NpcCharacterStore

func configure(props: Dictionary) -> void:
	_props = props

func _ready() -> void:
	var props := _props
	var session: CampaignSession = props.get("session")
	if session == null:
		return
	var id := String(props.get("npc_id", ""))
	var rules: AlternityRules = props.get("rules")
	var doc := CharacterDoc.from_dict(rules, session.npcs.get(id, {}))
	_doc = doc
	var store := NpcCharacterStore.new(rules, session, props.get("store"), id)
	_store = store
	var ctx := SheetContext.new(doc, rules, props.get("router"), props.get("palette"))
	ctx.checks = NpcChecks.new(rules, ctx.router, ctx.palette)
	ctx.checks.session = session
	ctx.checks.campaigns = props.get("store")
	ctx.checks.npc_id = id
	ctx.checks.transport = props.get("transport")
	var sheet = preload("res://scenes/ui/screens/character_sheet.tscn").instantiate()
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sheet)
	sheet.setup(ctx, store)
	sheet.closed.connect(func(): close(null))
	# Route Back also saves; individual changes remain announced by doc.apply().
	doc.changed.connect(_on_doc_changed)

func _on_doc_changed(_sections: PackedStringArray) -> void:
	_store.save(_doc)

class NpcChecks extends CheckRunner:
	var session: CampaignSession
	var campaigns: CampaignStore
	var npc_id: String
	var transport: EnetTransport

	func _broadcast(check: SkillCheck, outcome: Dictionary, doc: CharacterDoc) -> void:
		check.player_id = npc_id
		var payload := outcome.duplicate(true)
		payload["check"] = check.to_dict()
		payload["character_name"] = doc.get_hero_name()
		payload["character_id"] = npc_id
		session.append_roll(npc_id, payload)
		campaigns.save(session)
		if transport != null:
			transport._deliver(session.events.back())
