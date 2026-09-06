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
@warning_ignore("unused_signal")
signal player_connected(player_id: String, is_reconnect: bool)
@warning_ignore("unused_signal")
signal player_disconnected(player_id: String)

## A completed roll arrived. `roll` is a serialized RollResult.
@warning_ignore("unused_signal")
signal roll_received(player_id: String, roll: Dictionary)

## A log event arrived, already carrying its host-assigned sequence number.
##
## The general form of the two signals below, and the one a client applies to
## its own copy of the campaign. Rolls and chat also raise their specific signal,
## because most listeners care about one kind; anything that has to keep a log in
## step -- AP awards included -- listens here instead.
@warning_ignore("unused_signal")
signal event_received(event: Dictionary)

## Everything the host had that this peer did not, sent in one piece after a
## reconnect. Ordered oldest first.
@warning_ignore("unused_signal")
signal events_replayed(events: Array)

## A chat message arrived. `to_player_id` is empty for table-wide messages and
## set for a private line with the GM.
@warning_ignore("unused_signal")
signal chat_received(player_id: String, text: String, to_player_id: String)

## A buff or beneficial skill arrived.
@warning_ignore("unused_signal")
signal buff_received(buff: Dictionary)

## The fight changed: a round started, a check landed, a phase closed.
##
## Client side. The whole round arrives each time rather than a diff -- it is a
## small dictionary that changes a few times a round, and sending it whole means
## a player joining mid-fight needs no catch-up path at all.
@warning_ignore("unused_signal")
signal round_updated(round_data: Dictionary)

## A player rolled their action check for the round.
##
## Host side. Carries the degree, the character's own action check score and what
## the dice showed, because the score is what orders a phase and the roll is what
## a player wants to see in the log.
@warning_ignore("unused_signal")
signal action_check_received(player_id: String, result: Dictionary)

## A player declared a dodge for this round.
##
## Host side. Carries the degree it was rolled at, which is what the step penalty
## on every attack against them is worked out from -- see combat.dodge_step.
@warning_ignore("unused_signal")
signal defence_declared(player_id: String, defence: Dictionary)

## An attack landed on this device's character.
##
## Client side. Already rolled: the GM is the attacker and has decided both
## whether it hit and for how much. What is left is what this character's own
## armor and durability make of it.
@warning_ignore("unused_signal")
signal attack_received(attack: Dictionary)

## The target said what the attack did to them.
##
## Host side. Carries what got through, what the armor stopped, and whether they
## went down -- everything the GM needs without being handed the character.
@warning_ignore("unused_signal")
signal attack_resolved(player_id: String, attack: Dictionary)

## A player wants to attempt a skill and is waiting on a step ruling.
##
## Host side only. The check carries what is being attempted and the score to
## roll against; what it is missing is the GM's half of the step total.
@warning_ignore("unused_signal")
signal check_requested(player_id: String, check: Dictionary)

## The GM answered a request, or called for a check unprompted.
##
## Client side only. Both arrive here because they end in the same place -- a
## check with a known total step, ready for the tray -- and a screen that had to
## tell them apart would duplicate the roll path.
@warning_ignore("unused_signal")
signal check_ruled(check: Dictionary)

## A player pushed their character's current numbers.
##
## A snapshot, taken when the character changes -- not a live view. The player's
## device owns the character file and is its only writer; what crosses the wire
## is a read-only summary for the GM to look at, so the two devices can never be
## editing the same document.
@warning_ignore("unused_signal")
signal character_received(player_id: String, snapshot: Dictionary)

## Transport-level failure worth surfacing (host unreachable, port in use).
@warning_ignore("unused_signal")
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
func host(_session: CampaignSession, _port: int = 0) -> Error:
	return _not_implemented("host")


## Join a hosted session, identifying as a known player where possible.
##
## `player_id` should be the id this device was given previously, so the GM can
## match it to an existing seat. Pass "" only for a genuinely new player.
##
## `since_seq` is how far this device's copy of the log already got, so the host
## replays what was missed rather than a year of history. Zero asks for whatever
## tail the host still holds.
func join(
	_address: String,
	_port: int = 0,
	_player_id: String = "",
	_player_name: String = "",
	_since_seq: int = 0
) -> Error:
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
