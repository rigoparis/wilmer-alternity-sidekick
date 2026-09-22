class_name PlayerIdentity
extends RefCounted
##
## What this device remembers about being a player at other people's tables.
##
## One small file under user://, holding the person's name and, per campaign,
## the player_id the GM issued and how far this device's copy of the log got.
##
## It exists because identity has to outlive the connection. ENet hands out a new
## peer id every time, so without something stored here a player rejoining next
## week is indistinguishable from a stranger: the GM would seat them again, they
## would lose their achievement points and their character binding, and the
## campaign would slowly fill with abandoned duplicate seats.
##
## Deliberately not part of CampaignSession. That document belongs to the GM's
## device and describes the table; this belongs to the player's device and
## describes them. A player who plays in two campaigns has two ids here and one
## name.
##

const FORMAT_VERSION := 3
const FILE_NAME := "player_identity.json"

## Directory this reads and writes, always with a trailing slash. Injectable for
## the same reason CharacterStore's is: tests must not overwrite the real file.
var _dir: String = "user://"

var _player_name: String = ""

## campaign_id -> {player_id, last_seq, campaign_name, joined_at}.
var _campaigns: Dictionary = {}
var _active_table: Dictionary = {}
## campaign_id -> attack_id -> {attack, absorbed, outcome, parried, resolved}.
## This is the player's idempotency record: character damage must never be
## applied twice just because the result packet was lost during reconnect.
var _attack_progress: Dictionary = {}


func _init(directory: String = "user://") -> void:
	_dir = directory if directory.ends_with("/") else directory + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_load()


func _path() -> String:
	return _dir + FILE_NAME


func player_name() -> String:
	return _player_name


func set_player_name(value: String) -> void:
	var trimmed := value.strip_edges()
	if trimmed.is_empty() or trimmed == _player_name:
		return
	_player_name = trimmed
	_save()


## What this device knows about one campaign, or an empty-ish record.
##
## An unknown campaign yields an empty player_id, which is the signal to the
## transport that this is a genuinely new player rather than a returning one.
func for_campaign(campaign_id: String) -> Dictionary:
	var known = _campaigns.get(campaign_id, null)
	if typeof(known) != TYPE_DICTIONARY:
		return {"player_id": "", "last_seq": 0, "campaign_name": ""}
	return known.duplicate(true)


func player_id_for(campaign_id: String) -> String:
	return String(for_campaign(campaign_id).get("player_id", ""))


## The minimum identity material a transport may use after a host tells it
## which campaign is at the other end.
##
## A typed address does not carry a campaign id. Passing these claims into the
## transport lets it wait for the host's table introduction, then present only
## the matching campaign's stable id. The whole identity document never crosses
## the wire.
func reconnect_claims() -> Dictionary:
	var claims := {}
	for campaign_id in _campaigns:
		var known = _campaigns[campaign_id]
		if typeof(known) != TYPE_DICTIONARY:
			continue
		var player_id := String(known.get("player_id", ""))
		if player_id.is_empty():
			continue
		claims[campaign_id] = {
			"player_id": player_id,
			"last_seq": AlternityNum.as_int(known.get("last_seq", 0)),
		}
	return claims


## The last table this device deliberately joined. This is local navigation
## state, not campaign authority: it contains only how to reconnect and which
## local character file to reopen.
func active_table() -> Dictionary:
	return _active_table.duplicate(true)


func remember_active_table(
	address: String,
	port: int,
	campaign_id: String = "",
	campaign_name: String = "",
	character_file: String = ""
) -> void:
	if address.strip_edges().is_empty():
		return
	var previous := _active_table
	_active_table = {
		"address": address.strip_edges(),
		"port": port,
		"campaign_id": campaign_id if not campaign_id.is_empty() else String(previous.get("campaign_id", "")),
		"campaign_name": campaign_name if not campaign_name.is_empty() else String(previous.get("campaign_name", "")),
		"character_file": character_file if not character_file.is_empty() else String(previous.get("character_file", "")),
	}
	_save()


func remember_active_character(character_file: String) -> void:
	if _active_table.is_empty() or character_file.is_empty():
		return
	_active_table["character_file"] = character_file
	_save()


func clear_active_table() -> void:
	if _active_table.is_empty():
		return
	_active_table.clear()
	_save()


func remember_attack_applied(
	campaign_id: String,
	attack: Dictionary,
	absorbed: int,
	outcome: Dictionary,
	parried: bool
) -> void:
	var attack_id := String(attack.get("attack_id", ""))
	if campaign_id.is_empty() or attack_id.is_empty():
		return
	var campaign = _attack_progress.get(campaign_id, {})
	if typeof(campaign) != TYPE_DICTIONARY:
		campaign = {}
	campaign[attack_id] = {
		"attack": attack.duplicate(true),
		"absorbed": absorbed,
		"outcome": outcome.duplicate(true),
		"parried": parried,
		"resolved": {},
	}
	_attack_progress[campaign_id] = campaign
	_save()


