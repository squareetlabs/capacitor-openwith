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