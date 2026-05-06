import AppKit
import Foundation
import Vision

final class OCRReader {
    private let queue = DispatchQueue(label: "local.mackim.CornerShot.ocr", qos: .utility)

    func recognizeText(from imageData: Data, completion: @escaping (String) -> Void) {
        queue.async {
            guard let image = NSImage(data: imageData),
                  let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                DispatchQueue.main.async {
                    completion("")
                }
                return
            }

            let request = VNRecognizeTextRequest { request, _ in
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let recognizedText = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")

                DispatchQueue.main.async {
                    completion(recognizedText)
                }
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["ko-KR", "en-US"]

            do {
                try VNImageRequestHandler(cgImage: cgImage).perform([request])
            } catch {
                DispatchQueue.main.async {
                    completion("")
                }
            }
        }
    }
}
