// RUN: %empty-directory(%t)
// RUN: split-file %s %t
// RUN: %empty-directory(%t/elf)
// RUN: %empty-directory(%t/coff)
// RUN: %empty-directory(%t/macho)
// RUN: %swift_frontend_plain -target x86_64-unknown-linux-gnu -parse-stdlib -disable-objc-interop -enable-experimental-feature CustomMetadata -emit-module %t/Keys.swift -module-name Keys -o %t/elf/Keys.swiftmodule
// RUN: %swift_frontend_plain -target x86_64-unknown-linux-gnu -parse-stdlib -disable-objc-interop -enable-experimental-feature CustomMetadata -I %t/elf -emit-ir %t/main.swift -module-name main -o - | %FileCheck %t/main.swift --check-prefixes=CHECK,CHECK-ELF
// RUN: %swift_frontend_plain -target x86_64-unknown-windows-msvc -parse-stdlib -disable-objc-interop -enable-experimental-feature CustomMetadata -emit-module %t/Keys.swift -module-name Keys -o %t/coff/Keys.swiftmodule
// RUN: %swift_frontend_plain -target x86_64-unknown-windows-msvc -parse-stdlib -disable-objc-interop -enable-experimental-feature CustomMetadata -I %t/coff -emit-ir %t/main-coff.swift -module-name main -o - | %FileCheck %t/main-coff.swift --check-prefix=CHECK-COFF
// RUN: %swift_frontend_plain -target arm64-apple-macosx14.0 -parse-stdlib -disable-objc-interop -enable-experimental-feature CustomMetadata -emit-module %t/Keys.swift -module-name Keys -o %t/macho/Keys.swiftmodule
// RUN: %swift_frontend_plain -target arm64-apple-macosx14.0 -parse-stdlib -disable-objc-interop -enable-experimental-feature CustomMetadata -I %t/macho -emit-ir %t/main-macho.swift -module-name main -o - | %FileCheck %t/main-macho.swift --check-prefix=CHECK-MACHO

// REQUIRES: swift_feature_CustomMetadata
// REQUIRES: CODEGENERATOR=X86
// REQUIRES: CODEGENERATOR=AArch64

//--- Keys.swift
@customMetadata public enum Rule {}
public struct Foreign {}

//--- main.swift
import Keys

@customMetadata enum Local {}

// A key from this module on a type from this module.
@Local struct Mine {}

// A key from another module on a type from another module, through an
// extension: both descriptor references are indirect.
@Rule extension Foreign {}

// Opting out records nothing.
struct Helper {}
@available(*, unavailable) @Local extension Helper {}

// CHECK-ELF: @"\01l_custom_metadata_record" = private constant { i32, i32, i32, i32, i32 } { i32 trunc {{.*}}@"$s4main4MineVMn"{{.*}}, i32 trunc {{.*}}@"$s4main5LocalOMn"{{.*}}, i32 0, i32 0, i32 0 }, section "swift5_runtime_attributes", {{.*}}align 4
// CHECK-ELF: @"\01l_custom_metadata_record.1" = private constant { i32, i32, i32, i32, i32 } { i32 add {{.*}}@"got.$s4Keys7ForeignVMn"{{.*}}, i32 1), i32 add {{.*}}@"got.$s4Keys4RuleOMn"{{.*}}, i32 1), i32 0, i32 0, i32 0 }, section "swift5_runtime_attributes", {{.*}}align 4
// CHECK-NOT: l_custom_metadata_record.2
// CHECK: @llvm{{(\.compiler)?}}.used = {{.*}}@"\01l_custom_metadata_record"{{.*}}@"\01l_custom_metadata_record.1"

//--- main-coff.swift
import Keys

@customMetadata enum Local {}
@Local struct Mine {}

// CHECK-COFF: @"\01l_custom_metadata_record" = private constant { i32, i32, i32, i32, i32 } {{.*}}, section ".sw5ratt$B", {{.*}}align 4

//--- main-macho.swift
import Keys

@customMetadata enum Local {}
@Local struct Mine {}

// The record carries the type's minimum OS version beyond the deployment
// target: 99.1.2 packs as 99 << 16 | 1 << 8 | 2.
@available(macOS 99.1.2, *)
@Local struct Later {}

// CHECK-MACHO: @"\01l_custom_metadata_record" = private constant { i32, i32, i32, i32, i32 } {{.*}}, i32 0, i32 0, i32 0 }, section "__TEXT, __swift5_rattrs, regular", {{.*}}align 4
// CHECK-MACHO: @"\01l_custom_metadata_record.1" = private constant { i32, i32, i32, i32, i32 } {{.*}}, i32 0, i32 0, i32 6488322 }, section "__TEXT, __swift5_rattrs, regular", {{.*}}align 4
