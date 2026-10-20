class_name NpcCharacterStore
extends CharacterStore
## Adapts the existing sheet editor to campaign-owned NPC documents.

var session: CampaignSession
var campaigns: CampaignStore
var npc_id: String

func _init(rules, campaign: CampaignSession, storage: CampaignStore, id: String) -> void:
	super(rules)
	session = campaign
	campaigns = storage
	npc_id = id

func save(doc: CharacterDoc) -> Dictionary:
	session.npcs[npc_id] = doc.to_dict()
	var ok := bool(campaigns.save(session).get("ok", false))
	if ok:
		doc.mark_saved()
	return {"ok": ok, "file_name": "campaign NPC: " + doc.get_hero_name()}
