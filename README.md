# @squareetlabs/capacitor-openwith

Capacitor plugin to handle files and content shared from other apps on Android and iOS.

## Installation

```bash
npm install @squareetlabs/capacitor-openwith
npx cap sync
```

## Android Configuration

Add the following permissions to your `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

## iOS Configuration

Para permitir que tu aplicación reciba archivos compartidos desde otras aplicaciones, necesitas configurar una Share Extension:

### 1. Crear Share Extension

1. Abre tu proyecto en XCode
2. Ve a `File > New > Target`
3. Selecciona "Share Extension" en la sección de iOS
4. Dale un nombre (por ejemplo, "ShareExtension")
5. Asegúrate de que "Embed in Application" esté seleccionado

### 2. Configuración de App Groups

1. Selecciona tu proyecto en XCode
2. Selecciona el target principal de tu aplicación
3. Ve a "Signing & Capabilities"
4. Haz clic en "+" y añade "App Groups"
5. Crea un nuevo grupo con el formato: `group.[tu-bundle-identifier]`
6. Repite el proceso para el target de la Share Extension

### 3. Configuración del Info.plist de la Share Extension

Añade lo siguiente a tu Info.plist de la Share Extension:

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>NSExtensionActivationRule</key>
        <dict>
            <key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
            <integer>1</integer>
            <key>NSExtensionActivationSupportsFileWithMaxCount</key>
            <integer>1</integer>
            <key>NSExtensionActivationSupportsText</key>
            <true/>
            <key>NSExtensionActivationSupportsImageWithMaxCount</key>
            <integer>1</integer>
            <key>NSExtensionActivationSupportsMovieWithMaxCount</key>
            <integer>1</integer>
        </dict>
    </dict>
    <key>NSExtensionMainStoryboard</key>
    <string>MainInterface</string>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.share-services</string>
</dict>
```

### 4. Implementación del ShareViewController

Reemplaza el contenido del archivo `ShareViewController.swift` con el siguiente código:

```swift
import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {

    override func isContentValid() -> Bool {
        return true
    }
    
    override func didSelectPost() {
        if let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
           let attachments = extensionItem.attachments {
            
            for attachment in attachments {
                if #available(iOS 14.0, *) {
                    if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                        attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
                            guard let self = self else { return }
                            
                            if let url = item as? URL {
                                self.saveSharedContent(content: url.absoluteString, type: "url")
                            }
                            
                            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                        }
                    }
                } else {
                    // Para iOS 13 y anteriores
                    let urlIdentifier = kUTTypeURL as String
                    if attachment.hasItemConformingToTypeIdentifier(urlIdentifier) {
                        attachment.loadItem(forTypeIdentifier: urlIdentifier, options: nil) { [weak self] (item, error) in
                            guard let self = self else { return }
                            
                            if let url = item as? URL {
                                self.saveSharedContent(content: url.absoluteString, type: "url")
                            }
                            
                            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                        }
                    }
                }
            }
        } else {
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
    
    override func configurationItems() -> [Any]! {
        return []
    }
    
    private func saveSharedContent(content: String, type: String) {
        // Usa el mismo App Group ID que en tu plugin
        let bundleId = Bundle.main.bundleIdentifier?.split(separator: ".").dropLast().joined(separator: ".") ?? ""
        let appGroupId = "group.\(bundleId)"
        
        NSLog("OpenWith ShareExtension: Intentando guardar con App Group: \(appGroupId)")
        
        if let userDefaults = UserDefaults(suiteName: appGroupId) {
            userDefaults.set(content, forKey: "SharedContent")
            userDefaults.set(type, forKey: "SharedContentType")
            userDefaults.synchronize()
            
            // Enviar notificación
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("SharedFile"), object: nil)
            }
            
            NSLog("OpenWith ShareExtension: Contenido guardado correctamente")
        } else {
            NSLog("OpenWith ShareExtension: No se pudo acceder a UserDefaults con App Group: \(appGroupId)")
        }
    }
}
```

