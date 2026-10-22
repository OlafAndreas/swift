//===--- CustomMetadata.cpp - Custom metadata attribute lookup ------------===//
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
//
// Finds the types that carry a custom metadata attribute by walking the
// records the compiler emits for each application.
//
//===----------------------------------------------------------------------===//

#include "ImageInspection.h"
#include "ImageInspectionCommon.h"
#include "swift/ABI/Metadata.h"
#include "swift/Runtime/Config.h"
#include "swift/Runtime/Metadata.h"
#include "llvm/ADT/SmallVector.h"

#if SWIFT_OBJC_INTEROP && defined(SWIFT_RUNTIME_OS_VERSIONING)
#include "swift/shims/FoundationShims.h"
#endif

#include <algorithm>
#include <cstdint>

using namespace swift;

namespace {

/// One application of a custom metadata attribute, as the compiler emits it.
struct CustomMetadataRecord {
  RelativeIndirectablePointer<const ContextDescriptor> type;
  RelativeIndirectablePointer<const ContextDescriptor> attribute;
  RelativeDirectPointer<const void> value;
  uint32_t flags;
  uint32_t availability;
};

struct Query {
  const Metadata *key;
  bool (*body)(const Metadata *type, void *context);
  void *context;
  llvm::SmallVector<const Metadata *, 16> seen;
  bool stopped = false;
};

} // end anonymous namespace

/// The metadata of a non-generic type, or null.
static const Metadata *resolveNonGeneric(const ContextDescriptor *descriptor) {
  auto *type = dyn_cast_or_null<TypeContextDescriptor>(descriptor);
  if (!type || type->isGeneric())
    return nullptr;
  auto accessFunction = type->getAccessFunction();
  if (!accessFunction)
    return nullptr;
  return accessFunction(MetadataState::Complete).Value;
}

/// Whether the running OS meets a record's packed minimum version.
static bool isAvailable(uint32_t availability) {
  if (availability == 0)
    return true;
#if SWIFT_OBJC_INTEROP && defined(SWIFT_RUNTIME_OS_VERSIONING)
  auto running = _swift_stdlib_operatingSystemVersion();
  uint32_t required[3] = {availability >> 16, (availability >> 8) & 0xFF,
                          availability & 0xFF};
  uint32_t current[3] = {static_cast<uint32_t>(running.majorVersion),
                         static_cast<uint32_t>(running.minorVersion),
                         static_cast<uint32_t>(running.patchVersion)};
  return !std::lexicographical_compare(current, current + 3, required,
                                       required + 3);
#else
  return true;
#endif
}

static bool visitRecords(const void *start, size_t size, void *context) {
  auto &query = *static_cast<Query *>(context);
  auto *record = static_cast<const CustomMetadataRecord *>(start);
  auto *end = record + size / sizeof(CustomMetadataRecord);
  auto *keyDescriptor = query.key->getTypeContextDescriptor();

  for (; record < end; ++record) {
    // A record with flags this runtime does not define may point at something
    // other than a type descriptor.
    if (record->flags != 0)
      continue;

    auto *attribute = record->attribute.get();
    if (attribute != keyDescriptor && resolveNonGeneric(attribute) != query.key)
      continue;

    if (!isAvailable(record->availability))
      continue;

    auto *type = resolveNonGeneric(record->type.get());
    if (!type || std::find(query.seen.begin(), query.seen.end(), type) !=
                     query.seen.end())
      continue;
    query.seen.push_back(type);

    if (!query.body(type, query.context)) {
      query.stopped = true;
      return false;
    }
  }
  return true;
}

#if !defined(__MACH__)
static bool visitImage(const MetadataSections *sections, void *context) {
  // Images built by an older toolchain carry no records.
  if (sections->version < 6)
    return true;
  const auto &range = sections->swift5_runtime_attributes;
  if (range.length == 0)
    return true;
  return visitRecords(reinterpret_cast<const void *>(range.start), range.length,
                      context);
}
#endif

SWIFT_RUNTIME_EXPORT
void swift_enumerateCustomMetadataTypes(const Metadata *key,
                                        bool (*body)(const Metadata *type,
                                                     void *context),
                                        void *context) {
  if (!key || !body || !key->getTypeContextDescriptor())
    return;

  Query query{key, body, context, {}};
#if defined(__MACH__)
  swift_enumerateCustomSections("__TEXT,__swift5_rattrs", visitRecords, &query);
#else
  swift_enumerateAllMetadataSections(visitImage, &query);
#endif
}
