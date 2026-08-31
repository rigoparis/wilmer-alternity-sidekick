class_name NetTransport
extends RefCounted
##
## How a table talks to each other. Abstract -- no implementation yet.
##
## Reserved now, deliberately, because the shape of the seam is what keeps the
## LAN-versus-internet question open. The intended first implementation is
## EnetTransport over ENetMultiplayerPeer on a local network, which is what a
## group sitting in the same room needs and requires no hosting. A relayed or
## hosted implementation can be added later without game logic changing, as long
## as nothing above this interface assumes direct connectivity.
##
## Two rules this interface exists to enforce:
##
## 1. Identity is a CampaignSession player_id, never a peer id. ENet assigns
##    peer ids randomly per connection, so a player returning next week gets a
##    different one. Implementations map peer -> player_id on connect and expose
##    only the stable id upward; see CampaignSession for why.
##
## 2. Dice results travel as facts, not as instructions. A roll is resolved on
##    the roller device -- by tumbling physics, which is authoritative and never
##    re-simulated anywhere else -- and only the settled RollResult is sent. No
##    implementation should try to replicate a simulation or re-roll on receipt.
##

## A player became reachable. `is_reconnect` is true when the id matched an
## existing seat, which is the normal case for a campaign in progress.
signal player_connected(player_id: String, is_reconnect: bool)
signal player_disconnected(player_id: String)

## A completed roll arrived. `roll` is a serialized RollResult.
signal roll_received(player_id: String, roll: Dictionary)

## A chat message arrived. `to_player_id` is empty for table-wide messages and
## set for a private line with the GM.
signal chat_received(player_id: String, text: String, to_player_id: String)

## Transport-level failure worth surfacing (host unreachable, port in use).
signal transport_error(message: String)


enum Role {
	## Owns the campaign document and is authoritative over session state.
	GM,
	## Connects to a GM and contributes rolls and chat.
	PLAYER,
}


## Start hosting. Returns OK or a failing Error.
##
## Implementations must check the underlying create_server() result rather than
## assuming success: a port already in use returns ERR_CANT_CREATE and otherwise
## looks exactly like a silent hang.
func host(_session: CampaignSession, _port: int) -> Error:
	return _not_implemented("host")


## Join a hosted session, identifying as a known player where possible.
##
## `player_id` should be the id this device was given previously, so the GM can
## match it to an existing seat. Pass "" only for a genuinely new player.
func join(_address: String, _port: int, _player_id: String) -> Error:
	return _not_implemented("join")


func leave() -> void:
	pass


func is_connected_to_table() -> bool:
	return false


func local_role() -> Role:
	return Role.PLAYER


## Send a settled roll to the table.
func send_roll(_roll: Dictionary) -> void:
	_not_implemented("send_roll")


## Send a chat message. Empty `to_player_id` means the whole table.
func send_chat(_text: String, _to_player_id: String = "") -> void:
	_not_implemented("send_chat")


func _not_implemented(what: String) -> Error:
	push_error("NetTransport.%s is abstract -- no transport implementation yet" % what)
	return ERR_UNAVAILABLE
