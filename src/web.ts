import { WebPlugin } from '@capacitor/core';

import type { OpenWithPlugin } from './definitions';

export class OpenWithWeb extends WebPlugin implements OpenWithPlugin {
  async echo(options: { value: string }): Promise<{ value: string }> {
    console.log('ECHO', options);
    return options;
  }
}
