/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Defines the roles that parties can hold on a release. Releases support two
 * roles: Primary (the main artist) and Featured (a guest or collaborating artist).
 */

import { MoveEnum, normalizeMoveArguments } from '../utils/index.js';
import { type Transaction, type TransactionArgument } from '@mysten/sui/transactions';
const $moduleName = '@local-pkg/musicos::release_party_role';
/** Represents a party's role on a release. */
export const ReleasePartyRole = new MoveEnum({ name: `${$moduleName}::ReleasePartyRole`, fields: {
        Primary: null,
        Featured: null
    } });
export interface NewPrimaryRoleOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a new primary role. */
export function newPrimaryRole(options: NewPrimaryRoleOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release_party_role',
        function: 'new_primary_role',
    });
}
export interface NewFeaturedRoleOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a new featured role. */
export function newFeaturedRole(options: NewFeaturedRoleOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release_party_role',
        function: 'new_featured_role',
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
        module: 'release_party_role',
        function: 'name',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsPrimaryRoleArguments {
    self: TransactionArgument;
}
export interface IsPrimaryRoleOptions {
    package?: string;
    arguments: IsPrimaryRoleArguments | [
        self: TransactionArgument
    ];
}
/** Checks if the role is a primary role. */
export function isPrimaryRole(options: IsPrimaryRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release_party_role',
        function: 'is_primary_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsFeaturedRoleArguments {
    self: TransactionArgument;
}
export interface IsFeaturedRoleOptions {
    package?: string;
    arguments: IsFeaturedRoleArguments | [
        self: TransactionArgument
    ];
}
/** Checks if the role is a featured role. */
export function isFeaturedRole(options: IsFeaturedRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release_party_role',
        function: 'is_featured_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}