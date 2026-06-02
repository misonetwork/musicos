/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Represents cover artwork for releases and tracks in MusicOS. Supports both
 * static images and optional animated artwork (GIFs, videos).
 * 
 * ### Key Features:
 * 
 * - Required static image for all cover art
 * - Optional animated version for enhanced presentation
 * - References external storage via Data type
 */

import { MoveStruct, normalizeMoveArguments } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction, type TransactionArgument } from '@mysten/sui/transactions';
import * as walrus_data from './deps/ori/walrus_data.js';
const $moduleName = '@local-pkg/musicos::cover_art';
export const CoverArt = new MoveStruct({ name: `${$moduleName}::CoverArt`, fields: {
        static: walrus_data.WalrusData,
        animated: bcs.option(walrus_data.WalrusData)
    } });
export interface NewArguments {
    static: TransactionArgument;
    animated: TransactionArgument;
}
export interface NewOptions {
    package?: string;
    arguments: NewArguments | [
        static_: TransactionArgument,
        animated: TransactionArgument
    ];
}
/**
 * Creates new cover art with a static image and optional animated version.
 * `static` - Required static image data reference. `animated` - Optional animated
 * image/video data reference.
 */
export function _new(options: NewOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["static", "animated"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'cover_art',
        function: 'new',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface StaticArguments {
    self: TransactionArgument;
}
export interface StaticOptions {
    package?: string;
    arguments: StaticArguments | [
        self: TransactionArgument
    ];
}
/** Returns a reference to the static image data. */
export function static_(options: StaticOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'cover_art',
        function: 'static',
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