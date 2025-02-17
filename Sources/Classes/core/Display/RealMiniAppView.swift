import WebKit

// swiftlint:disable file_length
internal class RealMiniAppView: UIView {

    internal var webView: WKWebView
    internal var miniAppTitle: String
    internal var queryParams: String?
    internal var miniAppURL: URL?
    internal var miniAppId: String?
    internal var projectId: String?
    internal var miniAppVersion: String?
    internal var navBar: (UIView & MiniAppNavigationDelegate)?
    internal var webViewBottomConstraintStandalone: NSLayoutConstraint?
    internal var webViewBottomConstraintWithNavBar: NSLayoutConstraint?
    internal var navBarVisibility: MiniAppNavigationVisibility
    internal var isNavBarCustom = false
    internal var supportedMiniAppOrientation: UIInterfaceOrientationMask
    internal var initialLoadCallback: ((Bool) -> Void)?
    internal var analyticsConfig: [MAAnalyticsConfig]?
    internal var messageBodies: [String] = []
    internal var onExternalWebviewResponse: ((URL) -> Void)?
    internal var onExternalWebviewClose: ((URL) -> Void)?
    internal var closeAlertInfo: CloseAlertInfo?

    internal weak var hostAppMessageDelegate: MiniAppMessageDelegate?
    internal weak var navigationDelegate: MiniAppNavigationDelegate?
    internal weak var currentDialogController: UIAlertController?
    var canGoBackObservation: NSKeyValueObservation?
    var canGoForwardObservation: NSKeyValueObservation?

    let secureStorage: MiniAppSecureStorage
    var shouldAutoLoadSecureStorage: Bool

    init(
        miniAppId: String,
        versionId: String,
        projectId: String,
        miniAppTitle: String,
        queryParams: String? = nil,
        hostAppMessageDelegate: MiniAppMessageDelegate,
        adsDisplayer: MiniAppAdDisplayer? = nil,
        displayNavBar: MiniAppNavigationVisibility = .never,
        navigationDelegate: MiniAppNavigationDelegate? = nil,
        navigationView: (UIView & MiniAppNavigationDelegate)? = nil,
        analyticsConfig: [MAAnalyticsConfig]? = [],
        storageMaxSizeInBytes: UInt64? = nil,
        shouldAutoLoadSecureStorage: Bool = true) {

        self.miniAppTitle = miniAppTitle
        webView = MiniAppWebView(miniAppId: miniAppId, versionId: versionId, queryParams: queryParams)
        self.hostAppMessageDelegate = hostAppMessageDelegate
        navBarVisibility = displayNavBar
        supportedMiniAppOrientation = []
        self.miniAppVersion = versionId
        self.projectId = projectId
        self.analyticsConfig = analyticsConfig
        self.secureStorage = MiniAppSecureStorage(appId: miniAppId, storageMaxSizeInBytes: storageMaxSizeInBytes)
        self.shouldAutoLoadSecureStorage = shouldAutoLoadSecureStorage
        super.init(frame: .zero)
        commonInit(miniAppId: miniAppId,
                   hostAppMessageDelegate: hostAppMessageDelegate,
                   adsDisplayer: adsDisplayer,
                   navigationDelegate: navigationDelegate,
                   navigationView: navigationView)
    }

    init(
        miniAppURL: URL,
        miniAppTitle: String,
        queryParams: String? = nil,
        hostAppMessageDelegate: MiniAppMessageDelegate,
        adsDisplayer: MiniAppAdDisplayer? = nil,
        initialLoadCallback: ((Bool) -> Void)? = nil,
        displayNavBar: MiniAppNavigationVisibility = .never,
        navigationDelegate: MiniAppNavigationDelegate? = nil,
        navigationView: (UIView & MiniAppNavigationDelegate)? = nil,
        analyticsConfig: [MAAnalyticsConfig]? = [],
        storageMaxSizeInBytes: UInt64? = nil,
        shouldAutoLoadSecureStorage: Bool = true) {

        let randomMiniAppId = "custom\(Int32.random(in: 0...Int32.max))" // some id is needed to handle permissions
        self.miniAppTitle = miniAppTitle
        self.miniAppURL = miniAppURL
        self.initialLoadCallback = initialLoadCallback
        webView = MiniAppWebView(miniAppURL: miniAppURL)
        self.hostAppMessageDelegate = hostAppMessageDelegate
        navBarVisibility = displayNavBar
        supportedMiniAppOrientation = []
        self.analyticsConfig = analyticsConfig
        self.secureStorage = MiniAppSecureStorage(appId: randomMiniAppId, storageMaxSizeInBytes: storageMaxSizeInBytes)
        self.shouldAutoLoadSecureStorage = shouldAutoLoadSecureStorage
        super.init(frame: .zero)
        commonInit(miniAppId: randomMiniAppId,
                   hostAppMessageDelegate: hostAppMessageDelegate,
                   adsDisplayer: adsDisplayer,
                   navigationDelegate: navigationDelegate,
                   navigationView: navigationView)
    }

