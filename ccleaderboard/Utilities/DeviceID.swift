import Foundation
import IOKit

enum DeviceID {
    static let current: String = {
        getDeviceUUID()
    }()

    private static func getDeviceUUID() -> String {
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        let uuid = IORegistryEntryCreateCFProperty(platformExpert, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0)
        IOObjectRelease(platformExpert)
        return (uuid?.takeRetainedValue() as? String) ?? UUID().uuidString
    }
}