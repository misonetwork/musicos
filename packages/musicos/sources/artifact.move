module musicos::artifact;

use std::string::String;

public struct Artifact<phantom ArtifactKind> has copy, drop, store {
    blob_id: String,
    description: Option<String>,
}

public fun blob_id<ArtifactKind>(self: &Artifact<ArtifactKind>): String {
    self.blob_id
}

public fun description<ArtifactKind>(self: &Artifact<ArtifactKind>): Option<String> {
    self.description
}
