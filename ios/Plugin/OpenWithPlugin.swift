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
    
    @objc func init(_ call: CAPPluginCall) {
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
            let data = JSObject()
            
            // 1. Source app information
            if let sourceApp = getSourceApplication() {
                let source = JSObject()
                source.setValue(sourceApp.bundleId, forKey: "packageName")
                source.setValue(sourceApp.name, forKey: "applicationName")
                source.setValue(sourceApp.iconName, forKey: "applicationIcon")
                data.setValue(source, forKey: "source")
            }
            
            // 2. URI and scheme
            data.setValue(url.absoluteString, forKey: "uri")
            data.setValue(url.scheme, forKey: "scheme")
            
            // 3. MIME type and file information
            if #available(iOS 14.0, *) {
                if let uti = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
                    data.setValue(uti.preferredMIMEType, forKey: "type")
                }
            } else {
                if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, url.pathExtension as CFString, nil)?.takeRetainedValue(),
                   let mimeType = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
                    data.setValue(mimeType as String, forKey: "type")
                }
            }
            
            // 4. File attributes and extras
            let extras = JSObject()
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            
            extras.setValue(url.lastPathComponent, forKey: "title")
            
            // Try to read content based on type
            if isTextFile(url: url) {
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    extras.setValue(content, forKey: "text")
                }
            }
            
            // Handle different content types
            handleSpecialContent(url: url, extras: extras)
            
            data.setValue(extras, forKey: "extras")
            
            // Notify through event
            let eventData = JSObject()
            eventData.setValue(data, forKey: "data")
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
    
    private func handleSpecialContent(url: URL, extras: JSObject) {
        // Handle contacts
        if url.pathExtension.lowercased() == "vcf" {
            if let contactData = try? String(contentsOf: url, encoding: .utf8) {
                extras.setValue(contactData, forKey: "contact")
            }
        }
        
        // Handle calendar events
        if url.pathExtension.lowercased() == "ics" {
            if let eventData = try? String(contentsOf: url, encoding: .utf8) {
                extras.setValue(eventData, forKey: "event")
            }
        }
        
        // Handle locations
        if url.scheme == "geo" {
            let coordinates = url.absoluteString.replacingOccurrences(of: "geo:", with: "").split(separator: ",")
            if coordinates.count >= 2 {
                extras.setValue(Double(coordinates[0]), forKey: "latitude")
                extras.setValue(Double(coordinates[1]), forKey: "longitude")
            }
        }
    }
    
    private func getSourceApplication() -> (bundleId: String?, name: String?, iconName: String?) {
        guard let sourceApp = bridge?.viewController?.view.window?.windowScene?.session.sourceApplication else {
            return (nil, nil, nil)
        }
        
        let bundleId = sourceApp
        var name: String? = nil
        var iconName: String? = nil
        
        if let appBundle = Bundle(identifier: bundleId) {
            name = appBundle.infoDictionary?["CFBundleDisplayName"] as? String
            iconName = appBundle.infoDictionary?["CFBundleIconName"] as? String
        }
        
        return (bundleId, name, iconName)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 