### 5. Configuración del Bundle Identifier

Asegúrate de que el Bundle Identifier de la Share Extension esté correctamente configurado en el Info.plist:

```xml
<key>CFBundleIdentifier</key>
<string>$(PRODUCT_BUNDLE_IDENTIFIER).share-extension</string>
```

### 6. Configuración adicional en el Info.plist de la aplicación principal

Para que tu aplicación aparezca en las opciones de compartir, debes añadir lo siguiente al Info.plist de tu aplicación principal:

```xml
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
<key>UIFileSharingEnabled</key>
<true/>
<key>UTImportedTypeDeclarations</key>
<array>
    <dict>
        <key>UTTypeConformsTo</key>
        <array>
            <string>public.data</string>
            <string>public.content</string>
        </array>
        <key>UTTypeDescription</key>
        <string>Contenido compartido</string>
        <key>UTTypeIdentifier</key>
        <string>com.tu-empresa.app.shared-content</string>
        <key>UTTypeTagSpecification</key>
        <dict>
            <key>public.filename-extension</key>
            <array>
                <string>*</string>
            </array>
            <key>public.mime-type</key>
            <array>
                <string>*/*</string>
            </array>
        </dict>
    </dict>
</array>
```

Asegúrate de reemplazar `com.tu-empresa.app.shared-content` con un identificador único basado en el bundle identifier de tu aplicación.

### 7. Uso en tu aplicación

Una vez configurado, puedes escuchar los eventos de archivos compartidos en tu aplicación:

```typescript
import { OpenWith } from '@capacitor-community/open-with';

OpenWith.addListener('receivedFiles', async (data) => {
  console.log('Archivo recibido:', data);
  // data.data contiene:
  // - uri: URL del archivo
  // - type: tipo MIME
  // - source: información de la app que compartió (si está disponible)
  // - extras: información adicional como título, texto, etc.
});

// Inicializar el plugin
await OpenWith.initialize();
```

### 8. Solución de Problemas

Si la Share Extension no aparece en el menú compartir:
- Verifica que el App Group esté correctamente configurado en ambos targets
- Asegúrate de que los tipos de archivo que quieres compartir estén incluidos en NSExtensionActivationRule
- Comprueba que la Share Extension esté firmada con el mismo equipo de desarrollo que la aplicación principal
- Limpia y reconstruye el proyecto (Product > Clean Build Folder)
- Desinstala y vuelve a instalar la aplicación en el dispositivo/simulador

## API

The plugin provides the following functions:

- `addHandler()`: Adds a handler for shared file events
- `initialize()`: Initializes the plugin
- `setVerbosity({ level: number })`: Configures logging level (0: disabled, 1: enabled)

### Interfaces

```typescript
interface SharedData {
  // Source application information
  source?: {
    packageName: string;
    applicationName: string;
    applicationIcon: string;
  };
  // Intent action
  action?: string;
  // MIME type
  type?: string;
  // Content URI
  uri?: string;
  // URI scheme
  scheme?: string;
  // Additional data
  extras?: {
    text?: string;
    htmlText?: string;
    subject?: string;
    title?: string;
    email?: string[];
    cc?: string[];
    bcc?: string[];
    phoneNumber?: string;
    latitude?: number;
    longitude?: number;
    eventTitle?: string;
    eventDescription?: string;
    eventLocation?: string;
    [key: string]: any;
  };
  // ClipData information
  clipData?: {
    text?: string;
    uri?: string;
    htmlText?: string;
  }[];
}

interface SharedFilesEvent {
  data: SharedData;
}
```

## Usage
The plugin can be used with various frameworks. Choose your framework below for specific implementation details:

