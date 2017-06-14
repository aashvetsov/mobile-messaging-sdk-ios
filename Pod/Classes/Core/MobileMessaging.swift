//
//  MobileMessaging.swift
//  MobileMessaging
//
//  Created by Andrey K. on 17/02/16.
//
//

import Foundation

public final class MobileMessaging: NSObject {
	//MARK: Public

	/// Fabric method for Mobile Messaging session.
	/// - parameter userNotificationType: Preferable notification types that indicating how the app alerts the user when a  push notification arrives.
	/// - parameter applicationCode: The application code of your Application from Push Portal website.
	public class func withApplicationCode(_ code: String, notificationType: UIUserNotificationType) -> MobileMessaging? {
		return MobileMessaging.withApplicationCode(code, notificationType: notificationType, backendBaseURL: APIValues.prodBaseURLString)
	}
	
	/// Fabric method for Mobile Messaging session.
	/// - parameter code: The application code of your Application from Push Portal website.
	/// - parameter notificationType: Preferable notification types that indicating how the app alerts the user when a  push notification arrives.
	/// - parameter forceCleanup: Defines whether the SDK must be cleaned up on startup.
	/// - warning: The cleanup (parameter `forceCleanup = true`) must be performed manually if you changed the application code while `PrivacySettings.applicationCodePersistingDisabled` is set to `true`.
	public class func withApplicationCode(_ code: String, notificationType: UIUserNotificationType, forceCleanup: Bool) -> MobileMessaging? {
		return MobileMessaging.withApplicationCode(code, notificationType: notificationType, backendBaseURL: APIValues.prodBaseURLString, forceCleanup: forceCleanup)
	}
	
	/// Fabric method for Mobile Messaging session.
	/// - parameter notificationType: Preferable notification types that indicating how the app alerts the user when a  push notification arrives.
	/// - parameter code: The application code of your Application from Push Portal website.
	/// - parameter backendBaseURL: Your backend server base URL, optional parameter. Default is http://oneapi.infobip.com.
	public class func withApplicationCode(_ code: String, notificationType: UIUserNotificationType, backendBaseURL: String) -> MobileMessaging? {
		return MobileMessaging.withApplicationCode(code, notificationType: notificationType, backendBaseURL: backendBaseURL, forceCleanup: false)
	}
	
	/// Fabric method for Mobile Messaging session.
	/// It is possible to supply a default implementation of Message Storage to the Mobile Messaging library during initialization. In this case the library will save all received Push messages using the `MMDefaultMessageStorage`. Library can also be initialized either without message storage or with user-provided one (see `withMessageStorage(messageStorage:)`).
	public func withDefaultMessageStorage() -> MobileMessaging {
		self.messageStorage = MMDefaultMessageStorage()
		return self
	}
	
	/// Fabric method for Mobile Messaging session.
	/// It is possible to supply an implementation of Message Storage to the Mobile Messaging library during initialization. In this case the library will save all received Push messages to the supplied `messageStorage`. Library can also be initialized either without message storage or with the default message storage (see `withDefaultMessageStorage()` method).
	/// - parameter messageStorage: a storage object, that implements the `MessageStorage` protocol
	public func withMessageStorage(_ messageStorage: MessageStorage) -> MobileMessaging {
		self.messageStorage = messageStorage
		return self
	}
	
	/// Fabric method for Mobile Messaging session.
	///
	/// App Groups used to share data among app Notification Extension and the main application itself. Provide the appropriate App Group ID for both application and application extension in order to keep them in sync.
	/// - parameter appGroupId: An ID of an App Group
	/// - remark: If you are facing with the following error in your console:
	/// `[User Defaults] Failed to read values in CFPrefsPlistSource<0xXXXXXXX> (Domain: ..., User: kCFPreferencesAnyUser, ByHost: Yes, Container: (null)): Using kCFPreferencesAnyUser with a container is only allowed for SystemContainers, detaching from cfprefsd`.
	/// Although this warning doesn't mean that our code doesn't work, you can shut it up by prefixing your App Group ID with a Team ID of a certificate that you are signing the build with. For example: `"9S95Y6XXXX.group.com.mobile-messaging.notification-service-extension"`. The App Group ID itself doesn't need to be changed though.
	@available(iOS 10.0, *)
	public func withAppGroupId(_ appGroupId: String) -> MobileMessaging {
		self.sharedNotificationExtensionStorage = DefaultSharedDataStorage(applicationCode: applicationCode, appGroupId: appGroupId)
		return self
	}
	
