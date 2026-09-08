# Multiplayer

The goal, from the original roadmap: **a GM view that players connect to over
the local network, with dice rolls and events broadcast to the GM, plus private
player↔GM chat, in campaigns that run for months and survive reconnection.**

All three phases are built. What follows is what exists, the decisions that were
made along the way, and the things that still cannot be verified from a
development machine.

---

## What exists

### The documents

- **`core/session/campaign_session.gd`** — the campaign. Seats with a stable
  `player_id`, character binding, GM designation, an append-only event log
  (`roll`, `chat`, `note`, `join`, `ap_award`, `ap_set`), AP award reasons and
  optional-rule storage. Sequence numbers are tracked explicitly rather than
  derived from `events.size()`; see "Sequence numbers" below.
- **`core/session/campaign_store.gd`** — save/load/list/rename/delete under
  `user://campaigns/`. Each campaign is a small header (`<id>.json`) plus an
  append-only log sidecar (`<id>.events.jsonl`), so a roll appends one line
  rather than rewriting a year of history. `compact()` trims the sidecar.
- **`core/session/player_identity.gd`** — what a *player's* device remembers:
  their name, and per campaign the `player_id` the GM issued plus how far their
  copy of the log got. Separate from the campaign because it describes the
  person, not the table.
- **`core/session/character_snapshot.gd`** — the read-only view of a hero a
  player's device sends the GM.

### The wire

- **`core/session/net_transport.gd`** — the interface. Signals for connection,
  rolls, chat, individual events and reconnect replay.
- **`core/session/enet_transport.gd`** — ENet over a LAN. The GM hosts; players
  join by discovery or by address. Built on `ENetMultiplayerPeer`'s packet
  interface rather than `MultiplayerAPI` and `@rpc` — there is no scene to
  replicate, and a scoped `MultiplayerAPI` per peer would need two node subtrees
  to talk to each other in one `SceneTree`, which is what makes the two-peer
  test possible at all. The host identifies its campaign before the player
  presents a saved identity, so a typed-address reconnect finds the existing
  seat instead of creating a duplicate.
- **`core/session/lan_discovery.gd`** — UDP broadcast question, unicast answer,
  so nobody types an IP. Deliberately separate: it fails for boring reasons
  (guest-network client isolation, an unanswered firewall prompt, a phone on
  mobile data) and none of those should stop a GM reading out an address.

### Action checks and the tray

- **`core/session/skill_check.gd`** — one check on its way from "I want to try
  this" to a settled result. The character's own step modifiers and the GM's
  difficulty are kept apart the whole way, so the log can say which of them made
  it hard.
- **`core/dice/die_shape.gd`** — generated dice geometry, and the orientation to
  number mapping. The d4 is read by its apex through the same rule as every
  other die.
- **`core/dice/dice_tray.gd`** — the physics. A cocked die voids the throw; a
  hard timeout forces a result.
- **`core/dice/physical_dice_source.gd`** — a `RandomSource`, so the same call
  site serves the tray and the seeded `RngSource`.
- **`ui/check_runner.gd`** — joins them. A check crosses a screen, a network
  round trip and a simulation; none of those three knows about the other two.

Three paths, one ending: at a table the GM sets the step; a GM-called check
arrives with it already set; with no table the player sets it themselves.

### The screens

- **Campaign select** — create, open, rename, delete, and "Join a Table".
- **GM screen** — the seat list with each seat's hero and key numbers, AP awards
  with reasons, a live event feed, table hosting, and GM chat with a recipient
  picker.
- **Table join** — search for tables, or type the GM's address. Both, always.
- **Player table** — the feed, a chat box with a private toggle, and banked AP
  the player applies to their own hero.

---

## Decisions, and why

### Identity is a `player_id`, never a peer id

ENet assigns peer ids randomly per connection, so a player returning next week
gets a different one. The transport maps peer → `player_id` on handshake and
exposes only the stable id upward. Reconnect is "match a returning peer to an
existing seat", not "add a player". `PlayerIdentity` is what makes that survive
a restart on the player's device. A reconnect welcome also includes the current
combat round before the table is considered connected, so pending initiative and
fight membership are restored as one state rather than a later best-effort
broadcast.

### Mobile suspension and reconnect

ENet allows three minutes without acknowledged traffic before abandoning a peer,
which covers ordinary app switching better than its shorter default. If the
socket is gone when the player returns, `TableSession` reopens it with exponential
backoff while keeping the same table screen and stable identity. Only a genuine
socket loss retries; a protocol mismatch or a refusal remains visible instead of
looping forever. Android Back is handled by the shell and asks “Leave the table?”
before disconnecting; it does not implicitly close the app or expose character
selection underneath the live table.

The player identity file also holds the last joined endpoint and local character
binding. If Android kills the process, the next launch rebuilds the table session,
reopens that hero and reconnects automatically. The host campaign id is checked
before the client says hello, so an address later reused by a different campaign
cannot silently create a seat there.

### Pending checks and attacks are state

Unanswered player check requests, ruled checks waiting for a player, and attacks
waiting for their target are stored in the campaign header rather than only on a
screen. The reconnect welcome includes only the pending work addressed to that
stable player id. A roll, refusal, or attack result removes the corresponding
item, and duplicate packets are idempotent.

Attack application also has a small player-owned journal. If damage was saved but
the result packet was lost, the returning device reuses the stored outcome and
resends it; it never applies the same attack to the character twice. The journal
is pruned after a later welcome confirms that the GM no longer considers the
attack pending.

