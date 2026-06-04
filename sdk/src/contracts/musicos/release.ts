/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Represents a music release in MusicOS. A release is a collection of tracks
 * organized into discs, with cover art and revenue distribution configuration.
 * 
 * ### Key Features:
 * 
 * - Multi-disc releases with track sequencing
 * - Configurable per-track revenue splits
 * - Revenue distribution to composition and recording royalty pools
 * - State machine: Initialized -> Published
 */

import { MoveTuple, MoveEnum, MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction, type TransactionArgument } from '@mysten/sui/transactions';
import * as release_kind from './release_kind.js';
import * as vec_map from './deps/sui/vec_map.js';
import * as credit from './deps/partyos/credit.js';
import * as release_party_role from './release_party_role.js';
import * as disc from './disc.js';
import * as cover_art from './cover_art.js';
const $moduleName = '@local-pkg/musicos::release';
export const RELEASE = new MoveTuple({ name: `${$moduleName}::RELEASE`, fields: [bcs.bool()] });
/** Lifecycle state of a release. */
export const ReleaseState = new MoveEnum({ name: `${$moduleName}::ReleaseState`, fields: {
        /** Release is initialized but not yet created. */
        Initialized: bcs.bool(),
        /** Release is published and immutable. Includes publication timestamp. */
        Published: bcs.u64()
    } });
export const Release = new MoveStruct({ name: `${$moduleName}::Release`, fields: {
        /** Unique identifier for this release. */
        id: bcs.Address,
        /** The type of release. */
        kind: release_kind.ReleaseKind,
        /** Current lifecycle state. */
        state: ReleaseState,
        /** Title of the release. */
        title: bcs.string(),
        /** Optional subtitle (e.g., "Deluxe Edition"). */
        subtitle: bcs.option(bcs.string()),
        /** Description of the release. */
        description: bcs.string(),
        /** Attribution information for the release. */
        credits: vec_map.VecMap(bcs.Address, credit.Credit(release_party_role.ReleasePartyRole)),
        /** Collection of discs containing tracks. */
        discs: bcs.vector(disc.Disc),
        /** Cover artwork for the release. */
        cover_art: cover_art.CoverArt
    } });
export const ReleaseKey = new MoveTuple({ name: `${$moduleName}::ReleaseKey`, fields: [bcs.vector(bcs.u8())] });
export const ReleaseRegistry = new MoveStruct({ name: `${$moduleName}::ReleaseRegistry`, fields: {
        id: bcs.Address
    } });
export const ReleaseAdminCap = new MoveStruct({ name: `${$moduleName}::ReleaseAdminCap`, fields: {
        /** Unique identifier for this capability. */
        id: bcs.Address,
        /** ID of the release this capability controls. */
        release_id: bcs.Address
    } });
export const ReleaseAdminCapKey = new MoveTuple({ name: `${$moduleName}::ReleaseAdminCapKey`, fields: [bcs.bool()] });
export const ReleasePublishedEvent = new MoveStruct({ name: `${$moduleName}::ReleasePublishedEvent`, fields: {
        release_id: bcs.Address
    } });
export interface NewArguments {
    kind: TransactionArgument;
    title: RawTransactionArgument<string>;
    description: RawTransactionArgument<string>;
    coverArt: TransactionArgument;
    discs: TransactionArgument;
    nonce: RawTransactionArgument<number | bigint>;
    registry: RawTransactionArgument<string>;
}
export interface NewOptions {
    package?: string;
    arguments: NewArguments | [
        kind: TransactionArgument,
        title: RawTransactionArgument<string>,
        description: RawTransactionArgument<string>,
        coverArt: TransactionArgument,
        discs: TransactionArgument,
        nonce: RawTransactionArgument<number | bigint>,
        registry: RawTransactionArgument<string>
    ];
}
/**
 * Creates a new release with the given configuration. Returns the release and
 * admin capability.
 */
