//  Playco
//  Copyright © 2026 Christopher Dionne. Tous droits réservés.
//
//  playco-video — outils vidéo Playco en ligne de commande (hors de l'app).
//  Sur un Mac :  swift run --package-path Modules/PlaycoVideo playco-video aide
//

import Foundation

#if canImport(AVFoundation)
import PlaycoVideo

let resultat = await CommandesVideo.executer(Array(CommandLine.arguments.dropFirst()))
print(resultat.sortie)
exit(resultat.code)
#else
print("playco-video : les commandes vidéo exigent macOS (AVFoundation).")
exit(1)
#endif
