/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Represents a track on a release, linking a recording to its position in the
 * tracklist. Each track captures metadata from the recording at the time of
 * release creation for efficient access during playback.
 * 
 * ### Key Features:
 * 
 * - Caches recording metadata for quick access
 * - Supports optional track-specific cover art
 * - Stores the track's split of release revenue and the composition royalty rate
 */

import { MoveEnum, MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction, type TransactionArgument } from '@mysten/sui/transactions';
import * as type_name from './deps/std/type_name.js';
import * as bps from './deps/bps/bps.js';
import * as cover_art from './cover_art.js';
const $moduleName = '@local-pkg/musicos::track';
/** Lifecycle state of a track within a release. */
export const TrackState = new MoveEnum({ name: `${$moduleName}::TrackState`, fields: {
        /** Track has been created but not yet assigned to a release. */
        Unassigned: new MoveStruct({ name: `TrackState.Unassigned`, fields: {
                release_id: bcs.Address
            } }),
        /** Track has been assigned to its target release. */
        Assigned: null
    } });
export const Track = new MoveStruct({ name: `${$moduleName}::Track`, fields: {
        /** Current state of the track. */
        state: TrackState,
        /** ID of the underlying composition. */
        composition_id: bcs.Address,
        /** Type of the composition's share token. */
        composition_share_type: type_name.TypeName,
        /** Royalty rate owed to the composition. */
        composition_royalty_rate: bps.BPS,
        /** ID of the recording on this track. */
        recording_id: bcs.Address,
        /** Type of the recording's share token. */
        recording_share_type: type_name.TypeName,
        /** Description of the track. */
        title: bcs.string(),
        /** Cover art for the track. Inherited from the recording by default. */
        cover_art: cover_art.CoverArt,
        /**
         * This track's share of the release's revenue, in basis points. All tracks in a
         * release sum to 100%. (The composition-vs-recording split within this share is
         * governed by `composition_royalty_rate`.)
         */
        split_bps: bps.BPS
    } });
export interface NewArguments {
    deal: RawTransactionArgument<string>;
}
export interface NewOptions {
    package?: string;
    arguments: NewArguments | [
        deal: RawTransactionArgument<string>
    ];
}
/**
 * Creates a new track by accepting a deal. The deal itself is the authorization —
 * it was created by the recording's admin and carries the recording's metadata and
 * the agreed split. Emits a `DealAcceptedEvent`.
 */
export function _new(options: NewOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["deal"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'track',
        function: 'new',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface CompositionIdArguments {
    self: TransactionArgument;
}
export interface CompositionIdOptions {
    package?: string;
    arguments: CompositionIdArguments | [
        self: TransactionArgument
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
        module: 'track',
        function: 'composition_id',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface CompositionShareTypeArguments {
    self: TransactionArgument;
}
export interface CompositionShareTypeOptions {
    package?: string;
    arguments: CompositionShareTypeArguments | [
        self: TransactionArgument
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
        module: 'track',
        function: 'composition_share_type',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface CompositionRoyaltyRateArguments {
    self: TransactionArgument;
}
export interface CompositionRoyaltyRateOptions {
    package?: string;
    arguments: CompositionRoyaltyRateArguments | [
        self: TransactionArgument
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
        module: 'track',
        function: 'composition_royalty_rate',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface RecordingIdArguments {
    self: TransactionArgument;
}
export interface RecordingIdOptions {
    package?: string;
    arguments: RecordingIdArguments | [
        self: TransactionArgument
    ];
}
/** Returns the ID of the recording. */
export function recordingId(options: RecordingIdOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'track',
        function: 'recording_id',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface RecordingShareTypeArguments {
    self: TransactionArgument;
}
export interface RecordingShareTypeOptions {
    package?: string;
    arguments: RecordingShareTypeArguments | [
        self: TransactionArgument
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
        module: 'track',
        function: 'recording_share_type',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface TitleArguments {
    self: TransactionArgument;
}
export interface TitleOptions {
    package?: string;
    arguments: TitleArguments | [
        self: TransactionArgument
    ];
}
/** Returns the title of the track. */
export function title(options: TitleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'track',
        function: 'title',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface CoverArtArguments {
    self: TransactionArgument;
}
export interface CoverArtOptions {
    package?: string;
    arguments: CoverArtArguments | [
        self: TransactionArgument
    ];
}
/** Returns the cover art for the track. */
export function coverArt(options: CoverArtOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'track',
        function: 'cover_art',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface SplitBpsArguments {
    self: TransactionArgument;
}
export interface SplitBpsOptions {
    package?: string;
    arguments: SplitBpsArguments | [
        self: TransactionArgument
    ];
}
/** Returns this track's share of the release's revenue (in basis points). */
export function splitBps(options: SplitBpsOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'track',
        function: 'split_bps',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsAssignedStateArguments {
    self: TransactionArgument;
}
export interface IsAssignedStateOptions {
    package?: string;
    arguments: IsAssignedStateArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if the track is in the Assigned state. */
export function isAssignedState(options: IsAssignedStateOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'track',
        function: 'is_assigned_state',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsUnassignedStateArguments {
    self: TransactionArgument;
}
export interface IsUnassignedStateOptions {
    package?: string;
    arguments: IsUnassignedStateArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if the track is in the Unassigned state. */
export function isUnassignedState(options: IsUnassignedStateOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'track',
        function: 'is_unassigned_state',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}