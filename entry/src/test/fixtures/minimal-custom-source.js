/**
 * @name Repo Fixture Source
 * @description Minimal custom source fixture for preload compatibility tests
 * @version 1.0.0
 * @author Codex
 * @homepage https://example.com
 */

const { EVENT_NAMES, on, send } = window.lx;

on(EVENT_NAMES.request, ({ action }) => {
  if (action !== 'musicUrl') {
    return Promise.reject(new Error(`unsupported action: ${String(action)}`));
  }
  return Promise.resolve('https://www.example.com/');
});

send(EVENT_NAMES.inited, {
  status: true,
  openDevTools: false,
  sources: {
    kw: {
      name: 'Fixture KW',
      type: 'music',
      actions: ['musicUrl'],
      qualitys: ['128k']
    }
  }
});
