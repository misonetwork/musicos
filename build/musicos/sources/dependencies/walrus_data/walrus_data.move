module walrus_data::walrus_data;

public struct WalrusData(Option<u256>, u256) has copy, drop, store;

public fun new(quilt_id: Option<u256>, blob_id: u256): WalrusData {
    WalrusData(quilt_id, blob_id)
}

public fun quilt_id(data: &WalrusData): Option<u256> {
    data.0
}

public fun blob_id(data: &WalrusData): u256 {
    data.1
}
