/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Defines the roles that parties can hold on a recording. Recordings are audio
 * performances of compositions, and these roles represent the various production
 * and performance contributions.
 * 
 * Most roles support an optional level (Lead, Assistant, etc.) to indicate the
 * party's seniority or prominence on the recording.
 */

import { MoveEnum, MoveTuple, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction, type TransactionArgument } from '@mysten/sui/transactions';
const $moduleName = '@local-pkg/musicos::recording_party_role';
/** Indicates the seniority or prominence level of a party. */
export const RecordingPartyRoleLevel = new MoveEnum({ name: `${$moduleName}::RecordingPartyRoleLevel`, fields: {
        /** Additional/supplementary party. */
        Additional: null,
        /** Assistant to the primary party. */
        Assistant: null,
        /** Associate-level party. */
        Associate: null,
        /** Backing/support role (e.g., backing vocals). */
        Backing: null,
        /** Executive-level oversight role. */
        Executive: null,
        /** Featured prominently on the recording. */
        Featured: null,
        /** Lead/primary party in this role. */
        Lead: null,
        /** Primary artist on the recording. */
        Primary: null,
        /** Principal party with primary responsibility. */
        Principal: null
    } });
/**
 * Represents a party's role on a recording. Most roles include an optional level
 * to indicate seniority.
 */
export const RecordingPartyRole = new MoveEnum({ name: `${$moduleName}::RecordingPartyRole`, fields: {
        /** Performed voice acting or spoken word performance. */
        Actor: bcs.option(RecordingPartyRoleLevel),
        /** Arranged the musical parts for the recording. */
        Arranger: bcs.option(RecordingPartyRoleLevel),
        /** A&R representative who discovered or developed the artist. */
        ArtistsAndRepertoire: null,
        /** Performed as part of a choir. */
        Choir: bcs.option(RecordingPartyRoleLevel),
        /** Directed the choir performance. */
        ChoirMaster: bcs.option(RecordingPartyRoleLevel),
        /** Conducted the orchestra or ensemble. */
        Conductor: bcs.option(RecordingPartyRoleLevel),
        /** Hired and managed session musicians. */
        Contractor: bcs.option(RecordingPartyRoleLevel),
        /** Prepared written music parts for performers. */
        Copyist: null,
        /** Edited and compiled audio takes. */
        Editor: bcs.option(RecordingPartyRoleLevel),
        /** Performed as part of a musical ensemble. */
        Ensemble: bcs.option(RecordingPartyRoleLevel),
        /** Played an instrument on the recording. Includes instrument name. */
        Instrumentalist: new MoveTuple({ name: `RecordingPartyRole.Instrumentalist`, fields: [bcs.string(), bcs.option(RecordingPartyRoleLevel)] }),
        /** Mastered the final audio for distribution. */
        MasteringEngineer: bcs.option(RecordingPartyRoleLevel),
        /** Mixed the multitrack recording into stereo/surround. */
        MixingEngineer: bcs.option(RecordingPartyRoleLevel),
        /** Directed the musical performance. */
        MusicDirector: bcs.option(RecordingPartyRoleLevel),
        /** Oversaw music selection and licensing. */
        MusicSupervisor: bcs.option(RecordingPartyRoleLevel),
        /** Narrated spoken content. */
        Narrator: bcs.option(RecordingPartyRoleLevel),
        /** Performed as part of an orchestra. */
        Orchestra: bcs.option(RecordingPartyRoleLevel),
        /** Created orchestral arrangements. */
        Orchestrator: bcs.option(RecordingPartyRoleLevel),
        /** Oversaw the creative and technical aspects of the recording. */
        Producer: bcs.option(RecordingPartyRoleLevel),
        /** Programmed beats, synths, or electronic elements. */
        Programmer: bcs.option(RecordingPartyRoleLevel),
        /** Operated recording equipment during sessions. */
        RecordingEngineer: bcs.option(RecordingPartyRoleLevel),
        /** Created a remix of the recording. */
        RemixingEngineer: bcs.option(RecordingPartyRoleLevel),
        /** Created sound effects or sonic textures. */
        SoundDesigner: bcs.option(RecordingPartyRoleLevel),
        /** Provided vocals on the recording. */
        Vocalist: bcs.option(RecordingPartyRoleLevel)
    } });
