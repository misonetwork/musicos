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
 * A recording carries no name of its own. Its display title is its composition's
 * title, read by reference — composition titles are immutable, so an embedded copy
 * would carry no information. Anything that names this particular take — "(Live)",
 * "Radio Edit", a translated title — has more than one correct rendering, which
 * makes it presentation, and presentation lives in the metadata extension, never
 * in the frozen core. Core stores what a recording _is_; extensions describe it.
 * 
 * ### Lifecycle and trust model
 * 
 * A recording is `key`-only with no `drop`: a fresh `Initialized` object cannot be
 * transferred, wrapped, publicly shared, or discarded, and its only by-value
 * consumer is `publish`. Create-and-publish is therefore atomic by construction —
 * an `Initialized` recording cannot outlive its creating transaction, and every
 * recording that exists on-chain is `Published` and shared. There is deliberately
 * no keep function; staged building must fit one transaction.
 * 
 * `uid_mut` works in any lifecycle state and is permanent root over ALL dynamic
 * fields on the object — including fields attached by other extensions. "Immutable
 * after publish" covers the embedded fields only; extension-layer data stays
 * admin-mutable in perpetuity. This is the designed extension surface, and it is
 * the one trust assumption that never expires: integrators should model the cap
 * holder as able to mutate or delete any extension data, forever.
 * 
 * The recording carries its parent composition's identity as the
 * `CompositionShare` phantom type parameter — the composition's share type is its
 * durable identity (a share currency is published independently of miso and
 * survives a fresh republish, whereas an object ID does not). This makes the
 * recording↔composition lineage compile-time enforced wherever the two meet, and
 * it is the sole link: the composition's object id is not stored on the recording.
 * Off-chain consumers that need the composition object resolve its share type to
 * an id via `composition::CompositionPublishedEvent`, which binds the two.
 * 
 * A recording is its own freshly-created object (`object::new`), not a derived
 * child of its composition: `recording::new` takes a read-only `&Composition`
 * (only to read its royalty rate and id), so publishing recordings under a
 * composition neither contends on the composition's shared-object version nor
 * collides on a per-composition index.
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
        state: RecordingState
    } });
export const RecordingAdminCap = new MoveStruct({ name: `${$moduleName}::RecordingAdminCap<phantom RecordingShare>`, fields: {
        /** Unique identifier for this capability. */
        id: bcs.Address
    } });
export const RecordingAdminCapKey = new MoveTuple({ name: `${$moduleName}::RecordingAdminCapKey`, fields: [bcs.bool()] });
export const RecordingPublishedEvent = new MoveStruct({ name: `${$moduleName}::RecordingPublishedEvent<phantom RecordingShare, phantom CompositionShare>`, fields: {
        recording_id: bcs.Address
    } });
export const CompositionSharesGrantedEvent = new MoveStruct({ name: `${$moduleName}::CompositionSharesGrantedEvent<phantom RecordingShare, phantom CompositionShare>`, fields: {
        /** Recording-share base units granted to the composition. */
        value: bcs.u64(),
        /** The composition royalty rate applied at creation, in basis points. */
        rate_bps: bcs.u16()
    } });
export interface NewArguments {
    composition: RawTransactionArgument<string>;
    shareCurrency: RawTransactionArgument<string>;
    shareTreasuryCap: RawTransactionArgument<string>;
    maxRoyaltyRateBps: RawTransactionArgument<number>;
}
export interface NewOptions {
    package?: string;
    arguments: NewArguments | [
        composition: RawTransactionArgument<string>,
        shareCurrency: RawTransactionArgument<string>,
        shareTreasuryCap: RawTransactionArgument<string>,
        maxRoyaltyRateBps: RawTransactionArgument<number>
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
 * `max_royalty_rate_bps` is a slippage guard: `new` reads the composition's
 * royalty rate live off a shared object, so a composition owner could land a rate
 * increase in a transaction ordered just before this one and capture more of the
 * recording's shares than the recorder saw. The call aborts if the composition's
 * current rate exceeds `max_royalty_rate_bps`, so the recorder pins the most they
 * will grant (pass the rate they observed, or `2000` to accept up to the protocol
 * maximum).
 *
 * The composition need not be `Published`: within the composition's own creating
 * transaction its creator can already mint recordings against it. Third parties
 * only ever see `Published`, shared compositions (an `Initialized` one cannot
 * escape its creating transaction), so indexers may observe a recording created
 * "against an unpublished composition" only as an intra-transaction ordering,
 * never across transactions.
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
        null,
        null,
        'u16'
    ] satisfies (string | null)[];
    const parameterNames = ["composition", "shareCurrency", "shareTreasuryCap", "maxRoyaltyRateBps"];
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
 * embedded fields are frozen. The reference is root over every dynamic field on
 * the object, including fields attached by other extensions.
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