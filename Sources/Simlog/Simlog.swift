//
//  Created by Anton Spivak
//

import Darwin
import OSLog

// MARK: - log

public enum log {
    // MARK: Public

    public static func info(_ items: Any..., category: Category, options: Options = .default) {
        let string = options.string(from: items)
        process(.info, category, string, options)
    }

    public static func debug(_ items: Any..., category: Category, options: Options = .default) {
        let string = options.string(from: items)
        process(.debug, category, string, options)
    }

    public static func error(_ items: Any..., category: Category, options: Options = .default) {
        let string = options.string(from: items)
        process(.error, category, string, options)
    }

    public static func fault(
        _ items: Any...,
        category: Category,
        options: Options = .default,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Never {
        let string = "[\(file):\(line)] " + options.string(from: items)
        process(.fault, category, string, options)
        abort()
    }

    public static func use(_ configuration: Configuration) {
        Configuration.shared = configuration
    }

    // MARK: Private

    private static func process(
        _ level: OSLogType,
        _ category: Category,
        _ string: String,
        _ options: Options
    ) {
        level.oslog(category, string, options)
    }
}

private extension OSLogType {
    /// - note:
    /// https://stackoverflow.com/questions/33177182/detect-if-swift-app-is-being-run-from-xcode
    private static var isXcodeAttached: Bool = {
        var info = kinfo_proc()
        var size = MemoryLayout.stride(ofValue: info)
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        let junk = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        assert(junk == 0, "sysctl failed")
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }()

    func oslog(_ category: Category, _ value: String, _ options: Options) {
        guard !print(value, options)
        else {
            return
        }

        let string = "\(value.wrapped(for: .xcode(self)))\(options.terminator)"
        category.rawLogger.log(level: self, "\(string)")
    }

    private func print(_ value: String, _ options: Options) -> Bool {
        guard !OSLogType.isXcodeAttached, isatty(STDOUT_FILENO) == 1
        else {
            return false
        }

        var terminator = options.terminator
        if terminator == "\n" {
            terminator = ""
        }

        let value = value.wrapped(for: .default(self)) + terminator

        var standardError = Configuration.shared.standardError
        var standardOutput = Configuration.shared.standardOutput

        switch self {
        case .error, .fault:
            Swift.print(value, to: &standardError)
        default:
            Swift.print(value, to: &standardOutput)
        }

        return true
    }
}

// MARK: - String.TerminalColor

internal extension String {
    enum TerminalColor: String {
        case black = "\u{001B}[0;30m"
        case red = "\u{001B}[0;31m"
        case green = "\u{001B}[0;32m"
        case yellow = "\u{001B}[0;33m"
        case blue = "\u{001B}[0;34m"
        case magenta = "\u{001B}[0;35m"
        case cyan = "\u{001B}[0;36m"
        case white = "\u{001B}[0;37m"
        case `default` = "\u{001B}[0;0m"
    }
}

private extension OSLogType {
    var color: String.TerminalColor? {
        switch self {
        case .info:
            return .green
        case .error:
            return .red
        case .fault:
            return .magenta
        default:
            return nil
        }
    }

    var text: String? {
        switch self {
        case .info:
            return "[info] "
        case .error:
            return "[error] "
        case .fault:
            return "[fault] "
        default:
            return nil
        }
    }
}

internal extension String {
    enum Target {
        case `default`(OSLogType)
        case xcode(OSLogType)
    }

    func wrapped(for target: Target) -> Self {
        switch target {
        case let .default(level):
            if let color = level.color {
                return "\(color.rawValue)\(self)\(TerminalColor.default.rawValue)"
            } else {
                return self
            }
        case let .xcode(level):
            if let text = level.text {
                return "\(text)\(self)"
            } else {
                return self
            }
        }
    }
}

// MARK: - Configuration

public struct Configuration {
    // MARK: Lifecycle

    public init(
        standardError: OutputStream = OutputStream(stderr),
        standardOutput: OutputStream = OutputStream(stdout)
    ) {
        self.standardError = standardError
        self.standardOutput = standardOutput
    }

    // MARK: Public

    public let standardError: OutputStream
    public let standardOutput: OutputStream
}

private extension Configuration {
    static var shared = Configuration()
}

// MARK: Configuration.OutputStream

public extension Configuration {
    struct OutputStream: TextOutputStream {
        // MARK: Lifecycle

        public init<T>(_ stream: T) where T: TextOutputStream {
            self.pointer = nil
            self.stream = stream
        }

        public init(_ pointer: UnsafeMutablePointer<FILE>) {
            self.pointer = pointer
            self.stream = nil
        }

        // MARK: Public

        public mutating func write(_ string: String) {
            if let pointer {
                string.utf8.forEach({ putc(numericCast($0), pointer) })
            } else if var stream = stream as? TextOutputStream {
                stream.write(string)
            } else {
                fatalError()
            }
        }

        // MARK: Internal

        internal let pointer: UnsafeMutablePointer<FILE>?
        internal let stream: Any?
    }
}

// MARK: - Category

public struct Category {
    // MARK: Lifecycle

    public init(subsystem: String, category: String) {
        self.rawLogger = Logger(subsystem: subsystem, category: category)
    }

    // MARK: Internal

    let rawLogger: Logger
}

// MARK: - Options

public struct Options {
    // MARK: Lifecycle

    private init(separator: String, terminator: String) {
        self.separator = separator
        self.terminator = terminator
    }

    // MARK: Public

    public let separator: String
    public let terminator: String
}

public extension Options {
    static let `default` = Options(separator: " ", terminator: "\n")

    static func options(_ separator: String = " ", _ terminator: String = "\n") -> Options {
        Options(separator: separator, terminator: terminator)
    }
}

internal extension Options {
    func string(from items: [Any]) -> String {
        items.map({ "\($0)" }).joined(separator: separator)
    }
}
