/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Represents an audio recording of a composition in MusicOS. Recordings are the
 * audio performances that are distributed and played. Each recording has its own
 * share token for ownership distribution.
 * 
 * ### Key Features:
 * 
 * - Share token initialization with fixed supply (100M tokens, 6 decimals)
 * - Party management with role assignments (Producer, Vocalist, etc.)
 * - State machine: Initialized -> Published (immutable after publish)
 * - Deterministic addresses via derived object pattern
 */

import { MoveEnum, MoveStruct, MoveTuple, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction, type TransactionArgument } from '@mysten/sui/transactions';
import * as bps from './deps/bps/bps.js';
import * as vec_set from './deps/sui/vec_set.js';
import * as vec_map from './deps/sui/vec_map.js';
import * as credit from './deps/partyos/credit.js';
import * as recording_party_role from './recording_party_role.js';
import * as language_code from './deps/gengo/language_code.js';
import * as audio from './deps/audio/audio.js';
import * as cover_art from './cover_art.js';
import * as type_name from './deps/std/type_name.js';
const $moduleName = '@local-pkg/musicos::recording';
/** Lifecycle state of a recording. */
export const RecordingState = new MoveEnum({ name: `${$moduleName}::RecordingState`, fields: {
        /** Recording is being set up and can be modified. */
        Initialized: null,
        /** Recording is published and immutable. Includes publication timestamp. */
        Published: bcs.u64()
    } });
export const Recording = new MoveStruct({ name: `${$moduleName}::Recording<phantom RecordingShare>`, fields: {
        /** Unique identifier for this recording. */
        id: bcs.Address,
        /** Current lifecycle state. */
        state: RecordingState,
        /** Primary title of the recording. */
        title: bcs.string(),
        /** Version suffix (e.g., "Radio Edit", "Extended Mix"). */
        title_version: bcs.option(bcs.string()),
        /** Subtitle of the recording. */
        subtitle: bcs.option(bcs.string()),
        /** ID of the underlying composition. */
        composition_id: bcs.Address,
        /**
         * Royalty rate owed to the composition (captured from the composition at creation
         * time).
         */
        composition_royalty_rate: bps.BPS,
        primary_artist_ids: vec_set.VecSet(bcs.Address),
        featured_artist_ids: vec_set.VecSet(bcs.Address),
        /** Map of party IDs to their roles on this recording. */
        credits: vec_map.VecMap(bcs.Address, credit.Credit(recording_party_role.RecordingPartyRole)),
        /** Language of the vocals (if any). */
        language: bcs.option(language_code.LanguageCode),
        /** Whether the recording contains explicit content. */
        is_explicit: bcs.bool(),
        /** Whether the recording is instrumental (no vocals). */
        is_instrumental: bcs.bool(),
        /** The final mixed/mastered audio file. */
        master: audio.Audio,
        /** Cover art for the recording. */
        cover_art: cover_art.CoverArt
    } });
export const RecordingAdminCap = new MoveStruct({ name: `${$moduleName}::RecordingAdminCap<phantom RecordingShare>`, fields: {
        /** Unique identifier for this capability. */
        id: bcs.Address
    } });
export const RecordingAdminCapKey = new MoveTuple({ name: `${$moduleName}::RecordingAdminCapKey`, fields: [bcs.bool()] });
export const RecordingKey = new MoveTuple({ name: `${$moduleName}::RecordingKey`, fields: [bcs.u256(), type_name.TypeName] });
export const RecordingPublishedEvent = new MoveStruct({ name: `${$moduleName}::RecordingPublishedEvent<phantom RecordingShare>`, fields: {
        recording_id: bcs.Address,
        composition_id: bcs.Address
    } });
