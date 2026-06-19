/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Represents a music release in Miso. A release is a collection of tracks
 * organized into discs, with cover art and revenue distribution configuration.
 * 
 * ### Key Features:
 * 
 * - Multi-disc releases with track sequencing
 * - Configurable per-track revenue splits
 * - State machine: Initialized -> Published
 * 
 * Attribution (credits, primary/featured artists) is intentionally NOT part of
 * core: it is display-oriented, varies across platforms, and is never read by the
 * economics. It lives in a first-party credits extension attached via `uid_mut`,
 * so core takes no dependency on an identity package and core publish enforces no
 * attribution.
 */

import { MoveTuple, MoveEnum, MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction, type TransactionArgument } from '@mysten/sui/transactions';
import * as disc from './disc.js';
const $moduleName = '@local-pkg/miso::release';
export const RELEASE = new MoveTuple({ name: `${$moduleName}::RELEASE`, fields: [bcs.bool()] });
/** Lifecycle state of a release. */
export const ReleaseState = new MoveEnum({ name: `${$moduleName}::ReleaseState`, fields: {
        /** Release is initialized but not yet published. */
        Initialized: null,
        /** Release is published and immutable. Includes publication timestamp. */
        Published: bcs.u64()
    } });
export const Release = new MoveStruct({ name: `${$moduleName}::Release`, fields: {
        /** Unique identifier for this release. */
        id: bcs.Address,
        /** Current lifecycle state. */
        state: ReleaseState,
        /** Title of the release. */
        title: bcs.string(),
        /** Optional subtitle (e.g., "Deluxe Edition"). */
        subtitle: bcs.option(bcs.string()),
        /** Collection of discs containing tracks. */
        discs: bcs.vector(disc.Disc)
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
    title: RawTransactionArgument<string>;
    discs: TransactionArgument;
    nonce: RawTransactionArgument<number | bigint>;
    registry: RawTransactionArgument<string>;
}
export interface NewOptions {
    package?: string;
    arguments: NewArguments | [
        title: RawTransactionArgument<string>,
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
    const packageAddress = options.package ?? '@local-pkg/miso';
    const argumentsTypes = [
        '0x1::string::String',
        'vector<null>',
        'u256',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["title", "discs", "nonce", "registry"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release',
        function: 'new',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface SetSubtitleArguments {
    self: RawTransactionArgument<string>;
    cap: RawTransactionArgument<string>;
    subtitle: RawTransactionArgument<string>;
}
export interface SetSubtitleOptions {
    package?: string;
    arguments: SetSubtitleArguments | [
        self: RawTransactionArgument<string>,
        cap: RawTransactionArgument<string>,
        subtitle: RawTransactionArgument<string>
    ];
}
/**
 * Sets the subtitle of the release (e.g., "Deluxe Edition"). A subtitle is part of
 * the release's identity — it distinguishes which edition this release is — so it
 * lives in the frozen embedded fields. Required State: Initialized
 */
export function setSubtitle(options: SetSubtitleOptions) {
    const packageAddress = options.package ?? '@local-pkg/miso';
    const argumentsTypes = [
        null,
        null,
        '0x1::string::String'
    ] satisfies (string | null)[];
    const parameterNames = ["self", "cap", "subtitle"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release',
        function: 'set_subtitle',
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
 *
 * Note: core enforces no attribution requirement — credits live in the credits
 * extension and may be attached before or after publish via `uid_mut`.
 */
export function publish(options: PublishOptions) {
    const packageAddress = options.package ?? '@local-pkg/miso';
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
    const packageAddress = options.package ?? '@local-pkg/miso';
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
    const packageAddress = options.package ?? '@local-pkg/miso';
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
    const packageAddress = options.package ?? '@local-pkg/miso';
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
    const packageAddress = options.package ?? '@local-pkg/miso';
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
    const packageAddress = options.package ?? '@local-pkg/miso';
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
    const packageAddress = options.package ?? '@local-pkg/miso';
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
    const packageAddress = options.package ?? '@local-pkg/miso';
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
    const packageAddress = options.package ?? '@local-pkg/miso';
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
    const packageAddress = options.package ?? '@local-pkg/miso';
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
    const packageAddress = options.package ?? '@local-pkg/miso';
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
    const packageAddress = options.package ?? '@local-pkg/miso';
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
    const packageAddress = options.package ?? '@local-pkg/miso';
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
    const packageAddress = options.package ?? '@local-pkg/miso';
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
/**
 * Returns a mutable reference to the release's UID. Requires the admin capability.
 * Works in any lifecycle state — dynamic fields are the extension surface (e.g.
 * credits) and stay admin-mutable after publish; only the embedded fields are
 * frozen.
 */
export function uidMut(options: UidMutOptions) {
    const packageAddress = options.package ?? '@local-pkg/miso';
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