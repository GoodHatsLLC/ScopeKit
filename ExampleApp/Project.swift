import ProjectDescription


// MARK: - Project

let platform = Platform.iOS


let infoPlist: [String: InfoPlist.Value] = [
    "CFBundleShortVersionString": "1.0",
    "CFBundleVersion": "1",
    "UIMainStoryboardFile": "",
    "UILaunchStoryboardName": "LaunchScreen"
    ]

let dependencies: [TargetDependency] = [
        .external(name: "ScopeKit")
]
let exampleName = "ExampleApp"
let exampleAppTarget = Target(
    name: exampleName,
    platform: platform,
    product: .app,
    bundleId: "llc.goodhats.\(exampleName)",
    infoPlist: .extendingDefault(with: infoPlist),
    sources: ["Targets/\(exampleName)/Sources/**"],
    resources: ["Targets/\(exampleName)/Resources/**"],
    dependencies: dependencies
)


let project = Project(name: "ExampleApp",
                      organizationName: "goodhats.llc",
                      targets: [exampleAppTarget])