export interface NewArguments {
    composition: RawTransactionArgument<string>;
    isExplicit: RawTransactionArgument<boolean>;
    isInstrumental: RawTransactionArgument<boolean>;
    master: TransactionArgument;
    coverArt: TransactionArgument;
    shareCurrency: RawTransactionArgument<string>;
    shareTreasuryCap: RawTransactionArgument<string>;
}
export interface NewOptions {
    package?: string;
    arguments: NewArguments | [
        composition: RawTransactionArgument<string>,
        isExplicit: RawTransactionArgument<boolean>,
        isInstrumental: RawTransactionArgument<boolean>,
        master: TransactionArgument,
        coverArt: TransactionArgument,
        shareCurrency: RawTransactionArgument<string>,
        shareTreasuryCap: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/**
 * Creates a new recording for a composition. Initializes share tokens (100M
 * supply, 6 decimals) and returns:
 *
 * - The recording object
 * - Admin capability for the owner
 * - Initial share token balance
 * - Promise that must be consumed by calling `share()`
 */
export function _new(options: NewOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null,
        'bool',
        'bool',
        null,
        null,
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["composition", "isExplicit", "isInstrumental", "master", "coverArt", "shareCurrency", "shareTreasuryCap"];
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
        string
    ];
}
/**
 * Publishes the recording, making it immutable. Requires at least one party to be
 * assigned. Required State: Initialized
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
        string
    ];
}
/**
 * Sets the title version (e.g., "Radio Edit", "Extended Mix"). Required State:
 * Initialized
 */
export function setTitleVersion(options: SetTitleVersionOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
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
        string
    ];
}
/** Sets the subtitle of the recording. Required State: Initialized */
export function setSubtitle(options: SetSubtitleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
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
export interface SetLanguageArguments {
    self: RawTransactionArgument<string>;
    _: RawTransactionArgument<string>;
    languageCode: RawTransactionArgument<string>;
}
export interface SetLanguageOptions {
    package?: string;
    arguments: SetLanguageArguments | [
        self: RawTransactionArgument<string>,
        _: RawTransactionArgument<string>,
        languageCode: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Sets the language of the recording. Required State: Initialized */
export function setLanguage(options: SetLanguageOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null,
        null,
        '0x1::string::String'
    ] satisfies (string | null)[];
    const parameterNames = ["self", "_", "languageCode"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording',
        function: 'set_language',
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
 * Adds a party to the recording with specified roles. Each party must have 1-10
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
        module: 'recording',
        function: 'add_credit',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface AddPrimaryArtistArguments {
    self: RawTransactionArgument<string>;
    _: RawTransactionArgument<string>;
    party: RawTransactionArgument<string>;
}
export interface AddPrimaryArtistOptions {
    package?: string;
    arguments: AddPrimaryArtistArguments | [
        self: RawTransactionArgument<string>,
        _: RawTransactionArgument<string>,
        party: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Adds a party as a primary artist on the recording. The party must already be
 * credited and not already assigned as primary or featured. Required State:
 * Initialized
 */
export function addPrimaryArtist(options: AddPrimaryArtistOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null,
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "_", "party"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording',
        function: 'add_primary_artist',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface AddFeaturedArtistArguments {
    self: RawTransactionArgument<string>;
    _: RawTransactionArgument<string>;
    party: RawTransactionArgument<string>;
}
export interface AddFeaturedArtistOptions {
    package?: string;
    arguments: AddFeaturedArtistArguments | [
        self: RawTransactionArgument<string>,
        _: RawTransactionArgument<string>,
        party: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Adds a party as a featured artist on the recording. The party must already be
 * credited and not already assigned as primary or featured. Required State:
 * Initialized
 */
export function addFeaturedArtist(options: AddFeaturedArtistOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null,
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "_", "party"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording',
        function: 'add_featured_artist',
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
/** Returns the recording's object ID. */
export function id(options: IdOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
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
        string
    ];
}
/** Returns true if the recording is in the Initialized state. */
export function isInitializedState(options: IsInitializedStateOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
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
        string
    ];
}
/** Returns true if the recording is in the Published state. */
export function isPublishedState(options: IsPublishedStateOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
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
        string
    ];
}
/** Returns the optional title version. */
export function titleVersion(options: TitleVersionOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
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
        string
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
        module: 'recording',
        function: 'subtitle',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
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
    typeArguments: [
        string
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
        module: 'recording',
        function: 'composition_id',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
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
    typeArguments: [
        string
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
        module: 'recording',
        function: 'composition_royalty_rate',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface PrimaryArtistIdsArguments {
    self: RawTransactionArgument<string>;
}
export interface PrimaryArtistIdsOptions {
    package?: string;
    arguments: PrimaryArtistIdsArguments | [
        self: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns a reference to the primary artist IDs. */
export function primaryArtistIds(options: PrimaryArtistIdsOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording',
        function: 'primary_artist_ids',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface FeaturedArtistIdsArguments {
    self: RawTransactionArgument<string>;
}
export interface FeaturedArtistIdsOptions {
    package?: string;
    arguments: FeaturedArtistIdsArguments | [
        self: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns a reference to the featured artist IDs. */
export function featuredArtistIds(options: FeaturedArtistIdsOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording',
        function: 'featured_artist_ids',
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
/** Returns the party-to-roles mapping. */
export function credits(options: CreditsOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording',
        function: 'credits',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface LanguageArguments {
    self: RawTransactionArgument<string>;
}
export interface LanguageOptions {
    package?: string;
    arguments: LanguageArguments | [
        self: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns the optional language code. */
export function language(options: LanguageOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording',
        function: 'language',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface IsExplicitArguments {
    self: RawTransactionArgument<string>;
}
export interface IsExplicitOptions {
    package?: string;
    arguments: IsExplicitArguments | [
        self: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns whether the recording contains explicit content. */
export function isExplicit(options: IsExplicitOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording',
        function: 'is_explicit',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface IsInstrumentalArguments {
    self: RawTransactionArgument<string>;
}
export interface IsInstrumentalOptions {
    package?: string;
    arguments: IsInstrumentalArguments | [
        self: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns whether the recording is instrumental. */
export function isInstrumental(options: IsInstrumentalOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording',
        function: 'is_instrumental',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface MasterArguments {
    self: RawTransactionArgument<string>;
}
export interface MasterOptions {
    package?: string;
    arguments: MasterArguments | [
        self: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns a reference to the master audio file. */
export function master(options: MasterOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording',
        function: 'master',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface MasterIngesterTypeArguments {
    self: RawTransactionArgument<string>;
}
export interface MasterIngesterTypeOptions {
    package?: string;
    arguments: MasterIngesterTypeArguments | [
        self: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns the ingester type of the recording's master audio file. */
export function masterIngesterType(options: MasterIngesterTypeOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording',
        function: 'master_ingester_type',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
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
    typeArguments: [
        string
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
        module: 'recording',
        function: 'cover_art',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface IsPrimaryArtistArguments {
    self: RawTransactionArgument<string>;
    partyId: RawTransactionArgument<string>;
}
export interface IsPrimaryArtistOptions {
    package?: string;
    arguments: IsPrimaryArtistArguments | [
        self: RawTransactionArgument<string>,
        partyId: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns whether the provided ID is a primary artist on the recording. */
export function isPrimaryArtist(options: IsPrimaryArtistOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null,
        '0x2::object::ID'
    ] satisfies (string | null)[];
    const parameterNames = ["self", "partyId"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording',
        function: 'is_primary_artist',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface IsFeaturedArtistArguments {
    self: RawTransactionArgument<string>;
    partyId: RawTransactionArgument<string>;
}
export interface IsFeaturedArtistOptions {
    package?: string;
    arguments: IsFeaturedArtistArguments | [
        self: RawTransactionArgument<string>,
        partyId: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns whether the party is a featured artist on the recording. */
export function isFeaturedArtist(options: IsFeaturedArtistOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null,
        '0x2::object::ID'
    ] satisfies (string | null)[];
    const parameterNames = ["self", "partyId"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording',
        function: 'is_featured_artist',
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
/** Returns a reference to the recording's UID for reading dynamic fields. */
export function uid(options: UidOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
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
        string
    ];
}
/**
 * Returns a mutable reference to the recording's UID. Requires the admin
 * capability.
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
        module: 'recording',
        function: 'uid_mut',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}