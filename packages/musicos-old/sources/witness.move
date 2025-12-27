module musicos::witness;

public struct Witness() has drop;

public(package) fun new(): Witness {
    Witness()
}
