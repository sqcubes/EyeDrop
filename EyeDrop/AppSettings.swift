import Cocoa

public enum AppSettings: Int, Hashable {
    case interval
    case otherSetting
    case darknessOption
    
    private static var defaults: UserDefaults { return UserDefaults.standard }
    private var defaults: UserDefaults { return AppSettings.defaults }
    
    var key: String {
        switch self {
        case .interval: return "minutesInterval"
        case .otherSetting: return "otherSetting"
        case .darknessOption: return "darknessOption"
        }
    }
    
    var defaultValue: Any? {
        switch self {
        case .interval: return TimeInterval(20 * 60)
        case .otherSetting: return nil
        case .darknessOption: return DarknessOption.Medium.rawValue
        }
    }
    
    public var value: Any? { return defaults.value(forKey: key) }
    public var string: String? { return defaults.string(forKey: key) }
    public var array: [AnyObject]? { return defaults.array(forKey: key) as [AnyObject]? }
    public var dictionary: [AnyHashable: Any]? { return defaults.dictionary(forKey: key) }
    public var data: Data? { return defaults.data(forKey: key) }
    public var stringArray: [String]? { return defaults.stringArray(forKey: key) }
    public var integer: Int { return defaults.integer(forKey: key) }
    public var float: Float { return defaults.float(forKey: key) }
    public var double: Double { return defaults.double(forKey: key) }
    public var bool: Bool { return defaults.bool(forKey: key) }
    public var url: URL? { return defaults.url(forKey: key) }
    public func remove() { defaults.removeObject(forKey: key) }
    
    @discardableResult public func set(_ value: Any?) { defaults.set(value, forKey: key) }
    @discardableResult public func set(_ value: Int)  { defaults.set(value, forKey: key) }
    @discardableResult public func set(_ value: Int64) { defaults.set(value, forKey: key) }
    @discardableResult public func set(_ value: Float) { defaults.set(value, forKey: key) }
    @discardableResult public func set(_ value: Double) { defaults.set(value, forKey: key) }
    @discardableResult public func set(_ value: Bool) { defaults.set(value, forKey: key) }
    @discardableResult public func set(_ url: URL) { defaults.set(value, forKey: key) }
    
    public static func registerDefaults() {
        var defaults = [String:Any]()
        for setting in all {
            if let defaultValue = setting.defaultValue {
                defaults[setting.key] = defaultValue
            }
        }
        AppSettings.defaults.register(defaults: defaults)
    }
    
    public static func reset() {
        defaults.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
        registerDefaults()
    }
    
    // http://stackoverflow.com/questions/24007461/how-to-enumerate-an-enum-with-string-type
    public static var all: [AppSettings] = { () -> [AppSettings] in
        let retVal = AnySequence { () -> AnyIterator<AppSettings> in
            var raw = 0
            return AnyIterator {
                let current : AppSettings = withUnsafePointer(to: &raw) {
                    $0.withMemoryRebound(to: AppSettings.self, capacity: 1) { $0.pointee }
                }
                guard current.hashValue == raw else { return nil }
                raw += 1
                return current
            }
        }
        
        return [AppSettings](retVal)
    }()
}
