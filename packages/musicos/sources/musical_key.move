module musicos::musical_key;

public struct MusicalKey(NoteLetter, Accidental, Mode) has copy, drop, store;

public enum NoteLetter has copy, drop, store {
    C,
    D,
    E,
    F,
    G,
    A,
    B,
}

public enum Accidental has copy, drop, store {
    Natural,
    Sharp,
    Flat,
}

public enum Mode has copy, drop, store {
    Major,
    Minor,
}

public fun note_letter(self: &MusicalKey): NoteLetter { self.0 }

public fun accidental(self: &MusicalKey): Accidental { self.1 }

public fun mode(self: &MusicalKey): Mode { self.2 }
