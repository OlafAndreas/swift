// RUN: %target-typecheck-verify-swift -enable-experimental-feature Embedded -enable-experimental-feature CustomMetadata

// REQUIRES: swift_feature_Embedded
// REQUIRES: swift_feature_CustomMetadata

@customMetadata // expected-error {{'@customMetadata' is not supported in Embedded Swift}}
enum Key {}

@Key // expected-error {{metadata attribute 'Key' is not supported in Embedded Swift}}
struct Marked {}

struct Other {}
@Key // expected-error {{metadata attribute 'Key' is not supported in Embedded Swift}}
extension Other {}
