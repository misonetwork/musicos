// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Represents cover artwork for releases and tracks in MusicOS.
/// Supports both static images and optional animated artwork (GIFs, videos).
///
/// ### Key Features:
///
/// - Required static image for all cover art
/// - Optional animated version for enhanced presentation
/// - References external storage via Data type
module musicos::cover_art;

use ori::walrus_data::WalrusData;

// === Structs ===

/// Cover artwork with required static image and optional animation.
public struct CoverArt has copy, drop, store {
    static: WalrusData,
    animated: Option<WalrusData>,
}

// === Public Functions ===

/// Creates new cover art with a static image and optional animated version.
/// `static` - Required static image data reference.
/// `animated` - Optional animated image/video data reference.
public fun new(static: WalrusData, animated: Option<WalrusData>): CoverArt {
    static.assert_is_blob();
    if (animated.is_some()) {
        animated.borrow().assert_is_blob();
    };
    CoverArt {
        static,
        animated,
    }
}

// === Public View Functions ===

/// Returns a reference to the static image data.
public fun static(self: &CoverArt): &WalrusData {
    &self.static
}

/// Returns a reference to the optional animated artwork data.
public fun animated(self: &CoverArt): &Option<WalrusData> {
    &self.animated
}

/// Creates cover art for testing with a dummy blob.
#[test_only]
public fun new_for_testing(): CoverArt {
    use ori::walrus_data;
    CoverArt {
        static: walrus_data::new_blob(0),
        animated: option::none(),
    }
}
