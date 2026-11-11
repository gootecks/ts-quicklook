import Cocoa
import QuickLookUI
import UniformTypeIdentifiers

@objc(PreviewProvider)
class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let url = request.fileURL
        return QLPreviewReply(dataOfContentType: .html, contentSize: CGSize(width: 900, height: 700)) { reply in
            reply.stringEncoding = .utf8
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            return Data(Renderer.page(for: data).utf8)
        }
    }
}