- [Angular Implementation](#1-create-a-service-to-handle-the-plugin)
- [React Implementation](#react-example)
- [Vue Implementation](#vue-example)
- [Svelte Implementation](#svelte-example-bonus)

### 1. Create a service to handle the plugin

```typescript
// open-with.service.ts
import {Injectable} from '@angular/core';
import {Subject} from 'rxjs';
import {Capacitor} from '@capacitor/core';
import {OpenWith, SharedData, SharedFilesEvent} from '@squareetlabs/capacitor-openwith';

@Injectable({
    providedIn: 'root'
})
export class OpenWithService {
    private filesReceived = new Subject<SharedData>();
    public filesReceived$ = this.filesReceived.asObservable();

    constructor() {
        this.init();
    }

    private async init() {
        if (!Capacitor.isNativePlatform()) {
            console.log('OpenWith only works on native platforms');
            return;
        }

        try {
            await OpenWith.addHandler(() => {
                console.log('OpenWith handler added successfully');
            });

            await OpenWith.setVerbosity({level: 1});
            await OpenWith.initialize();

            await OpenWith.addListener('receivedFiles', (shared: SharedFilesEvent) => {
                console.log('Received data:', shared);
                if (shared && shared.data) {
                    this.filesReceived.next(shared.data);
                }
            });

        } catch (error) {
            console.error('Error initializing OpenWith:', error);
        }
    }
}
```

### 2. Use the service in your component

```typescript
// my-component.ts
import {Component} from '@angular/core';
import {OpenWithService} from './open-with.service';
import {SharedData} from '@squareetlabs/capacitor-openwith';

@Component({
    selector: 'app-my-component',
    template: `
        <div *ngIf="sharedData">
            <h2>Shared Content</h2>
            <p>From: {{sharedData.source?.applicationName}}</p>
            <p>Type: {{sharedData.type}}</p>
            <p>Text: {{sharedData.extras?.text}}</p>
            <!-- Add more fields as needed -->
        </div>
    `
})
export class MyComponent {
    sharedData: SharedData | null = null;

    constructor(private openWithService: OpenWithService) {
        this.openWithService.filesReceived$.subscribe(
            (data: SharedData) => {
                this.sharedData = data;
                this.handleSharedContent(data);
            }
        );
    }

    private handleSharedContent(data: SharedData) {
        // Example of how to handle different content types
        if (data.extras?.text) {
            console.log('Shared text:', data.extras.text);
        }
        if (data.extras?.phoneNumber) {
            console.log('Phone number:', data.extras.phoneNumber);
        }
        if (data.uri) {
            console.log('Shared URI:', data.uri);
        }
        // etc...
    }
}
```

## Framework Examples

### React Example

```typescript
// OpenWithProvider.tsx
import React, { createContext, useContext, useEffect, useState } from 'react';
import { Capacitor } from '@capacitor/core';
import { OpenWith, SharedData } from '@squareetlabs/capacitor-openwith';

interface OpenWithContextType {
  sharedData: SharedData | null;
}

const OpenWithContext = createContext<OpenWithContextType>({ sharedData: null });

export const useOpenWith = () => useContext(OpenWithContext);

export const OpenWithProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [sharedData, setSharedData] = useState<SharedData | null>(null);

  useEffect(() => {
    if (!Capacitor.isNativePlatform()) {
      console.log('OpenWith only works on native platforms');
      return;
    }

    const initializeOpenWith = async () => {
      try {
        await OpenWith.addHandler(() => {
          console.log('OpenWith handler added successfully');
        });

        await OpenWith.setVerbosity({ level: 1 });
        await OpenWith.initialize();

        await OpenWith.addListener('receivedFiles', (shared) => {
          console.log('Received data:', shared);
          if (shared && shared.data) {
            setSharedData(shared.data);
          }
        });
      } catch (error) {
        console.error('Error initializing OpenWith:', error);
      }
    };

    initializeOpenWith();
  }, []);

  return (
    <OpenWithContext.Provider value={{ sharedData }}>
      {children}
    </OpenWithContext.Provider>
  );
};

// App.tsx
import { OpenWithProvider } from './OpenWithProvider';

const App: React.FC = () => {
  return (
    <OpenWithProvider>
      <YourApp />
    </OpenWithProvider>
  );
};

// SharedContent.tsx
import { useOpenWith } from './OpenWithProvider';

const SharedContent: React.FC = () => {
  const { sharedData } = useOpenWith();

  if (!sharedData) return null;

  return (
    <div>
      <h2>Shared Content</h2>
      <p>From: {sharedData.source?.applicationName}</p>
      <p>Type: {sharedData.type}</p>
      <p>Text: {sharedData.extras?.text}</p>
    </div>
  );
};
```

### Vue Example

```typescript
// openWithPlugin.ts
import { ref, readonly } from 'vue';
import { Capacitor } from '@capacitor/core';
import { OpenWith, SharedData } from '@squareetlabs/capacitor-openwith';

const sharedData = ref<SharedData | null>(null);

export const useOpenWith = () => {
  const initialize = async () => {
    if (!Capacitor.isNativePlatform()) {
      console.log('OpenWith only works on native platforms');
      return;
    }

    try {
      await OpenWith.addHandler(() => {
        console.log('OpenWith handler added successfully');
      });

      await OpenWith.setVerbosity({ level: 1 });
      await OpenWith.initialize();

      await OpenWith.addListener('receivedFiles', (shared) => {
        console.log('Received data:', shared);
        if (shared && shared.data) {
          sharedData.value = shared.data;
        }
      });
    } catch (error) {
      console.error('Error initializing OpenWith:', error);
    }
  };

  return {
    sharedData: readonly(sharedData),
    initialize
  };
};

// main.ts
import { createApp } from 'vue';
import App from './App.vue';

const app = createApp(App);
app.mount('#app');

// App.vue
<script setup lang="ts">
import { onMounted } from 'vue';
import { useOpenWith } from './openWithPlugin';

const { sharedData, initialize } = useOpenWith();

onMounted(() => {
  initialize();
});
</script>

<template>
  <div v-if="sharedData">
    <h2>Shared Content</h2>
    <p>From: {{ sharedData.source?.applicationName }}</p>
    <p>Type: {{ sharedData.type }}</p>
    <p>Text: {{ sharedData.extras?.text }}</p>
  </div>
</template>
```

### Svelte Example (Bonus)

```typescript
// openWith.ts
import { writable } from 'svelte/store';
import { Capacitor } from '@capacitor/core';
import { OpenWith, SharedData } from '@squareetlabs/capacitor-openwith';

export const sharedData = writable<SharedData | null>(null);

export const initializeOpenWith = async () => {
  if (!Capacitor.isNativePlatform()) {
    console.log('OpenWith only works on native platforms');
    return;
  }

  try {
    await OpenWith.addHandler(() => {
      console.log('OpenWith handler added successfully');
    });

    await OpenWith.setVerbosity({ level: 1 });
    await OpenWith.initialize();

    await OpenWith.addListener('receivedFiles', (shared) => {
      console.log('Received data:', shared);
      if (shared && shared.data) {
        sharedData.set(shared.data);
      }
    });
  } catch (error) {
    console.error('Error initializing OpenWith:', error);
  }
};

// App.svelte
<script lang="ts">
  import { onMount } from 'svelte';
  import { sharedData, initializeOpenWith } from './openWith';

  onMount(() => {
    initializeOpenWith();
  });
</script>

{#if $sharedData}
  <div>
    <h2>Shared Content</h2>
    <p>From: {$sharedData.source?.applicationName}</p>
    <p>Type: {$sharedData.type}</p>
    <p>Text: {$sharedData.extras?.text}</p>
  </div>
{/if}


## Supported Content Types

The plugin can handle various types of shared content:

- Plain text
- URLs
- Images
- Documents
- Contacts
- Locations
- Calendar events
- Phone numbers
- Emails
- Media content
- And more...

## Debugging

To enable detailed logging, use:

```typescript
await OpenWith.setVerbosity({level: 1});
```

## Supported Platforms

- ✅ Android
- ✅ iOS (coming soon)

## License

MIT