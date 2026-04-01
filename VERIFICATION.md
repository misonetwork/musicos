# Formal Verification Report

**Protocol**: MusicOS
**Prover**: [unconfirmedlabs/sui-prover](https://github.com/unconfirmedlabs/sui-prover) (Boogie + Z3)
**Result**: 210/210 checks passed
**Specs**: 70 across 9 modules

## How to reproduce

```bash
# Clone and build the prover
git clone https://github.com/unconfirmedlabs/sui-prover.git
cd sui-prover && cargo install --path crates/sui-prover

# Install dependencies
brew install z3 dotnet@8

# Run verification from the musicos root
DOTNET_ROOT=$(brew --prefix dotnet@8)/libexec \
BOOGIE_EXE=$(which boogie) \
Z3_EXE=$(which z3) \
sui-prover -v
```

## Verified properties

### Audio (6 specs)

| Spec | Property |
|------|----------|
| `new_aborts_zero_channels` | Channels must be > 0 |
| `new_aborts_invalid_bit_depth` | Bit depth must be 8, 16, 24, or 32 |
| `new_aborts_zero_sample_rate` | Sample rate must be > 0 |
| `new_aborts_zero_samples` | Sample count must be > 0 |
| `new_aborts_samples_overflow` | Sample count must be <= MAX_SAMPLES |
| `new_preserves_values` | On success, all input values are preserved exactly |

### Composition (14 specs)

| Spec | Property |
|------|----------|
| `add_credit_aborts_when_published` | Published compositions cannot add credits |
| `set_lyrics_aborts_when_published` | Published compositions cannot set lyrics |
| `set_demo_aborts_when_published` | Published compositions cannot set demo |
| `set_chart_aborts_when_published` | Published compositions cannot set chart |
| `set_score_aborts_when_published` | Published compositions cannot set score |
| `set_split_bps_aborts_when_published` | Published compositions cannot change split |
| `add_alternate_title_aborts_when_published` | Published compositions cannot add titles |
| `add_credit_increments_count` | Adding a credit increases count by exactly 1 |
| `add_credit_aborts_duplicate_party` | Same party cannot be credited twice |
| `add_alternate_title_increments_count` | Adding a title increases count by exactly 1 |
| `add_credit_aborts_zero_roles` | Credits must have at least 1 role |
| `add_credit_aborts_too_many_roles` | Credits cannot exceed 5 roles |
| `add_credit_aborts_max_credits` | Cannot exceed 50 credits |
| `add_alternate_title_aborts_at_max` | Cannot exceed 5 alternate titles |

### Recording (32 specs)

| Spec | Property |
|------|----------|
| `add_credit_aborts_when_published` | Published recordings cannot add credits |
| `add_primary_artist_aborts_when_published` | Published recordings cannot add primary artists |
| `add_featured_artist_aborts_when_published` | Published recordings cannot add featured artists |
| `set_lyrics_aborts_when_published` | Published recordings cannot set lyrics |
| `set_title_version_aborts_when_published` | Published recordings cannot set title version |
| `set_subtitle_aborts_when_published` | Published recordings cannot set subtitle |
| `set_language_aborts_when_published` | Published recordings cannot set language |
| `set_primary_genre_aborts_when_published` | Published recordings cannot change primary genre |
| `add_secondary_genre_aborts_when_published` | Published recordings cannot add secondary genres |
| `set_musical_key_aborts_when_published` | Published recordings cannot set musical key |
| `set_tempo_bpm_aborts_when_published` | Published recordings cannot set tempo |
| `add_stem_aborts_when_published` | Published recordings cannot add stems |
| `remove_secondary_genre_aborts_when_published` | Published recordings cannot remove genres |
| `add_credit_increments_count` | Adding a credit increases count by exactly 1 |
| `add_credit_aborts_duplicate` | Same party cannot be credited twice |
| `add_primary_artist_aborts_if_featured` | Primary and featured artist sets are disjoint |
| `add_featured_artist_aborts_if_primary` | Featured and primary artist sets are disjoint |
| `add_primary_artist_requires_credit` | Primary artists must be credited |
| `add_featured_artist_requires_credit` | Featured artists must be credited |
| `set_lyrics_aborts_when_instrumental` | Instrumental recordings cannot have lyrics |
| `add_secondary_genre_aborts_if_primary` | Secondary genre cannot be the primary genre |
| `add_stem_increments_count` | Adding a stem increases count by exactly 1 |
| `add_credit_aborts_zero_roles` | Credits must have at least 1 role |
| `add_credit_aborts_too_many_roles` | Credits cannot exceed 10 roles |
| `add_credit_aborts_max_credits` | Cannot exceed 150 credits |
| `add_stem_aborts_max_stems` | Cannot exceed 100 stems |
| `add_primary_artist_aborts_at_max` | Cannot exceed 20 primary artists |
| `add_featured_artist_aborts_at_max` | Cannot exceed 50 featured artists |
| `add_secondary_genre_aborts_at_max` | Cannot exceed 3 secondary genres |
| `set_primary_genre_aborts_if_secondary` | Cannot set primary genre to an existing secondary |
| `set_tempo_bpm_aborts_zero` | Tempo must be >= 1 BPM |

### Release (8 specs)

| Spec | Property |
|------|----------|
| `add_credit_aborts_when_published` | Published releases cannot add credits |
| `authorize_aborts_wrong_cap` | Authorization fails with mismatched admin cap |
| `authorize_succeeds` | Authorization succeeds with correct admin cap |
| `add_credit_increments_count` | Adding a credit increases count by exactly 1 |
| `add_credit_aborts_duplicate` | Same party cannot be credited twice |
| `add_credit_aborts_zero_roles` | Credits must have at least 1 role |
| `add_credit_aborts_multiple_roles` | Release credits must have exactly 1 role |
| `add_credit_aborts_max_credits` | Cannot exceed 50 credits |

### Track (2 specs)

| Spec | Property |
|------|----------|
| `assign_transitions_to_assigned` | Assignment transitions Unassigned → Assigned |
| `assign_aborts_when_assigned` | Already-assigned tracks cannot be re-assigned |

### Disc (2 specs)

| Spec | Property |
|------|----------|
| `new_enforces_max_tracks` | Disc creation enforces max 50 tracks |
| `new_aborts_too_many_tracks` | Disc creation aborts when > 50 tracks |

### Deal (2 specs)

| Spec | Property |
|------|----------|
| `new_aborts_on_composition_id_mismatch` | Deal creation aborts when composition ID doesn't match recording |
| `new_preserves_ids` | Deal preserves composition, recording, and release IDs exactly |

### Stem (4 specs)

| Spec | Property |
|------|----------|
| `add_contributor_increments_count` | Adding a contributor increases count by exactly 1 |
| `add_contributor_aborts_duplicate` | Same contributor cannot be added twice |
| `add_contributor_aborts_at_max` | Cannot exceed 10 contributors |
| `remove_contributor_aborts_out_of_bounds` | Removal aborts on invalid index |

### TimeSignature (1 spec)

| Spec | Property |
|------|----------|
| `new_spec` | Aborts iff beats_per_measure == 0 or beat_unit == 0; preserves exact values on success |

## Properties not yet verified

| Property | Reason | Priority |
|----------|--------|----------|
| Release BPS split sum = 10,000 | Requires loop invariant over nested disc/track iteration | P0 |
| Publish prerequisites (credits, content, primary credit) | Complex multi-condition specs | P1 |
| Disc duration = sum of track durations | Requires loop invariant | P2 |
| Release structural bounds (discs 1-20, tracks <= 255) | Needs release::new spec with complex setup | P2 |
| Genre name validation ([A-Z_], 1-50 chars) | Requires character-level quantifier | P3 |
| Cross-object reference validity | Cannot verify across transactions | N/A |
| Dynamic field extension safety | Unconstrained by design | N/A |

## Understanding the results

Each spec generates 3 verification checks:

- **Check** — The main proof. Z3 exhaustively searches for any input violating the property.
- **Assume** — Consistency check. Verifies the preconditions are satisfiable (not vacuously true).
- **SpecNoAbortCheck** — Ensures the spec function itself doesn't abort on valid inputs.

All 210 checks (70 × 3) passing means every listed property is mathematically proven for all possible inputs satisfying the preconditions.
