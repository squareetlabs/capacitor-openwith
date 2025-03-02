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

1. Add required capabilities in Xcode:
   - Go to your app target
   - Select "Signing & Capabilities" tab
   - Add "Document Types" and configure the file types you want to handle

2. Update your AppDelegate.swift to handle shared files:

```swift
func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    NotificationCenter.default.post(name: Notification.Name("OpenWithURLNotification"), object: url)
    return true
}

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // ... other initialization code ...
    
    if let url = launchOptions?[UIApplication.LaunchOptionsKey.url] as? URL {
        NotificationCenter.default.post(name: Notification.Name("OpenWithURLNotification"), object: url)
    }
    
    return true
}
```

3. Update your app's Info.plist to declare the document types your app can handle:

```xml
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>All Files</string>
        <key>LSHandlerRank</key>
        <string>Alternate</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>public.content</string>
            <string>public.data</string>
            <string>public.text</string>
            <string>public.image</string>
            <string>public.audio</string>
            <string>public.movie</string>
            <string>public.composite-content</string>
        </array>
    </dict>
</array>
```

## API

The plugin provides the following functions:

- `addHandler()`: Adds a handler for shared file events
- `init()`: Initializes the plugin
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
            await OpenWith.init();

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
        await OpenWith.init();

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
      await OpenWith.init();

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
    await OpenWith.init();

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