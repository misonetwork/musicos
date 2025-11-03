module musicos::bit_rate;

public enum BitRate has copy, drop, store {
    ABR(u16),
    CBR(u16),
    VBR(u16),
}

public fun new_abr(bit_rate: u16): BitRate {
    BitRate::ABR(bit_rate)
}

public fun new_cbr(bit_rate: u16): BitRate {
    BitRate::CBR(bit_rate)
}

public fun new_vbr(bit_rate: u16): BitRate {
    BitRate::VBR(bit_rate)
}

public fun bit_rate(self: &BitRate): u16 {
    match (self) {
        BitRate::ABR(bit_rate) => *bit_rate,
        BitRate::CBR(bit_rate) => *bit_rate,
        BitRate::VBR(bit_rate) => *bit_rate,
    }
}
