//===--- CustomMetadata.swift ---------------------------------------------===//
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

#if !$Embedded

import SwiftShims

/// The runtime's walk over the custom metadata attribute records of every
/// loaded image. Absent from Apple OS releases whose runtime predates it, so
/// weak-linked and guarded by the availability check below.
@available(SwiftStdlib 6.5, *)
@usableFromInline
@_silgen_name("swift_enumerateCustomMetadataTypes")
internal func _swift_enumerateCustomMetadataTypes(
  _ key: Any.Type,
  _ body: @convention(c) (
    _ type: UnsafeRawPointer,
    _ context: UnsafeMutableRawPointer?
  ) -> Bool,
  _ context: UnsafeMutableRawPointer?
)

/// Returns every type in a loaded image that carries the custom metadata
/// attribute `key`.
///
/// A custom metadata attribute is a struct or enum marked `@customMetadata`.
/// Applying it to a type, or to an extension of one, records that the type
/// carries it:
///
///     @customMetadata
///     public enum LintRule {}
///
///     @LintRule
///     struct ArrayInitRule: Rule { ... }
///
/// The record is emitted in the module that contains the application, so a
/// library finds the types that carry its attribute in every loaded image
/// without a registry.
///
/// - Parameter key: A type marked `@customMetadata`.
/// - Returns: Each type that carries `key` once, in no particular order, for
///   the images loaded at the time of the call. A type whose availability
///   excludes the running OS is not returned.
@backDeployed(before: SwiftStdlib 6.5)
public func customMetadataTypes<Key>(marked key: Key.Type) -> [Any.Type] {
  var result: [Any.Type] = []
  withUnsafeMutablePointer(to: &result) { resultPointer in
    let context = UnsafeMutableRawPointer(resultPointer)
    unsafe _enumerateCustomMetadataTypes(key, { type, context in
      guard let context = unsafe context else {
        return true
      }
      let result = unsafe context.assumingMemoryBound(to: [Any.Type].self)
      unsafe result.pointee.append(
        unsafe unsafeBitCast(type, to: Any.Type.self))
      return true
    }, context)
  }
  return result
}

/// Uses the runtime's walk where the runtime has one, and the client-side
/// fallback on Apple OS releases whose runtime predates it.
@_alwaysEmitIntoClient
internal func _enumerateCustomMetadataTypes(
  _ key: Any.Type,
  _ body: @convention(c) (UnsafeRawPointer, UnsafeMutableRawPointer?) -> Bool,
  _ context: UnsafeMutableRawPointer?
) {
  // Literal versions, as in `_enumerateCustomSections`.
  if #available(
    macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, visionOS 9999, *
  ) {
    unsafe _swift_enumerateCustomMetadataTypes(key, body, context)
  } else {
    unsafe _enumerateCustomMetadataTypesWithoutRuntime(key, body, context)
  }
}

/// The back-deployment fallback. It walks the `__swift5_rattrs` section of
/// every image dyld reports and applies the runtime's rules to each record,
/// reaching type metadata only through context descriptors and their access
/// functions. Other platforms ship the runtime with the toolchain and never
/// reach this.
@_alwaysEmitIntoClient
internal func _enumerateCustomMetadataTypesWithoutRuntime(
  _ key: Any.Type,
  _ body: @convention(c) (UnsafeRawPointer, UnsafeMutableRawPointer?) -> Bool,
  _ context: UnsafeMutableRawPointer?
) {
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
  let keyMetadata = unsafe unsafeBitCast(key, to: UnsafeRawPointer.self)
  guard let keyDescriptor =
    unsafe _swift_stdlib_customMetadata_valueTypeDescriptor(keyMetadata)
  else { return }

  // The record: type and attribute descriptors as indirectable relative
  // pointers, the reserved value, flags and availability.
  let recordSize = 20
  var seen: [UnsafeRawPointer] = unsafe []
  let imageCount = _swift_stdlib_customSections_imageCount()
  for index in 0..<imageCount {
    guard let header = unsafe _swift_stdlib_customSections_imageHeader(index)
    else { continue }
    var size = 0
    guard let start = unsafe _swift_stdlib_customSections_sectionData(
      header, "__TEXT", "__swift5_rattrs", &size
    ) else { continue }

    for offset in stride(from: 0, to: size - recordSize + 1, by: recordSize) {
      let record = unsafe start + offset
      // A record with flags this version does not define may point at
      // something other than a type descriptor.
      guard unsafe record.load(fromByteOffset: 12, as: UInt32.self) == 0 else {
        continue
      }

      let attribute = unsafe _resolveIndirectableRelativePointer(record + 4)
      guard unsafe attribute == keyDescriptor ||
        _swift_stdlib_customMetadata_resolve(attribute) == keyMetadata
      else { continue }

      let availability = unsafe record.load(fromByteOffset: 16, as: UInt32.self)
      if availability != 0 {
        let major = Int(availability >> 16)
        let minor = Int((availability >> 8) & 0xFF)
        let patch = Int(availability & 0xFF)
        guard Bool(_stdlib_isOSVersionAtLeast(
          major._builtinWordValue, minor._builtinWordValue,
          patch._builtinWordValue
        )) else { continue }
      }

      guard let type = unsafe _swift_stdlib_customMetadata_resolve(
        _resolveIndirectableRelativePointer(record)
      ), unsafe !seen.contains(type) else { continue }
      unsafe seen.append(type)
      if unsafe !body(type, context) { return }
    }
  }
#endif
}

/// The target of a relative pointer that may refer through a pointer-sized
/// slot, which the low bit of the offset selects.
@_alwaysEmitIntoClient
internal func _resolveIndirectableRelativePointer(
  _ field: UnsafeRawPointer
) -> UnsafeRawPointer? {
  let offset = unsafe Int(field.load(as: Int32.self))
  if offset == 0 { return nil }
  let target = unsafe field + (offset & ~1)
  if offset & 1 == 0 { return unsafe target }
  return unsafe target.load(as: UnsafeRawPointer?.self)
}

#endif // !$Embedded
