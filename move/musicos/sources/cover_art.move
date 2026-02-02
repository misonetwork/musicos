// Copyright (c) Unconfirmed Labs, LLC
// SPDX-License-Identifier: Apache-2.0

/// Represents cover artwork for releases and tracks in MusicOS.
/// Supports both static images and optional animated artwork (GIFs, videos).
///
/// Key features:
/// - Required static image for all cover art
/// - Optional animated version for enhanced presentation
/// - References external storage via Data type
module musicos::cover_art;

use walrus_data::walrus_data::WalrusData;

/// Cover artwork with required static image and optional animation.
public struct CoverArt has copy, drop, store {
    static: WalrusData,
    animated: Option<WalrusData>,
}

/// Creates new cover art with a static image and optional animated version.
/// `static` - Required static image data reference.
/// `animated` - Optional animated image/video data reference.
public fun new(static: WalrusData, animated: Option<WalrusData>): CoverArt {
    CoverArt {
        static,
        animated,
    }
}

/// Returns a reference to the static image data.
public fun static(self: &CoverArt): &WalrusData {
    &self.static
}

/// Returns a reference to the optional animated artwork data.
public fun animated(self: &CoverArt): &Option<WalrusData> {
    &self.animated
}
