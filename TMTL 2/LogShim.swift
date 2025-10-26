// LogShim.swift
import Foundation

#if DEBUG
// Temporarily silence *all* plain `print(...)` calls in Debug builds.
func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
  // no-op: intentionally blank so non-notification prints don't spam the console
}
#endif

