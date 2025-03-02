import Foundation
import Capacitor
import MobileCoreServices

@objc(OpenWithPlugin)
public class OpenWithPlugin: CAPPlugin {
    private var verboseLogging = false
    private var handlerAdded = false
    
    @objc func addHandler(_ call: CAPPluginCall) {
        handlerAdded = true
        call.resolve()
        
        if verboseLogging {
            print("OpenWith: Handler added")
        }
    }
    
    @objc func init(_ call: CAPPluginCall) {
        // Procesar cualquier archivo pendiente
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
    
    public override func load() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUrlNotification(_:)),
            name: Notification.Name("OpenWithURLNotification"),
            object: nil
        )
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
            
            // 1. Información de la fuente
            if let sourceApp = getSourceApplication() {
                let source = JSObject()
                source.setValue(sourceApp.bundleIdentifier, forKey: "packageName")
                source.setValue(sourceApp.displayName, forKey: "applicationName")
                source.setValue(sourceApp.icon?.description, forKey: "applicationIcon")
                data.setValue(source, forKey: "source")
            }
            
            // 2. URI y esquema
            data.setValue(url.absoluteString, forKey: "uri")
            data.setValue(url.scheme, forKey: "scheme")
            
            // 3. Tipo MIME
            if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, url.pathExtension as CFString, nil)?.takeRetainedValue(),
               let mimeType = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
                data.setValue(mimeType as String, forKey: "type")
            }
            
            // 4. Extras
            let extras = JSObject()
            
            // Intentar leer contenido como texto
            if let content = try? String(contentsOf: url) {
                extras.setValue(content, forKey: "text")
            }
            
            // Añadir información del archivo
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            extras.setValue(url.lastPathComponent, forKey: "title")
            
            data.setValue(extras, forKey: "extras")
            
            // Notificar a través del evento
            let eventData = JSObject()
            eventData.setValue(data, forKey: "data")
            notifyListeners("receivedFiles", data: eventData)
            
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
    
    private func getSourceApplication() -> (bundleIdentifier: String?, displayName: String?, icon: UIImage?) {
        // Implementación para obtener la información de la app que comparte
        // Esto requerirá acceso a través del UIApplication.shared.windows
        return (nil, nil, nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 