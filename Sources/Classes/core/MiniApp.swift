import Foundation
import UIKit

/// Mini App Public API methods
public class MiniApp: NSObject {
    public static let version = "4.2.0"
    private static let shared = MiniApp()
    private let realMiniApp = RealMiniApp()
    public static var MAOrientationLock: UIInterfaceOrientationMask = []
    private static var didConfigure: Bool = false

    private override init() {
        super.init()
        checkConfiguration()
        realMiniApp.cleanUpKeychain()
    }

    /// Starts configuration and makes sure to load analytics
    /// Should be called in AppDelegate didLoad when the app starts
    public static func configure() {
        didConfigure = true
        MiniAppAnalyticsLoader.loadMiniAppAnalytics()
    }

    private func checkConfiguration() {
        guard MiniApp.didConfigure else {
            fatalError("`MiniApp.configure()` has to be called at app start before using any MiniApp method")
        }
    }

    /// Instance of MiniApp which uses the default config settings as defined in Info.plist.
    /// A MiniAppSdkConfig object can be provided to override this configuration
    ///
    /// - Parameters:
    ///     -   settings: A MiniAppSdkConfig object containing values to override default config settings.
    public class func shared(with settings: MiniAppSdkConfig? = nil, navigationSettings: MiniAppNavigationConfig? = nil) -> MiniApp {
        shared.realMiniApp.update(with: settings, navigationConfig: navigationSettings)
        return shared
    }

    /// Fetch the List of [MiniAppInfo] information.
    /// Error information will be returned if any problem while fetching from the backed
    ///
    /// - Parameters:
    ///     -   completionHandler: A block to be called when list of [MiniAppInfo] information is fetched. Completion blocks receives the following parameters
    ///         -   [MiniAppInfo]: List of [MiniAppInfo] information.
    ///         -   MASDKError: MASDKError details if fetching is failed.
    public func list(completionHandler: @escaping (Result<[MiniAppInfo], MASDKError>) -> Void) {
        return realMiniApp.listMiniApp(completionHandler: completionHandler)
    }

    /// Fetch the MiniAppInfo information for a given MiniApp id.
    ///
    /// - Parameters:
    ///     -   miniAppId: the identifier string of the Mini App you want information
    ///     -   completionHandler: A block to be called when MiniAppInfo information is fetched. Completion blocks receives the following parameters
    ///         -   MiniAppInfo: MiniAppInfo information.
    ///         -   MASDKError: MASDKError details if fetching is failed.
    public func info(miniAppId: String, miniAppVersion: String? = nil, completionHandler: @escaping (Result<MiniAppInfo, MASDKError>) -> Void) {
        if miniAppId.count == 0 {
            return completionHandler(.failure(.invalidAppId))
        }
        return realMiniApp.getMiniApp(miniAppId: miniAppId, miniAppVersion: miniAppVersion, completionHandler: completionHandler)
    }

    /// Create a Mini App for the given mini appId, Mini app will be downloaded and cached in local.
    ///
    /// - Parameters:
    ///   - appId: Mini AppId String value
    ///   - version: optional Mini App version String value. If omitted the most recent one is picked
    ///   - queryParams: Optional Query parameters that the host app would like to share while creating a mini app
    ///   - completionHandler: A block to be called on successful creation of [MiniAppView] or throws errors if any. Completion blocks receives the following parameters
    ///         -   MiniAppDisplayProtocol: Protocol that helps the hosting application to communicate with the displayer module of the mini app. More like an interface for host app
    ///                         to interact with View component of mini app.
    ///         -   MASDKError: MASDKError details if Mini App View creating is failed
    ///   - messageInterface: Protocol implemented by the user that helps to communicate between Mini App and native application
    ///   - adsDisplayer: a MiniAppAdDisplayer that will handle Miniapp ads requests
    public func create(appId: String,
                       version: String? = nil,
                       queryParams: String? = nil,
                       completionHandler: @escaping (Result<MiniAppDisplayDelegate, MASDKError>) -> Void,
                       messageInterface: MiniAppMessageDelegate,
                       adsDisplayer: MiniAppAdDisplayer? = nil,
                       fromCache: Bool? = false) {
        return realMiniApp.createMiniApp(
            appId: appId,
            version: version,
            queryParams: queryParams,
            completionHandler: completionHandler,
            messageInterface: messageInterface,
            adsDisplayer: adsDisplayer,
            fromCache: fromCache)
    }

