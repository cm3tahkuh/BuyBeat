export default {
  routes: [
    {
      method: 'GET',
      path: '/profiles/:id',
      handler: 'profile.publicById',
      config: {
        auth: false,
        policies: [],
        middlewares: [],
      },
    },
  ],
};
