import type { Core } from '@strapi/strapi';

const config: Core.Config.Middlewares = [
  'strapi::logger',
  'strapi::errors',
  {
    name: 'strapi::security',
    config: {
      contentSecurityPolicy: {
        useDefaults: true,
        directives: {
          'connect-src': ["'self'", 'https:', 'http:', 'ws:', 'wss:'],
          'img-src': ["'self'", 'data:', 'blob:', 'https://market-assets.strapi.io', 'http:'],
          'media-src': ["'self'", 'data:', 'blob:', 'http:'],
        },
      },
    },
  },
  {
    name: 'strapi::cors',
    config: {
      origin: '*',
      credentials: true,
      methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS'],
      headers: ['Content-Type', 'Authorization', 'X-Requested-With'],
    },
  },
  'strapi::poweredBy',
  'strapi::query',
  'strapi::body',
  'strapi::session',
  'strapi::favicon',
  'strapi::public',
];

export default config;
