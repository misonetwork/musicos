// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Defines the types of artifacts that can be attached to compositions.
/// Used as a phantom type parameter for type-safe artifact categorization.
module musicos::composition_artifact_kind;

use musicos::data::Data;
use std::string::String;

/// Types of artifacts that can be attached to a composition.
public enum CompositionArtifactKind has copy, drop, store {
    ChordChart(Data),
    Demo(Data),
    LeadSheet(Data),
    Midi(Data),
    MusicXml(Data),
    NotationProject(Data),
    SheetMusic(Data),
    Tablature(Data),
}

public fun new_chord_chart_kind(data: Data): CompositionArtifactKind {
    CompositionArtifactKind::ChordChart(data)
}

public fun new_demo_kind(data: Data): CompositionArtifactKind {
    CompositionArtifactKind::Demo(data)
}

public fun new_lead_sheet_kind(data: Data): CompositionArtifactKind {
    CompositionArtifactKind::LeadSheet(data)
}

public fun new_midi_kind(data: Data): CompositionArtifactKind {
    CompositionArtifactKind::Midi(data)
}

public fun new_music_xml_kind(data: Data): CompositionArtifactKind {
    CompositionArtifactKind::MusicXml(data)
}

public fun new_notation_project_kind(data: Data): CompositionArtifactKind {
    CompositionArtifactKind::NotationProject(data)
}

public fun new_sheet_music_kind(data: Data): CompositionArtifactKind {
    CompositionArtifactKind::SheetMusic(data)
}

public fun new_tablature_kind(data: Data): CompositionArtifactKind {
    CompositionArtifactKind::Tablature(data)
}

public fun data(kind: &CompositionArtifactKind): &Data {
    match (kind) {
        CompositionArtifactKind::ChordChart(data) => data,
        CompositionArtifactKind::Demo(data) => data,
        CompositionArtifactKind::LeadSheet(data) => data,
        CompositionArtifactKind::Midi(data) => data,
        CompositionArtifactKind::MusicXml(data) => data,
        CompositionArtifactKind::NotationProject(data) => data,
        CompositionArtifactKind::SheetMusic(data) => data,
        CompositionArtifactKind::Tablature(data) => data,
    }
}

public fun name(kind: &CompositionArtifactKind): String {
    match (kind) {
        CompositionArtifactKind::ChordChart(_) => "Chord Chart",
        CompositionArtifactKind::Demo(_) => "Demo",
        CompositionArtifactKind::LeadSheet(_) => "Lead Sheet",
        CompositionArtifactKind::Midi(_) => "MIDI",
        CompositionArtifactKind::MusicXml(_) => "MusicXML",
        CompositionArtifactKind::NotationProject(_) => "Notation Project",
        CompositionArtifactKind::SheetMusic(_) => "Sheet Music",
        CompositionArtifactKind::Tablature(_) => "Tablature",
    }
}