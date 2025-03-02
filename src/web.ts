import { WebPlugin } from '@capacitor/core';
import type { OpenWithPlugin, FileDescriptor } from './definitions';

export class OpenWithWeb extends WebPlugin implements OpenWithPlugin {
  DEBUG = 0;
  INFO = 10;
  WARN = 20;
  ERROR = 30;

  SEND = 'SEND';
  VIEW = 'VIEW';


  private verbosityLevel: number = this.INFO;

  async init(): Promise<void> {
    console.log('init not implemented on web');
  }

  async exit(): Promise<void> {
    console.log('OpenWith Web: exit()');
    return;
  }

  async setVerbosity(options: { level: number }): Promise<void> {
    console.log('setVerbosity not implemented on web', options);
  }

  async getVerbosity(): Promise<number> {
    return this.verbosityLevel;
  }

  async addHandler(callback: () => void): Promise<void> {
    console.log('addHandler not implemented on web', callback);
  }

  async load(dataDescriptor: FileDescriptor): Promise<string> {
    console.log('Attempting to load file:', dataDescriptor);
    throw new Error('Method not implemented in web version');
  }
}
