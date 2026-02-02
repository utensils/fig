import Foundation

/// A type-erased `Codable` value that preserves arbitrary JSON during round-trip encoding/decoding.
///
/// This is essential for preserving unknown keys in Claude Code's configuration files,
/// ensuring Fig doesn't lose fields it doesn't understand.
///
/// - Note: This type is marked `@unchecked Sendable` because it stores `Any` internally.
///   In practice, values are only created from JSON decoding (which produces Sendable primitives,
///   arrays, and dictionaries) or from the ExpressibleBy literal protocols. Avoid storing
///   non-Sendable types directly.
public struct AnyCodable: Codable, Equatable, Hashable, @unchecked Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = Self.sanitize(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map(\.value)
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable cannot decode value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "AnyCodable cannot encode value of type \(type(of: value))"
                )
            )
        }
    }

    // MARK: - Equatable

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        areEqual(lhs.value, rhs.value)
    }

    /// Compares two `Any` values for equality without allocating wrapper objects.
    private static func areEqual(_ lhs: Any, _ rhs: Any) -> Bool {
        switch (lhs, rhs) {
        case is (NSNull, NSNull):
            return true
        case let (lhs as Bool, rhs as Bool):
            return lhs == rhs
        case let (lhs as Int, rhs as Int):
            return lhs == rhs
        case let (lhs as Double, rhs as Double):
            return lhs == rhs
        case let (lhs as String, rhs as String):
            return lhs == rhs
        case let (lhs as [Any], rhs as [Any]):
            guard lhs.count == rhs.count else { return false }
            return zip(lhs, rhs).allSatisfy { areEqual($0, $1) }
        case let (lhs as [String: Any], rhs as [String: Any]):
            guard lhs.count == rhs.count else { return false }
            return lhs.allSatisfy { key, value in
                guard let rhsValue = rhs[key] else { return false }
                return areEqual(value, rhsValue)
            }
        default:
            return false
        }
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        Self.hashValue(value, into: &hasher)
    }

    /// Hashes an `Any` value without allocating wrapper objects.
    private static func hashValue(_ value: Any, into hasher: inout Hasher) {
        switch value {
        case is NSNull:
            hasher.combine(0)
        case let bool as Bool:
            hasher.combine(1)
            hasher.combine(bool)
        case let int as Int:
            hasher.combine(2)
            hasher.combine(int)
        case let double as Double:
            hasher.combine(3)
            hasher.combine(double)
        case let string as String:
            hasher.combine(4)
            hasher.combine(string)
        case let array as [Any]:
            hasher.combine(5)
            hasher.combine(array.count)
            for element in array {
                hashValue(element, into: &hasher)
            }
        case let dictionary as [String: Any]:
            hasher.combine(6)
            hasher.combine(dictionary.count)
            for key in dictionary.keys.sorted() {
                hasher.combine(key)
                hashValue(dictionary[key]!, into: &hasher)
            }
        default:
            // Hash the type to ensure different unsupported types don't collide
            hasher.combine(7)
            hasher.combine(ObjectIdentifier(type(of: value)))
        }
    }

    // MARK: - Private

    /// Recursively sanitize values to ensure Sendable compliance.
    private static func sanitize(_ value: Any) -> Any {
        switch value {
        case let array as [Any]:
            return array.map { sanitize($0) }
        case let dictionary as [String: Any]:
            return dictionary.mapValues { sanitize($0) }
        default:
            return value
        }
    }
}

// MARK: - ExpressibleBy Literals

extension AnyCodable: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self.init(NSNull())
    }
}

extension AnyCodable: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self.init(value)
    }
}

extension AnyCodable: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(value)
    }
}

extension AnyCodable: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self.init(value)
    }
}

extension AnyCodable: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

extension AnyCodable: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Any...) {
        self.init(elements)
    }
}

extension AnyCodable: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Any)...) {
        self.init(Dictionary(uniqueKeysWithValues: elements))
    }
}
