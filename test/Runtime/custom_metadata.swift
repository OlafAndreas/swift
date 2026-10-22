// RUN: %empty-directory(%t)
// RUN: split-file %s %t
// RUN: %target-build-swift-dylib(%t/%target-library-name(Rules)) %t/Rules.swift -module-name Rules -emit-module -emit-module-path %t/Rules.swiftmodule -enable-experimental-feature CustomMetadata
// RUN: %target-build-swift %t/main.swift -I %t -L %t -lRules -o %t/main %target-rpath(%t) -enable-experimental-feature CustomMetadata
// RUN: %target-codesign %t/main %t/%target-library-name(Rules)
// RUN: %target-run %t/main %t/%target-library-name(Rules) | %FileCheck %s

// REQUIRES: executable_test
// REQUIRES: swift_feature_CustomMetadata

// The query is back-deployed, so this also runs against an older OS stdlib,
// where the client-side fallback walks dyld's image list.

//--- Rules.swift
@customMetadata public enum Rule {}
@customMetadata public enum Other {}

@Rule public struct ArrayInitRule {}
public struct TrailingWhitespaceRule {}
@Other public final class OtherOnly {}

// Excluded by its availability on Apple platforms.
@available(macOS 99, iOS 99, tvOS 99, watchOS 99, visionOS 99, *)
@Rule public struct FutureRule {}

//--- main.swift
import Rules

// Applied from a second module to a type of the first.
@Rule extension TrailingWhitespaceRule {}

// Applied again from a second module: the type is returned once.
@Rule extension ArrayInitRule {}

@Rule enum LocalRule {}

func names(_ types: [Any.Type]) -> [String] {
  types.map { String(reflecting: $0) }.sorted()
}

// Only Apple platforms have OS versions to exclude a type by.
#if canImport(Darwin)
let futureRuleIsReturned = false
#else
let futureRuleIsReturned = true
#endif

let rules = names(customMetadataTypes(marked: Rule.self))
print(rules.filter { $0 != "Rules.FutureRule" })
print(rules.contains("Rules.FutureRule") == futureRuleIsReturned)
print(names(customMetadataTypes(marked: Other.self)))
print(customMetadataTypes(marked: Int.self).count)

// CHECK: ["Rules.ArrayInitRule", "Rules.TrailingWhitespaceRule", "main.LocalRule"]
// CHECK-NEXT: true
// CHECK-NEXT: ["Rules.OtherOnly"]
// CHECK-NEXT: 0
