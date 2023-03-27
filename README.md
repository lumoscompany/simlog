# Simlog

Simplify work with `OSLog` withing Swift

## Installation

```swift
.package(
    url: "https://github.com/lumoscompany/simlog.git",
    .upToNextMajor(from: "0.1.0")
)
```

## Usage

```swift
import Simlog

extension Simlog.Category {
    static let resources = Category("resources")
}

private extension Simlog.Category {
    init(_ named: String) {
        self.init(subsystem: "com.example.module", category: named)
    }
}

log.info("Can't locate color named '\(name)'", category: .resources)
```

## Authors

- adam@stragner.com
