/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Represents a disc within a release, containing an ordered list of tracks.
 * Multi-disc releases (like double albums) are modeled as multiple Disc objects.
 * 
 * ### Key Features:
 * 
 * - Maximum of 50 tracks per disc
 * - Automatic duration calculation from tracks
 * - Optional disc-specific artwork
 */

import { MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction, type TransactionArgument } from '@mysten/sui/transactions';
import * as track from './track.js';
import * as cover_art from './cover_art.js';
const $moduleName = '@local-pkg/musicos::disc';
export const Disc = new MoveStruct({ name: `${$moduleName}::Disc`, fields: {
        /** Ordered list of tracks on this disc. */
        tracks: bcs.vector(track.Track),
        /**
         * Optional disc-specific artwork (e.g., for multi-disc sets with different
         * covers).
         */
        artwork: bcs.option(cover_art.CoverArt),
        /** Title of the disc. */
        title: bcs.option(bcs.string()),
        /** Total duration of all tracks in milliseconds. */
        duration_ms: bcs.u64()
    } });
export interface NewArguments {
    tracks: TransactionArgument;
    title: RawTransactionArgument<string | null>;
}
export interface NewOptions {
    package?: string;
    arguments: NewArguments | [
        tracks: TransactionArgument,
        title: RawTransactionArgument<string | null>
    ];
}
/**
 * Creates a new disc from a vector of tracks. Automatically calculates the total
 * duration. Aborts if more than 50 tracks are provided.
 */
export function _new(options: NewOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        'vector<null>',
        '0x1::option::Option<0x1::string::String>'
    ] satisfies (string | null)[];
    const parameterNames = ["tracks", "title"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'disc',
        function: 'new',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface SetArtworkArguments {
    self: TransactionArgument;
    artwork: TransactionArgument;
}
export interface SetArtworkOptions {
    package?: string;
    arguments: SetArtworkArguments | [
        self: TransactionArgument,
        artwork: TransactionArgument
    ];
}
/** Sets or updates the disc-specific artwork. */
export function setArtwork(options: SetArtworkOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "artwork"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'disc',
        function: 'set_artwork',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface TracksArguments {
    self: TransactionArgument;
}
export interface TracksOptions {
    package?: string;
    arguments: TracksArguments | [
        self: TransactionArgument
    ];
}
/** Returns a reference to all tracks on this disc. */
export function tracks(options: TracksOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'disc',
        function: 'tracks',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface ArtworkArguments {
    self: TransactionArgument;
}
export interface ArtworkOptions {
    package?: string;
    arguments: ArtworkArguments | [
        self: TransactionArgument
    ];
}
/** Returns the optional disc-specific artwork. */
export function artwork(options: ArtworkOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'disc',
        function: 'artwork',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface DurationMsArguments {
    self: TransactionArgument;
}
export interface DurationMsOptions {
    package?: string;
    arguments: DurationMsArguments | [
        self: TransactionArgument
    ];
}
/** Returns the total duration of this disc in milliseconds. */
export function durationMs(options: DurationMsOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'disc',
        function: 'duration_ms',
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
/** Returns the optional title of this disc. */
export function title(options: TitleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'disc',
        function: 'title',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}