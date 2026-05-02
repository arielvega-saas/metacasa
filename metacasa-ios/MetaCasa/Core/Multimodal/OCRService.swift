import Foundation
import UIKit
@preconcurrency import Vision

/// OCR on-device via Apple Vision. Reconoce texto en imágenes (recibos,
/// tickets, facturas) sin enviar nada a internet.
///
/// Uso: `let text = try await OCRService.extractText(from: uiImage)` →
/// se pasa el resultado a `ReceiptParser` para extraer monto/fecha/comercio.
enum OCRService {
    enum OCRError: LocalizedError {
        case invalidImage

        var errorDescription: String? {
            switch self {
            case .invalidImage: "La imagen no se pudo procesar."
            }
        }
    }

    /// Reconoce todo el texto de una imagen con OCR preciso.
    /// Usa `recognitionLanguages` multi-idioma para cubrir recibos en ES/EN/PT.
    static func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { throw OCRError.invalidImage }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                // Ordenar por Y descendente (top to bottom) para preservar el layout visual.
                let sorted = observations.sorted { lhs, rhs in
                    lhs.boundingBox.origin.y > rhs.boundingBox.origin.y
                }
                let lines = sorted.compactMap { obs -> String? in
                    obs.topCandidates(1).first?.string
                }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }

            request.recognitionLanguages = ["es-AR", "es-ES", "en-US", "pt-BR"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
