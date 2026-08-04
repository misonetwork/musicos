/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Basis-points arithmetic with a newtype wrapper.
 * 
 * 1 bps = 0.01%. 10_000 bps = 100%.
 * 
 * Storage-optimal: `BPS` stores a `u16` (2 bytes), the tightest width that fits
 * the `[0, 10_000]` range. Apply functions cover every standard integer width
 * (`u8` through `u256`); overflow safety on `u8`–`u128` is delegated to
 * `std::uX::mul_div` / `mul_div_ceil`, which widen to the next-larger type
 * internally. `u256` has no wider type, so the multiplication is performed
 * directly and only overflows for amounts exceeding `u256::MAX / 10_000`
 * (~1.16e73).
 */

import { MoveTuple } from '../../../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
const $moduleName = 'bps::bps';
export const BPS = new MoveTuple({ name: `${$moduleName}::BPS`, fields: [bcs.u16()] });