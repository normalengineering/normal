import AppIntents

extension UnblockDuration: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Unblock Duration" }

    static let caseDisplayRepresentations: [UnblockDuration: DisplayRepresentation] = [
        .fifteenMinutes: "15 Minutes",
        .thirtyMinutes: "30 Minutes",
        .oneHour: "1 Hour",
        .fourHours: "4 Hours",
    ]
}