    /// Cache the Custom permissions status for a given MiniApp ID
    /// - Parameters:
    ///   - appId: Mini AppId String value
    ///   - permissionList: List of MASDKCustomPermissionModel class that contains the MiniAppCustomPermissionType and MiniAppCustomPermissionGrantedStatus
    public func setCustomPermissions(forMiniApp appId: String, permissionList: [MASDKCustomPermissionModel]) {
        return realMiniApp.storeCustomPermissions(forMiniApp: appId, permissionList: permissionList)
    }

    /// Get the list of supported Custom permissions and its status for a given Mini app ID
    /// - Parameter appId: Mini AppId String value
    /// - Returns: List of MASDKCustomPermissionModel that contains the details of every custom permission type, status and description.
    public func getCustomPermissions(forMiniApp appId: String) -> [MASDKCustomPermissionModel] {
        if !appId.isEmpty {
            return realMiniApp.retrieveCustomPermissions(forMiniApp: appId)
        }
        return []
    }

    /// Gets the list of downloaded Mini apps info and associated custom permissions status
    /// - Returns:Dictionary of MiniAppInfo and respective custom permissions info
    public func listDownloadedWithCustomPermissions() -> [(MiniAppInfo, [MASDKCustomPermissionModel])] {
        return realMiniApp.getDownloadedListWithCustomPermissions()
    }

    /// Creates a Mini App for the given mini app info object, Mini app will be downloaded and cached in local.
    /// This method should only be used in "Preview Mode".
    ///
    /// - Parameters:
    ///   - appInfo: Mini App info object
    ///   - queryParams: Optional Query parameters that the host app would like to share while creating a mini app
    ///   - completionHandler: A block to be called on successful creation of [MiniAppView] or throws errors if any. Completion blocks receives the following parameters
    ///         -   MiniAppDisplayProtocol: Protocol that helps the hosting application to communicate with the displayer module of the mini app. More like an interface for host app
    ///                         to interact with View component of mini app.
    ///         -   MASDKError: MASDKError details if Mini App View creating is failed
    ///   - messageInterface: Protocol implemented by the user that helps to communicate between Mini App and native application
    ///   - adsDisplayer: a MiniAppAdDisplayer that will handle Miniapp ads requests
    public func create(appInfo: MiniAppInfo,
                       queryParams: String? = nil,
                       completionHandler: @escaping (Result<MiniAppDisplayDelegate, MASDKError>) -> Void,
                       messageInterface: MiniAppMessageDelegate,
                       adsDisplayer: MiniAppAdDisplayer? = nil,
                       fromCache: Bool? = false) {
        return realMiniApp.createMiniApp(
            appInfo: appInfo,
            queryParams: queryParams,
            completionHandler: completionHandler,
            messageInterface: messageInterface,
            adsDisplayer: adsDisplayer,
            fromCache: fromCache)
    }

    /// Method to return the meta-data information of a mini-app
    /// - Parameters:
    ///   - miniAppId:  Mini AppId String value
    ///   - miniAppVersion:  Mini VersionId String value
    ///   - completionHandler: A block to be called on successful retrieval of mini-app meta data MiniAppManifest or throws errors if any
    public func getMiniAppManifest(miniAppId: String,
                                   miniAppVersion: String,
                                   languageCode: String? = nil,
                                   completionHandler: @escaping (Result<MiniAppManifest, MASDKError>) -> Void) {
        return realMiniApp.retrieveMiniAppMetaData(appId: miniAppId,
                                                   version: miniAppVersion,
                                                   languageCode: languageCode,
                                                   completionHandler: completionHandler)
    }

