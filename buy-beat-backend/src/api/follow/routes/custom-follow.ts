export default {
  routes: [
    {
      method: 'POST',
      path: '/follows/toggle',
      handler: 'custom-follow.toggle',
      config: {
        auth: false,
        policies: [],
        middlewares: [],
      },
    },
    {
      method: 'GET',
      path: '/follows/my-following',
      handler: 'custom-follow.myFollowing',
      config: {
        auth: false,
        policies: [],
        middlewares: [],
      },
    },
  ],
};