	/// Starts a new Mobile Messaging session.
	///
	/// This method should be called form AppDelegate's `application(_:didFinishLaunchingWithOptions:)` callback.
	/// - remark: For now, Mobile Messaging SDK doesn't support Badge. You should handle the badge counter by yourself.
	public func start(_ completion: ((Void) -> Void)? = nil) {
		MMLogDebug("Starting service...")

		performForEachSubservice { subservice in
			subservice.mobileMessagingWillStart(self)
		}
		
		messageStorage?.start()
		
		self.appListener = MMApplicationListener(mmContext: self)
		
		if MobileMessaging.isPushRegistrationEnabled {
			messageHandler.start()
		}

		if application.isRegisteredForRemoteNotifications && currentInstallation.deviceToken == nil {
			MMLogDebug("The application is registered for remote notifications but MobileMessaging lacks of device token. Unregistering...")
			self.application.unregisterForRemoteNotifications()
		}
	
		application.registerUserNotificationSettings(UIUserNotificationSettings(types: userNotificationType, categories: nil))
		
		if application.isRegisteredForRemoteNotifications == false {
			MMLogDebug("Registering for remote notifications...")
			application.registerForRemoteNotifications()
		}
		
		if !isTestingProcessRunning {
			#if DEBUG
				VersionManager(remoteApiManager: self.remoteApiManager).validateVersion()
			#endif
		}
		
		performForEachSubservice { subservice in
			subservice.mobileMessagingDidStart(self)
		}
		
		completion?()
		MMLogDebug("Service started!")
	}
	
	/// Syncronizes all available subservices with the server.
	public static func sync() {
		MobileMessaging.sharedInstance?.sync()
	}
	
	/// Current push registration status.
	/// The status defines whether the device is allowed to be receiving push notifications (regular push messages/geofencing campaign messages/messages fetched from the server).
	/// MobileMessaging SDK has the push registration enabled by default.
	public static var isPushRegistrationEnabled: Bool {
		return MobileMessaging.sharedInstance?.isPushRegistrationEnabled ?? true
	}
	
	/// Cleans up all internal persisted data.
	///
	/// Use this method in order to completely drop any data persisted by the SDK (i.e. internal SDK data, optional user data, optional messages metadata).
	/// - Parameter clearKeychain: defines whether the internalId in keychain will be cleaned. True by default.
	public static func cleanUpAndStop(_ clearKeychain: Bool = true) {
		MobileMessaging.sharedInstance?.cleanUpAndStop(clearKeychain)
	}

	/// Enables the push registration so the device can receive push notifications (regular push messages/geofencing campaign messages/messages fetched from the server).
	/// MobileMessaging SDK has the push registration enabled by default.
	public static func enablePushRegistration(completion: ((NSError?) -> Void)? = nil) {
		MobileMessaging.sharedInstance?.updateRegistrationEnabledStatus(true, completion: completion)
	}
	
	/// Disables the push registration so the device no longer receives any push notifications (regular push messages/geofencing campaign messages/messages fetched from the server).
	/// MobileMessaging SDK has the push registration enabled by default.
	public static func disablePushRegistration(completion: ((NSError?) -> Void)? = nil) {
		MobileMessaging.sharedInstance?.updateRegistrationEnabledStatus(false, completion: completion)
	}
	
	/// Stops all the currently running Mobile Messaging services.
	/// - Parameter cleanUpData: defines whether the Mobile Messaging internal storage will be dropped. False by default.
	/// - Attention: This function doesn't disable push notifications, they are still being received by the OS.
	public class func stop(_ cleanUpData: Bool = false) {
		if cleanUpData {
			MobileMessaging.sharedInstance?.cleanUpAndStop()
		} else {
			MobileMessaging.sharedInstance?.stop()
		}
		
