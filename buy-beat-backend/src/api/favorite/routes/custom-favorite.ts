/**
 * Custom favorite routes — toggle endpoint
 */
export default {
  routes: [
    {
      method: 'POST',
      path: '/favorites/toggle',
      handler: 'custom-favorite.toggle',
      config: {
        policies: [],
        middlewares: [],
      },
    },
    {
      method: 'GET',
      path: '/favorites/my',
      handler: 'custom-favorite.my',
      config: {
        policies: [],
        middlewares: [],
      },
    },
  ],
};