    /// Method to return the cached meta-data information of a mini-app
    /// - Parameters:
    ///   - miniAppId:  Mini AppId String value
    /// - Returns: MiniAppManifest object info from the cache, Returns nil, if the mini-app is not downloaded already.
    public func getDownloadedManifest(miniAppId: String) -> MiniAppManifest? {
        return realMiniApp.getCachedManifestData(appId: miniAppId)
    }

    /// Method to return the Preview MiniAppInfo
    /// - Parameters:
    ///   - token: Preview Token that is received after scanning QR code
    ///   - completionHandler: Completion handler that returns PreviewMiniAppInfo on successful retrieval or Error
    public func getMiniAppPreviewInfo(using token: String, completionHandler: @escaping (Result<PreviewMiniAppInfo, MASDKError>) -> Void) {
        realMiniApp.getMiniAppPreviewInfo(using: token, completionHandler: completionHandler)
    }

    /// Method to call when the Keyboard is shown
    /// - Parameters:
    ///   - navigationBarHeight: Navigation Bar height
    ///   - screenHeight: Total Height of the screen
    ///   - keyboardheight: Keyboard Height
    public func keyboardShown(navigationBarHeight: CGFloat, screenHeight: CGFloat, keyboardheight: CGFloat) {
        realMiniApp.keyboardShown(navigationBarHeight: navigationBarHeight, screenHeight: screenHeight, keyboardheight: keyboardheight)
    }

    /// Method to call when the Keyboard is hidden
    /// - Parameters:
    ///   - navigationBarHeight: Navigation Bar height
    ///   - screenHeight: Total Height of the screen
    ///   - keyboardheight: Keyboard Height
    public func keyboardHidden(navigationBarHeight: CGFloat, screenHeight: CGFloat = 0, keyboardheight: CGFloat = 0) {
        realMiniApp.keyboardHidden(navigationBarHeight: navigationBarHeight, screenHeight: screenHeight, keyboardheight: keyboardheight)
    }

    /// Method which will delete/clears the Secure storage files for all the mini-apps that is downloaded
    public func clearAllSecureStorage() {
        try? MiniAppSecureStorage.wipeSecureStorages()
    }

    /// Method which will delete/clear secure storage for a specific MiniAppID
    /// - Parameter miniAppId: MiniApp ID
    public func clearSecureStorage(for miniAppId: String) {
        try? MiniAppSecureStorage.wipeSecureStorage(for: miniAppId)
    }

}

// MARK: - Testing
public extension MiniApp {
    /// Creates a Mini App for the given url.
    /// Mini app will NOT be downloaded and cached in local, its content will be read directly from provided url.
    /// This should only be used for previewing a mini app from a local server.
    ///
    /// - Parameters:
    ///   - url: a HTTP url containing Mini App content
    ///   - queryParams: Optional Query parameters that the host app would like to share while creating a mini app
    ///   - errorHandler: A block to be called on unsuccessful initial load of Mini App's web content. The handler block receives the following parameter
    ///         -   MASDKError: MASDKError details if Mini App's url content loading is failed, otherwise nil.
    ///   - messageInterface: Protocol implemented by the user that helps to communicate between Mini App and native application
    //    - adsDisplayer: a MiniAppAdDisplayer that will handle Miniapp ads requests
    /// - Returns: MiniAppDisplayProtocol: Protocol that helps the hosting application to communicate with the displayer module of the mini app. More like an interface for host app
    ///                         to interact with View component of mini app.
    func create(url: URL, queryParams: String? = nil,
                errorHandler: @escaping (MASDKError) -> Void,
                messageInterface: MiniAppMessageDelegate,
                adsDisplayer: MiniAppAdDisplayer? = nil) -> MiniAppDisplayDelegate {
        return realMiniApp.createMiniApp(url: url,
                                         queryParams: queryParams,
                                         errorHandler: errorHandler,
                                         messageInterface: messageInterface,
                                         adsDisplayer: adsDisplayer)
    }
}
