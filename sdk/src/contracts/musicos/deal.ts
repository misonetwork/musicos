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
 * - A recording owner creates a `Deal` specifying the target release, track split,
 *   and optional overrides for title and cover art.
 * - The deal is consumed by `track::new` to create a track, transferring the
 *   recording's metadata and authorization into the release.
 * - Deals can be destroyed if no longer needed.
 */

import { MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction, type TransactionArgument } from '@mysten/sui/transactions';
import * as type_name from './deps/std/type_name.js';
import * as bps from './deps/bps/bps.js';
import * as cover_art from './cover_art.js';
const $moduleName = '@local-pkg/musicos::deal';
export const Deal = new MoveStruct({ name: `${$moduleName}::Deal`, fields: {
        /** Unique identifier for this deal. */
        id: bcs.Address,
        /** ID of the target release this deal authorizes. */
        release_id: bcs.Address,
        /** ID of the underlying composition. */
        composition_id: bcs.Address,
        /** Type of the composition's share token. */
        composition_share_type: type_name.TypeName,
        /** Royalty rate owed to the composition. */
        composition_royalty_rate: bps.BPS,
        /** ID of the recording being authorized. */
        recording_id: bcs.Address,
        /** Type of the recording's share token. */
        recording_share_type: type_name.TypeName,
        /** Duration of the recording in milliseconds. */
        recording_duration_ms: bcs.u64(),
        /** Ingester of the recording's master audio file. */
        recording_master_ingester_type: type_name.TypeName,
        /** Title for the track (defaults to recording title). */
        track_title: bcs.string(),
        /** Revenue split allocated to this track in basis points. */
        track_split_bps: bps.BPS,
        /** Cover art for the track (defaults to recording cover art). */
        track_cover_art: cover_art.CoverArt
    } });
export const DealCreatedEvent = new MoveStruct({ name: `${$moduleName}::DealCreatedEvent`, fields: {
        /** ID of the deal. */
        deal_id: bcs.Address,
        /** ID of the target release. */
        release_id: bcs.Address,
        /** ID of the recording. */
        recording_id: bcs.Address,
        /** ID of the composition. */
        composition_id: bcs.Address,
        /** Title for the track (may override recording title). */
        track_title: bcs.string(),
        /** Track-level revenue split in basis points. */
        track_split_bps_value: bcs.u16(),
        /** Static cover art blob ID for the track. */
        track_cover_art_static_blob_id: bcs.u256(),
        /** Animated cover art blob ID for the track, if present. */
        track_cover_art_animated_blob_id: bcs.option(bcs.u256())
    } });
export const DealDestroyedEvent = new MoveStruct({ name: `${$moduleName}::DealDestroyedEvent`, fields: {
        /** ID of the deal. */
        deal_id: bcs.Address,
        /** ID of the target release. */
        release_id: bcs.Address,
        /** ID of the recording. */
        recording_id: bcs.Address,
        /** ID of the composition. */
        composition_id: bcs.Address
    } });
export interface NewArguments {
    _: RawTransactionArgument<string>;
    composition: RawTransactionArgument<string>;
    recording: RawTransactionArgument<string>;
    releaseId: RawTransactionArgument<string>;
    trackSplitBpsValue: RawTransactionArgument<number>;
    trackTitle: RawTransactionArgument<string | null>;
    trackCoverArt: TransactionArgument;
}
export interface NewOptions {
    package?: string;
    arguments: NewArguments | [
        _: RawTransactionArgument<string>,
        composition: RawTransactionArgument<string>,
        recording: RawTransactionArgument<string>,
        releaseId: RawTransactionArgument<string>,
        trackSplitBpsValue: RawTransactionArgument<number>,
        trackTitle: RawTransactionArgument<string | null>,
        trackCoverArt: TransactionArgument
    ];
    typeArguments: [
        string,
        string
    ];
}
/**
 * Creates a new deal authorizing a recording for inclusion in a release. Requires
 * the recording admin capability. Captures recording metadata at creation time.
 * Optional title and cover art override the recording defaults.
 */