		// just to break retain cycles:
		MobileMessaging.sharedInstance?.currentInstallation = nil
		MobileMessaging.sharedInstance?.currentUser = nil
		MobileMessaging.sharedInstance?.appListener = nil
		MobileMessaging.sharedInstance?.messageHandler = nil
		MobileMessaging.sharedInstance?.remoteApiManager = nil
		MobileMessaging.sharedInstance?.application = nil
		MobileMessaging.sharedInstance?.reachabilityManager = nil
		MobileMessaging.sharedInstance?.keychain = nil
		MobileMessaging.sharedInstance?.sharedNotificationExtensionStorage = nil
		
		MobileMessaging.sharedInstance = nil
	}
	
	/// Logging utility is used for:
	/// - setting up the logging options and logging levels.
	/// - obtaining a path to the logs file in case the Logging utility is set up to log in file (logging options contains `.file` option).
	public static var logger: MMLogging? = (MMLoggerFactory() as MMLoggerFactoryProtocol).createLogger?()
	
	/// This method handles a new APNs device token and updates user's registration on the server.
	///
	/// This method should be called form AppDelegate's `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` callback.
	/// - parameter token: A token that identifies a particular device to APNs.
	public class func didRegisterForRemoteNotificationsWithDeviceToken(_ token: Data) {
		MobileMessaging.sharedInstance?.didRegisterForRemoteNotificationsWithDeviceToken(token)
	}
	
	/// This method handles incoming remote notifications and triggers sending procedure for delivery reports. The method should be called from AppDelegate's `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` callback.
	///
	/// - parameter userInfo: A dictionary that contains information related to the remote notification, potentially including a badge number for the app icon, an alert sound, an alert message to display to the user, a notification identifier, and custom data.
	/// - parameter fetchCompletionHandler: A block to execute when the download operation is complete. The block is originally passed to AppDelegate's `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` callback as a `fetchCompletionHandler` parameter. Mobile Messaging will execute this block after sending notification's delivery report.
	public class func didReceiveRemoteNotification(_ userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
		MobileMessaging.sharedInstance?.didReceiveRemoteNotification(userInfo, completion: { result in
			completionHandler(result.backgroundFetchResult)
		})
	}
	
	
	
	/// This method is called when a running app receives a local notification. The method should be called from AppDelegate's `application(_:didReceiveLocalNotification:)` or `application(_:didReceive:)` callback.
	///
	/// - parameter notification: A local notification that encapsulates details about the notification, potentially including custom data.
	public class func didReceiveLocalNotification(_ notification: UILocalNotification) {
		
		guard let userInfo = notification.userInfo,
			let payload = userInfo[LocalNotificationKeys.pushPayload] as? APNSPayload,
			let createdDate = userInfo[LocalNotificationKeys.createdDate] as? Date,
			let message = MTMessage(payload: payload, createdDate: createdDate),
			let applicationState = MobileMessaging.sharedInstance?.application.applicationState,
			MMMessageHandler.isNotificationTapped(message, applicationState: applicationState) else {
				return
		}
		MMMessageHandler.handleNotificationTap(with: message)
	}
	
	/// Maintains attributes related to the current application installation such as APNs device token, badge number, etc.
	public class var currentInstallation: MMInstallation? {
		return MobileMessaging.sharedInstance?.currentInstallation
	}
	
	/// Returns the default message storage if used. For more information see `MMDefaultMessageStorage` class description.
	public class var defaultMessageStorage: MMDefaultMessageStorage? {
		return MobileMessaging.sharedInstance?.messageStorage as? MMDefaultMessageStorage
	}

	/// Maintains attributes related to the current user such as unique ID for the registered user, email, MSISDN, custom data, external id.
	public class var currentUser: MMUser? {
		return MobileMessaging.sharedInstance?.currentUser
	}
	
	/// This method sets seen status for messages and sends a corresponding request to the server. If something went wrong, the library will repeat the request until it reaches the server.
	/// - parameter messageIds: Array of identifiers of messages that need to be marked as seen.
	public class func setSeen(messageIds: [String]) {
		MobileMessaging.sharedInstance?.setSeen(messageIds)
	}
	