    required init?(coder: NSCoder) {
        nil
    }

    fileprivate func initExternalWebViewClosures() {
        onExternalWebviewResponse = { [weak self] (url) in
            self?.webView.load(URLRequest(url: url))
        }
        onExternalWebviewClose = { [weak self] (url) in
            self?.didReceiveEvent(.externalWebViewClosed, message: url.absoluteString)
            NotificationCenter.default.sendCustomEvent(MiniAppEvent.Event(type: .resume, comment: "MiniApp close external webview"))
        }
    }

    private func commonInit(
        miniAppId: String,
        hostAppMessageDelegate: MiniAppMessageDelegate,
        adsDisplayer: MiniAppAdDisplayer? = nil,
        navigationDelegate: MiniAppNavigationDelegate? = nil,
        navigationView: (UIView & MiniAppNavigationDelegate)? = nil) {
        self.miniAppId = miniAppId

        webView.navigationDelegate = self

        if navBarVisibility != .never {
            if let nav = navigationView {
                navBar = nav
                isNavBarCustom = true
            } else {
                navBar = MiniAppNavigationBar(frame: .zero)
            }
        }
        navBar?.miniAppNavigation(delegate: self)
        webView.configuration.userContentController.addMiniAppScriptMessageHandler(delegate: self,
                                                                                   hostAppMessageDelegate: hostAppMessageDelegate,
                                                                                   adsDisplayer: adsDisplayer,
                                                                                   secureStorageDelegate: self,
                                                                                   miniAppId: miniAppId,
                                                                                   miniAppTitle: self.miniAppTitle,
                                                                                   miniAppManageDelegate: self)
        webView.configuration.userContentController.addBridgingJavaScript()
        webView.uiDelegate = self
        self.navigationDelegate = navigationDelegate
        addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.layoutAttachTop()
        webViewBottomConstraintStandalone = webView.layoutAttachBottom()
        webView.layoutAttachLeading()
        webView.layoutAttachTrailing()
        if !isNavBarCustom {
            webViewBottomConstraintWithNavBar = navBar?.layoutAttachTop(to: webView)
            webViewBottomConstraintStandalone?.isActive = false
        }
        MiniAppAnalytics.sendAnalytics(event: .open, miniAppId: miniAppId, miniAppVersion: miniAppVersion, projectId: projectId, analyticsConfig: analyticsConfig)
        initExternalWebViewClosures()
        observeWebView()

        if shouldAutoLoadSecureStorage {
            secureStorage.loadStorage { success in
                if success {
                    MiniAppSecureStorage.sendLoadStorageReady()
                } else {
                    MiniAppSecureStorage.sendLoadStorageError()
                }
            }
        }
    }

