# `genre`

> Curated genre vocabulary plus recording-admin self-classification for Miso.

**Attaches to:** `miso::recording::Recording`. A recording's genre selection is stored as a single `GenreAssignment` dynamic field (keyed by `GenreAssignmentKey()`) on the recording's `&mut UID`, obtained through `Recording::uid_mut`, gated by the matching `RecordingAdminCap`. The `Genre` vocabulary objects are separate, registry-derived, frozen objects referenced by id.

Genre is a classification rather than protocol-verifiable state, so it lives in an extension instead of the core `Recording`. The package has two halves. The **vocabulary** is a set of `Genre` objects created only by a `GenreRegistryCap` holder and derived from the shared `GenreRegistry` by canonical name (`GenreKey(name)`), so each name maps to one deterministic object id and re-creating a name aborts (automatic dedup). Names must be non-empty, at most 64 bytes, and consist only of `A`-`Z` and `_` (e.g. `HIP_HOP`); each `Genre` is frozen on creation. **Self-classification** lets a recording's admin pick one primary genre and up to 5 secondary genres (which must differ from the primary and from each other). Changing an already-set primary requires at least `MIN_PRIMARY_GENRE_EPOCHS` (30 epochs, ~30 days) since it was last set; the first set is free. Genre selections reference `Genre` ids by value and do not hold the objects.

## Entry points

- **`genre::new`** — cap-gated (`GenreRegistryCap`). Validates the name, claims a derived `Genre` from the registry by `GenreKey(name)`, freezes it, and emits `GenreCreatedEvent`. Aborts if the name is already in the vocabulary.
- **`genre::set_primary_genre`** — gated by `RecordingAdminCap`. Sets or replaces the recording's primary genre, recording the current epoch. First set creates the `GenreAssignment` dynamic field; replacing an existing primary aborts unless at least 30 epochs have elapsed since the last set (`EPrimaryGenreLocked`). Emits `PrimaryGenreSetEvent`.
- **`genre::add_secondary_genre`** — gated by `RecordingAdminCap`. Appends a secondary genre. Requires a primary to exist; rejects a secondary equal to the primary, duplicates, and counts at/above `MAX_SECONDARY_GENRES` (5). Emits `SecondaryGenreAddedEvent`.
- **`genre::remove_secondary_genre`** — gated by `RecordingAdminCap`. Removes a secondary genre; aborts if it is not present. Emits `SecondaryGenreRemovedEvent`.

## Views

- **`derive_genre_id`** — given the registry and a name, returns the object id a `Genre` with that name would have, without creating it (offline resolution).
- **`id`** — a `Genre`'s object id.
- **`name`** — a `Genre`'s canonical name (`&String`).
- **`has_genre`** — whether a recording has a genre assignment.
- **`primary_genre`** — the recording's primary genre id as `Option<ID>`.
- **`secondary_genres`** — the recording's secondary genre ids as `vector<ID>` (empty if none).

## Dependencies

- **`miso`** — provides `Recording` and `RecordingAdminCap`; the assignment attaches via the recording's `&mut UID`.

## Build & test

```sh
sui move build
sui move test
```