export function _new(options: NewOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null,
        null,
        null,
        '0x2::object::ID',
        'u16',
        '0x1::option::Option<0x1::string::String>',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["_", "composition", "recording", "releaseId", "trackSplitBpsValue", "trackTitle", "trackCoverArt"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'deal',
        function: 'new',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface DestroyArguments {
    self: RawTransactionArgument<string>;
}
export interface DestroyOptions {
    package?: string;
    arguments: DestroyArguments | [
        self: RawTransactionArgument<string>
    ];
}
/**
 * Destroys a deal, emitting a `DealDestroyedEvent`. Used when a deal is no longer
 * needed or the negotiation falls through.
 */
export function destroy(options: DestroyOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'deal',
        function: 'destroy',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
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
    });
}
export interface CompositionIdArguments {
    self: RawTransactionArgument<string>;
}
export interface CompositionIdOptions {
    package?: string;
    arguments: CompositionIdArguments | [
        self: RawTransactionArgument<string>
    ];
}
/** Returns the ID of the underlying composition. */
export function compositionId(options: CompositionIdOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'deal',
        function: 'composition_id',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface CompositionShareTypeArguments {
    self: RawTransactionArgument<string>;
}
export interface CompositionShareTypeOptions {
    package?: string;
    arguments: CompositionShareTypeArguments | [
        self: RawTransactionArgument<string>
    ];
}
/** Returns the type of the composition's share token. */
export function compositionShareType(options: CompositionShareTypeOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'deal',
        function: 'composition_share_type',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface CompositionRoyaltyRateArguments {
    self: RawTransactionArgument<string>;
}
export interface CompositionRoyaltyRateOptions {
    package?: string;
    arguments: CompositionRoyaltyRateArguments | [
        self: RawTransactionArgument<string>
    ];
}
/** Returns the royalty rate owed to the composition. */
export function compositionRoyaltyRate(options: CompositionRoyaltyRateOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'deal',
        function: 'composition_royalty_rate',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
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
    });
}
export interface RecordingShareTypeArguments {
    self: RawTransactionArgument<string>;
}
export interface RecordingShareTypeOptions {
    package?: string;
    arguments: RecordingShareTypeArguments | [
        self: RawTransactionArgument<string>
    ];
}
/** Returns the type of the recording's share token. */
export function recordingShareType(options: RecordingShareTypeOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'deal',
        function: 'recording_share_type',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface RecordingDurationMsArguments {
    self: RawTransactionArgument<string>;
}
export interface RecordingDurationMsOptions {
    package?: string;
    arguments: RecordingDurationMsArguments | [
        self: RawTransactionArgument<string>
    ];
}
/** Returns the duration of the recording in milliseconds. */
export function recordingDurationMs(options: RecordingDurationMsOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'deal',
        function: 'recording_duration_ms',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface RecordingMasterIngesterTypeArguments {
    self: RawTransactionArgument<string>;
}
export interface RecordingMasterIngesterTypeOptions {
    package?: string;
    arguments: RecordingMasterIngesterTypeArguments | [
        self: RawTransactionArgument<string>
    ];
}
/** Returns the ingester of the recording's master audio file. */
export function recordingMasterIngesterType(options: RecordingMasterIngesterTypeOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'deal',
        function: 'recording_master_ingester_type',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface TrackTitleArguments {
    self: RawTransactionArgument<string>;
}
export interface TrackTitleOptions {
    package?: string;
    arguments: TrackTitleArguments | [
        self: RawTransactionArgument<string>
    ];
}
/** Returns the track title. */
export function trackTitle(options: TrackTitleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'deal',
        function: 'track_title',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
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
    });
}
export interface TrackCoverArtArguments {
    self: RawTransactionArgument<string>;
}
export interface TrackCoverArtOptions {
    package?: string;
    arguments: TrackCoverArtArguments | [
        self: RawTransactionArgument<string>
    ];
}
/** Returns a reference to the track's cover art. */
export function trackCoverArt(options: TrackCoverArtOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'deal',
        function: 'track_cover_art',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}