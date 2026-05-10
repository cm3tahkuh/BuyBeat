import type { Core } from '@strapi/strapi';

const config: Core.Config.Api = {
  rest: {
    defaultLimit: 25,
    maxLimit: -1,
    withCount: false,
  },
};

export default config;
