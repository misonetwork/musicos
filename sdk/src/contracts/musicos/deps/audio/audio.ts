/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * A verified audio file with technical metadata — a standalone, wrapped primitive
 * that any protocol can embed (e.g. as a recording's master).
 * 
 * ### Key Features:
 * 
 * - Format (codec/container, e.g. `flac`) and PCM parameters (channels, bit depth,
 *   sample rate, samples)
 * - Walrus blob ID for storage reference
 * - Witness-gated creation: only packages that can produce an `Ingester` witness
 *   type (with `drop`) can create `Audio`. The `Audio` records which ingester
 *   attested it, so multiple ingester implementations can coexist.
 */

import { MoveStruct } from '../../../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import * as type_name from '../std/type_name.js';
import * as walrus_data from '../ori/walrus_data.js';
const $moduleName = 'audio::audio';
export const Audio = new MoveStruct({ name: `${$moduleName}::Audio`, fields: {
        /** The ingester that attested this audio. */
        ingester: type_name.TypeName,
        /**
         * Codec/container of the stored blob, as a bare lowercase short name (e.g. `flac`,
         * `wav`, `opus`). No `audio/` prefix — the type is already audio.
         */
        format: bcs.string(),
        /** Number of audio channels (1 = mono, 2 = stereo). */
        channels: bcs.u8(),
        /** Bits per sample (8, 16, 24, or 32). */
        bit_depth: bcs.u8(),
        /** Sample rate in hertz (e.g., 44100, 48000, 96000). */
        sample_rate_hz: bcs.u32(),
        /** Total number of PCM samples in the audio. */
        samples: bcs.u64(),
        /**
         * `blake2b-256` digest of the canonical decoded PCM (codec-independent content
         * fingerprint). 32 bytes.
         */
        pcm_digest: bcs.vector(bcs.u8()),
        /** Walrus data reference for the audio (must be a blob). */
        data: walrus_data.WalrusData
    } });