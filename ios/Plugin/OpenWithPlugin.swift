import Foundation
import Capacitor
import MobileCoreServices
import UniformTypeIdentifiers

@objc(OpenWithPlugin)
public class OpenWithPlugin: CAPPlugin {
    private var verboseLogging = false
    private var handlerAdded = false
    private static let EVENT_NAME = "receivedFiles"

    private func getAppGroupId() -> String {
        // Obtener el identificador completo de la aplicación host
        // Ejemplo: com.squareetlabs.qr -> group.com.squareetlabs.qr
        let hostBundleId = Bundle.main.bundleIdentifier ?? ""
        return "group.\(hostBundleId)"
    }

    @objc override public func load() {
        // Usamos el método para obtener el App Group ID
        let appGroupId = getAppGroupId()
        
        if verboseLogging {
            print("OpenWith: Plugin loading with App Group: \(appGroupId)")
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUrlNotification(_:)),
            name: Notification.Name("OpenWithURLNotification"),
            object: nil
        )
        checkSharedContent()

        if verboseLogging {
            print("OpenWith: Plugin loaded")
        }
    }

    @objc public func addHandler(_ call: CAPPluginCall) {
        handlerAdded = true
        call.resolve()

        if verboseLogging {
            print("OpenWith: Handler added")
        }
    }

    @objc public func initialize(_ call: CAPPluginCall) {
        // Obtener el identificador del grupo usando el método común
        let appGroupId = getAppGroupId()
        
        if verboseLogging {
            print("OpenWith: Intentando inicializar con App Group: \(appGroupId)")
        }
        
        if let userDefaults = UserDefaults(suiteName: appGroupId) {
            userDefaults.synchronize()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleSharedFile),
                name: NSNotification.Name("SharedFile"),
                object: nil
            )
            
            // Verificar si hay contenido compartido pendiente
            checkSharedContent(withAppGroupId: appGroupId)
            
            if verboseLogging {
                print("OpenWith: Plugin initialized successfully with App Group: \(appGroupId)")
            }
            
            call.resolve()
        } else {
            if verboseLogging {
                print("OpenWith: Failed to initialize UserDefaults with App Group: \(appGroupId)")
            }
            call.reject("Failed to initialize plugin: App Group not configured correctly. Make sure '\(appGroupId)' is configured in Xcode.")
        }
    }

    @objc public func setVerbosity(_ call: CAPPluginCall) {
        let level = call.getInt("level") ?? 0
        verboseLogging = level > 0

        if verboseLogging {
            print("OpenWith: Verbosity set to \(level)")
        }
        call.resolve()
    }

    private func checkSharedContent(withAppGroupId: String? = nil) {
        // Usar el appGroupId proporcionado o obtenerlo con el método común
        let appGroupId = withAppGroupId ?? getAppGroupId()
        
        if verboseLogging {
            print("OpenWith: Checking shared content with App Group: \(appGroupId)")
        }
        
        if let userDefaults = UserDefaults(suiteName: appGroupId) {
            if let content = userDefaults.string(forKey: "SharedContent"),
               let type = userDefaults.string(forKey: "SharedContentType") {
                
                let sharedData: [String: Any] = [
                    "uri": content,
                    "type": type,
                    "extras": [:] as [String: Any]
                ]
                
                notifyListeners(OpenWithPlugin.EVENT_NAME, data: [
                    "data": sharedData
                ])
                
                // Limpiar los datos después de procesarlos
                userDefaults.removeObject(forKey: "SharedContent")
                userDefaults.removeObject(forKey: "SharedContentType")
                userDefaults.synchronize()
                
                if verboseLogging {
                    print("OpenWith: Processed pending shared content")
                }
            } else if verboseLogging {
                print("OpenWith: No pending shared content found")
            }
        } else if verboseLogging {
            print("OpenWith: Failed to access UserDefaults with App Group: \(appGroupId)")
        }
    }

    @objc private func handleSharedFile(_ notification: Notification) {
        if verboseLogging {
            print("OpenWith: Received SharedFile notification")
        }
        checkSharedContent()
    }

    private func processInitialFiles() {
        if let url = UserDefaults.standard.url(forKey: "OpenWithURL") {
            handleUrl(url)
            UserDefaults.standard.removeObject(forKey: "OpenWithURL")
        }
    }

    @objc private func handleUrlNotification(_ notification: Notification) {
        if let url = notification.object as? URL {
            handleUrl(url)
        }
    }

    private func handleUrl(_ url: URL) {
        guard handlerAdded else {
            if verboseLogging {
                print("OpenWith: Handler not added yet, storing URL")
            }
            UserDefaults.standard.set(url, forKey: "OpenWithURL")
            return
        }

        do {
            var data = JSObject()
            var extras = JSObject()


             let sourceApp = getSourceApplication()
             if sourceApp.bundleId != nil || sourceApp.name != nil || sourceApp.iconName != nil {
                 var source = JSObject()
                 source["packageName"] = sourceApp.bundleId
                 source["applicationName"] = sourceApp.name
                 source["applicationIcon"] = sourceApp.iconName
                 data["source"] = source
             }


            // 2. URI and scheme
            data["uri"] = url.absoluteString
            data["scheme"] = url.scheme

            // 3. MIME type and file information
            if #available(iOS 14.0, *) {
                if let uti = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
                    data["type"] = uti.preferredMIMEType
                }
            } else {
                if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, url.pathExtension as CFString, nil)?.takeRetainedValue(),
                   let mimeType = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
                    data["type"] = mimeType as String
                }
            }

            // 4. Añadir el título al objeto extras
            extras["title"] = url.lastPathComponent

            // Try to read content based on type
            if isTextFile(url: url) {
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    extras["text"] = content
                }
            }

            // Handle different content types
            handleSpecialContent(url: url, extras: &extras)

            data["extras"] = extras


            // Notify through event
            var eventData = JSObject()
            eventData["data"] = data
            notifyListeners(OpenWithPlugin.EVENT_NAME, data: eventData)

            if verboseLogging {
                print("OpenWith: Processed URL: \(url)")
                print("OpenWith: Event data: \(eventData)")
            }

        } catch {
            if verboseLogging {
                print("OpenWith: Error processing URL: \(error)")
            }
        }
    }

    private func isTextFile(url: URL) -> Bool {
        if #available(iOS 14.0, *) {
            if let uti = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
                return uti.conforms(to: .text)
            }
        }
        return url.pathExtension.lowercased() == "txt"
    }

    // En handleSpecialContent
    private func handleSpecialContent(url: URL, extras: inout JSObject) {
        // Handle contacts
        if url.pathExtension.lowercased() == "vcf" {
            if let contactData = try? String(contentsOf: url, encoding: .utf8) {
                extras["contact"] = contactData
            }
        }

        // Handle calendar events
        if url.pathExtension.lowercased() == "ics" {
            if let eventData = try? String(contentsOf: url, encoding: .utf8) {
                extras["event"] = eventData
            }
        }

        // Handle locations
        if url.scheme == "geo" {
            let coordinates = url.absoluteString.replacingOccurrences(of: "geo:", with: "").split(separator: ",")
            if coordinates.count >= 2 {
                extras["latitude"] = Double(coordinates[0])
                extras["longitude"] = Double(coordinates[1])
            }
        }
    }

    private func getSourceApplication() -> (bundleId: String?, name: String?, iconName: String?) {
        // En iOS 13 y posteriores, podemos usar el scene
        if #available(iOS 13.0, *) {
            guard let scene = bridge?.viewController?.view.window?.windowScene else {
                return (nil, nil, nil)
            }

            // Intentar obtener la información de la aplicación de origen desde userActivity
            if let activity = scene.session.stateRestorationActivity {
                if let sourceAppBundleId = activity.userInfo?["UIApplicationOpenURLOptionsSourceApplicationKey"] as? String {
                    var name: String? = nil
                    var iconName: String? = nil

                    if let appBundle = Bundle(identifier: sourceAppBundleId) {
                        name = appBundle.infoDictionary?["CFBundleDisplayName"] as? String
                        iconName = appBundle.infoDictionary?["CFBundleIconName"] as? String
                    }

                    return (sourceAppBundleId, name, iconName)
                }
            }
        }

        // Fallback para versiones anteriores o si no se encuentra la información
        if let options = UserDefaults.standard.dictionary(forKey: "URLOpenOptions") as? [String: Any],
           let sourceAppBundleId = options[UIApplication.OpenURLOptionsKey.sourceApplication.rawValue] as? String {
            var name: String? = nil
            var iconName: String? = nil

            if let appBundle = Bundle(identifier: sourceAppBundleId) {
                name = appBundle.infoDictionary?["CFBundleDisplayName"] as? String
                iconName = appBundle.infoDictionary?["CFBundleIconName"] as? String
            }

            return (sourceAppBundleId, name, iconName)
        }

        return (nil, nil, nil)
    }

    @objc public func getAppGroup(_ call: CAPPluginCall) {
        let appGroupId = getAppGroupId()
        
        // Comprobar si el App Group está configurado
        let isConfigured = UserDefaults(suiteName: appGroupId) != nil
        
        call.resolve([
            "appGroupId": appGroupId,
            "isConfigured": isConfigured
        ])
        
        if verboseLogging {
            print("OpenWith: App Group ID requested: \(appGroupId), configured: \(isConfigured)")
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