func remember_attack_resolved(campaign_id: String, attack: Dictionary) -> void:
	var attack_id := String(attack.get("attack_id", ""))
	if campaign_id.is_empty() or attack_id.is_empty():
		return
	var campaign = _attack_progress.get(campaign_id, {})
	if typeof(campaign) != TYPE_DICTIONARY:
		campaign = {}
	var progress = campaign.get(attack_id, {})
	if typeof(progress) != TYPE_DICTIONARY:
		progress = {}
	progress["resolved"] = attack.duplicate(true)
	campaign[attack_id] = progress
	_attack_progress[campaign_id] = campaign
	_save()


func attack_progress(campaign_id: String, attack_id: String) -> Dictionary:
	var campaign = _attack_progress.get(campaign_id, {})
	if typeof(campaign) != TYPE_DICTIONARY:
		return {}
	var progress = campaign.get(attack_id, {})
	return progress.duplicate(true) if typeof(progress) == TYPE_DICTIONARY else {}


## The GM's welcome lists every attack it still considers outstanding. Anything
## absent was acknowledged and can leave the local idempotency journal.
func reconcile_attacks(campaign_id: String, pending_attack_ids: Array) -> void:
	var campaign = _attack_progress.get(campaign_id, {})
	if typeof(campaign) != TYPE_DICTIONARY:
		return
	var changed := false
	for attack_id in campaign.keys():
		if not pending_attack_ids.has(String(attack_id)):
			campaign.erase(attack_id)
			changed = true
	if campaign.is_empty():
		_attack_progress.erase(campaign_id)
	else:
		_attack_progress[campaign_id] = campaign
	if changed:
		_save()


## Record the id a GM issued for a campaign.
##
## Called on every welcome, including a reconnect, so a GM who reissued an id
## (because the seat was removed and remade) is followed rather than argued with.
## The GM's device owns the campaign; this device owns only its own name.
func remember(campaign_id: String, player_id: String, last_seq: int = 0, campaign_name: String = "") -> void:
	if campaign_id.is_empty() or player_id.is_empty():
		# A join by typed address before the welcome arrives has no campaign_id
		# yet; the welcome will carry it. Nothing to store in the meantime.
		return
	var known := for_campaign(campaign_id)
	_campaigns[campaign_id] = {
		"player_id": player_id,
		# Never lower the mark: a welcome carries no sequence, and overwriting a
		# high-water mark with zero would ask the host to replay the campaign.
		"last_seq": maxi(AlternityNum.as_int(known.get("last_seq", 0)), last_seq),
		"campaign_name": campaign_name if not campaign_name.is_empty() else String(known.get("campaign_name", "")),
		"joined_at": AlternityNum.as_int(known.get("joined_at", 0)) if known.has("joined_at") else int(Time.get_unix_time_from_system()),
	}
	_save()


## Record how far this device's copy of the log has got.
##
## The number handed back to join() next time, which is what limits a reconnect
## replay to the gap instead of the whole campaign.
func note_seq(campaign_id: String, seq: int) -> void:
	var known = _campaigns.get(campaign_id, null)
	if typeof(known) != TYPE_DICTIONARY:
		return
	if seq <= AlternityNum.as_int(known.get("last_seq", 0)):
		return
	known["last_seq"] = seq
	_save()


## Campaigns this device has played in, most recently joined first.
func campaigns() -> Array:
	var out: Array = []
	for campaign_id in _campaigns:
		var entry: Dictionary = _campaigns[campaign_id].duplicate(true)
		entry["campaign_id"] = campaign_id
		out.append(entry)
	out.sort_custom(func(a, b): return AlternityNum.as_int(a.get("joined_at", 0)) > AlternityNum.as_int(b.get("joined_at", 0)))
	return out


func forget(campaign_id: String) -> bool:
	if not _campaigns.has(campaign_id):
		return false
	_campaigns.erase(campaign_id)
	_save()
	return true


# --- Persistence -----------------------------------------------------------

func _load() -> void:
	var file := FileAccess.open(_path(), FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return
	_player_name = String(data.get("player_name", ""))
	var stored = data.get("campaigns", {})
	_campaigns = stored.duplicate(true) if typeof(stored) == TYPE_DICTIONARY else {}
	var active = data.get("active_table", {})
	_active_table = active.duplicate(true) if typeof(active) == TYPE_DICTIONARY else {}
	var attacks = data.get("attack_progress", {})
	_attack_progress = attacks.duplicate(true) if typeof(attacks) == TYPE_DICTIONARY else {}


func _save() -> void:
	var file := FileAccess.open(_path(), FileAccess.WRITE)
	if file == null:
		push_error("PlayerIdentity: cannot write %s (error %d)" % [_path(), FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify({
		"format_version": FORMAT_VERSION,
		"player_name": _player_name,
		"campaigns": _campaigns,
		"active_table": _active_table,
		"attack_progress": _attack_progress,
	}, "\t"))
	file.close()
