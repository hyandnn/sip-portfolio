import Foundation

/// Repository fixtures shared by tests; this target is not an app dependency.
public enum TestResources {
    public static func url(forResource name: String, withExtension ext: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures")
    }

    public static func data(named name: String, extension ext: String) throws -> Data {
        guard let file = url(forResource: name, withExtension: ext) else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        return try Data(contentsOf: file)
    }
}
