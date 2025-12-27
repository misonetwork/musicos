module musicos::vault;

use musicos::artifact::Artifact;
use musicos::contributor::{Contributor, ContributorAdminCap};
use musicos::snapshot::Snapshot;
use sui::derived_object::claim;

public struct Vault<Work: key, ArtifactVariant> has store {
    artifacts: vector<Artifact<ArtifactVariant>>,
    snapshots: vector<Snapshot>,
}

public(package) fun add_artifact<Work: key, ArtifactVariant>(
    self: &mut Vault<Work, ArtifactVariant>,
    artifact: Artifact<ArtifactVariant>,
) {
    self.artifacts.push_back(artifact);
}

public(package) fun remove_artifact<Work: key, ArtifactVariant>(
    self: &mut Vault<Work, ArtifactVariant>,
    artifact_idx: u64,
) {
    self.artifacts.remove(artifact_idx);
}

public(package) fun add_snapshot<Work: key, ArtifactVariant>(
    self: &mut Vault<Work, ArtifactVariant>,
    snapshot: Snapshot,
) {
    self.snapshots.push_back(snapshot);
}

public(package) fun remove_snapshot<Work: key, ArtifactVariant>(
    self: &mut Vault<Work, ArtifactVariant>,
    snapshot_idx: u64,
) {
    self.snapshots.remove(snapshot_idx);
}
