# Multiplayer plan

The goal, from the original roadmap: **a GM view that players connect to over
the local network, with dice rolls and events broadcast to the GM, plus private
player↔GM chat, in campaigns that run for months and survive reconnection.**

## What already exists

Do not rebuild these.

- **`scripts/core/session/campaign_session.gd`** — the campaign document. Seats
  with a stable `player_id`, character binding, GM designation, an append-only
  event log (`roll`, `chat`, `note`, `join`, `ap_award`, `ap_set`), AP award
  reasons, optional-rule storage, and `FORMAT_VERSION`. Covered by
  `smoke_campaign_session` (66 checks). **It is wired to nothing** — no store,
  no UI, no transport.
- **`scripts/core/session/net_transport.gd`** — abstract. Signals only:
  `player_connected(player_id, is_reconnect)`, `player_disconnected`,
  `roll_received(player_id, roll)`, chat with an optional `to_player_id` for
  private lines. No implementation.
- **`scripts/core/dice/`** — `RandomSource`, seeded `RngSource`, `RollResult`
  (serialisable, carries `player_id` and a `source` field). `smoke_dice`, 163
  checks.
- **`UiRouter` + `AppShell`** — screen routing exists, so a GM view is a
  destination rather than a rewrite.
- **`CharacterStore`** — load/save/list against `user://`, no UI coupling.
- **Android `permissions/internet`** is already set in `export_presets.cfg`.

## Two decisions that are already made — do not relitigate

1. **Identity is the CampaignSession `player_id`, never an ENet peer id.** Peer
   ids are random per connection; a player returning next week gets a new one.
   Transports map peer → player_id on connect and expose only the stable id.
   Reconnect is "match returning peer to existing seat", not "add a player".
2. **Dice are client-authoritative and results travel as facts.** A roll is
   resolved on the roller's device and only the settled `RollResult` is sent.
   Nothing re-simulates or re-rolls on receipt. Physical dice at a real table
   work the same way; do not build anti-cheat around this.

---

## Phase M1 — Campaign persistence and a local GM view (no networking)

The whole feature is usable single-device first, which also makes every later
phase testable without two machines.

1. **`core/session/campaign_store.gd`** — mirror `CharacterStore`. Save/load/
   list campaigns under `user://campaigns/`, honouring `FORMAT_VERSION`. The
   event log is append-only, so write it as a sidecar (`<id>.events.jsonl`)
   rather than rewriting one growing JSON blob on every roll.
2. **Campaign select screen**, alongside character select: create, open, delete,
   rename. Reuse the existing router.
3. **GM screen** as a top-level destination: the seat list, each seat's bound
   character and key numbers (durability, action check, last resorts), and a
   live event feed.
4. **AP awards from the GM screen**, writing `ap_award` / `ap_set` events. The
   award reasons are already constants.

**Checkpoint:** a GM can run a session on one device, award AP, and reopen the
campaign a week later with the log intact.

## Phase M2 — ENet transport on a LAN

5. **`core/session/enet_transport.gd`** implementing `NetTransport` over
   `ENetMultiplayerPeer`. The GM device hosts; players join by IP.
6. **Peer → player_id handshake.** On connect the client sends its `player_id`;
   the host matches it to a seat and answers `is_reconnect`. An unknown id
   creates a new seat only if the GM allows it.
7. **Discovery**, so nobody types an IP: UDP broadcast on the LAN, host
   answering with campaign name and port. Fall back to manual IP entry.
8. **Broadcast rolls and chat.** One reliable RPC per event. Private lines set
   `to_player_id` and are delivered only to that seat and the GM.
9. **Reconnect and buffering.** A client that drops keeps its local state; on
   rejoin the host replays events since the client's last known sequence number.
   This is why the log is append-only with a sequence.

**Checkpoint:** two devices on one Wi-Fi, a roll on the player device appearing
on the GM's feed, and a mid-session reconnect that loses nothing.

## Phase M3 — The seams that get expensive later

10. **Input map.** `project.godot` still has no `[input]` section at all. Any
    keyboard shortcut or dice gesture needs one created from scratch.
11. **Character sync policy.** Decide explicitly whether the GM sees a live
    character or a snapshot pushed on change. Snapshot-on-change is simpler and
    enough; live sync means every `CharacterDoc` signal becomes a network event.
12. **Conflict rule.** The player's device owns their character; the GM's
    changes (AP awards) are events the player's device applies. One owner per
    document, always.

---

## Risks worth naming up front

- **The event log grows without bound** across a year-long campaign. Decide
  early whether to compact it, and never make correctness depend on replaying
  the whole log — seats carry current state.
- **Android's INTERNET permission is set, but debug exports get it implicitly.**
  Test networking from a **release** APK at least once, or a permission problem
  will only appear on the friends' devices.
- **Hosting on the GM's phone** means the session dies if that app is
  backgrounded. Decide whether the host must be a desktop.
- **`smoke_campaign_session` covers the model, not the wire.** Add a transport
  test with two in-process peers before trusting reconnect.

## Suggested first session

Phase M1 items 1 and 2 only — `campaign_store.gd` plus the campaign select
screen. That is self-contained, needs no second device, and makes everything
after it demonstrable.
