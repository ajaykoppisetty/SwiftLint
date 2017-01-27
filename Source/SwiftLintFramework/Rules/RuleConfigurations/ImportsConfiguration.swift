//
//  ImportsRuleConfiguration.swift
//  SwiftLint
//
//  Created by Miguel Revetria on 31/1/17.
//  Copyright © 2017 Realm. All rights reserved.
//

import Foundation

public struct ImportsConfiguration: RuleConfiguration, Equatable {

    private(set) var ignoreCase: Bool
    private(set) var ignoreDuplicatedImports: Bool
    private(set) var ignoreImportsOrder: Bool
    private(set) var ignoreImportsPosition: Bool

    private(set) var severityConfiguration = SeverityConfiguration(.warning)

    public var consoleDescription: String {
        return severityConfiguration.consoleDescription +
            ", ignore_order: \(ignoreImportsOrder), ignore_position: \(ignoreImportsPosition)"
    }

    public var severity: ViolationSeverity {
        return severityConfiguration.severity
    }

    public init(ignoreCase: Bool,
                ignoreDuplicatedImports: Bool,
                ignoreImportsOrder: Bool,
                ignoreImportsPosition: Bool) {
        self.ignoreCase = ignoreCase
        self.ignoreDuplicatedImports = ignoreDuplicatedImports
        self.ignoreImportsOrder = ignoreImportsOrder
        self.ignoreImportsPosition = ignoreImportsPosition
    }

    public mutating func apply(configuration: Any) throws {
        guard let configuration = configuration as? [String: Any] else {
            throw ConfigurationError.unknownConfiguration
        }

        ignoreCase = (configuration["ignore_case"] as? Bool == true)
        ignoreDuplicatedImports = (configuration["ignore_duplicated"] as? Bool == true)
        ignoreImportsOrder = (configuration["ignore_order"] as? Bool == true)
        ignoreImportsPosition = (configuration["ignore_position"] as? Bool == true)

        if let severity = configuration["severity"] as? String {
            try severityConfiguration.apply(configuration: severity)
        }
    }

}

public func == (lhs: ImportsConfiguration, rhs: ImportsConfiguration) -> Bool {
    return lhs.ignoreCase == rhs.ignoreCase &&
        lhs.ignoreDuplicatedImports == rhs.ignoreDuplicatedImports &&
        lhs.ignoreImportsOrder == rhs.ignoreImportsOrder &&
        lhs.ignoreImportsPosition == rhs.ignoreImportsPosition &&
        lhs.severityConfiguration == rhs.severityConfiguration
}
