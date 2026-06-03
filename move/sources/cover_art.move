// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Represents cover artwork for releases and tracks in MusicOS.
/// Supports both a still image and optional animated artwork (GIFs, videos).
///
/// ### Key Features:
///
/// - Required still image for all cover art
/// - Optional animated version for enhanced presentation
/// - References external storage via Data type
module musicos::cover_art;

use walrus_data::walrus_data::WalrusData;

// === Structs ===

/// Cover artwork with a required still image and optional animation.
public struct CoverArt has copy, drop, store {
    still: WalrusData,
    animated: Option<WalrusData>,
}

// === Public Functions ===

/// Creates new cover art with a still image and optional animated version.
/// `still` - Required still image data reference.
/// `animated` - Optional animated image/video data reference.
public fun new(still: WalrusData, animated: Option<WalrusData>): CoverArt {
    still.assert_is_blob();
    if (animated.is_some()) {
        animated.borrow().assert_is_blob();
    };
    CoverArt {
        still,
        animated,
    }
}

// === Public View Functions ===

/// Returns a reference to the still image data.
public fun still(self: &CoverArt): &WalrusData {
    &self.still
}

/// Returns a reference to the optional animated artwork data.
public fun animated(self: &CoverArt): &Option<WalrusData> {
    &self.animated
}

/// Creates cover art for testing with a dummy blob.
#[test_only]
public fun new_for_testing(): CoverArt {
    use walrus_data::walrus_data;
    CoverArt {
        still: walrus_data::new_blob(0),
        animated: option::none(),
    }
}
