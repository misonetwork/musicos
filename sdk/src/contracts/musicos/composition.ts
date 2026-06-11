/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Represents a musical composition (song, instrumental work) in MusicOS.
 * Compositions are the underlying written works that recordings are based on. Each
 * composition has its own share token for ownership distribution.
 * 
 * ### Key Features:
 * 
 * - Share token initialization with fixed supply (10M tokens, 6 decimals)
 * - Party management with role assignments (Composer, Lyricist, Songwriter)
 * - State machine: Initialized -> Published (embedded fields immutable after
 *   publish; dynamic fields remain extensible via `uid_mut`)
 * - Deterministic addresses via derived object pattern
 */

import { MoveEnum, MoveTuple, MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction, type TransactionArgument } from '@mysten/sui/transactions';
import * as bps from './deps/bps/bps.js';
import * as vec_map from './deps/sui/vec_map.js';
import * as credit from './deps/partyos/credit.js';
import * as composition_party_role from './composition_party_role.js';
const $moduleName = '@local-pkg/musicos::composition';
/** Lifecycle state of a composition. */
export const CompositionState = new MoveEnum({ name: `${$moduleName}::CompositionState`, fields: {
        /** Composition is initialized but not published. */
        Initialized: null,
        /** Composition is published and immutable. Includes publication timestamp. */
        Published: bcs.u64()
    } });
export const CompositionRoyaltyRate = new MoveTuple({ name: `${$moduleName}::CompositionRoyaltyRate`, fields: [bps.BPS, bcs.u64()] });
export const Composition = new MoveStruct({ name: `${$moduleName}::Composition<phantom CompositionShare>`, fields: {
        /** Unique identifier for this composition. */
        id: bcs.Address,
        /** Current lifecycle state. */
        state: CompositionState,
        /** Primary title of the composition. */
        title: bcs.string(),
        /** Map of party IDs to their roles on this composition. */
        credits: vec_map.VecMap(bcs.Address, credit.Credit(composition_party_role.CompositionPartyRole)),
        /**
         * Royalty rate this composition earns from each recording's revenue, paired with
         * the epoch it was last changed in. Each rate stays in effect for at least one
         * full epoch.
         */
        royalty_rate: CompositionRoyaltyRate
    } });
export const CompositionAdminCap = new MoveStruct({ name: `${$moduleName}::CompositionAdminCap<phantom CompositionShare>`, fields: {
        /** Unique identifier for this capability. */
        id: bcs.Address
    } });
export const CompositionAdminCapKey = new MoveTuple({ name: `${$moduleName}::CompositionAdminCapKey`, fields: [bcs.bool()] });
export const CompositionPublishedEvent = new MoveStruct({ name: `${$moduleName}::CompositionPublishedEvent<phantom CompositionShare>`, fields: {
        composition_id: bcs.Address
    } });
export const CompositionRoyaltySetEvent = new MoveStruct({ name: `${$moduleName}::CompositionRoyaltySetEvent`, fields: {
        composition_id: bcs.Address,
        royalty_rate_bps: bcs.u16()
    } });
