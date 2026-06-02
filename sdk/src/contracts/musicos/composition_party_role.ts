/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Defines the roles that parties can hold on a composition. Compositions are the
 * written musical works (songs, instrumentals), and these roles represent the
 * creative contributions to that work.
 * 
 * Available roles:
 * 
 * - Composer: Created the music/melody
 * - Lyricist: Wrote the lyrics/words
 * - Songwriter: Contributed to both music and lyrics
 */

import { MoveEnum, normalizeMoveArguments } from '../utils/index.js';
import { type Transaction, type TransactionArgument } from '@mysten/sui/transactions';
const $moduleName = '@local-pkg/musicos::composition_party_role';
/** Represents a party's role on a composition. */
export const CompositionPartyRole = new MoveEnum({ name: `${$moduleName}::CompositionPartyRole`, fields: {
        /** Adapted the musical composition for a specific instrument or voice. */
        Adapter: null,
        /** Arranged the musical composition. */
        Arranger: null,
        /** Created the musical composition (melody, harmony, structure). */
        Composer: null,
        /** Wrote the lyrics/words for the composition. */
        Lyricist: null,
        /** Contributed to both the music and lyrics. */
        Songwriter: null,
        /** Translated the musical composition into a different language. */
        Translator: null
    } });
export interface NewAdapterRoleOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a new Adapter role. */
export function newAdapterRole(options: NewAdapterRoleOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition_party_role',
        function: 'new_adapter_role',
    });
}
export interface NewArrangerRoleOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a new Arranger role. */
export function newArrangerRole(options: NewArrangerRoleOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition_party_role',
        function: 'new_arranger_role',
    });
}
export interface NewComposerRoleOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a new Composer role. */
export function newComposerRole(options: NewComposerRoleOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition_party_role',
        function: 'new_composer_role',
    });
}
export interface NewLyricistRoleOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a new Lyricist role. */
export function newLyricistRole(options: NewLyricistRoleOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition_party_role',
        function: 'new_lyricist_role',
    });
}
export interface NewSongwriterRoleOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a new Songwriter role. */
export function newSongwriterRole(options: NewSongwriterRoleOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition_party_role',
        function: 'new_songwriter_role',
    });
}
export interface NewTranslatorRoleOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a new Translator role. */
export function newTranslatorRole(options: NewTranslatorRoleOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition_party_role',
        function: 'new_translator_role',
    });
}
export interface NameArguments {
    self: TransactionArgument;
}
export interface NameOptions {
    package?: string;
    arguments: NameArguments | [
        self: TransactionArgument
    ];
}
/** Returns the human-readable name of the role. */
export function name(options: NameOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition_party_role',
        function: 'name',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsAdapterRoleArguments {
    self: TransactionArgument;
}
export interface IsAdapterRoleOptions {
    package?: string;
    arguments: IsAdapterRoleArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is an Adapter role. */
export function isAdapterRole(options: IsAdapterRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition_party_role',
        function: 'is_adapter_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsArrangerRoleArguments {
    self: TransactionArgument;
}
export interface IsArrangerRoleOptions {
    package?: string;
    arguments: IsArrangerRoleArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is an Arranger role. */
export function isArrangerRole(options: IsArrangerRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition_party_role',
        function: 'is_arranger_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsComposerRoleArguments {
    self: TransactionArgument;
}
export interface IsComposerRoleOptions {
    package?: string;
    arguments: IsComposerRoleArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is a Composer role. */
export function isComposerRole(options: IsComposerRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition_party_role',
        function: 'is_composer_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsLyricistRoleArguments {
    self: TransactionArgument;
}
export interface IsLyricistRoleOptions {
    package?: string;
    arguments: IsLyricistRoleArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is a Lyricist role. */
export function isLyricistRole(options: IsLyricistRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition_party_role',
        function: 'is_lyricist_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsSongwriterRoleArguments {
    self: TransactionArgument;
}
export interface IsSongwriterRoleOptions {
    package?: string;
    arguments: IsSongwriterRoleArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is a Songwriter role. */
export function isSongwriterRole(options: IsSongwriterRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition_party_role',
        function: 'is_songwriter_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsTranslatorRoleArguments {
    self: TransactionArgument;
}
export interface IsTranslatorRoleOptions {
    package?: string;
    arguments: IsTranslatorRoleArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is a Translator role. */
export function isTranslatorRole(options: IsTranslatorRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition_party_role',
        function: 'is_translator_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}