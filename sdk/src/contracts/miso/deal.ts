/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Represents a deal authorizing a recording to be included in a release. Deals are
 * created by recording owners to grant permission for their recordings to appear
 * on specific releases with agreed-upon revenue splits.
 * 
 * ### Flow:
 * 
 * - A recording owner creates a `Deal` specifying the target release and track
 *   split.
 * - The deal is consumed by `track::new` to create a track, transferring the
 *   recording's authorization into the release.
 * - Deals can be destroyed if no longer needed.
 * 
 * `Deal<RecordingShare, CompositionShare>` carries the recording's and
 * composition's identities as phantom type parameters rather than stored values —
 * a `Deal` is consumed one-to-one into a `Track` and is never collected, so it has
 * no reason to flatten to `TypeName`s early. The recording↔composition pairing is
 * type-enforced at `new` via the `Recording<RecordingShare, CompositionShare>`
 * argument — no ID is stored and no runtime assert is needed.
 * 
 * A deal stores only what is genuinely release-specific and not carried by the
 * type parameters: the target `release_id` and the `track_split_bps`. The
 * recording is identified by the phantom, so no `recording_id` is stored —
 * `track::new` reads the recording's address from the matching `Recording` it is
 * handed (the phantoms force it to be the right one). Display metadata (title,
 * cover art) is _not_ duplicated here — it is derived from the recording.
 */

import { MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction } from '@mysten/sui/transactions';
import * as bps from './deps/bps/bps.js';
const $moduleName = '@local-pkg/miso::deal';
export const Deal = new MoveStruct({ name: `${$moduleName}::Deal<phantom RecordingShare, phantom CompositionShare>`, fields: {
        /** Unique identifier for this deal. */
        id: bcs.Address,
        /** ID of the target release this deal authorizes. */
        release_id: bcs.Address,
        /** Revenue split allocated to this track in basis points. */
        track_split_bps: bps.BPS
    } });
export const DealCreatedEvent = new MoveStruct({ name: `${$moduleName}::DealCreatedEvent<phantom RecordingShare, phantom CompositionShare>`, fields: {
        /** ID of the deal. */
        deal_id: bcs.Address,
        /** ID of the recording whose inclusion is authorized. */
        recording_id: bcs.Address,
        /** ID of the target release. */
        release_id: bcs.Address,
        /** Track-level revenue split in basis points. */
        track_split_bps_value: bcs.u16(),
        created_by: bcs.Address
    } });
export const DealAcceptedEvent = new MoveStruct({ name: `${$moduleName}::DealAcceptedEvent<phantom RecordingShare, phantom CompositionShare>`, fields: {
        /** ID of the deal. */
        deal_id: bcs.Address,
        /** ID of the target release. */
        release_id: bcs.Address
    } });
export const DealRejectedEvent = new MoveStruct({ name: `${$moduleName}::DealRejectedEvent<phantom RecordingShare, phantom CompositionShare>`, fields: {
        /** ID of the deal. */
        deal_id: bcs.Address,
        /** ID of the target release. */
        release_id: bcs.Address
    } });
export interface NewArguments {
    _: RawTransactionArgument<string>;
    recording: RawTransactionArgument<string>;
    releaseId: RawTransactionArgument<string>;
    trackSplitBpsValue: RawTransactionArgument<number>;
}
export interface NewOptions {
    package?: string;
    arguments: NewArguments | [
        _: RawTransactionArgument<string>,
        recording: RawTransactionArgument<string>,
        releaseId: RawTransactionArgument<string>,
        trackSplitBpsValue: RawTransactionArgument<number>
    ];
    typeArguments: [
        string,
        string
    ];
}
/**
 * Creates a new deal authorizing a recording for inclusion in a release. Requires
 * the recording admin capability.
 *
 * The composition is identified by the recording's `CompositionShare` phantom, so
 * the recording↔composition pairing is compile-time enforced — there is no
 * `Composition` argument and no runtime ID check.
 *
 * ### What signing a deal consents to
 *
 * `release_id` is derived from the release digest, so targeting it consents to
 * that release's exact economics and membership: the ordered list of
 * `(recording, split)` pairs and the creator's nonce, nothing more. The release's
 * title, artwork, credits, and display grouping are chosen by the release creator
 * — before or after this deal is signed — and are not bound by the digest.
 * Presentation is trusted and publicly attributable, not cryptographically
 * committed.
 *
 * The recording need not be `Published`: its admin can strike deals inside the
 * recording's own creating transaction (an `Initialized` recording cannot escape
 * that transaction, so across transactions deals always reference `Published`,
 * shared recordings).
 *
 * ### A transferred deal is out of its creator's hands
 *
 * A deal has no expiry and cannot be withdrawn by its creator: only the holder can
 * `reject` it, or accept it — at any future time — into exactly the consented
 * release via `track::new`. The digest binding confines a stale deal's blast
 * radius to that one release. Acceptance is itself provisional until the release
 * publishes: an accepted deal's track can be embedded in a release that never
 * publishes, with no extraction path — the deal is then consumed while the
 * recording never ships, and the recording admin's recourse is a new deal for a
 * new release.
 *
 * `recording` is deliberately unread (hence the `#[allow]`): it exists to
 * compile-time-bind the `RecordingShare`/`CompositionShare` phantom pairing.
 */
export function _new(options: NewOptions) {
    const packageAddress = options.package ?? '@local-pkg/miso';
    const argumentsTypes = [
        null,
        null,
        '0x2::object::ID',
        'u16'
    ] satisfies (string | null)[];
    const parameterNames = ["_", "recording", "releaseId", "trackSplitBpsValue"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'deal',
        function: 'new',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface RejectArguments {
    self: RawTransactionArgument<string>;
}
export interface RejectOptions {
    package?: string;
    arguments: RejectArguments | [
        self: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/**
 * Rejects the deal, destroying it without inclusion in a release. Used when the
 * holder declines or the negotiation falls through. Emits a `DealRejectedEvent`.
 */
export function reject(options: RejectOptions) {
    const packageAddress = options.package ?? '@local-pkg/miso';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'deal',
        function: 'reject',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface IdArguments {
    self: RawTransactionArgument<string>;
}
export interface IdOptions {
    package?: string;
    arguments: IdArguments | [
        self: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/** Returns the deal's object ID. */
export function id(options: IdOptions) {
    const packageAddress = options.package ?? '@local-pkg/miso';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'deal',
        function: 'id',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface ReleaseIdArguments {
    self: RawTransactionArgument<string>;
}
export interface ReleaseIdOptions {
    package?: string;
    arguments: ReleaseIdArguments | [
        self: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/** Returns the ID of the target release. */
export function releaseId(options: ReleaseIdOptions) {
    const packageAddress = options.package ?? '@local-pkg/miso';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'deal',
        function: 'release_id',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface TrackSplitBpsArguments {
    self: RawTransactionArgument<string>;
}
export interface TrackSplitBpsOptions {
    package?: string;
    arguments: TrackSplitBpsArguments | [
        self: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/** Returns the track's revenue split in basis points. */
export function trackSplitBps(options: TrackSplitBpsOptions) {
    const packageAddress = options.package ?? '@local-pkg/miso';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'deal',
        function: 'track_split_bps',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}