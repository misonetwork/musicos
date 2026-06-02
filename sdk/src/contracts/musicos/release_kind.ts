/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/
import { MoveEnum, normalizeMoveArguments } from '../utils/index.js';
import { type Transaction, type TransactionArgument } from '@mysten/sui/transactions';
const $moduleName = '@local-pkg/musicos::release_kind';
export const ReleaseKind = new MoveEnum({ name: `${$moduleName}::ReleaseKind`, fields: {
        Album: null,
        ExtendedPlay: null,
        Single: null
    } });
export interface NewAlbumKindOptions {
    package?: string;
    arguments?: [
    ];
}
export function newAlbumKind(options: NewAlbumKindOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release_kind',
        function: 'new_album_kind',
    });
}
export interface NewExtendedPlayKindOptions {
    package?: string;
    arguments?: [
    ];
}
export function newExtendedPlayKind(options: NewExtendedPlayKindOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release_kind',
        function: 'new_extended_play_kind',
    });
}
export interface NewSingleKindOptions {
    package?: string;
    arguments?: [
    ];
}
export function newSingleKind(options: NewSingleKindOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release_kind',
        function: 'new_single_kind',
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
export function name(options: NameOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release_kind',
        function: 'name',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}