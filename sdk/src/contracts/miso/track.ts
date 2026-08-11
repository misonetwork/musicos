/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Represents a track on a release, linking a recording to its position in the
 * tracklist.
 * 
 * A `Track` is the minimal positioned (recording, revenue-share) pair:
 * 
 * - `recording_id` — the routing target for the track's revenue, and the handle
 *   through which all other metadata (title, cover art, and the
 *   recording/composition share-type identities) is reached.
 * - `split_bps` — this track's share of the release's revenue; genuinely
 *   release-specific and not derivable from the recording.
 * - `state` — the assign-once lifecycle that carries (then sheds) each deal's
 *   target release commitment; see `TrackState`.
 * 
 * `Track` is intentionally monomorphic: a `Release` holds a `vector<Track>` of
 * tracks from many different recordings/compositions, so it cannot be generic over
 * their share types. It stores no title, cover art, or share-type — all derived
 * from the recording via `recording_id`.
 */

import { MoveEnum, MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction, type TransactionArgument } from '@mysten/sui/transactions';
import * as bps from './deps/bps/bps.js';
const $moduleName = '@local-pkg/miso::track';
/**
 * Lifecycle state of a track within a release. A track is born `Unassigned`,
 * carrying the target `release_id` its originating `Deal` committed to (the
 * release id is a digest of the whole tracklist, so this is the recording owner's
 * consent to the exact release configuration). At publish the release verifies the
 * match and transitions the track to `Assigned`, which carries no id — shedding
 * the 32-byte commitment once it has served its purpose.
 */
export const TrackState = new MoveEnum({ name: `${$moduleName}::TrackState`, fields: {
        /**
          * Track has been created but not yet assigned to a release. Carries the target
          * release id the originating deal committed to.
          */
        Unassigned: bcs.Address,
        /** Track has been assigned to its target release. */
        Assigned: null
    } });
export const Track = new MoveStruct({ name: `${$moduleName}::Track`, fields: {
        /** Current state of the track. */
        state: TrackState,
        /**
         * ID of the recording on this track. The routing target for the track's revenue;
         * also the handle a consumer uses to fetch the recording (whose type carries the
         * recording and composition share-type identities).
         */
        recording_id: bcs.Address,
        /**
         * This track's share of the release's revenue, in basis points. All tracks in a
         * release sum to 100%. The composition's cut is settled as recording-share
         * ownership at recording creation, so it is not split out here — a track routes
         * its full share to the recording.
         */
        split_bps: bps.BPS
    } });
export interface NewArguments {
    deal: RawTransactionArgument<string>;
    recording: RawTransactionArgument<string>;
}
export interface NewOptions {
    package?: string;
    arguments: NewArguments | [
        deal: RawTransactionArgument<string>,
        recording: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/**
 * Creates a new track by accepting a deal. The deal is the authorization — created
 * by the recording's admin, carrying the target release and the agreed split.
 * Emits a `DealAcceptedEvent`.
 *
 * The deal's `RecordingShare`/`CompositionShare` phantoms are erased here: a
 * `Track` is monomorphic so it can live in a release's heterogeneous
 * `vector<Track>`. Identity rides on those phantoms up to this point, but the
 * monomorphic `Track` must store the recording's _address_ for revenue routing —
 * and an address can't come from a phantom. So the matching `Recording` is passed
 * in (the deal's phantoms force it to be the right one) purely to read its id; the
 * deal no longer stores it.
 */
export function _new(options: NewOptions) {
    const packageAddress = options.package ?? '@local-pkg/miso';
    const argumentsTypes = [
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["deal", "recording"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'track',
        function: 'new',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
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
    const packageAddress = options.package ?? '@local-pkg/miso';
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
    const packageAddress = options.package ?? '@local-pkg/miso';
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