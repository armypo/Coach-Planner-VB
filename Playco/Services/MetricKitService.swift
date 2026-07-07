//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  2.2.b — MetricKit : diagnostics crash/hang natifs Apple, zéro dépendance.
//  Les payloads arrivent au plus tard 24 h après l'incident et sont journalisés
//  dans le log unifié (Console.app, catégorie "MetricKit") — première ligne de
//  défense observabilité avant tout backend. Aucune donnée ne quitte l'appareil.

import Foundation
import MetricKit
import os

private let logger = Logger(subsystem: "com.origotech.playco", category: "MetricKit")

final class MetricKitService: NSObject, MXMetricManagerSubscriber {

    static let partage = MetricKitService()

    private override init() { super.init() }

    /// Abonne le service au flux MetricKit. Appeler une fois au démarrage.
    func demarrer() {
        MXMetricManager.shared.add(self)
        logger.info("MetricKitService abonné aux diagnostics")
    }

    // MetricKit livre sur une file d'arrière-plan — on ne touche qu'au Logger.
    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            let crashs = payload.crashDiagnostics?.count ?? 0
            let hangs = payload.hangDiagnostics?.count ?? 0
            let cpu = payload.cpuExceptionDiagnostics?.count ?? 0
            let disque = payload.diskWriteExceptionDiagnostics?.count ?? 0
            if crashs > 0 || hangs > 0 {
                logger.error("Diagnostics — crashs: \(crashs), hangs: \(hangs), cpu: \(cpu), disque: \(disque) (période jusqu'au \(payload.timeStampEnd))")
            } else if cpu > 0 || disque > 0 {
                logger.warning("Diagnostics — cpu: \(cpu), disque: \(disque)")
            }
            for crash in payload.crashDiagnostics ?? [] {
                logger.error("Crash: \(crash.callStackTree.jsonRepresentation().count) octets de call stack — signal \(crash.signal?.stringValue ?? "?"), code \(crash.exceptionCode?.stringValue ?? "?")")
            }
        }
    }

    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            let lancement = payload.applicationLaunchMetrics?.histogrammedTimeToFirstDraw.averageestimation ?? 0
            logger.info("Métriques quotidiennes reçues (time-to-first-draw moyen ≈ \(lancement, format: .fixed(precision: 2)))")
        }
    }
}

private extension MXHistogram<UnitDuration> {
    /// Estimation grossière de la moyenne d'un histogramme MetricKit (log seulement).
    var averageestimation: Double {
        var total = 0.0, poids = 0.0
        let enumerateur = bucketEnumerator
        while let bucket = enumerateur.nextObject() as? MXHistogramBucket<UnitDuration> {
            let milieu = (bucket.bucketStart.value + bucket.bucketEnd.value) / 2
            total += milieu * Double(bucket.bucketCount)
            poids += Double(bucket.bucketCount)
        }
        return poids > 0 ? total / poids : 0
    }
}
