//
//  AlwaysFailRule.swift
//  SwiftLint
//
//  Created by Miguel Revetria on 30/1/17.
//  Copyright © 2017 Realm. All rights reserved.
//

import Foundation
import SourceKittenFramework

public struct ImportsRule: ConfigurationProviderRule, OptInRule {

    public var configuration = ImportsConfiguration(
        ignoreCase: true,
        ignoreDuplicatedImports: false,
        ignoreImportsOrder: false,
        ignoreImportsPosition: false
    )

    public init() {
    }

    public static let description = RuleDescription(
        identifier: "imports",
        name: "Imports",
        description: "Imports should at top of the file and alphabetically sorted.",
        nonTriggeringExamples: [
            "",
            "import UIKit",
            "@testable import Test",
            "import UIKit\n@testeable import Test",
            "import AVKit.AVError\nimport enum Test.Enum\nimport GameKit\nimport struct Test.Struct",
            "import Foundation\n\nimport UIKit",
            "import Foundation\n\nstruct Test { }",
            "@testable import Test\n\nstruct Test { }",
            "struct Test { }"
        ],
        triggeringExamples: [
            "import UIKit\nimport Foundation",
            "@testable import Test\nimport Foundation",
            "import Foundation\n\nstruct Test { }\nimport Test",
            "@testable import Test\nimport Foundation\nstruct Test { }",
            "struct Test { }\n\nimport Foundation",
            "struct Test { }\n\n@testable import Foundation",
            "import UIKit\nimport UIKit"
        ]
    )

    public func validate(file: File) -> [StyleViolation] {
        var violations: [StyleViolation] = []
        violations.append(contentsOf: validateImportsAtTop(file: file))
        violations.append(contentsOf: validateImportsOrder(file: file))
        violations.append(contentsOf: validateImportUniqueness(file: file))

        return violations
    }

}

// MARK: - Imports duplication validation

extension ImportsRule {

    fileprivate func validateImportUniqueness(file: File) -> [StyleViolation] {
        guard !configuration.ignoreDuplicatedImports else {
            return []
        }

        var violations: [StyleViolation] = []

        var lineContents: [String] = []

        uncommentedLines(fromFile: file).filter(isImport)
            .sorted { $0.content < $1.content }
            .forEach { line in
                if lineContents.contains(line.content) {
                    violations.append(StyleViolation(
                        ruleDescription: type(of: self).description,
                        severity: configuration.severity,
                        location: Location(file: file.path, line: line.index),
                        reason: "Duplicated imports should be avoided"
                    ))
                } else {
                    lineContents.append(line.content)
                }
            }

        return violations
    }

}

// MARK: - Imports order validation

extension ImportsRule {

    fileprivate func validateImportsOrder(file: File) -> [StyleViolation] {
        guard !configuration.ignoreImportsOrder else {
            return []
        }

        var violations: [StyleViolation] = []

        let imports = uncommentedLines(fromFile: file).filter(isImport)
        if imports.isEmpty {
            return []
        }

        for ind in 0..<(imports.count - 1) {
            let line = imports[ind]
            let nextLine = imports[ind + 1]
            if isLine(line, greaterThan: nextLine) {
                let testableInMiddle = isTestableImport(line: line) && !isTestableImport(line: nextLine)
                let location = Location(file: file.path, line: imports[ind + 1].index)
                violations.append(StyleViolation(
                    ruleDescription: type(of: self).description,
                    severity: configuration.severity,
                    location: location,
                    reason: testableInMiddle ?
                        "Testable imports should be grouped after normal imports." :
                        "Imports should be alphabetically sorted."
                ))
            }
        }

        return violations
    }

}

// MARK: - Imports position validation

extension ImportsRule {

    fileprivate func validateImportsAtTop(file: File) -> [StyleViolation] {
        guard !configuration.ignoreImportsPosition else {
            return []
        }

        var violations: [StyleViolation] = []

        let linesOfCode = uncommentedLines(fromFile: file)

        guard !linesOfCode.isEmpty, let firstLineOfCodeIndex = linesOfCode.index(where: { !isImport(line: $0) }) else {
            return []
        }

        // Search for imports after the first line of code
        linesOfCode.suffix(linesOfCode.count - firstLineOfCodeIndex)
            .filter(isImport)
            .forEach { line in
                let location = Location(file: file.path, line: line.index)
                violations.append(StyleViolation(
                    ruleDescription: type(of: self).description,
                    severity: configuration.severity,
                    location: location,
                    reason: "Imports should be declared at top of the file"
                ))
            }

        return violations
    }

}

// MARK: - Utility functions

extension ImportsRule {

    fileprivate func isLine(_ lhs: Line, greaterThan rhs: Line) -> Bool {
        let lhsContent = normalize(lhs.content, lowerCased: configuration.ignoreCase)
        let rhsContent = normalize(rhs.content, lowerCased: configuration.ignoreCase)

        if isTestableImport(line: lhs) && isTestableImport(line: rhs) {
            return lhsContent > rhsContent
        } else if isTestableImport(line: lhs) {
            return true
        } else if isTestableImport(line: rhs) {
            return false
        } else {
            return lhsContent > rhsContent
        }
    }

    fileprivate func normalize(_ content: String, lowerCased: Bool = false) -> String {
        let normalized = content.trimmingCharacters(in: CharacterSet.whitespaces)
        return lowerCased ? normalized.lowercased() : normalized
    }

    fileprivate func isImport(line: Line) -> Bool {
        return normalize(line.content).hasPrefix("import ") || isTestableImport(line: line)
    }

    fileprivate func isTestableImport(line: Line) -> Bool {
        return normalize(line.content).hasPrefix("@testable import ")
    }

    fileprivate func uncommentedLines(fromFile file: File) -> [Line] {
        var lines: [Line] = []

        var ind = 0
        while ind < file.lines.count {
            let line = file.lines[ind]
            let content = normalize(line.content)
            if let _ = content.range(of: "\\/\\/.*\\/\\*", options: .regularExpression) {
                if !content.hasPrefix("//") {
                    // This line doesn't start with a comment mark, it may have useful and code we have to include it
                    lines.append(line)
                }
            } else if content.contains("/*") && content.contains("*/") {
                // Multiline comment closed in the same line
                if !content.hasPrefix("/*") {
                    // This line doesn't start with a comment mark, it may have useful and code we have to include it
                    lines.append(line)
                }
            } else if content.contains("/*") {
                if !content.hasPrefix("/*") {
                    // This line doesn't start with a comment mark, it may have useful and code we have to include it
                    lines.append(line)
                }

                // Multiline comment that is not closed in the same line,
                // move forward until the end of this comment block
                ind += 1
                while (ind < file.lines.count) && (!file.lines[ind].content.contains("*/")) {
                    ind += 1
                }
            } else if !content.hasPrefix("//") && !content.isEmpty {
                lines.append(line)
            }
            ind += 1
        }

        return lines
    }

}