### Dice are client-authoritative, and results travel as facts

A roll is resolved on the roller's device and only the settled `RollResult` is
sent. Nothing re-simulates or re-rolls on receipt. Physical dice at a real table
work the same way; there is no anti-cheat here and there should not be.

### One owner per document

The GM's device owns the campaign and assigns **every** sequence number, so one
history exists. The player's device owns the character file and is its only
writer: an AP award is an event the player applies to their own hero, and the GM
never writes to a character they cannot see.

### Character sync: snapshot on change (M3 item 11)

Chosen over live sync, and not for bandwidth. A live view would mean the GM's
screen holds a second copy of a document the player is editing, and every
`CharacterDoc` signal becomes a network event. A snapshot is a fact about the
past, which nobody can be confused about who owns.

A snapshot carries what a GM asks for out loud — name, durability, action check,
last resorts, damage marked — and deliberately excludes anything a GM would want
to *edit* (skills, equipment, perks). Sending those would invite a second writer.
The GM screen shows a bound local character first, a pushed snapshot second, and
labels the snapshot with how old it is.

### Sequence numbers

`append_event` uses a tracked high-water mark, never `events.size() + 1`. The log
can be compacted or loaded as a tail, and deriving the next number from the array
length would reissue numbers already spent — which would make reconnect replay
("everything after seq N") silently resend or skip. The campaign header stores
the mark too, so a campaign whose log is lost still continues the sequence rather
than restarting it.

### Private lines are addressed to a sentinel

A player device is never told the seat list, so it cannot name the GM's
`player_id`. It addresses `EnetTransport.TO_GM` and the host resolves that to the
real seat before logging, so a GM handover later does not leave a trail of
messages addressed to a sentinel.

Reconnect replay applies the same visibility rule as live delivery: public
events are replayed to everyone, while a private message is replayed only to its
author and recipient. Rejoining cannot reveal another player's private GM chat.

### Opening a table seats a GM

A campaign created from the campaign list has no seats. A table with no GM seat
has nowhere to deliver a private line — it would be broadcast to everyone — so
hosting seats a "Game Master" if the campaign has not already said who that is.

### Input map (M3 item 10)

`project.godot` has an `[input]` section: `dice_roll`, `dice_nudge`, and
`table_chat` (T), which focuses the message box on both the GM and player
screens. Shortcuts go through the Input Map rather than raw keycodes so they stay
rebindable.

---

## Tests

| Suite | Checks | Covers |
|---|---|---|
| `smoke_campaign_session` | 109 | the document, reconnect flow, replay, and durable pending work |
| `smoke_campaign_store` | 76 | the sidecar log, compaction, a lost log, rename |
| `smoke_gm_screen` | 133 | M1's checkpoint, driven through the real shell, and who the GM can attack |
| `smoke_enet_transport` | 118 | two peers over the loopback, typed-address identity recovery, a moved table refused, private replay, the check round trip |
| `smoke_lan_discovery` | 26 | a busy port, foreign traffic, a departed host |
| `smoke_table_session` | 166 | two whole shells, automatic and cold-start reconnect, pending-work recovery, exactly-once damage, and Android Back confirmation |
| `smoke_character_sync` | 47 | the snapshot policy and the conflict rule |
| `smoke_skill_check` | 77 | the check document, both directions, the step total |
| `smoke_die_shape` | 738 | every die read at every one of its numbers |
| `smoke_dice_tray` | 68 | real physics: dice settle, in range, always answer |
| `smoke_check_flow` | 52 | a check end to end through two shells and real dice |

Every one of these was checked by breaking the thing it claims to test and
confirming it fails.

---

## Still open

These are the things a development machine cannot settle.

1. **Two real devices on one Wi-Fi.** The suites use the loopback, which proves
   the protocol and not the network. Specifically untested: UDP broadcast
   discovery (a packet to `255.255.255.255` does not come back to another socket
   on the same host under Windows, so the suite asks `127.0.0.1` instead), and
   anything a router does to peer-to-peer traffic.

2. **A release APK on real phones.** The release export itself is settled: a
   signed release APK builds, and its manifest declares `INTERNET` and
   `ACCESS_NETWORK_STATE` rather than inheriting INTERNET implicitly the way a
   debug export does. What is still unproven is joining a table from that APK on
   a real phone, backgrounding it past the three-minute timeout, and letting the
   OS kill it to exercise cold-start recovery. Release signing also still uses
   the debug keystore, which has to be replaced before public distribution.

3. **Whether the host must be a desktop.** A briefly suspended phone now has a
   longer timeout and players automatically reconnect after a dropped socket.
   Android may still kill a backgrounded GM process entirely; there is no host
   migration or service keeping that table alive. The decision is about what to
   tell the group and what real devices do under their battery policies.

4. **When to compact.** `CampaignStore.compact()` exists and is tested, but
   nothing calls it automatically. A weekly campaign will not trouble the
   `DEFAULT_EVENT_TAIL` of 5000 for a long time, so this is a decision to make
   before it matters rather than a bug.

5. **Two paths to the same roll.** A GM-called check is shown in both places a
   player might be looking: the character sheet banner and the player table
   view, which lists each called check with its own Roll and Dismiss buttons.
   Both read `TableSession.incoming_checks`, so a check restored by a reconnect
   appears wherever the player happens to be. What remains unsettled is that
   `CheckRunner.check_arrived` still has no listener — the table view is driven
   by `TableSession.check_arrived` instead — so that signal is currently dead
   weight and should either be used or removed.
