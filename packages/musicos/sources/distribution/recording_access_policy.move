module musicos::recording_decryption_license;

public struct RecordingDecryptionLicense has store { recording_id: ID, timestamp: u64 }

public(package) fun new(recording_id: ID, timestamp: u64): RecordingDecryptionLicense {
    RecordingDecryptionLicense { recording_id, timestamp }
}
