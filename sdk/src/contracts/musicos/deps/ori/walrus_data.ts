/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/
import { MoveEnum, MoveTuple } from '../../../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
const $moduleName = 'ori::walrus_data';
/** Represents either a standalone Walrus blob or a patch within a quilt. */
export const WalrusData = new MoveEnum({ name: `${$moduleName}::WalrusData`, fields: {
        /** A standalone Walrus blob. Fields: blob_id. */
        Blob: bcs.u256(),
        /**
         * A patch within a Walrus quilt. Fields: quilt_id, version, start_index,
         * end_index.
         */
        QuiltPatch: new MoveTuple({ name: `WalrusData.QuiltPatch`, fields: [bcs.u256(), bcs.u8(), bcs.u16(), bcs.u16()] })
    } });