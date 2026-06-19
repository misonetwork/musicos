/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Represents an audio recording of a composition in Miso. Recordings are the audio
 * performances that are distributed and played. Each recording has its own share
 * token for ownership distribution.
 * 
 * ### Key Features:
 * 
 * - Share token initialization with fixed supply (10M tokens, 6 decimals)
 * - State machine: Initialized -> Published (embedded fields immutable after
 *   publish; dynamic fields remain extensible via `uid_mut`, e.g. masters, and
 *   credits/attribution attached by the credits extension)
 * - Deterministic addresses via derived object pattern
 * 
 * Attribution (credits, primary/featured artists) is intentionally NOT part of
 * core: it is display-oriented, varies across platforms, and is never read by the
 * economics. It lives in a first-party credits extension attached via `uid_mut`,
 * so core takes no dependency on an identity package and core publish enforces no
 * attribution.
 * 
 * The recording carries its parent composition's identity as the
 * `CompositionShare` phantom type parameter — the composition's share type is its
 * durable identity (a share currency is published independently of miso and
 * survives a fresh republish, whereas an object ID does not). This makes the
 * recording↔composition lineage compile-time enforced wherever the two meet, with
 * no stored `composition_id` to keep or assert.
 */

import { MoveEnum, MoveStruct, MoveTuple, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction } from '@mysten/sui/transactions';
const $moduleName = '@local-pkg/miso::recording';
/** Lifecycle state of a recording. */
export const RecordingState = new MoveEnum({ name: `${$moduleName}::RecordingState`, fields: {
        /** Recording is being set up and can be modified. */
        Initialized: null,
        /** Recording is published and immutable. Includes publication timestamp. */
        Published: bcs.u64()
    } });
export const Recording = new MoveStruct({ name: `${$moduleName}::Recording<phantom RecordingShare, phantom CompositionShare>`, fields: {
        /** Unique identifier for this recording. */
        id: bcs.Address,
        /** Current lifecycle state. */
        state: RecordingState,
        /** Primary title of the recording. */
        title: bcs.string(),
        /** Version suffix (e.g., "Radio Edit", "Extended Mix"). */
        title_version: bcs.option(bcs.string()),
        /** Subtitle of the recording. */
        subtitle: bcs.option(bcs.string())
    } });
export const RecordingAdminCap = new MoveStruct({ name: `${$moduleName}::RecordingAdminCap<phantom RecordingShare>`, fields: {
        /** Unique identifier for this capability. */
        id: bcs.Address
    } });
export const RecordingAdminCapKey = new MoveTuple({ name: `${$moduleName}::RecordingAdminCapKey`, fields: [bcs.bool()] });
export const RecordingKey = new MoveTuple({ name: `${$moduleName}::RecordingKey`, fields: [bcs.u64()] });
export const RecordingPublishedEvent = new MoveStruct({ name: `${$moduleName}::RecordingPublishedEvent<phantom RecordingShare, phantom CompositionShare>`, fields: {
        recording_id: bcs.Address
    } });
export const CompositionSharesGrantedEvent = new MoveStruct({ name: `${$moduleName}::CompositionSharesGrantedEvent<phantom RecordingShare, phantom CompositionShare>`, fields: {
        recording_id: bcs.Address,
        composition_id: bcs.Address,
        /** Recording-share base units granted to the composition. */
        value: bcs.u64(),
        /** The composition royalty rate applied at creation, in basis points. */
        rate_bps: bcs.u16()
    } });