export function _new(options: NewOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null,
        '0x1::string::String',
        '0x1::string::String',
        null,
        'vector<null>',
        'u256',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["kind", "title", "description", "coverArt", "discs", "nonce", "registry"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release',
        function: 'new',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface AddCreditArguments {
    self: RawTransactionArgument<string>;
    cap: RawTransactionArgument<string>;
    party: RawTransactionArgument<string>;
    credit: TransactionArgument;
}
export interface AddCreditOptions {
    package?: string;
    arguments: AddCreditArguments | [
        self: RawTransactionArgument<string>,
        cap: RawTransactionArgument<string>,
        party: RawTransactionArgument<string>,
        credit: TransactionArgument
    ];
}
/**
 * Adds a credit to the release for a party. Each credit must have exactly one role
 * (Primary or Featured). Required State: Initialized
 */
export function addCredit(options: AddCreditOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null,
        null,
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "cap", "party", "credit"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release',
        function: 'add_credit',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface PublishArguments {
    self: RawTransactionArgument<string>;
    cap: RawTransactionArgument<string>;
}
export interface PublishOptions {
    package?: string;
    arguments: PublishArguments | [
        self: RawTransactionArgument<string>,
        cap: RawTransactionArgument<string>
    ];
}
/**
 * Publishes the release, making it immutable. Track splits must be set and sum to
 * 100% before publishing. Required State: Initialized
 */
export function publish(options: PublishOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null,
        null,
        '0x2::clock::Clock'
    ] satisfies (string | null)[];
    const parameterNames = ["self", "cap"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release',
        function: 'publish',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface AuthorizeArguments {
    self: RawTransactionArgument<string>;
    cap: RawTransactionArgument<string>;
}
export interface AuthorizeOptions {
    package?: string;
    arguments: AuthorizeArguments | [
        self: RawTransactionArgument<string>,
        cap: RawTransactionArgument<string>
    ];
}
/** Verifies that the admin capability matches this release. */
export function authorize(options: AuthorizeOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "cap"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release',
        function: 'authorize',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface DeriveReleaseIdArguments {
    recordingIds: RawTransactionArgument<Array<string>>;
    trackSplitValues: RawTransactionArgument<Array<number | bigint>>;
    nonce: RawTransactionArgument<number | bigint>;
    registry: RawTransactionArgument<string>;
}
export interface DeriveReleaseIdOptions {
    package?: string;
    arguments: DeriveReleaseIdArguments | [
        recordingIds: RawTransactionArgument<Array<string>>,
        trackSplitValues: RawTransactionArgument<Array<number | bigint>>,
        nonce: RawTransactionArgument<number | bigint>,
        registry: RawTransactionArgument<string>
    ];
}
/**
 * Derives the release ID that `new()` would produce for the given inputs, without
 * creating the object. This is the on-chain equivalent of the client-side
 * `deriveReleaseId()` function.
 */
export function deriveReleaseId(options: DeriveReleaseIdOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        'vector<0x2::object::ID>',
        'vector<u64>',
        'u256',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["recordingIds", "trackSplitValues", "nonce", "registry"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release',
        function: 'derive_release_id',
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
/** Returns the release's object ID. */
export function id(options: IdOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release',
        function: 'id',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface KindArguments {
    self: RawTransactionArgument<string>;
}
export interface KindOptions {
    package?: string;
    arguments: KindArguments | [
        self: RawTransactionArgument<string>
    ];
}
/** Returns the release kind. */
export function kind(options: KindOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release',
        function: 'kind',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface StateArguments {
    self: RawTransactionArgument<string>;
}
export interface StateOptions {
    package?: string;
    arguments: StateArguments | [
        self: RawTransactionArgument<string>
    ];
}
/** Returns the release state. */
export function state(options: StateOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release',
        function: 'state',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsInitializedStateArguments {
    self: RawTransactionArgument<string>;
}
export interface IsInitializedStateOptions {
    package?: string;
    arguments: IsInitializedStateArguments | [
        self: RawTransactionArgument<string>
    ];
}
/** Returns true if the release is in the Initialized state. */
export function isInitializedState(options: IsInitializedStateOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release',
        function: 'is_initialized_state',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsPublishedStateArguments {
    self: RawTransactionArgument<string>;
}
export interface IsPublishedStateOptions {
    package?: string;
    arguments: IsPublishedStateArguments | [
        self: RawTransactionArgument<string>
    ];
}
/** Returns true if the release is in the Published state. */
export function isPublishedState(options: IsPublishedStateOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release',
        function: 'is_published_state',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface TitleArguments {
    self: RawTransactionArgument<string>;
}
export interface TitleOptions {
    package?: string;
    arguments: TitleArguments | [
        self: RawTransactionArgument<string>
    ];
}
/** Returns the release title. */
export function title(options: TitleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release',
        function: 'title',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface SubtitleArguments {
    self: RawTransactionArgument<string>;
}
export interface SubtitleOptions {
    package?: string;
    arguments: SubtitleArguments | [
        self: RawTransactionArgument<string>
    ];
}
/** Returns the optional subtitle. */
export function subtitle(options: SubtitleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release',
        function: 'subtitle',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface DescriptionArguments {
    self: RawTransactionArgument<string>;
}
export interface DescriptionOptions {
    package?: string;
    arguments: DescriptionArguments | [
        self: RawTransactionArgument<string>
    ];
}
/** Returns the release description. */
export function description(options: DescriptionOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release',
        function: 'description',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface CreditsArguments {
    self: RawTransactionArgument<string>;
}
export interface CreditsOptions {
    package?: string;
    arguments: CreditsArguments | [
        self: RawTransactionArgument<string>
    ];
}
/** Returns a reference to the release credits. */
export function credits(options: CreditsOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release',
        function: 'credits',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface DiscsArguments {
    self: RawTransactionArgument<string>;
}
export interface DiscsOptions {
    package?: string;
    arguments: DiscsArguments | [
        self: RawTransactionArgument<string>
    ];
}
/** Returns a reference to all discs. */
export function discs(options: DiscsOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release',
        function: 'discs',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface CoverArtArguments {
    self: RawTransactionArgument<string>;
}
export interface CoverArtOptions {
    package?: string;
    arguments: CoverArtArguments | [
        self: RawTransactionArgument<string>
    ];
}
/** Returns a reference to the cover art. */
export function coverArt(options: CoverArtOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release',
        function: 'cover_art',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface TotalTracksArguments {
    self: RawTransactionArgument<string>;
}
export interface TotalTracksOptions {
    package?: string;
    arguments: TotalTracksArguments | [
        self: RawTransactionArgument<string>
    ];
}
/** Returns the total number of tracks across all discs. */
export function totalTracks(options: TotalTracksOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release',
        function: 'total_tracks',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface ContainsRecordingArguments {
    self: RawTransactionArgument<string>;
    recordingId: RawTransactionArgument<string>;
}
export interface ContainsRecordingOptions {
    package?: string;
    arguments: ContainsRecordingArguments | [
        self: RawTransactionArgument<string>,
        recordingId: RawTransactionArgument<string>
    ];
}
/** Returns whether the release contains a track for the given recording. */
export function containsRecording(options: ContainsRecordingOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null,
        '0x2::object::ID'
    ] satisfies (string | null)[];
    const parameterNames = ["self", "recordingId"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release',
        function: 'contains_recording',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface DurationMsArguments {
    self: RawTransactionArgument<string>;
}
export interface DurationMsOptions {
    package?: string;
    arguments: DurationMsArguments | [
        self: RawTransactionArgument<string>
    ];
}
/** Returns the total duration of all tracks in milliseconds. */
export function durationMs(options: DurationMsOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release',
        function: 'duration_ms',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface AudioIngesterTypesArguments {
    self: RawTransactionArgument<string>;
}
export interface AudioIngesterTypesOptions {
    package?: string;
    arguments: AudioIngesterTypesArguments | [
        self: RawTransactionArgument<string>
    ];
}
export function audioIngesterTypes(options: AudioIngesterTypesOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release',
        function: 'audio_ingester_types',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface ReleaseAdminCapReleaseIdArguments {
    cap: RawTransactionArgument<string>;
}
export interface ReleaseAdminCapReleaseIdOptions {
    package?: string;
    arguments: ReleaseAdminCapReleaseIdArguments | [
        cap: RawTransactionArgument<string>
    ];
}
/** Returns the release ID associated with the admin capability. */
export function releaseAdminCapReleaseId(options: ReleaseAdminCapReleaseIdOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["cap"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release',
        function: 'release_admin_cap_release_id',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface UidArguments {
    self: RawTransactionArgument<string>;
}
export interface UidOptions {
    package?: string;
    arguments: UidArguments | [
        self: RawTransactionArgument<string>
    ];
}
/** Returns a reference to the release's UID for reading dynamic fields. */
export function uid(options: UidOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release',
        function: 'uid',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface UidMutArguments {
    self: RawTransactionArgument<string>;
    cap: RawTransactionArgument<string>;
}
export interface UidMutOptions {
    package?: string;
    arguments: UidMutArguments | [
        self: RawTransactionArgument<string>,
        cap: RawTransactionArgument<string>
    ];
}
/** Returns a mutable reference to the release's UID. Requires the admin capability. */
export function uidMut(options: UidMutOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "cap"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release',
        function: 'uid_mut',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}