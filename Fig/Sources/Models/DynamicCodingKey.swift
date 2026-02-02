import Foundation

/// A dynamic coding key that can represent any string key.
///
/// Used for encoding/decoding unknown keys during round-trip JSON serialization.
struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = String(intValue)
    }
}
