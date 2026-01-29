module musicos::lyric_line;

use std::string::String;

//=== Structs ===

public struct LyricLine has copy, drop, store {
    start_pos_ms: u64,
    end_pos_ms: u64,
    text: String,
}

// === Constants ===

const ELengthMismatch: u64 = 0;

//=== Public Functions ===

/// Creates a new lyric line.
public fun new(start_pos_ms: u64, end_pos_ms: u64, text: String): LyricLine {
    LyricLine { start_pos_ms, end_pos_ms, text }
}

/// Creates a new lyric line from parts.
public fun from_parts(
    mut start_pos_ms: vector<u64>,
    mut end_pos_ms: vector<u64>,
    mut texts: vector<String>,
): vector<LyricLine> {
    // Get the batch size.
    let batch_size = start_pos_ms.length();

    // Assert the batch size is consistent with the end positions and texts vectors.
    assert!(batch_size == end_pos_ms.length() && batch_size == texts.length(), ELengthMismatch);

    // Reverse the vectors to pop the back elements.
    start_pos_ms.reverse();
    end_pos_ms.reverse();
    texts.reverse();

    // Create the lyric lines vector.
    vector::tabulate!(batch_size, |_| {
        LyricLine {
            start_pos_ms: start_pos_ms.pop_back(),
            end_pos_ms: end_pos_ms.pop_back(),
            text: texts.pop_back(),
        }
    })
}

//=== Public View Functions ===

public fun start_pos_ms(self: &LyricLine): u64 {
    self.start_pos_ms
}

public fun end_pos_ms(self: &LyricLine): u64 {
    self.end_pos_ms
}

public fun text(self: &LyricLine): &String {
    &self.text
}
