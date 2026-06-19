# `cover_art`

> Evolvable cover-art metadata for Miso recordings and releases, stored off the frozen protocol core.

**Attaches to:** `Recording` and `Release` (Miso core) as dynamic fields on each object's `&mut UID`, reached through the object's cap-gated `uid_mut`. The shared `CoverArt` value type itself is a plain `copy`/`drop`/`store` struct, not an object.

`CoverArt` is a still image plus an optional animation, each a reference to external storage via `ori::WalrusData`. Both references must be Walrus blobs (enforced in `cover_art::new`). The format is deliberately kept in this small extension rather than in immutable core: a new cover format (e.g. additional media) is a republish of this package or a new cover-art standard, not a republish of the frozen protocol.

The recording module attaches one cover per recording. The release module attaches a single `ReleaseCoverArt` record holding a release-level cover plus a sparse per-disc map (`VecMap<u64, CoverArt>`) keyed by disc index; disc indices are validated against the release's actual disc count, and since discs are fixed at release creation a valid index stays valid. All writes are gated by the relevant Miso admin cap (`RecordingAdminCap` / `ReleaseAdminCap`); views are permissionless.

## Entry points

- **`cover_art::new`** — constructs a `CoverArt` from a still blob and optional animated blob; asserts both are Walrus blobs.
- **`recording_cover_art::set`** — cap-gated; sets or replaces the recording's single cover art.
- **`recording_cover_art::unset`** — cap-gated; removes the recording's cover art if present.
- **`release_cover_art::set_cover`** — cap-gated; sets or replaces the release-level cover (lazily initializing the record).
- **`release_cover_art::unset_cover`** — cap-gated; clears the release-level cover if present.
- **`release_cover_art::set_disc_cover_art`** — cap-gated; sets or replaces the cover for a specific disc index, aborting if the index is out of bounds for the release's disc count.
- **`release_cover_art::unset_disc_cover_art`** — cap-gated; removes a specific disc's cover if present.

## Views

- **`cover_art::still`** — borrows the still-image `WalrusData`.
- **`cover_art::animated`** — borrows the optional animated `WalrusData`.
- **`recording_cover_art::has_cover_art`** — whether the recording has cover art attached.
- **`recording_cover_art::cover_art`** — borrows the recording's `CoverArt`; aborts if none.
- **`release_cover_art::has_cover_art`** — whether a `ReleaseCoverArt` record is attached to the release.
- **`release_cover_art::cover`** — borrows the release-level cover `Option<CoverArt>`; aborts if no record is attached.
- **`release_cover_art::has_disc_cover_art`** — whether the given disc has cover art.
- **`release_cover_art::disc_cover_art`** — returns a specific disc's `CoverArt` by value; aborts if none.

## Dependencies

- **`miso`** — core protocol; provides `Recording`/`Release` and their admin caps + `uid_mut`/`uid` accessors.
- **`ori`** — `WalrusData` references to off-chain (Walrus) cover-image storage.

## Build & test

```sh
sui move build
sui move test
```
