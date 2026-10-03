import BackgroundAssets
import ExtensionFoundation
import StoreKit

/// Downloads the Apple-hosted sound packs (Managed Background Assets) for
/// the app. Apple's default implementation: the system decides when, and
/// this lets every pack through. The app asks for an on-demand pack with
/// `AssetPackManager.ensureLocalAvailability(of:)`.
@main
struct DownloaderExtension: StoreDownloaderExtension {
    func shouldDownload(_ assetPack: AssetPack) -> Bool {
        true
    }
}
