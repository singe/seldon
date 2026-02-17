// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SeldonChat",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "SeldonChat", targets: ["SeldonChat"])
    ],
    targets: [
        .executableTarget(
            name: "SeldonChat",
            path: "Sources/SeldonChat"
        )
    ]
)
