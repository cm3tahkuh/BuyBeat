export default {
  routes: [
    {
      method: 'GET',
      path: '/activities/my',
      handler: 'activity.my',
      config: {
        auth: false,
        policies: [],
        middlewares: [],
      },
    },
  ],
};
