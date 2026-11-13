import AppKit
import AVFoundation
import AVKit

final class VideoPreviewView: NSView {
    private let url: URL
    private let player: AVPlayer
    private let playerView = AVPlayerView()

    init(url: URL) {
        self.url = url
        player = AVPlayer(url: url)
        super.init(frame: NSRect(x: 0, y: 0, width: 640, height: 360))
        playerView.frame = bounds
        playerView.autoresizingMask = [.width, .height]
        playerView.controlsStyle = .inline
        playerView.videoGravity = .resizeAspect
        playerView.player = player
        addSubview(playerView)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("not used")
    }

    func load(completion: @escaping (NSSize?) -> Void) {
        let asset = AVURLAsset(url: url)
        Task {
            var result: NSSize?
            do {
                let playable = try await asset.load(.isPlayable)
                if playable {
                    let tracks = try await asset.loadTracks(withMediaType: .video)
                    if let track = tracks.first {
                        let (size, transform) = try await track.load(.naturalSize, .preferredTransform)
                        let rect = CGRect(origin: .zero, size: size).applying(transform)
                        result = NSSize(width: abs(rect.width), height: abs(rect.height))
                    } else {
                        result = NSSize(width: 640, height: 360)
                    }
                }
            } catch {
                result = nil
            }
            let final = result
            await MainActor.run { completion(final) }
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            player.pause()
        }
    }
}
