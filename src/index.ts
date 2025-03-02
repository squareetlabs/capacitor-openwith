import { registerPlugin } from '@capacitor/core';

import type { OpenWithPlugin } from './definitions';

const OpenWith = registerPlugin<OpenWithPlugin>('OpenWith', {
  web: () => import('./web').then(m => new m.OpenWithWeb()),
});

export * from './definitions';
export { OpenWith };