export interface NewArguments {
    composition: RawTransactionArgument<string>;
    idx: RawTransactionArgument<number | bigint>;
    shareCurrency: RawTransactionArgument<string>;
    shareTreasuryCap: RawTransactionArgument<string>;
}
export interface NewOptions {
    package?: string;
    arguments: NewArguments | [
        composition: RawTransactionArgument<string>,
        idx: RawTransactionArgument<number | bigint>,
        shareCurrency: RawTransactionArgument<string>,
        shareTreasuryCap: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/**
 * Creates a new recording for a composition.
 *
 * Initializes share tokens (10M supply, 6 decimals), then splits the composition's
 * royalty-rate worth of those shares off the freshly minted supply and
 * `send_funds`es them to the composition's address. This settles the composition's
 * cut as cap-table ownership: the composition literally owns its share of the
 * recording, so its claim on recording revenue is enforced by share ownership
 * rather than by any revenue distributor choosing to honor a rate. What the
 * composition owner then does with the shares (hold, stake, sell) is outside the
 * protocol's scope.
 *
 * Returns:
 *
 * - The recording object (typed to its parent composition's `CompositionShare`)
 * - Admin capability for the owner
 * - The creator's remaining share balance (full supply minus the composition's
 *   cut)
 */
export function _new(options: NewOptions) {
    const packageAddress = options.package ?? '@local-pkg/miso';
    const argumentsTypes = [
        null,
        'u64',
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["composition", "idx", "shareCurrency", "shareTreasuryCap"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording',
        function: 'new',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface PublishArguments {
    self: RawTransactionArgument<string>;
    _: RawTransactionArgument<string>;
}
export interface PublishOptions {
    package?: string;
    arguments: PublishArguments | [
        self: RawTransactionArgument<string>,
        _: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/**
 * Publishes the recording, making its embedded fields immutable. Required State:
 * Initialized
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
    const parameterNames = ["self", "_"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording',
        function: 'publish',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetTitleVersionArguments {
    self: RawTransactionArgument<string>;
    _: RawTransactionArgument<string>;
    titleVersion: RawTransactionArgument<string>;
}
export interface SetTitleVersionOptions {
    package?: string;
    arguments: SetTitleVersionArguments | [
        self: RawTransactionArgument<string>,
        _: RawTransactionArgument<string>,
        titleVersion: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/**
 * Sets the title version (e.g., "Radio Edit", "Extended Mix"). Required State:
 * Initialized
 */
export function setTitleVersion(options: SetTitleVersionOptions) {
    const packageAddress = options.package ?? '@local-pkg/miso';
    const argumentsTypes = [
        null,
        null,
        '0x1::string::String'
    ] satisfies (string | null)[];
    const parameterNames = ["self", "_", "titleVersion"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording',
        function: 'set_title_version',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetSubtitleArguments {
    self: RawTransactionArgument<string>;
    _: RawTransactionArgument<string>;
    subtitle: RawTransactionArgument<string>;
}
export interface SetSubtitleOptions {
    package?: string;
    arguments: SetSubtitleArguments | [
        self: RawTransactionArgument<string>,
        _: RawTransactionArgument<string>,
        subtitle: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/** Sets the subtitle of the recording. Required State: Initialized */
export function setSubtitle(options: SetSubtitleOptions) {
    const packageAddress = options.package ?? '@local-pkg/miso';
    const argumentsTypes = [
        null,
        null,
        '0x1::string::String'
    ] satisfies (string | null)[];
    const parameterNames = ["self", "_", "subtitle"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording',
        function: 'set_subtitle',
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
/** Returns the recording's object ID. */
export function id(options: IdOptions) {
    const packageAddress = options.package ?? '@local-pkg/miso';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording',
        function: 'id',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
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
    typeArguments: [
        string,
        string
    ];
}
/** Returns the current lifecycle state. */
export function state(options: StateOptions) {
    const packageAddress = options.package ?? '@local-pkg/miso';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording',
        function: 'state',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
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
    typeArguments: [
        string,
        string
    ];
}
/** Returns true if the recording is in the Initialized state. */
export function isInitializedState(options: IsInitializedStateOptions) {
    const packageAddress = options.package ?? '@local-pkg/miso';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording',
        function: 'is_initialized_state',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
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
    typeArguments: [
        string,
        string
    ];
}
/** Returns true if the recording is in the Published state. */
export function isPublishedState(options: IsPublishedStateOptions) {
    const packageAddress = options.package ?? '@local-pkg/miso';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording',
        function: 'is_published_state',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
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
    typeArguments: [
        string,
        string
    ];
}
/** Returns the primary title. */
export function title(options: TitleOptions) {
    const packageAddress = options.package ?? '@local-pkg/miso';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording',
        function: 'title',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface TitleVersionArguments {
    self: RawTransactionArgument<string>;
}
export interface TitleVersionOptions {
    package?: string;
    arguments: TitleVersionArguments | [
        self: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/** Returns the optional title version. */
export function titleVersion(options: TitleVersionOptions) {
    const packageAddress = options.package ?? '@local-pkg/miso';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording',
        function: 'title_version',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
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
    typeArguments: [
        string,
        string
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
        module: 'recording',
        function: 'subtitle',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
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
    typeArguments: [
        string,
        string
    ];
}
/** Returns a reference to the recording's UID for reading dynamic fields. */
export function uid(options: UidOptions) {
    const packageAddress = options.package ?? '@local-pkg/miso';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording',
        function: 'uid',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface UidMutArguments {
    self: RawTransactionArgument<string>;
    _: RawTransactionArgument<string>;
}
export interface UidMutOptions {
    package?: string;
    arguments: UidMutArguments | [
        self: RawTransactionArgument<string>,
        _: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/**
 * Returns a mutable reference to the recording's UID. Requires the admin
 * capability. Works in any lifecycle state — dynamic fields are the extension
 * surface (e.g. masters, credits) and stay admin-mutable after publish; only the
 * embedded fields are frozen.
 */
export function uidMut(options: UidMutOptions) {
    const packageAddress = options.package ?? '@local-pkg/miso';
    const argumentsTypes = [
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "_"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording',
        function: 'uid_mut',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}