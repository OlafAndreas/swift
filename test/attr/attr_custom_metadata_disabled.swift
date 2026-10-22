// RUN: %target-typecheck-verify-swift

@customMetadata // expected-error {{'customMetadata' attribute is only valid when experimental feature CustomMetadata is enabled}}
enum Key {}
