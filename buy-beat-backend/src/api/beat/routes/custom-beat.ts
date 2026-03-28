/**
 * custom beat routes — play count increment
 */
export default {
  routes: [
    {
      method: 'POST',
      path: '/beats/:documentId/play',
      handler: 'beat.incrementPlay',
      config: {
        auth: false, // public — no JWT required
        policies: [],
        middlewares: [],
      },
    },
  ],
};
