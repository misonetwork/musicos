# `recording_ops`

> The marquee operations plugin for a vaulted `RecordingAdminCap`: an operator (a label, a distribution agent, an autonomous bot) drives a recording on the owner's behalf, with the vault enforcing the trust boundary at two tiers.

**Attaches to:** a `miso_vault::vault::Vault<RecordingAdminCap<RS>>`. The recording owner wraps the recording's `RecordingAdminCap` in a vault, authorizes an operator, and installs this plugin with `install`. The plugin's `Key()` witness/key type triples as the dynamic-field key for its `Config`, the witness for the vault's witness-gated cap borrow, and the witness for nonce consumption — so the vault's installation guard, borrow gate, and replay guard are all keyed to this package.

## Two trust tiers

- **Consent tier — `submit_deal`.** Binding a recording into a release at an agreed revenue split is high-stakes and economically irreversible. The operator may *relay* it, but only the recording owner (the vault's principal) can *authorize* it: the owner signs a canonical intent message off-chain with the raw Ed25519 key whose public half is stored on the vault (`admin_pubkey`), and this function verifies that signature **on-chain** before minting the `Deal`. The vault's nonce set makes each signed intent single-use; an explicit expiry bounds its lifetime; and a configurable economic floor (`min_split_bps`, set at install) is enforced on-chain so even a validly-signed sub-floor split is rejected.

- **Autonomous tier — royalty sweeps + `set_extension`.** Folding inbound revenue into the royalty pool and writing operational metadata are reversible, low-stakes, high-frequency acts. They require only a live `OperatorCap` — no per-call signed intent — so an agent can sweep continuously without the owner in the loop.

## Entry points

- **`install`** — owner-only (`VaultAdminCap`); installs the plugin and records the economic floor.
- **`submit_deal`** — consent tier; on-chain-verified signed intent → mints a `Deal` and routes it to the assembler. See `build_intent_msg` for the exact signed-message encoding.
- **`build_intent_msg`** — pure helper returning the canonical 101-byte intent message. Exposed `public` so the off-chain signer and on-chain verification share one source of truth.
- **`init_royalty_pool`** — operator-only; derives + shares the recording's `RoyaltyPool<RS, Cur>` through the vaulted cap.
- **`sweep_received`** — operator-only; receives `Coin<Cur>` sent to the recording's address and folds it into the pool.
- **`sweep_accrued`** — operator-only; redeems `value` base units from the recording's funds accumulator into the pool.
- **`set_extension`** — operator-only; writes a `String`-keyed bytes value into the recording's dynamic-field namespace through the vaulted cap.

## The `submit_deal` intent message

The owner signs, with the **raw** Ed25519 primitive (NOT `signPersonalMessage`), exactly:

```
msg = b"miso:submit_deal:v1"            // 19 bytes, domain tag, no length prefix
    ++ object::id(vault).to_bytes()      // 32 bytes, raw address bytes
    ++ release_id.to_bytes()             // 32 bytes, raw address bytes
    ++ bcs::to_bytes(&split_bps)         //  2 bytes, u16 little-endian
    ++ bcs::to_bytes(&nonce)             //  8 bytes, u64 little-endian
    ++ bcs::to_bytes(&intent_expires_ms) //  8 bytes, u64 little-endian
```

Total = 101 bytes. The two IDs are appended as bare 32-byte address representations (not BCS-wrapped); the three scalars are BCS-encoded (little-endian for fixed-width integers). `build_intent_msg` is the canonical on-chain implementation.

## Dependencies

- **`miso`** — `Recording`, `RecordingAdminCap`, `deal::new`, and the cap-gated `uid_mut`.
- **`miso_vault`** — the vault: operator-authority cap borrow, principal-signed-intent verification, and nonce replay protection.
- **`recording_royalty_pool`** / **`royalty_pool`** — the royalty-sweep tier folds revenue through these.

## Build & test

```sh
sui move build
sui move test
```
