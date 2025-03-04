import Foundation
import Capacitor
import MobileCoreServices
import UniformTypeIdentifiers

@objc(OpenWithPlugin)
public class OpenWithPlugin: CAPPlugin {
    private var verboseLogging = false
    private var handlerAdded = false
    private static let EVENT_NAME = "receivedFiles"

    override public func load() {
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

    @objc func addHandler(_ call: CAPPluginCall) {
        handlerAdded = true
        call.resolve()

        if verboseLogging {
            print("OpenWith: Handler added")
        }
    }

    @objc func initialize(_ call: CAPPluginCall) {
        if let userDefaults = UserDefaults(suiteName: "group." + Bundle.main.bundleIdentifier!) {
            userDefaults.synchronize()
            NotificationCenter.default.addObserver(self, selector: #selector(handleSharedFile), name: NSNotification.Name("SharedFile"), object: nil)
        }
        processInitialFiles()
        call.resolve()

        if verboseLogging {
            print("OpenWith: Plugin initialized")
        }
    }

    @objc func setVerbosity(_ call: CAPPluginCall) {
        let level = call.getInt("level") ?? 0
        verboseLogging = level > 0

        if verboseLogging {
            print("OpenWith: Verbosity set to \(level)")
        }
        call.resolve()
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

private func checkSharedContent() {
    if let userDefaults = UserDefaults(suiteName: "group." + Bundle.main.bundleIdentifier!) {
        if let sharedURL = userDefaults.string(forKey: "SharedURL") {
            // Procesar URL compartida
            handleSharedContent(content: sharedURL, type: "url")
            userDefaults.removeObject(forKey: "SharedURL")
        }

        if let sharedText = userDefaults.string(forKey: "SharedText") {
            // Procesar texto compartido
            handleSharedContent(content: sharedText, type: "text")
            userDefaults.removeObject(forKey: "SharedText")
        }

        if let sharedImage = userDefaults.string(forKey: "SharedImage") {
            // Procesar imagen compartida
            handleSharedContent(content: sharedImage, type: "image")
            userDefaults.removeObject(forKey: "SharedImage")
        }

        userDefaults.synchronize()
    }
}

private func handleSharedContent(content: String, type: String) {
    var data = JSObject()
    data["type"] = type
    data["content"] = content

    var eventData = JSObject()
    eventData["data"] = data
    notifyListeners(OpenWithPlugin.EVENT_NAME, data: eventData)
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



    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
