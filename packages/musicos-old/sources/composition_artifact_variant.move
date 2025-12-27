// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::composition_artifact_variant;

use std::string::String;

public enum CompositionArtifactVariant has copy, drop, store {
    AudioDemo(String),
    LeadSheet(String),
    Lrc(String),
    Midi(String),
    Midi2(String),
    MusicXml(String),
}

public fun new_midi(blob_id: String): CompositionArtifactVariant {
    CompositionArtifactVariant::Midi(blob_id)
}

public fun new_midi2(blob_id: String): CompositionArtifactVariant {
    CompositionArtifactVariant::Midi2(blob_id)
}

public fun new_music_xml(blob_id: String): CompositionArtifactVariant {
    CompositionArtifactVariant::MusicXml(blob_id)
}

public fun new_lead_sheet(blob_id: String): CompositionArtifactVariant {
    CompositionArtifactVariant::LeadSheet(blob_id)
}

public fun new_lrc(blob_id: String): CompositionArtifactVariant {
    CompositionArtifactVariant::Lrc(blob_id)
}

public fun new_audio_demo(blob_id: String): CompositionArtifactVariant {
    CompositionArtifactVariant::AudioDemo(blob_id)
}