	//FIXME: MOMEssage should be replaced with something lighter
	/// This method sends mobile originated messages to the server.
	/// - parameter messages: Array of objects of `MOMessage` class that need to be sent.
	/// - parameter completion: The block to execute after the server responded, passes an array of `MOMessage` messages, that cont
	public class func sendMessages(_ messages: [MOMessage], completion: (([MOMessage]?, NSError?) -> Void)? = nil) {
		MobileMessaging.sharedInstance?.sendMessages(messages, completion: completion)
	}
	
	/// An auxillary component provides the convinient access to the user agent data.
	public internal(set) static var userAgent = MMUserAgent()
	
	/// A block object to be executed when user opens the app by tapping on the notification alert. 
	/// Default implementation marks the corresponding message as seen.
	/// This block takes:
	/// - single MTMessage object initialized from the Dictionary.
	public static var notificationTapHandler: ((_ message: MTMessage) -> Void)? = {
		MMLogDebug("Notfication alert tapped.")
		MobileMessaging.setSeen(messageIds: [$0.messageId])
	}
	
	/// The message handling object defines the behaviour that is triggered during the message handling.
	///
	/// You can implement your own message handling either by subclassing `MMDefaultMessageHandling` or implementing the `MessageHandling` protocol.
	public static var messageHandling: MessageHandling = MMDefaultMessageHandling()
	
	/// The `URLSessionConfiguration` used for all url connections in the SDK
	///
	/// Default value is `URLSessionConfiguration.default`.
	/// You can provide your own configuration to define a custom NSURLProtocol, policies etc.
	public static var urlSessionConfiguration: URLSessionConfiguration = URLSessionConfiguration.default
	
	/// The `PrivacySettings` class incapsulates privacy settings that affect the SDK behaviour and business logic.
	public internal(set) static var privacySettings = PrivacySettings()
	
//MARK: Internal
	static var sharedInstance: MobileMessaging?
	let userNotificationType: UIUserNotificationType
	let applicationCode: String
	
	var storageType: MMStorageType = .SQLite
	let remoteAPIBaseURL: String
	
	class func withApplicationCode(_ code: String, notificationType: UIUserNotificationType, backendBaseURL: String, forceCleanup: Bool) -> MobileMessaging? {
		
		if let sharedInstance = sharedInstance, sharedInstance.applicationCode != code || sharedInstance.userNotificationType != notificationType || sharedInstance.remoteAPIBaseURL != backendBaseURL {
			MobileMessaging.stop()
		}
		sharedInstance = MobileMessaging(appCode: code, notificationType: notificationType, backendBaseURL: backendBaseURL, forceCleanup: forceCleanup)
		return sharedInstance
	}
	
	func sync() {
		currentInstallation?.syncInstallationWithServer()
		performForEachSubservice { subservice in
			subservice.syncWithServer(nil)
		}
	}
	
