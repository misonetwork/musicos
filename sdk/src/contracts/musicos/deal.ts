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
 * A deal carries only what is genuinely release-specific and non-derivable: the
 * target `release_id`, the `recording_id` (the revenue routing target), and the
 * `track_split_bps`. Display metadata (title, cover art) is _not_ duplicated here
 * — it is derived from the recording.
 */

import { MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction } from '@mysten/sui/transactions';
import * as bps from './deps/bps/bps.js';
const $moduleName = '@local-pkg/musicos::deal';
export const Deal = new MoveStruct({ name: `${$moduleName}::Deal<phantom RecordingShare, phantom CompositionShare>`, fields: {
        /** Unique identifier for this deal. */
        id: bcs.Address,
        /** ID of the target release this deal authorizes. */
        release_id: bcs.Address,
        /**
         * ID of the recording being authorized. Kept as an `ID` (not a type) because
         * revenue routing needs the recording's address, which a type can't provide.
         */
        recording_id: bcs.Address,
        /** Revenue split allocated to this track in basis points. */
        track_split_bps: bps.BPS
    } });
export const DealCreatedEvent = new MoveStruct({ name: `${$moduleName}::DealCreatedEvent<phantom RecordingShare, phantom CompositionShare>`, fields: {
        /** ID of the deal. */
        deal_id: bcs.Address,
        /** ID of the target release. */
        release_id: bcs.Address,
        /** ID of the recording. */
        recording_id: bcs.Address,
        /** Track-level revenue split in basis points. */
        track_split_bps_value: bcs.u16()
    } });
export const DealAcceptedEvent = new MoveStruct({ name: `${$moduleName}::DealAcceptedEvent<phantom RecordingShare, phantom CompositionShare>`, fields: {
        /** ID of the deal. */
        deal_id: bcs.Address,
        /** ID of the target release. */
        release_id: bcs.Address,
        /** ID of the recording. */
        recording_id: bcs.Address
    } });
export const DealRejectedEvent = new MoveStruct({ name: `${$moduleName}::DealRejectedEvent<phantom RecordingShare, phantom CompositionShare>`, fields: {
        /** ID of the deal. */
        deal_id: bcs.Address,
        /** ID of the target release. */
        release_id: bcs.Address,
        /** ID of the recording. */
        recording_id: bcs.Address
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
 */
export function _new(options: NewOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
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
    const packageAddress = options.package ?? '@local-pkg/musicos';
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
    const packageAddress = options.package ?? '@local-pkg/musicos';
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
    const packageAddress = options.package ?? '@local-pkg/musicos';
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
export interface RecordingIdArguments {
    self: RawTransactionArgument<string>;
}
export interface RecordingIdOptions {
    package?: string;
    arguments: RecordingIdArguments | [
        self: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/** Returns the ID of the recording being authorized. */
export function recordingId(options: RecordingIdOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'deal',
        function: 'recording_id',
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
    const packageAddress = options.package ?? '@local-pkg/musicos';
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