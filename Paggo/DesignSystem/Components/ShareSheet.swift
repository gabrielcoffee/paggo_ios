import SwiftUI
import UIKit

/// Folha de compartilhamento nativa (UIActivityViewController) para SwiftUI — usada p/ comprovantes.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
