enum DefaultOverride<Value: Hashable>: Hashable {
    case appDefault
    case none
    case value(Value)
}
