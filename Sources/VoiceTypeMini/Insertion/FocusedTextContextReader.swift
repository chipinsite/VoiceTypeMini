import ApplicationServices
import Foundation

struct FocusedTextContext: Equatable {
    let roleDescription: String?
    let selectedText: String?
    let nearbyText: String
    let fieldText: String
    var isEmpty: Bool {
        selectedText?.trimmedForLearning.isEmpty != false
            && nearbyText.trimmedForLearning.isEmpty
    }
}

struct FocusedTextSnapshot {
    let context: FocusedTextContext
    let fieldElement: AXUIElement
    var fieldText: String { context.fieldText }

    func isSameField(as other: FocusedTextSnapshot) -> Bool {
        CFEqual(fieldElement, other.fieldElement)
    }
}

@MainActor
final class FocusedTextContextReader {
    private let focusedApplicationAttribute = kAXFocusedApplicationAttribute as CFString
    private let focusedElementAttribute = "AXFocusedUIElement" as CFString
    private let selectedTextRangeAttribute = "AXSelectedTextRange" as CFString
    private let valueAttribute = "AXValue" as CFString
    private let roleAttribute = "AXRole" as CFString
    private let subroleAttribute = "AXSubrole" as CFString
    private let descriptionAttribute = "AXDescription" as CFString
    private let placeholderAttribute = "AXPlaceholderValue" as CFString

    func snapshot(maxCharactersAroundSelection: Int = 700) -> FocusedTextSnapshot? {
        guard AXIsProcessTrusted(),
              let element = focusedElement,
              !looksSensitive(element),
              let value = stringAttribute(valueAttribute, from: element),
              !value.trimmedForLearning.isEmpty
        else {
            return nil
        }

        let selectedRange = selectedRange(in: element)
        let selectedText = selectedRange
            .flatMap { stringRange(from: $0, in: value) }
            .map { String(value[$0]).trimmedForLearning }
            .flatMap { $0.isEmpty ? nil : $0 }

        let nearbyText = nearbyText(
            in: value,
            selectedRange: selectedRange,
            maxCharactersAroundSelection: maxCharactersAroundSelection
        )

        let context = FocusedTextContext(
            roleDescription: roleDescription(for: element),
            selectedText: selectedText,
            nearbyText: nearbyText,
            fieldText: value
        )

        return context.isEmpty ? nil : FocusedTextSnapshot(context: context, fieldElement: element)
    }

    private var focusedElement: AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedApplicationValue: CFTypeRef?
        let appResult = AXUIElementCopyAttributeValue(
            systemWide,
            focusedApplicationAttribute,
            &focusedApplicationValue
        )
        guard appResult == .success,
              let focusedApplication = axElement(from: focusedApplicationValue) else {
            return nil
        }

        var focusedElementValue: CFTypeRef?
        let elementResult = AXUIElementCopyAttributeValue(
            focusedApplication,
            focusedElementAttribute,
            &focusedElementValue
        )
        guard elementResult == .success,
              let focusedElement = axElement(from: focusedElementValue) else {
            return nil
        }

        return focusedElement
    }

    private func nearbyText(
        in value: String,
        selectedRange: CFRange?,
        maxCharactersAroundSelection: Int
    ) -> String {
        let utf16Count = value.utf16.count
        let anchorLocation = selectedRange?.location ?? utf16Count
        let anchorLength = selectedRange?.length ?? 0
        let lowerBound = max(0, anchorLocation - maxCharactersAroundSelection)
        let upperBound = min(utf16Count, anchorLocation + anchorLength + maxCharactersAroundSelection)
        let cfRange = CFRange(location: lowerBound, length: upperBound - lowerBound)

        guard let range = stringRange(from: cfRange, in: value) else {
            return String(value.suffix(maxCharactersAroundSelection * 2)).trimmedForLearning
        }

        return String(value[range]).trimmedForLearning
    }

    private func looksSensitive(_ element: AXUIElement) -> Bool {
        let role = stringAttribute(roleAttribute, from: element)?.lowercased() ?? ""
        let subrole = stringAttribute(subroleAttribute, from: element)?.lowercased() ?? ""
        let description = stringAttribute(descriptionAttribute, from: element)?.lowercased() ?? ""
        let placeholder = stringAttribute(placeholderAttribute, from: element)?.lowercased() ?? ""
        let combined = [role, subrole, description, placeholder].joined(separator: " ")

        if role.contains("secure") || subrole.contains("secure") {
            return true
        }

        let sensitiveTerms = [
            "password",
            "passcode",
            "pin",
            "one-time",
            "otp",
            "credit card",
            "card number",
            "security code",
            "cvv",
            "secret"
        ]

        return sensitiveTerms.contains { combined.contains($0) }
    }

    private func roleDescription(for element: AXUIElement) -> String? {
        let role = stringAttribute(roleAttribute, from: element)
        let subrole = stringAttribute(subroleAttribute, from: element)
        return [role, subrole]
            .compactMap { $0?.trimmedForLearning }
            .filter { !$0.isEmpty }
            .joined(separator: " / ")
            .nilIfEmpty
    }

    private func stringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &valueRef) == .success else {
            return nil
        }

        return valueRef as? String
    }

    private func selectedRange(in element: AXUIElement) -> CFRange? {
        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, selectedTextRangeAttribute, &rangeRef) == .success,
              let rangeValue = rangeRef,
              CFGetTypeID(rangeValue) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = rangeValue as! AXValue
        guard AXValueGetType(axValue) == .cfRange else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range) else {
            return nil
        }

        return range
    }

    private func axElement(from value: CFTypeRef?) -> AXUIElement? {
        guard let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }

        return (value as! AXUIElement)
    }

    private func stringRange(from cfRange: CFRange, in string: String) -> Range<String.Index>? {
        guard cfRange.location >= 0,
              cfRange.length >= 0 else {
            return nil
        }

        let utf16 = string.utf16
        guard let utf16Start = utf16.index(
            utf16.startIndex,
            offsetBy: cfRange.location,
            limitedBy: utf16.endIndex
        ),
              let utf16End = utf16.index(
                utf16Start,
                offsetBy: cfRange.length,
                limitedBy: utf16.endIndex
              ),
              let start = String.Index(utf16Start, within: string),
              let end = String.Index(utf16End, within: string) else {
            return nil
        }

        return start..<end
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
