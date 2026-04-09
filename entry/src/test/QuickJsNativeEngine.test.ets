import { describe, it, expect } from '@ohos/hypium';

import { LX_PRELOAD_SCRIPT } from '../main/ets/utils/LxUserApiPreload';
import { QuickJsEngineAdapter, QuickJsHttpRequest, QuickJsHttpTask } from '../main/ets/utils/QuickJsEngine';

interface NativeTestScriptInfo {
  name: string;
  description: string;
  version: string;
  author: string;
  homepage: string;
  rawScript: string;
}

interface NativeTestInitSource {
  type: string;
  actions: string[];
  qualitys: string[];
}

interface NativeTestInitSources {
  kw?: NativeTestInitSource;
}

interface NativeTestInitInfo {
  sources: NativeTestInitSources;
}

interface NativeTestInitPayload {
  status: boolean;
  errorMessage?: string;
  info?: NativeTestInitInfo;
}

interface NativeTestTrackType {
  type: string;
  size: string;
  hash: string;
}

interface NativeTestTrackTypeMeta {
  size: string;
  hash: string;
}

interface NativeTestTrackTypesMap {
  '128k'?: NativeTestTrackTypeMeta;
  '320k'?: NativeTestTrackTypeMeta;
}

interface NativeTestEmptyTypeUrl {
}

interface NativeTestMusicInfo {
  name: string;
  singer: string;
  source: string;
  songmid: string;
  interval: string;
  albumName: string;
  albumId: string;
  img: string;
  hash: string;
  types: NativeTestTrackType[];
  _types: NativeTestTrackTypesMap;
  typeUrl: NativeTestEmptyTypeUrl;
  copyrightId: string;
}

interface NativeTestMusicUrlRequestInfo {
  type: string;
  musicInfo: NativeTestMusicInfo;
}

interface NativeTestMusicUrlRequestData {
  source: string;
  action: string;
  info: NativeTestMusicUrlRequestInfo;
}

interface NativeTestMusicUrlRequestPayload {
  requestKey: string;
  data: NativeTestMusicUrlRequestData;
}

interface NativeTestMusicUrlResultData {
  type: string;
  url: string;
}

interface NativeTestMusicUrlResult {
  source: string;
  action: string;
  data: NativeTestMusicUrlResultData;
}

interface NativeTestMusicUrlResponsePayload {
  requestKey: string;
  status: boolean;
  result?: NativeTestMusicUrlResult;
  errorMessage?: string;
}

const SYNC_INIT_SOURCE_SCRIPT = String.raw`
const { EVENT_NAMES, on, send } = window.lx;

on(EVENT_NAMES.request, ({ action, info }) => {
  if (action !== 'musicUrl') {
    return Promise.reject(new Error('unsupported action: ' + String(action)));
  }
  return Promise.resolve('https://unit.test/audio-' + info.type + '.mp3');
});

send(EVENT_NAMES.inited, {
  sources: {
    kw: {
      name: 'Native Sync Source',
      type: 'music',
      actions: ['musicUrl'],
      qualitys: ['128k']
    }
  }
});
`;

const TIMER_INIT_SOURCE_SCRIPT = String.raw`
const { EVENT_NAMES, send } = window.lx;

setTimeout(() => {
  send(EVENT_NAMES.inited, {
    sources: {
      kw: {
        name: 'Native Timer Source',
        type: 'music',
        actions: ['musicUrl'],
        qualitys: ['128k']
      }
    }
  });
}, 10);
`;

const HTTP_INIT_SOURCE_SCRIPT = String.raw`
const { EVENT_NAMES, on, send } = window.lx;

on(EVENT_NAMES.request, ({ action, info }) => {
  if (action !== 'musicUrl') {
    return Promise.reject(new Error('unsupported action: ' + String(action)));
  }
  return Promise.resolve('https://unit.test/http-' + info.type + '.mp3');
});

lx.request('https://unit.test/bootstrap.json', { method: 'get' }, (error, response, body) => {
  if (error) {
    throw error;
  }
  send(EVENT_NAMES.inited, {
    sources: {
      kw: {
        name: 'Native Http Source',
        type: 'music',
        actions: ['musicUrl'],
        qualitys: [body.quality]
      }
    }
  });
});
`;

function createScriptInfo(rawScript: string): NativeTestScriptInfo {
  return {
    name: 'Native QuickJS Test',
    description: 'QuickJS native engine integration test fixture',
    version: '1.0.0',
    author: 'Codex',
    homepage: 'https://example.com',
    rawScript: rawScript
  };
}

