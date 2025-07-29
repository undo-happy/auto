// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OfflineChatbot",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "OfflineChatbot",
            targets: ["OfflineChatbot"]
        ),
        .library(
            name: "MLModel",
            targets: ["MLModel"]
        ),
        .library(
            name: "NetworkManager",
            targets: ["NetworkManager"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/realm/realm-swift.git", from: "10.40.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.3.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift-examples.git", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "OfflineChatbot",
            dependencies: [
                "MLModel",
                "NetworkManager",
                .product(name: "RealmSwift", package: "realm-swift")
            ]
        ),
        .target(
            name: "MLModel",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXLLM", package: "mlx-swift-examples"),
                .product(name: "MLXLMCommon", package: "mlx-swift-examples")
            ]
        ),
        .target(
            name: "NetworkManager",
            dependencies: []
        ),
        .testTarget(
            name: "OfflineChatbotTests",
            dependencies: ["OfflineChatbot"]
        ),
        .testTarget(
            name: "MLModelTests",
            dependencies: ["MLModel"]
        )
    ]
)