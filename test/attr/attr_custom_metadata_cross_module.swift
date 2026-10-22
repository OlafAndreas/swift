// RUN: %empty-directory(%t)
// RUN: split-file %s %t
// RUN: %target-swift-frontend -emit-module %t/Lib.swift -module-name Lib -o %t/Lib.swiftmodule -enable-experimental-feature CustomMetadata
// RUN: %target-swift-frontend -typecheck -verify %t/main.swift -I %t -enable-experimental-feature CustomMetadata -verify-ignore-unknown
// RUN: %empty-directory(%t/interface)
// RUN: %target-swift-frontend -emit-module %t/Lib.swift -module-name Lib -o %t/interface/Lib.swiftmodule -emit-module-interface-path %t/interface/Lib.swiftinterface -enable-library-evolution -swift-version 5 -enable-experimental-feature CustomMetadata
// RUN: %FileCheck %t/Lib.swift < %t/interface/Lib.swiftinterface
// RUN: %target-swift-frontend -typecheck-module-from-interface %t/interface/Lib.swiftinterface -module-name Lib -enable-experimental-feature CustomMetadata
// RUN: rm %t/interface/Lib.swiftmodule
// RUN: %target-swift-frontend -typecheck -verify %t/main.swift -I %t/interface -enable-experimental-feature CustomMetadata -verify-ignore-unknown

// REQUIRES: swift_feature_CustomMetadata

//--- Lib.swift
@customMetadata public enum Rule {}
@customMetadata enum InternalKey {}

public struct Helper {}
@available(*, unavailable)
@Rule extension Helper {}

public struct Open {}

// CHECK: @customMetadata public enum Rule
// CHECK-NOT: InternalKey
// CHECK: @available(*, unavailable)
// CHECK-NEXT: @Lib{{(::|\.)}}Rule extension Lib{{(::|\.)}}Helper
// An application of a key the interface cannot name is omitted, and the type
// is not guarded by the feature.
// CHECK: public struct Open {
// CHECK-NEXT: }
// CHECK-NEXT: public struct UsesInternalKey {
// CHECK-NOT: InternalKey

@InternalKey public struct UsesInternalKey {}

//--- main.swift
import Lib

@Rule extension Open {}

@Rule extension Helper {} // expected-error {{metadata attribute 'Rule' cannot be applied to struct 'Helper'; its module makes it unavailable}}

@InternalKey extension Open {} // expected-error {{unknown attribute 'InternalKey'}}