    func observeWebView() {
        canGoBackObservation = webView.observe(\.canGoBack, options: .initial) { [weak self] (webView, _) in
            self?.navigationDelegate?.miniAppNavigationCanGo(back: webView.canGoBack, forward: webView.canGoForward)
        }
        canGoForwardObservation = webView.observe(\.canGoForward) { [weak self] (webView, _) in
            self?.navigationDelegate?.miniAppNavigationCanGo(back: webView.canGoBack, forward: webView.canGoForward)
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sendCustomEvent(notification:)),
                                               name: MiniAppEvent.notificationName,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sendCustomEvent(notification:)),
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sendCustomEvent(notification:)),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
        // keyboard events
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sendKeyboardEvent(notification:)),
                                               name: MiniAppKeyboardEvent.notificationName,
                                               object: nil)
    }

    @objc
    func sendCustomEvent(notification: NSNotification) {
        switch notification.name {
        case UIApplication.willResignActiveNotification:
            didReceiveEvent(.pause, message: "Host app will resign active")
        case UIApplication.didBecomeActiveNotification:
            didReceiveEvent(.resume, message: "Host app did become active")
        default:
            if let event = notification.object as? MiniAppEvent.Event {
                didReceiveEvent(event.type, message: event.comment)
            } else {
                MiniAppLogger.w("MiniAppEvent not present in notification")
            }
        }

    }

    @objc
    func sendKeyboardEvent(notification: NSNotification) {
        if notification.name == MiniAppKeyboardEvent.notificationName {
            if let event = notification.object as? MiniAppKeyboardEvent.Event {
                didReceiveKeyboardEvent(event.type, message: event.comment, navigationBarHeight: event.navigationBarHeight, screenHeight: event.screenHeight, keyboardHeight: event.keyboardHeight)
            } else {
                MiniAppLogger.w("MiniAppEvent not present in notification")
            }
        }
    }

    func refreshNavBar() {
        var actionsAvailable = [MiniAppNavigationAction]()
        if webView.canGoBack || navBarVisibility == .always {
            actionsAvailable.append(.back)
        }
        if webView.canGoForward || navBarVisibility == .always {
            actionsAvailable.append(.forward)
        }
        navigationDelegate?.miniAppNavigation(canUse: actionsAvailable)
        if actionsAvailable.count == 0 && navBarVisibility != .never {
            webViewBottomConstraintStandalone?.isActive = navBarVisibility == .auto
            webViewBottomConstraintWithNavBar?.isActive = navBarVisibility == .always
            navBar?.removeFromSuperview()
        } else {
            if let nav = navBar {
                let navDelegate = navigationDelegate as? UIView
                if navDelegate == nil || navDelegate != nav {
                    nav.miniAppNavigation(canUse: actionsAvailable)
                }

                if navBarVisibility != .never {
                    addSubview(nav)
                    nav.translatesAutoresizingMaskIntoConstraints = false
                    webViewBottomConstraintStandalone?.isActive = isNavBarCustom
                    webViewBottomConstraintWithNavBar?.isActive = !isNavBarCustom
                    nav.layoutAttachBottom()
                    nav.layoutAttachLeading()
                    nav.layoutAttachTrailing()
                }
            } else {
                webViewBottomConstraintWithNavBar?.isActive = false
                webViewBottomConstraintStandalone?.isActive = true
            }
        }
    }

    deinit {
        canGoBackObservation?.invalidate()
        canGoForwardObservation?.invalidate()
        MiniAppAnalytics.sendAnalytics(event: .close, miniAppId: miniAppId, miniAppVersion: miniAppVersion, projectId: projectId, analyticsConfig: analyticsConfig)
        MiniApp.MAOrientationLock = []
        UIViewController.attemptRotationToDeviceOrientation()
        webView.configuration.userContentController.removeMessageHandler()
        NotificationCenter.default.removeObserver(self)
        secureStorage.unloadStorage()
    }

    func validateScheme(requestURL: URL, navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let scheme = requestURL.scheme {
            let schemeType = MiniAppSupportedSchemes(rawValue: scheme)
            switch schemeType {
            case .about: // mainly implemented to manage built-in alert dialogs
                return decisionHandler(.allow)
            case .tel, .mailto:
                UIApplication.shared.open(requestURL, options: [:], completionHandler: nil)
            default:
                if requestURL.isMiniAppURL(customMiniAppURL: miniAppURL) {
                    return decisionHandler(.allow)
                } else if requestURL.isBase64 {
                    if
                        let miniAppId = miniAppId,
                        MiniApp.shared()
                            .getCustomPermissions(forMiniApp: miniAppId)
                            .filter({ $0.permissionName == .fileDownload && $0.isPermissionGranted == .allowed })
                            .first != nil {
                        if let onResponse = onExternalWebviewResponse, let onClose = onExternalWebviewClose {
                            navigationDelegate?.miniAppNavigation(shouldOpen: requestURL, with: onResponse, onClose: onClose)
                        }
                    }
                    return decisionHandler(.cancel)
                } else {
                    // Allow navigation for requests loading external web content resources. E.G: iFrames
                    guard navigationAction.targetFrame?.isMainFrame != false else {
                        return decisionHandler(.allow)
                    }

                    if let onResponse = onExternalWebviewResponse, let onClose = onExternalWebviewClose {
                        if let miniAppURL = miniAppURL {
                            NotificationCenter.default.sendCustomEvent(MiniAppEvent.Event(type: .pause, comment: "MiniApp opened external webview"))
                            navigationDelegate?.miniAppNavigation(shouldOpen: requestURL, with: onResponse, onClose: onClose, customMiniAppURL: miniAppURL)
                        } else {
                            NotificationCenter.default.sendCustomEvent(MiniAppEvent.Event(type: .pause, comment: "MiniApp opened external webview"))
                            navigationDelegate?.miniAppNavigation(shouldOpen: requestURL, with: onResponse, onClose: onClose)
                        }
                    }
                }
            }
        }
        decisionHandler(.cancel)
    }

    internal func presentAlert(alertController: UIAlertController) {
        UIApplication.topViewController()?.present(alertController, animated: true, completion: nil)
    }
}

