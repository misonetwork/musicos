module musicos::data;

public struct Data(Option<u256>, u256) has copy, drop, store;

public fun new(quilt_id: Option<u256>, blob_id: u256): Data {
    Data(quilt_id, blob_id)
}

public fun quilt_id(data: &Data): Option<u256> {
    data.0
}

public fun blob_id(data: &Data): u256 {
    data.1
}