function buildSetupScript(engineKey: string, rawScript: string): string {
  let scriptInfo = createScriptInfo(rawScript);
  let scriptInfoJson = JSON.stringify(scriptInfo);
  let escapedScriptInfoJson = scriptInfoJson.replace(/\\/g, '\\\\').replace(/'/g, "\\'");
  return `${LX_PRELOAD_SCRIPT}\nlx_setup('${engineKey}', JSON.parse('${escapedScriptInfoJson}'));\n${rawScript}`;
}

function buildMusicUrlRequestJson(requestKey: string, quality: string): string {
  let trackType: NativeTestTrackType = {
    type: quality,
    size: '1234',
    hash: `hash_${quality}`
  };
  let typesMap: NativeTestTrackTypesMap = quality === '320k'
    ? { '320k': { size: '1234', hash: 'hash_320k' } }
    : { '128k': { size: '1234', hash: 'hash_128k' } };
  let payload: NativeTestMusicUrlRequestPayload = {
    requestKey: requestKey,
    data: {
      source: 'kw',
      action: 'musicUrl',
      info: {
        type: quality,
        musicInfo: {
          name: 'Test Song',
          singer: 'Test Singer',
          source: 'kw',
          songmid: 'songmid_1',
          interval: '180',
          albumName: 'Test Album',
          albumId: 'album_1',
          img: '',
          hash: `hash_${quality}`,
          types: [trackType],
          _types: typesMap,
          typeUrl: {},
          copyrightId: ''
        }
      }
    }
  };
  return JSON.stringify(payload);
}

function parseInitPayload(payloadJson: string): NativeTestInitPayload {
  return JSON.parse(payloadJson) as NativeTestInitPayload;
}

function requireKwSource(payload: NativeTestInitPayload): NativeTestInitSource {
  if (!payload.info || !payload.info.sources.kw) {
    throw new Error('kw source missing from init payload');
  }
  return payload.info.sources.kw;
}

function parseMusicUrlResponse(payloadJson: string): string {
  let payload = JSON.parse(payloadJson) as NativeTestMusicUrlResponsePayload;
  if (!payload.status || !payload.result) {
    throw new Error(payload.errorMessage || 'musicUrl request failed');
  }
  return payload.result.data.url;
}

function createEngineKey(prefix: string): string {
  return `${prefix}_${Date.now()}_${Math.floor(Math.random() * 10000)}`;
}

function createUnexpectedRequestTask(request: QuickJsHttpRequest): QuickJsHttpTask {
  return {
    response: Promise.reject(new Error(`unexpected host request: ${request.url}`))
  };
}

function createSuccessfulHttpInitResponseJson(requestKey: string): string {
  return `{"requestKey":"${requestKey}","error":"","response":{"statusCode":200,"statusMessage":"OK","headers":{"content-type":["application/json"]},"body":{"quality":"320k"}}}`;
}

export default function quickJsNativeEngineTest() {
  describe('QuickJsNativeEngine', () => {
    it('loads_sync_source_and_dispatches_musicUrl_via_libentry', 0, async () => {
      let engine = new QuickJsEngineAdapter((request: QuickJsHttpRequest): QuickJsHttpTask => createUnexpectedRequestTask(request));
      let engineKey = createEngineKey('native_sync');
      try {
        let initPayloadJson = await engine.loadSource(engineKey, buildSetupScript(engineKey, SYNC_INIT_SOURCE_SCRIPT));
        let initPayload = parseInitPayload(initPayloadJson);
        expect(initPayload.status).assertTrue();
        let kwSource = requireKwSource(initPayload);
        expect(kwSource.type).assertEqual('music');
        expect(kwSource.actions).assertContain('musicUrl');
        expect(kwSource.qualitys).assertContain('128k');

        let requestJson = buildMusicUrlRequestJson('request_sync_1', '128k');
        let responsePayloadJson = await engine.dispatch(engineKey, 'request', requestJson);
        let url = parseMusicUrlResponse(responsePayloadJson);
        expect(url).assertEqual('https://unit.test/audio-128k.mp3');
      } finally {
        engine.dispose();
      }
    });

    it('waits_for_setTimeout_before_init_completes', 0, async () => {
      let engine = new QuickJsEngineAdapter((request: QuickJsHttpRequest): QuickJsHttpTask => createUnexpectedRequestTask(request));
      let engineKey = createEngineKey('native_timer');
      try {
        let initPayloadJson = await engine.loadSource(engineKey, buildSetupScript(engineKey, TIMER_INIT_SOURCE_SCRIPT));
        let initPayload = parseInitPayload(initPayloadJson);
        expect(initPayload.status).assertTrue();
        let kwSource = requireKwSource(initPayload);
        expect(kwSource.qualitys).assertContain('128k');
      } finally {
        engine.dispose();
      }
    });

    it('waits_for_host_request_during_init_and_uses_response_data', 0, async () => {
      let requestUrls: string[] = [];
      let engine = new QuickJsEngineAdapter((request: QuickJsHttpRequest): QuickJsHttpTask => {
        requestUrls.push(request.url);
        return {
          response: Promise.resolve(createSuccessfulHttpInitResponseJson(request.requestKey))
        };
      });
      let engineKey = createEngineKey('native_http');
      try {
        let initPayloadJson = await engine.loadSource(engineKey, buildSetupScript(engineKey, HTTP_INIT_SOURCE_SCRIPT));
        let initPayload = parseInitPayload(initPayloadJson);
        expect(initPayload.status).assertTrue();
        expect(requestUrls.length).assertEqual(1);
        expect(requestUrls[0]).assertEqual('https://unit.test/bootstrap.json');
        let kwSource = requireKwSource(initPayload);
        expect(kwSource.qualitys).assertContain('320k');

        let requestJson = buildMusicUrlRequestJson('request_http_1', '320k');
        let responsePayloadJson = await engine.dispatch(engineKey, 'request', requestJson);
        let url = parseMusicUrlResponse(responsePayloadJson);
        expect(url).assertEqual('https://unit.test/http-320k.mp3');
      } finally {
        engine.dispose();
      }
    });
  });
}