	/// - parameter clearKeychain: Bool, true by default, used in unit tests
	func cleanUpAndStop(_ clearKeychain: Bool = true) {
		MMLogDebug("Cleaning up MobileMessaging service...")
		if #available(iOS 10.0, *) {
			sharedNotificationExtensionStorage?.cleanupMessages()
		}
		MMCoreDataStorage.dropStorages(internalStorage: internalStorage, messageStorage: messageStorage as? MMDefaultMessageStorage)
		if (clearKeychain) {
			keychain.clear()
		}
		stop()
	}
	
	func stop() {
		MMLogInfo("Stopping MobileMessaging service...")
		
		performForEachSubservice { subservice in
			subservice.mobileMessagingWillStop(self)
		}
		
		if application.isRegisteredForRemoteNotifications {
			application.unregisterForRemoteNotifications()
		}

		messageStorage?.stop()

		application = UIApplication.shared
		MobileMessaging.notificationTapHandler = nil
		MobileMessaging.messageHandling = MMDefaultMessageHandling()
		self.appListener = nil
		
		performForEachSubservice { subservice in
			subservice.mobileMessagingDidStop(self)
		}
		
		cleanupSubservices()
	}
	
	func didReceiveRemoteNotification(_ userInfo: [AnyHashable : Any], completion: ((MessageHandlingResult) -> Void)? = nil) {
		MMLogDebug("New remote notification received \(userInfo)")
		messageHandler.handleAPNSMessage(userInfo, completion: completion)
	}
	
	func didRegisterForRemoteNotificationsWithDeviceToken(_ token: Data, completion: ((NSError?) -> Void)? = nil) {
		MMLogDebug("Application did register with device token \(token.mm_toHexString)")
		NotificationCenter.mm_postNotificationFromMainThread(name: MMNotificationDeviceTokenReceived, userInfo: [MMNotificationKeyDeviceToken: token.mm_toHexString])
		currentInstallation.updateDeviceToken(token: token, completion: completion)
	}
	
	func updateRegistrationEnabledStatus(_ value: Bool, completion: ((NSError?) -> Void)? = nil) {
		currentInstallation.updateRegistrationEnabledStatus(value: value, completion: completion)
		updateRegistrationEnabledSubservicesStatus(isPushRegistrationEnabled: value)
	}
	
	func updateRegistrationEnabledSubservicesStatus(isPushRegistrationEnabled value: Bool) {
		performForEachSubservice { subservice in
			subservice.pushRegistrationStatusDidChange(self)
		}
	}

	func setSeen(_ messageIds: [String], completion: ((SeenStatusSendingResult) -> Void)? = nil) {
		MMLogDebug("Setting seen status: \(messageIds)")
		messageHandler.setSeen(messageIds, completion: completion)
	}
	
	func sendMessages(_ messages: [MOMessage], completion: (([MOMessage]?, NSError?) -> Void)? = nil) {
		MMLogDebug("Sending mobile originated messages...")
		messageHandler.sendMessages(messages, completion: completion)
	}
	
	func notificationTapped(_ message: MTMessage) {
		NotificationCenter.default.post(name: NSNotification.Name(rawValue: MMNotificationMessageTapped), object: self, userInfo: [MMNotificationKeyMessage: message])
		MobileMessaging.notificationTapHandler?(message)
	}
	
	var isPushRegistrationEnabled: Bool {
		return currentInstallation.isPushRegistrationEnabled
	}
	
	var subservices: [String: MobileMessagingService] = [:]
	func registerSubservice(_ ss: MobileMessagingService) {
		subservices[ss.uniqueIdentifier] = ss
	}
	func cleanupSubservices() {
		subservices.removeAll()
	}
	
	func performForEachSubservice(_ block: (MobileMessagingService) -> Void) {
		subservices.values.forEach { subservice in
			block(subservice)
		}
	}
	
	//MARK: Private
	private init?(appCode: String, notificationType: UIUserNotificationType, backendBaseURL: String, forceCleanup: Bool) {
		
		let logCoreDataInitializationError = {
			MMLogError("Unable to initialize Core Data stack. MobileMessaging SDK service stopped because of the fatal error!")
		}
		
		guard var storage = try? MMCoreDataStorage.makeInternalStorage(self.storageType) else {
			logCoreDataInitializationError()
			return nil
		}
        
		if forceCleanup || applicationCodeChanged(storage: storage, newApplicationCode: appCode) {
			MMLogDebug("Data will be cleaned up due to the application code change.")
			MMCoreDataStorage.dropStorages(internalStorage: storage, messageStorage: messageStorage as? MMDefaultMessageStorage)
			do {
				storage = try MMCoreDataStorage.makeInternalStorage(self.storageType)
			} catch {
				logCoreDataInitializationError()
				return nil
			}
		}
		self.internalStorage        = storage
		self.applicationCode        = appCode
		self.userNotificationType   = notificationType
		self.remoteAPIBaseURL       = backendBaseURL
		
		MMLogInfo("SDK successfully initialized!")
	}
	
	private(set) var messageStorage: MessageStorage? {
		didSet {
			messageStorageAdapter = MMMessageStorageQueuedAdapter(adapteeStorage: messageStorage)
		}
	}
	var messageStorageAdapter: MMMessageStorageQueuedAdapter?
	
	let internalStorage: MMCoreDataStorage
	lazy var coreDataProvider: CoreDataProvider = CoreDataProvider(storage: self.internalStorage)
	lazy var inMemoryDataProvider: InMemoryDataProvider = InMemoryDataProvider()
	lazy var currentInstallation: MMInstallation! = MMInstallation(inMemoryProvider: self.inMemoryDataProvider, coreDataProvider: self.coreDataProvider, storage: self.internalStorage, mmContext: self, applicationCode: self.applicationCode)
	lazy var currentUser: MMUser! = MMUser(inMemoryProvider: self.inMemoryDataProvider, coreDataProvider: self.coreDataProvider, mmContext: self)
	var appListener: MMApplicationListener!
	//TODO: continue decoupling. Move messageHandler to a subservice completely. (as GeofencingService)
	lazy var messageHandler: MMMessageHandler! = MMMessageHandler(storage: self.internalStorage, mmContext: self)
	lazy var remoteApiManager: RemoteAPIManager! = RemoteAPIManager(baseUrl: self.remoteAPIBaseURL, applicationCode: self.applicationCode, mmContext: self)
	lazy var application: MMApplication! = UIApplication.shared
	lazy var reachabilityManager: ReachabilityManagerProtocol! = MMNetworkReachabilityManager.sharedInstance
	lazy var keychain: MMKeychain! = MMKeychain()
	
	static var date: MMDate = MMDate() // testability
	
	var sharedNotificationExtensionStorage: AppGroupMessageStorage?
}

