// RUN: %target-typecheck-verify-swift -enable-experimental-feature CustomMetadata

// REQUIRES: swift_feature_CustomMetadata

@customMetadata
enum Key {}

@customMetadata
struct KeyWithMembers {
  var value: Int
  func method() {}
}

@customMetadata // expected-error {{'@customMetadata' cannot be applied to generic struct 'GenericKey', which is generic or nested in a generic type}}
struct GenericKey<T> {}

struct Outer<T> {
  @customMetadata // expected-error {{'@customMetadata' cannot be applied to enum 'NestedKey', which is generic or nested in a generic type}}
  enum NestedKey {}
}

@customMetadata // expected-error {{'@customMetadata' attribute cannot be applied to this declaration}}
class ClassKey {}

@customMetadata // expected-error {{'@customMetadata' attribute cannot be applied to this declaration}}
protocol ProtocolKey {}

func localKey() {
  @customMetadata // expected-error {{'@customMetadata' cannot be applied to local enum 'LocalKey'}}
  enum LocalKey {}
}

// Applications.

@Key struct S {}
@Key enum E {}
@Key class C {}
@Key actor A {}

struct Plain {}
@Key extension Plain {}

struct Twice {}
@Key extension Twice {} // expected-note {{'Key' is applied here}}
@Key extension Twice {} // expected-error {{metadata attribute 'Key' is already applied to struct 'Twice' in this module}}

@Key // expected-note {{'Key' is applied here}}
@Key // expected-error {{metadata attribute 'Key' is already applied to struct 'Doubled' in this module}}
struct Doubled {}

@Key(1) struct WithArguments {} // expected-error {{metadata attribute 'Key' takes no arguments}}

@Key struct GenericType<T> {} // expected-error {{metadata attribute 'Key' cannot be applied to generic struct 'GenericType', which is generic or nested in a generic type}}

struct GenericOuter<T> {
  @Key struct Inner {} // expected-error {{metadata attribute 'Key' cannot be applied to struct 'Inner', which is generic or nested in a generic type}}
}

struct NonGenericOuter {
  @Key struct Inner {}
}

func local() {
  @Key struct LocalType {} // expected-error {{metadata attribute 'Key' cannot be applied to local struct 'LocalType'}}
}

@Key protocol P {} // expected-error {{metadata attribute 'Key' can only be applied to a struct, enum, class or actor, or to an extension of one}}

@Key func f() {} // expected-error {{metadata attribute 'Key' can only be applied to a struct, enum, class or actor, or to an extension of one}}

@Key var v = 0 // expected-error {{metadata attribute 'Key' can only be applied to a struct, enum, class or actor, or to an extension of one}}

protocol Q {}
@Key extension Q {} // expected-error {{metadata attribute 'Key' can only be applied to a struct, enum, class or actor, or to an extension of one}}

// Opting out.

struct Helper {}
@available(*, unavailable)
@KeyWithMembers extension Helper {} // expected-note {{'KeyWithMembers' is made unavailable for struct 'Helper' here}}
@KeyWithMembers extension Helper {} // expected-error {{metadata attribute 'KeyWithMembers' cannot be applied to struct 'Helper'; its module makes it unavailable}}

@Key extension Helper {}