export interface NewActorRoleArguments {
    level: TransactionArgument;
}
export interface NewActorRoleOptions {
    package?: string;
    arguments: NewActorRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Actor role with optional level. */
export function newActorRole(options: NewActorRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_actor_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewArrangerRoleArguments {
    level: TransactionArgument;
}
export interface NewArrangerRoleOptions {
    package?: string;
    arguments: NewArrangerRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Arranger role with optional level. */
export function newArrangerRole(options: NewArrangerRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_arranger_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewArtistsAndRepertoireRoleOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a new Artists & Repertoire role. */
export function newArtistsAndRepertoireRole(options: NewArtistsAndRepertoireRoleOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_artists_and_repertoire_role',
    });
}
export interface NewChoirRoleArguments {
    level: TransactionArgument;
}
export interface NewChoirRoleOptions {
    package?: string;
    arguments: NewChoirRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Choir role with optional level. */
export function newChoirRole(options: NewChoirRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_choir_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewChoirMasterRoleArguments {
    level: TransactionArgument;
}
export interface NewChoirMasterRoleOptions {
    package?: string;
    arguments: NewChoirMasterRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Choir Master role with optional level. */
export function newChoirMasterRole(options: NewChoirMasterRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_choir_master_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewConductorRoleArguments {
    level: TransactionArgument;
}
export interface NewConductorRoleOptions {
    package?: string;
    arguments: NewConductorRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Conductor role with optional level. */
export function newConductorRole(options: NewConductorRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_conductor_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewContractorRoleArguments {
    level: TransactionArgument;
}
export interface NewContractorRoleOptions {
    package?: string;
    arguments: NewContractorRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Contractor role with optional level. */
export function newContractorRole(options: NewContractorRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_contractor_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewCopyistRoleOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a new Copyist role. */
export function newCopyistRole(options: NewCopyistRoleOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_copyist_role',
    });
}
export interface NewEditorRoleArguments {
    level: TransactionArgument;
}
export interface NewEditorRoleOptions {
    package?: string;
    arguments: NewEditorRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Editor role with optional level. */
export function newEditorRole(options: NewEditorRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_editor_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewEnsembleRoleArguments {
    level: TransactionArgument;
}
export interface NewEnsembleRoleOptions {
    package?: string;
    arguments: NewEnsembleRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Ensemble role with optional level. */
export function newEnsembleRole(options: NewEnsembleRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_ensemble_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewInstrumentalistRoleArguments {
    instrument: RawTransactionArgument<string>;
    level: TransactionArgument;
}
export interface NewInstrumentalistRoleOptions {
    package?: string;
    arguments: NewInstrumentalistRoleArguments | [
        instrument: RawTransactionArgument<string>,
        level: TransactionArgument
    ];
}
/** Creates a new Instrumentalist role with instrument name and optional level. */
export function newInstrumentalistRole(options: NewInstrumentalistRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        '0x1::string::String',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["instrument", "level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_instrumentalist_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewMasteringEngineerRoleArguments {
    level: TransactionArgument;
}
export interface NewMasteringEngineerRoleOptions {
    package?: string;
    arguments: NewMasteringEngineerRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Mastering Engineer role with optional level. */
export function newMasteringEngineerRole(options: NewMasteringEngineerRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_mastering_engineer_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewMixingEngineerRoleArguments {
    level: TransactionArgument;
}
export interface NewMixingEngineerRoleOptions {
    package?: string;
    arguments: NewMixingEngineerRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Mixing Engineer role with optional level. */
export function newMixingEngineerRole(options: NewMixingEngineerRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_mixing_engineer_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewMusicDirectorRoleArguments {
    level: TransactionArgument;
}
export interface NewMusicDirectorRoleOptions {
    package?: string;
    arguments: NewMusicDirectorRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Music Director role with optional level. */
export function newMusicDirectorRole(options: NewMusicDirectorRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_music_director_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewMusicSupervisorRoleArguments {
    level: TransactionArgument;
}
export interface NewMusicSupervisorRoleOptions {
    package?: string;
    arguments: NewMusicSupervisorRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Music Supervisor role with optional level. */
export function newMusicSupervisorRole(options: NewMusicSupervisorRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_music_supervisor_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewNarratorRoleArguments {
    level: TransactionArgument;
}
export interface NewNarratorRoleOptions {
    package?: string;
    arguments: NewNarratorRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Narrator role with optional level. */
export function newNarratorRole(options: NewNarratorRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_narrator_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewOrchestraRoleArguments {
    level: TransactionArgument;
}
export interface NewOrchestraRoleOptions {
    package?: string;
    arguments: NewOrchestraRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Orchestra role with optional level. */
export function newOrchestraRole(options: NewOrchestraRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_orchestra_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewOrchestratorRoleArguments {
    level: TransactionArgument;
}
export interface NewOrchestratorRoleOptions {
    package?: string;
    arguments: NewOrchestratorRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Orchestrator role with optional level. */
export function newOrchestratorRole(options: NewOrchestratorRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_orchestrator_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewProducerRoleArguments {
    level: TransactionArgument;
}
export interface NewProducerRoleOptions {
    package?: string;
    arguments: NewProducerRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Producer role with optional level. */
export function newProducerRole(options: NewProducerRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_producer_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewProgrammerRoleArguments {
    level: TransactionArgument;
}
export interface NewProgrammerRoleOptions {
    package?: string;
    arguments: NewProgrammerRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Programmer role with optional level. */
export function newProgrammerRole(options: NewProgrammerRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_programmer_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewRecordingEngineerRoleArguments {
    level: TransactionArgument;
}
export interface NewRecordingEngineerRoleOptions {
    package?: string;
    arguments: NewRecordingEngineerRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Recording Engineer role with optional level. */
export function newRecordingEngineerRole(options: NewRecordingEngineerRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_recording_engineer_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewRemixingEngineerRoleArguments {
    level: TransactionArgument;
}
export interface NewRemixingEngineerRoleOptions {
    package?: string;
    arguments: NewRemixingEngineerRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Remixing Engineer role with optional level. */
export function newRemixingEngineerRole(options: NewRemixingEngineerRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_remixing_engineer_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewSoundDesignerRoleArguments {
    level: TransactionArgument;
}
export interface NewSoundDesignerRoleOptions {
    package?: string;
    arguments: NewSoundDesignerRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Sound Designer role with optional level. */
export function newSoundDesignerRole(options: NewSoundDesignerRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_sound_designer_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewVocalistRoleArguments {
    level: TransactionArgument;
}
export interface NewVocalistRoleOptions {
    package?: string;
    arguments: NewVocalistRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Vocalist role with optional level. */
export function newVocalistRole(options: NewVocalistRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_vocalist_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewAdditionalRoleLevelOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates an Additional level. */
export function newAdditionalRoleLevel(options: NewAdditionalRoleLevelOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_additional_role_level',
    });
}
export interface NewAssistantRoleLevelOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates an Assistant level. */
export function newAssistantRoleLevel(options: NewAssistantRoleLevelOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_assistant_role_level',
    });
}
export interface NewAssociateRoleLevelOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates an Associate level. */
export function newAssociateRoleLevel(options: NewAssociateRoleLevelOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_associate_role_level',
    });
}
export interface NewBackingRoleLevelOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a Backing level. */
export function newBackingRoleLevel(options: NewBackingRoleLevelOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_backing_role_level',
    });
}
export interface NewExecutiveRoleLevelOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates an Executive level. */
export function newExecutiveRoleLevel(options: NewExecutiveRoleLevelOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_executive_role_level',
    });
}
export interface NewFeaturedRoleLevelOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a Featured level. */
export function newFeaturedRoleLevel(options: NewFeaturedRoleLevelOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_featured_role_level',
    });
}
export interface NewLeadRoleLevelOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a Lead level. */
export function newLeadRoleLevel(options: NewLeadRoleLevelOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_lead_role_level',
    });
}
export interface NewPrimaryRoleLevelOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a Primary level. */
export function newPrimaryRoleLevel(options: NewPrimaryRoleLevelOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_primary_role_level',
    });
}
export interface NewPrincipalRoleLevelOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a Principal level. */
export function newPrincipalRoleLevel(options: NewPrincipalRoleLevelOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_principal_role_level',
    });
}
export interface LevelArguments {
    self: TransactionArgument;
}
export interface LevelOptions {
    package?: string;
    arguments: LevelArguments | [
        self: TransactionArgument
    ];
}
/** Returns the optional level associated with this role. */
export function level(options: LevelOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'level',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
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
        module: 'recording_party_role',
        function: 'name',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsActorRoleArguments {
    self: TransactionArgument;
}
export interface IsActorRoleOptions {
    package?: string;
    arguments: IsActorRoleArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is an Actor role. */
export function isActorRole(options: IsActorRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_actor_role',
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
        module: 'recording_party_role',
        function: 'is_arranger_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsArtistsAndRepertoireRoleArguments {
    self: TransactionArgument;
}
export interface IsArtistsAndRepertoireRoleOptions {
    package?: string;
    arguments: IsArtistsAndRepertoireRoleArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is an Artists & Repertoire role. */
export function isArtistsAndRepertoireRole(options: IsArtistsAndRepertoireRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_artists_and_repertoire_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsChoirRoleArguments {
    self: TransactionArgument;
}
export interface IsChoirRoleOptions {
    package?: string;
    arguments: IsChoirRoleArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is a Choir role. */
export function isChoirRole(options: IsChoirRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_choir_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsChoirMasterRoleArguments {
    self: TransactionArgument;
}
export interface IsChoirMasterRoleOptions {
    package?: string;
    arguments: IsChoirMasterRoleArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is a Choir Master role. */
export function isChoirMasterRole(options: IsChoirMasterRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_choir_master_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsConductorRoleArguments {
    self: TransactionArgument;
}
export interface IsConductorRoleOptions {
    package?: string;
    arguments: IsConductorRoleArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is a Conductor role. */
export function isConductorRole(options: IsConductorRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_conductor_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsContractorRoleArguments {
    self: TransactionArgument;
}
export interface IsContractorRoleOptions {
    package?: string;
    arguments: IsContractorRoleArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is a Contractor role. */
export function isContractorRole(options: IsContractorRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_contractor_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsCopyistRoleArguments {
    self: TransactionArgument;
}
export interface IsCopyistRoleOptions {
    package?: string;
    arguments: IsCopyistRoleArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is a Copyist role. */
export function isCopyistRole(options: IsCopyistRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_copyist_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsEditorRoleArguments {
    self: TransactionArgument;
}
export interface IsEditorRoleOptions {
    package?: string;
    arguments: IsEditorRoleArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is an Editor role. */
export function isEditorRole(options: IsEditorRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_editor_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsEnsembleRoleArguments {
    self: TransactionArgument;
}
export interface IsEnsembleRoleOptions {
    package?: string;
    arguments: IsEnsembleRoleArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is an Ensemble role. */
export function isEnsembleRole(options: IsEnsembleRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_ensemble_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsInstrumentalistRoleArguments {
    self: TransactionArgument;
}
export interface IsInstrumentalistRoleOptions {
    package?: string;
    arguments: IsInstrumentalistRoleArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is an Instrumentalist role. */
export function isInstrumentalistRole(options: IsInstrumentalistRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_instrumentalist_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsMasteringEngineerRoleArguments {
    self: TransactionArgument;
}
export interface IsMasteringEngineerRoleOptions {
    package?: string;
    arguments: IsMasteringEngineerRoleArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is a Mastering Engineer role. */
export function isMasteringEngineerRole(options: IsMasteringEngineerRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_mastering_engineer_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsMixingEngineerRoleArguments {
    self: TransactionArgument;
}
export interface IsMixingEngineerRoleOptions {
    package?: string;
    arguments: IsMixingEngineerRoleArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is a Mixing Engineer role. */
export function isMixingEngineerRole(options: IsMixingEngineerRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_mixing_engineer_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsMusicDirectorRoleArguments {
    self: TransactionArgument;
}
export interface IsMusicDirectorRoleOptions {
    package?: string;
    arguments: IsMusicDirectorRoleArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is a Music Director role. */
export function isMusicDirectorRole(options: IsMusicDirectorRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_music_director_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsMusicSupervisorRoleArguments {
    self: TransactionArgument;
}
export interface IsMusicSupervisorRoleOptions {
    package?: string;
    arguments: IsMusicSupervisorRoleArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is a Music Supervisor role. */
export function isMusicSupervisorRole(options: IsMusicSupervisorRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_music_supervisor_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsNarratorRoleArguments {
    self: TransactionArgument;
}
export interface IsNarratorRoleOptions {
    package?: string;
    arguments: IsNarratorRoleArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is a Narrator role. */
export function isNarratorRole(options: IsNarratorRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_narrator_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsOrchestraRoleArguments {
    self: TransactionArgument;
}
export interface IsOrchestraRoleOptions {
    package?: string;
    arguments: IsOrchestraRoleArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is an Orchestra role. */
export function isOrchestraRole(options: IsOrchestraRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_orchestra_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsOrchestratorRoleArguments {
    self: TransactionArgument;
}
export interface IsOrchestratorRoleOptions {
    package?: string;
    arguments: IsOrchestratorRoleArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is an Orchestrator role. */
export function isOrchestratorRole(options: IsOrchestratorRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_orchestrator_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsProducerRoleArguments {
    self: TransactionArgument;
}
export interface IsProducerRoleOptions {
    package?: string;
    arguments: IsProducerRoleArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is a Producer role. */
export function isProducerRole(options: IsProducerRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_producer_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsProgrammerRoleArguments {
    self: TransactionArgument;
}
export interface IsProgrammerRoleOptions {
    package?: string;
    arguments: IsProgrammerRoleArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is a Programmer role. */
export function isProgrammerRole(options: IsProgrammerRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_programmer_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsRecordingEngineerRoleArguments {
    self: TransactionArgument;
}
export interface IsRecordingEngineerRoleOptions {
    package?: string;
    arguments: IsRecordingEngineerRoleArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is a Recording Engineer role. */
export function isRecordingEngineerRole(options: IsRecordingEngineerRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_recording_engineer_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsRemixingEngineerRoleArguments {
    self: TransactionArgument;
}
export interface IsRemixingEngineerRoleOptions {
    package?: string;
    arguments: IsRemixingEngineerRoleArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is a Remixing Engineer role. */
export function isRemixingEngineerRole(options: IsRemixingEngineerRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_remixing_engineer_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsSoundDesignerRoleArguments {
    self: TransactionArgument;
}
export interface IsSoundDesignerRoleOptions {
    package?: string;
    arguments: IsSoundDesignerRoleArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is a Sound Designer role. */
export function isSoundDesignerRole(options: IsSoundDesignerRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_sound_designer_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsVocalistRoleArguments {
    self: TransactionArgument;
}
export interface IsVocalistRoleOptions {
    package?: string;
    arguments: IsVocalistRoleArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is a Vocalist role. */
export function isVocalistRole(options: IsVocalistRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_vocalist_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsAdditionalRoleLevelArguments {
    self: TransactionArgument;
}
export interface IsAdditionalRoleLevelOptions {
    package?: string;
    arguments: IsAdditionalRoleLevelArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is an Additional level. */
export function isAdditionalRoleLevel(options: IsAdditionalRoleLevelOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_additional_role_level',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsAssistantRoleLevelArguments {
    self: TransactionArgument;
}
export interface IsAssistantRoleLevelOptions {
    package?: string;
    arguments: IsAssistantRoleLevelArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is an Assistant level. */
export function isAssistantRoleLevel(options: IsAssistantRoleLevelOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_assistant_role_level',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsAssociateRoleLevelArguments {
    self: TransactionArgument;
}
export interface IsAssociateRoleLevelOptions {
    package?: string;
    arguments: IsAssociateRoleLevelArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is an Associate level. */
export function isAssociateRoleLevel(options: IsAssociateRoleLevelOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_associate_role_level',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsBackingRoleLevelArguments {
    self: TransactionArgument;
}
export interface IsBackingRoleLevelOptions {
    package?: string;
    arguments: IsBackingRoleLevelArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is a Backing level. */
export function isBackingRoleLevel(options: IsBackingRoleLevelOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_backing_role_level',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsExecutiveRoleLevelArguments {
    self: TransactionArgument;
}
export interface IsExecutiveRoleLevelOptions {
    package?: string;
    arguments: IsExecutiveRoleLevelArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is an Executive level. */
export function isExecutiveRoleLevel(options: IsExecutiveRoleLevelOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_executive_role_level',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsFeaturedRoleLevelArguments {
    self: TransactionArgument;
}
export interface IsFeaturedRoleLevelOptions {
    package?: string;
    arguments: IsFeaturedRoleLevelArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is a Featured level. */
export function isFeaturedRoleLevel(options: IsFeaturedRoleLevelOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_featured_role_level',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsLeadRoleLevelArguments {
    self: TransactionArgument;
}
export interface IsLeadRoleLevelOptions {
    package?: string;
    arguments: IsLeadRoleLevelArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is a Lead level. */
export function isLeadRoleLevel(options: IsLeadRoleLevelOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_lead_role_level',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsPrimaryRoleLevelArguments {
    self: TransactionArgument;
}
export interface IsPrimaryRoleLevelOptions {
    package?: string;
    arguments: IsPrimaryRoleLevelArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is a Primary level. */
export function isPrimaryRoleLevel(options: IsPrimaryRoleLevelOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_primary_role_level',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsPrincipalRoleLevelArguments {
    self: TransactionArgument;
}
export interface IsPrincipalRoleLevelOptions {
    package?: string;
    arguments: IsPrincipalRoleLevelArguments | [
        self: TransactionArgument
    ];
}
/** Returns true if this is a Principal level. */
export function isPrincipalRoleLevel(options: IsPrincipalRoleLevelOptions) {
    const packageAddress = options.package ?? '@local-pkg/musicos';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'is_principal_role_level',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}