extension UIApplication: MMApplication {}

/// The `PrivacySettings` class incapsulates privacy settings that affect the SDK behaviour and business logic.
public class PrivacySettings: NSObject {
	/// A boolean variable that indicates whether the MobileMessaging SDK will be sending the carrier information to the server.
	///
	/// Default value is `false`.
	public var carrierInfoSendingDisabled: Bool = false
	
	/// A boolean variable that indicates whether the MobileMessaging SDK will be sending the system information such as OS version, device model, application version to the server.
	///
	/// Default value is `false`.
	public var systemInfoSendingDisabled: Bool = false
	
	/// A boolean variable that indicates whether the MobileMessaging SDK will be persisting the application code locally. This feature is a convenience to maintain SDK viability during debugging and possible application code changes.
	///
	/// Default value is `false`.
	/// - Warning: there might be situation when you want to switch between different Application Codes during development/testing. If you disable the application code persisting (value `true`), the SDK won't detect the application code changes, thus won't cleanup the old application code related data. You should manually invoke `MobileMessaging.cleanUpAndStop()` prior to start otherwise the SDK would not detect the application code change.
	public var applicationCodePersistingDisabled: Bool = false
	
	/// A boolean variable that indicates whether the MobileMessaging SDK will be persisting the user data locally. Persisting user data locally gives you quick access to the data and eliminates a need to implement it yourself.
	///
	/// Default value is `false`.
	public var userDataPersistingDisabled: Bool = false
}

class MMDate {
	var now: Date {
		return Date()
	}
	
	func timeInterval(sinceNow timeInterval: TimeInterval) -> Date {
		return Date(timeIntervalSinceNow: timeInterval)
	}
	
	func timeInterval(since1970 timeInterval: TimeInterval) -> Date {
		return Date(timeIntervalSince1970: timeInterval)
	}
	
	func timeInterval(sinceReferenceDate timeInterval: TimeInterval) -> Date {
		return Date(timeIntervalSinceReferenceDate: timeInterval)
	}
	
	func timeInterval(_ timeInterval: TimeInterval, since date: Date) -> Date {
		return Date(timeInterval: timeInterval, since: date)
	}
}

protocol MMApplication {
	var applicationIconBadgeNumber: Int { get set }
	var applicationState: UIApplicationState { get }
	var isRegisteredForRemoteNotifications: Bool { get }
	func unregisterForRemoteNotifications()
	func registerForRemoteNotifications()
	func presentLocalNotificationNow(_ notification: UILocalNotification)
	func registerUserNotificationSettings(_ notificationSettings: UIUserNotificationSettings)
	var currentUserNotificationSettings: UIUserNotificationSettings? { get }
}

extension MMApplication {
	var isInForegroundState: Bool {
		return applicationState != .background
	}
}

func applicationCodeChanged(storage: MMCoreDataStorage, newApplicationCode: String) -> Bool {
	let dataProvider = CoreDataProvider(storage: storage)
	let currentApplicationCode = dataProvider.getValueForKey("applicationCode") as? String
	return currentApplicationCode != nil && currentApplicationCode != newApplicationCode
}