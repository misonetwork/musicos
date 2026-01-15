// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Defines the types of artifacts that can be attached to compositions.
/// Used as a phantom type parameter for type-safe artifact categorization.
module musicos::composition_artifact_kind;

use std::string::String;

/// Types of artifacts that can be attached to a composition.
public enum CompositionArtifactKind has copy, drop, store {
    ChordChart,
    Demo,
    LeadSheet,
    Midi,
    MusicXml,
    NotationProject,
    SheetMusic,
    Tablature,
}

public fun new_chord_chart_kind(): CompositionArtifactKind {
    CompositionArtifactKind::ChordChart
}

public fun new_demo_kind(): CompositionArtifactKind {
    CompositionArtifactKind::Demo
}

public fun new_lead_sheet_kind(): CompositionArtifactKind {
    CompositionArtifactKind::LeadSheet
}

public fun new_midi_kind(): CompositionArtifactKind {
    CompositionArtifactKind::Midi
}

public fun new_music_xml_kind(): CompositionArtifactKind {
    CompositionArtifactKind::MusicXml
}

public fun new_notation_project_kind(): CompositionArtifactKind {
    CompositionArtifactKind::NotationProject
}

public fun new_sheet_music_kind(): CompositionArtifactKind {
    CompositionArtifactKind::SheetMusic
}

public fun new_tablature_kind(): CompositionArtifactKind {
    CompositionArtifactKind::Tablature
}

public fun name(kind: &CompositionArtifactKind): String {
    match (kind) {
        CompositionArtifactKind::ChordChart => "Chord Chart",
        CompositionArtifactKind::Demo => "Demo",
        CompositionArtifactKind::LeadSheet => "Lead Sheet",
        CompositionArtifactKind::Midi => "MIDI",
        CompositionArtifactKind::MusicXml => "MusicXML",
        CompositionArtifactKind::NotationProject => "Notation Project",
        CompositionArtifactKind::SheetMusic => "Sheet Music",
        CompositionArtifactKind::Tablature => "Tablature",
    }
}