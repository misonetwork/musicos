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
 * 
 * Artwork is intentionally NOT part of core: it is display metadata whose format
 * evolves over time (static → animated → future formats), so it lives in the
 * `artwork` extension (keyed by disc index on the release) rather than frozen in
 * an immutable struct here.
 */

import { MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction, type TransactionArgument } from '@mysten/sui/transactions';
import * as track from './track.js';
const $moduleName = '@local-pkg/miso::disc';
export const Disc = new MoveStruct({ name: `${$moduleName}::Disc`, fields: {
        /** Ordered list of tracks on this disc. */
        tracks: bcs.vector(track.Track),
        /** Title of the disc. */
        title: bcs.option(bcs.string())
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
 * Creates a new disc from a vector of tracks. Aborts if more than 50 tracks are
 * provided, or if a title is provided that is empty or longer than 300 bytes.
 * Discs are embedded in a release and frozen at publish, so the title must be
 * valid at construction.
 */
export function _new(options: NewOptions) {
    const packageAddress = options.package ?? '@local-pkg/miso';
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
    const packageAddress = options.package ?? '@local-pkg/miso';
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
    const packageAddress = options.package ?? '@local-pkg/miso';
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