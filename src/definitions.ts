import type { PluginListenerHandle } from '@capacitor/core';

export interface OpenWithPlugin {
  // Niveles de log
  DEBUG: number;
  INFO: number;
  WARN: number;
  ERROR: number;

  // Acciones
  SEND: string;
  VIEW: string;

  // Métodos principales
  initialize(): Promise<void>;
  exit(): Promise<void>;
  setVerbosity(options: { level: number }): Promise<void>;
  getVerbosity(): Promise<number>;
  addHandler(callback: () => void): Promise<void>;
  load(dataDescriptor: FileDescriptor): Promise<string>;
  addListener(
    eventName: 'receivedFiles',
    listenerFunc: (event: SharedFilesEvent) => void
  ): Promise<PluginListenerHandle>;
  removeAllListeners(): Promise<void>;
}

export interface SharedIntent {
  action: string;
  items: FileDescriptor[];
}

export interface FileDescriptor {
  path?: string;
  base64?: string;
  type: string;
  name: string;
  uri: string;
}

export interface SharedFile {
  path: string;
  type?: string;
  name?: string;
}

export interface SourceApp {
  packageName: string;
  applicationName: string;
  applicationIcon: string;
}

export interface ClipDataItem {
  text?: string;
  uri?: string;
  htmlText?: string;
}

export interface SharedExtras {
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
  mediaOutput?: string;
  eventTitle?: string;
  eventDescription?: string;
  eventLocation?: string;
  stream?: string;
  [key: string]: any; // Para otros extras no especificados
}

export interface SharedData {
  source?: SourceApp;
  action?: string;
  type?: string;
  uri?: string;
  scheme?: string;
  extras?: SharedExtras;
  clipData?: ClipDataItem[];
}

export interface SharedFilesEvent {
  data?: SharedData;
  error?: string;
}