export interface NewArguments {
    title: RawTransactionArgument<string>;
    royaltyRateBps: RawTransactionArgument<number>;
    shareCurrency: RawTransactionArgument<string>;
    shareTreasuryCap: RawTransactionArgument<string>;
}
export interface NewOptions {
    package?: string;
    arguments: NewArguments | [
        title: RawTransactionArgument<string>,
        royaltyRateBps: RawTransactionArgument<number>,
        shareCurrency: RawTransactionArgument<string>,
        shareTreasuryCap: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Creates a new composition with the given title and royalty rate. The royalty
 * rate must be within `[MIN_ROYALTY_RATE_BPS, MAX_ROYALTY_RATE_BPS]`. Initializes
 * share tokens (10M supply, 6 decimals) and returns:
 *
 * - The composition object
 * - Admin capability for the owner
 * - Initial share token balance
 */
export function _new(options: NewOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        '0x1::string::String',
        'u16',
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["title", "royaltyRateBps", "shareCurrency", "shareTreasuryCap"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition',
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
        string
    ];
}
/**
 * Publishes the composition, making it immutable. Requires at least one party.
 * Required State: Initialized
 */
export function publish(options: PublishOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null,
        null,
        '0x2::clock::Clock'
    ] satisfies (string | null)[];
    const parameterNames = ["self", "_"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition',
        function: 'publish',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface AddCreditArguments {
    self: RawTransactionArgument<string>;
    _: RawTransactionArgument<string>;
    party: RawTransactionArgument<string>;
    credit: TransactionArgument;
}
export interface AddCreditOptions {
    package?: string;
    arguments: AddCreditArguments | [
        self: RawTransactionArgument<string>,
        _: RawTransactionArgument<string>,
        party: RawTransactionArgument<string>,
        credit: TransactionArgument
    ];
    typeArguments: [
        string
    ];
}
/**
 * Adds a party to the composition with specified roles. Each party must have 1-5
 * roles. Required State: Initialized
 */
export function addCredit(options: AddCreditOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null,
        null,
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "_", "party", "credit"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition',
        function: 'add_credit',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetRoyaltyRateArguments {
    self: RawTransactionArgument<string>;
    _: RawTransactionArgument<string>;
    royaltyRateBps: RawTransactionArgument<number>;
}
export interface SetRoyaltyRateOptions {
    package?: string;
    arguments: SetRoyaltyRateArguments | [
        self: RawTransactionArgument<string>,
        _: RawTransactionArgument<string>,
        royaltyRateBps: RawTransactionArgument<number>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Sets the royalty rate this composition earns from each recording. Must be within
 * `[MIN_ROYALTY_RATE_BPS, MAX_ROYALTY_RATE_BPS]`, and only after a full epoch has
 * elapsed since the last change — a rate set in epoch N is changeable from epoch
 * N+2 onward, so every rate is in effect for at least one complete epoch. The rate
 * can be changed in any lifecycle state, including after publishing — because each
 * recording snapshots the rate when it is created, a change only affects
 * recordings created afterward (existing recordings keep the rate they captured).
 */
export function setRoyaltyRate(options: SetRoyaltyRateOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null,
        null,
        'u16'
    ] satisfies (string | null)[];
    const parameterNames = ["self", "_", "royaltyRateBps"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition',
        function: 'set_royalty_rate',
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
        string
    ];
}
/** Returns the composition's object ID. */
export function id(options: IdOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition',
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
        string
    ];
}
/** Returns the current lifecycle state. */
export function state(options: StateOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition',
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
        string
    ];
}
/** Returns true if the composition is in the Initialized state. */
export function isInitializedState(options: IsInitializedStateOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition',
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
        string
    ];
}
/** Returns true if the composition is in the Published state. */
export function isPublishedState(options: IsPublishedStateOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition',
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
        string
    ];
}
/** Returns the primary title. */
export function title(options: TitleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition',
        function: 'title',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
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
    typeArguments: [
        string
    ];
}
/** Returns the party-to-credit mapping. */
export function credits(options: CreditsOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition',
        function: 'credits',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface RoyaltyRateArguments {
    self: RawTransactionArgument<string>;
}
export interface RoyaltyRateOptions {
    package?: string;
    arguments: RoyaltyRateArguments | [
        self: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns the royalty rate this composition earns from each recording. */
export function royaltyRate(options: RoyaltyRateOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition',
        function: 'royalty_rate',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface RoyaltyRateLastChangedEpochArguments {
    self: RawTransactionArgument<string>;
}
export interface RoyaltyRateLastChangedEpochOptions {
    package?: string;
    arguments: RoyaltyRateLastChangedEpochArguments | [
        self: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns the epoch in which the royalty rate was last changed. */
export function royaltyRateLastChangedEpoch(options: RoyaltyRateLastChangedEpochOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition',
        function: 'royalty_rate_last_changed_epoch',
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
        string
    ];
}
/** Returns a reference to the composition's UID for reading dynamic fields. */
export function uid(options: UidOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition',
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
        string
    ];
}
/**
 * Returns a mutable reference to the composition's UID. Requires the admin
 * capability. Works in any lifecycle state — dynamic fields are the extension
 * surface and stay admin-mutable after publish; only the embedded fields are
 * frozen.
 */
export function uidMut(options: UidMutOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "_"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition',
        function: 'uid_mut',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}