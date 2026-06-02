/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Represents cover artwork for releases and tracks in MusicOS. Supports both a
 * still image and optional animated artwork (GIFs, videos).
 * 
 * ### Key Features:
 * 
 * - Required still image for all cover art
 * - Optional animated version for enhanced presentation
 * - References external storage via Data type
 */

import { MoveStruct, normalizeMoveArguments } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction, type TransactionArgument } from '@mysten/sui/transactions';
import * as walrus_data from './deps/ori/walrus_data.js';
const $moduleName = '@local-pkg/musicos::cover_art';
export const CoverArt = new MoveStruct({ name: `${$moduleName}::CoverArt`, fields: {
        still: walrus_data.WalrusData,
        animated: bcs.option(walrus_data.WalrusData)
    } });
export interface NewArguments {
    still: TransactionArgument;
    animated: TransactionArgument;
}
export interface NewOptions {
    package?: string;
    arguments: NewArguments | [
        still: TransactionArgument,
        animated: TransactionArgument
    ];
}
/**
 * Creates new cover art with a still image and optional animated version.
 * `still` - Required still image data reference. `animated` - Optional animated
 * image/video data reference.
 */
export function _new(options: NewOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["still", "animated"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'cover_art',
        function: 'new',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface StillArguments {
    self: TransactionArgument;
}
export interface StillOptions {
    package?: string;
    arguments: StillArguments | [
        self: TransactionArgument
    ];
}
/** Returns a reference to the still image data. */
export function still(options: StillOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'cover_art',
        function: 'still',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface AnimatedArguments {
    self: TransactionArgument;
}
export interface AnimatedOptions {
    package?: string;
    arguments: AnimatedArguments | [
        self: TransactionArgument
    ];
}
/** Returns a reference to the optional animated artwork data. */
export function animated(options: AnimatedOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'cover_art',
        function: 'animated',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}