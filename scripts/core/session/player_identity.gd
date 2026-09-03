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

const FORMAT_VERSION := 1
const FILE_NAME := "player_identity.json"

## Directory this reads and writes, always with a trailing slash. Injectable for
## the same reason CharacterStore's is: tests must not overwrite the real file.
var _dir: String = "user://"

var _player_name: String = ""

## campaign_id -> {player_id, last_seq, campaign_name, joined_at}.
var _campaigns: Dictionary = {}


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


func _save() -> void:
	var file := FileAccess.open(_path(), FileAccess.WRITE)
	if file == null:
		push_error("PlayerIdentity: cannot write %s (error %d)" % [_path(), FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify({
		"format_version": FORMAT_VERSION,
		"player_name": _player_name,
		"campaigns": _campaigns,
	}, "\t"))
	file.close()
