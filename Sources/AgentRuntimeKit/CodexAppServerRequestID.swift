import Foundation

public enum CodexAppServerRequestID: Hashable, Sendable {
	case int(Int)
	case string(String)

	public init?(raw: Any) {
		if let value = raw as? Int {
			self = .int(value)
			return
		}
		if let value = raw as? NSNumber {
			self = .int(value.intValue)
			return
		}
		if let value = raw as? String {
			self = .string(value)
			return
		}
		return nil
	}

	public var jsonValue: Any {
		switch self {
		case .int(let value): return value
		case .string(let value): return value
		}
	}

	public var displayValue: String {
		switch self {
		case .int(let value): return String(value)
		case .string(let value): return value
		}
	}
}
