// swift-tools-version: 6.0
//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  PlaycoVideo — cœur vidéo + fondations IA, HORS DE L'APP (docs/Plan_Video_IA.md).
//  Logique pure Foundation, sport-agnostique, testable sur Linux (CI) et Apple.
//  Non lié à la cible Playco tant que la vidéo n'est pas livrée.

import PackageDescription

let package = Package(
    name: "PlaycoVideo",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PlaycoVideo", targets: ["PlaycoVideo"])
    ],
    targets: [
        .target(name: "PlaycoVideo"),
        .testTarget(name: "PlaycoVideoTests", dependencies: ["PlaycoVideo"])
    ]
)
