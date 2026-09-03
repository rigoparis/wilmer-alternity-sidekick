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
  test possible at all.
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
a restart on the player's device.

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
| `smoke_campaign_session` | 82 | the document, reconnect flow, the replay window |
| `smoke_campaign_store` | 76 | the sidecar log, compaction, a lost log, rename |
| `smoke_gm_screen` | 87 | M1's checkpoint, driven through the real shell |
| `smoke_enet_transport` | 96 | two peers over the loopback, handshake, reconnect, the check round trip |
| `smoke_lan_discovery` | 26 | a busy port, foreign traffic, a departed host |
| `smoke_table_session` | 68 | M2's checkpoint: two whole shells against each other |
| `smoke_character_sync` | 43 | the snapshot policy and the conflict rule |
| `smoke_skill_check` | 77 | the check document, both directions, the step total |
| `smoke_die_shape` | 738 | every die read at every one of its numbers |
| `smoke_dice_tray` | 64 | real physics: dice settle, in range, always answer |
| `smoke_check_flow` | 45 | a check end to end through two shells and real dice |

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

2. **A release APK.** `permissions/internet` is set, but debug exports get
   INTERNET implicitly for the remote debugger — so networking will appear to
   work in testing and could fail only on the friends' devices. Export a release
   APK and join a table from it at least once.

3. **Whether the host must be a desktop.** Hosting on the GM's phone means the
   session dies when the app is backgrounded. Nothing in the code assumes either
   way; the decision is about what to tell the group.

4. **When to compact.** `CampaignStore.compact()` exists and is tested, but
   nothing calls it automatically. A weekly campaign will not trouble the
   `DEFAULT_EVENT_TAIL` of 5000 for a long time, so this is a decision to make
   before it matters rather than a bug.

5. **Rolls from the player table view.** Checks are rolled from the character
   sheet, where a skill has already been chosen. The player table view still has
   no roll button of its own, and a GM-called check arriving there is raised as
   a signal but not yet shown to the player — `CheckRunner.check_arrived` has no
   listener on that screen.
