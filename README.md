# @squareetlabs/capacitor-openwith

Plugin de Capacitor para manejar archivos y contenido compartido desde otras aplicaciones en Android e iOS.

## Instalación

```bash
npm install @squareetlabs/capacitor-openwith
npx cap sync
```

## Configuración Android

Añade los siguientes permisos en tu `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

## API

El plugin proporciona las siguientes funciones:

- `addHandler()`: Añade un manejador para los eventos de archivos compartidos
- `init()`: Inicializa el plugin
- `setVerbosity({ level: number })`: Configura el nivel de logs (0: desactivado, 1: activado)

### Interfaces

```typescript
interface SharedData {
  // Información de la aplicación de origen
  source?: {
    packageName: string;
    applicationName: string;
    applicationIcon: string;
  };
  // Acción del intent
  action?: string;
  // Tipo MIME
  type?: string;
  // URI del contenido
  uri?: string;
  // Esquema del URI
  scheme?: string;
  // Datos adicionales
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
  // Datos del ClipData
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

## Uso

### 1. Crear un servicio para manejar el plugin

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
            console.log('OpenWith solo funciona en plataformas nativas');
            return;
        }

        try {
            await OpenWith.addHandler(() => {
                console.log('OpenWith handler añadido correctamente');
            });

            await OpenWith.setVerbosity({level: 1});
            await OpenWith.init();

            await OpenWith.addListener('receivedFiles', (shared: SharedFilesEvent) => {
                console.log('Datos recibidos:', shared);
                if (shared && shared.data) {
                    this.filesReceived.next(shared.data);
                }
            });

        } catch (error) {
            console.error('Error inicializando OpenWith:', error);
        }
    }
}
```

### 2. Usar el servicio en tu componente

```typescript
// my-component.ts
import {Component} from '@angular/core';
import {OpenWithService} from './open-with.service';
import {SharedData} from '@squareetlabs/capacitor-openwith';

@Component({
    selector: 'app-my-component',
    template: `
        <div *ngIf="sharedData">
            <h2>Contenido Compartido</h2>
            <p>Desde: {{sharedData.source?.applicationName}}</p>
            <p>Tipo: {{sharedData.type}}</p>
            <p>Texto: {{sharedData.extras?.text}}</p>
            <!-- Añade más campos según necesites -->
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
        // Ejemplo de cómo manejar diferentes tipos de contenido
        if (data.extras?.text) {
            console.log('Texto compartido:', data.extras.text);
        }
        if (data.extras?.phoneNumber) {
            console.log('Número de teléfono:', data.extras.phoneNumber);
        }
        if (data.uri) {
            console.log('URI compartido:', data.uri);
        }
        // etc...
    }
}
```

## Tipos de contenido soportados

El plugin puede manejar varios tipos de contenido compartido:

- Texto plano
- URLs
- Imágenes
- Documentos
- Contactos
- Ubicaciones
- Eventos de calendario
- Números de teléfono
- Correos electrónicos
- Contenido multimedia
- Y más...

## Depuración

Para activar los logs detallados, usa:

```typescript
await OpenWith.setVerbosity({level: 1});
```

## Configuración iOS

1. Añade las capacidades necesarias en Xcode:
   - Ve a tu target de la aplicación
   - Selecciona la pestaña "Signing & Capabilities"
   - Añade "Document Types" y configura los tipos de archivo que quieres manejar

2. Actualiza tu AppDelegate.swift para manejar los archivos compartidos:

```swift
func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    NotificationCenter.default.post(name: Notification.Name("OpenWithURLNotification"), object: url)
    return true
}

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // ... otro código de inicialización ...
    
    if let url = launchOptions?[UIApplication.LaunchOptionsKey.url] as? URL {
        NotificationCenter.default.post(name: Notification.Name("OpenWithURLNotification"), object: url)
    }
    
    return true
}
```

## Plataformas soportadas

- ✅ Android
- ✅ iOS

## Licencia

MIT