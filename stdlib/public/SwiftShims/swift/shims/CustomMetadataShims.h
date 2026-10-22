//===--- CustomMetadataShims.h - Metadata for back deployment -----*- C -*-===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
///
/// \file
/// Header-only metadata access for the back-deployed copy of
/// `customMetadataTypes(marked:)`, which runs on Apple OS releases whose Swift
/// runtime predates `swift_enumerateCustomMetadataTypes`. Everything here uses
/// only the stable metadata ABI and is inline, so that the client binary
/// carries it; nothing is exported from libswiftCore.
///
//===----------------------------------------------------------------------===//

#ifndef SWIFT_STDLIB_SHIMS_CUSTOMMETADATASHIMS_H
#define SWIFT_STDLIB_SHIMS_CUSTOMMETADATASHIMS_H

#include "SwiftStddef.h"
#include "SwiftStdint.h"

#if defined(__APPLE__) && defined(__MACH__)

#if __has_feature(ptrauth_calls)
#include <ptrauth.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

/// The context descriptor of a struct or enum metadata record, or null for
/// any other kind of metadata.
static inline const void *_Nullable
_swift_stdlib_customMetadata_valueTypeDescriptor(
    const void *_Nonnull metadata) {
  // MetadataKind::Struct and MetadataKind::Enum.
  __swift_uintptr_t kind = *(const __swift_uintptr_t *)metadata;
  if (kind != 0x200 && kind != 0x201)
    return 0;
  const void *descriptor = ((const void *const *)metadata)[1];
#if __has_feature(ptrauth_calls)
  descriptor = ptrauth_strip(descriptor, ptrauth_key_process_independent_data);
#endif
  return descriptor;
}

typedef struct {
  const void *_Nullable value;
  __swift_size_t state;
} _SwiftCustomMetadataResponse;

/// The complete metadata of a non-generic type described by `descriptor`, or
/// null when `descriptor` is not a non-generic type context descriptor.
static inline const void *_Nullable _swift_stdlib_customMetadata_resolve(
    const void *_Nullable descriptor) {
  if (!descriptor)
    return 0;
  // ContextDescriptorFlags: kinds 16 to 31 are types; 0x80 marks generic.
  __swift_uint32_t flags = *(const __swift_uint32_t *)descriptor;
  if ((flags & 0x1F) < 16 || (flags & 0x80) != 0)
    return 0;
  // TypeContextDescriptor: flags, parent, name, then the access function.
  const __swift_int32_t *field = (const __swift_int32_t *)descriptor + 3;
  if (*field == 0)
    return 0;
  const void *function = (const char *)field + *field;
#if __has_feature(ptrauth_calls)
  function =
      ptrauth_sign_unauthenticated(function, ptrauth_key_function_pointer, 0);
#endif
  typedef _SwiftCustomMetadataResponse
      __attribute__((swiftcall)) AccessFunction(__swift_size_t request);
  // MetadataRequest 0 asks for complete metadata, blocking.
  return ((AccessFunction *)function)(0).value;
}

#ifdef __cplusplus
} // extern "C"
#endif

#endif // defined(__APPLE__) && defined(__MACH__)

#endif // SWIFT_STDLIB_SHIMS_CUSTOMMETADATASHIMS_H