extension RealMiniAppView: MiniAppDisplayDelegate {
    public func getMiniAppView() -> UIView {
        self
    }
}

extension RealMiniAppView: MiniAppCallbackDelegate {
    func didReceiveScriptMessageResponse(messageId: String, response: String) {
        let messageBody = Constants.JavaScript.successCallback + "('\(messageId)'," + "'\(response)')"
        messageBodies.append(messageBody)
        MiniAppLogger.d(messageBody, "♨️️")
        webView.evaluateJavaScript(messageBody)
    }

    func didReceiveScriptMessageError(messageId: String, errorMessage: String) {
        let messageBody = Constants.JavaScript.errorCallback + "('\(messageId)'," + "'\(errorMessage)')"
        messageBodies.append(messageBody)
        MiniAppLogger.d(messageBody, "♨️️")
        webView.evaluateJavaScript(messageBody)
    }

    func didOrientationChanged(orientation: UIInterfaceOrientationMask) {
        self.supportedMiniAppOrientation = orientation
    }

    func didReceiveEvent(_ event: MiniAppEvent, message: String) {
        let messageBody = Constants.JavaScript.eventCallback + "('\(event.rawValue)'," + "'\(message)')"
        messageBodies.append(messageBody)
        MiniAppLogger.d(messageBody, "♨️️")
        webView.evaluateJavaScript(messageBody)
    }

    func didReceiveKeyboardEvent(_ event: MiniAppKeyboardEvent, message: String, navigationBarHeight: CGFloat? = nil, screenHeight: CGFloat? = nil, keyboardHeight: CGFloat? = nil) {
        var messageBody = Constants.JavaScript.keyboardEventCallback + "('\(event.rawValue)'," + "'\(message)'"
        if let navigationBarHeight = navigationBarHeight, let screenHeight = screenHeight, let keyboardHeight = keyboardHeight {
            messageBody += ",'\(navigationBarHeight)','\(screenHeight)','\(keyboardHeight)')"
        } else {
            messageBody += ")"
        }
        messageBodies.append(messageBody)
        MiniAppLogger.d(messageBody, "♨️️")
        webView.evaluateJavaScript(messageBody)
    }
}

extension RealMiniAppView: MiniAppNavigationBarDelegate {
    func miniAppShouldClose() -> CloseAlertInfo? {
        return self.closeAlertInfo
    }

    func miniAppNavigationBar(didTriggerAction action: MiniAppNavigationAction) -> Bool {
        let canDo: Bool
        switch action {
        case .back:
            canDo = self.webView.canGoBack
            self.webView.goBack()
        case .forward:
            canDo = self.webView.canGoForward
            self.webView.goForward()
        }
        return canDo
    }
}

extension RealMiniAppView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let requestUrl = navigationAction.request.url {
            MiniAppLogger.d("navigation type for \(navigationAction.request.url?.absoluteString ?? "---"): \(navigationAction.navigationType.rawValue)")
            validateScheme(requestURL: requestUrl, navigationAction: navigationAction, decisionHandler: decisionHandler)
        } else {
            decisionHandler(.cancel)
        }
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        refreshNavBar()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        MiniAppLogger.e("Couldn't load Miniapp URL", error)
        initialLoadCallback?(false)
        initialLoadCallback = nil
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        initialLoadCallback?(true)
        initialLoadCallback = nil
    }
}

// MARK: - MiniAppSecureStorageDelegate
extension RealMiniAppView: MiniAppSecureStorageDelegate {
    func get(key: String) throws -> String? {
        return try secureStorage.get(key: key)
    }

    func set(dict: [String: String], completion: ((Result<Bool, MiniAppSecureStorageError>) -> Void)?) {
        return secureStorage.set(dict: dict, completion: completion)
    }

    func remove(keys: [String], completion: ((Result<Bool, MiniAppSecureStorageError>) -> Void)?) {
        return secureStorage.remove(keys: keys, completion: completion)
    }

    func size() -> MiniAppSecureStorageSize {
        return secureStorage.size()
    }

    func clearSecureStorage() throws {
        try secureStorage.clearSecureStorage()
    }
}

extension RealMiniAppView: MiniAppManageDelegate {
    func setMiniAppCloseAlertInfo(alertInfo: CloseAlertInfo?) {
        self.closeAlertInfo = alertInfo
    }
}
