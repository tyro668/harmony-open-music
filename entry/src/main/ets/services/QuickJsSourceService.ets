import { http } from '@kit.NetworkKit';

import {
  JsEngineInitInfo,
  MusicQualityType,
  MusicSourceConfig,
  MusicSourceQuality,
  MusicSourceTrack
} from '../models/AppModels';
import { QuickJsHttpRequest, QuickJsHttpTask } from '../utils/QuickJsEngine';
import {
  normalizeMusicSourceQuality,
  resolvePreferredSourceQuality
} from '../utils/MusicSourceUtils';

export interface JsEngineInitOutcome {
  ready: boolean;
  errorMessage: string;
  musicSources: MusicSourceConfig[];
  didUpdateSources: boolean;
}

function extractJsEngineMusicSources(info: JsEngineInitInfo | undefined): MusicSourceQuality[] {
  let updatedSources: MusicSourceQuality[] = [];
  if (!info || !info.sources) {
    return updatedSources;
  }
  let sourceKeys = Object.keys(info.sources);
  for (let index = 0; index < sourceKeys.length; index++) {
    let sourceKey = sourceKeys[index];
    let sourceInfo = info.sources[sourceKey];
    if (sourceInfo && sourceInfo.type === 'music') {
      updatedSources.push(normalizeMusicSourceQuality({
        source: sourceKey,
        qualitys: sourceInfo.qualitys || ['128k', '320k']
      }));
    }
  }
  return updatedSources;
}

export function handleJsEngineInitPayload(
  currentSources: MusicSourceConfig[],
  sourceId: string,
  data: Record<string, Object>
): JsEngineInitOutcome {
  let status = data['status'] as boolean;
  if (!status) {
    return {
      ready: false,
      errorMessage: (data['errorMessage'] as string) || 'init failed',
      musicSources: currentSources,
      didUpdateSources: false
    };
  }

  let info = data['info'] as JsEngineInitInfo;
  let updatedSources = extractJsEngineMusicSources(info);
  if (updatedSources.length === 0) {
    return {
      ready: true,
      errorMessage: '',
      musicSources: currentSources,
      didUpdateSources: false
    };
  }

  return {
    ready: true,
    errorMessage: '',
    musicSources: currentSources.map((source: MusicSourceConfig) => {
      if (source.id !== sourceId) {
        return source;
      }
      let mergedMusicSources = updatedSources.map((item: MusicSourceQuality) => {
        let currentSourceQuality = source.musicSources.find((currentItem: MusicSourceQuality) => currentItem.source === item.source);
        return normalizeMusicSourceQuality({
          source: item.source,
          qualitys: item.qualitys,
          preferredQuality: currentSourceQuality ? resolvePreferredSourceQuality(currentSourceQuality) : item.preferredQuality
        });
      });
      return {
        id: source.id,
        name: source.name,
        description: source.description,
        author: source.author,
        homepage: source.homepage,
        version: source.version,
        allowShowUpdateAlert: source.allowShowUpdateAlert,
        apiUrl: source.apiUrl,
        apiKey: source.apiKey,
        musicSources: mergedMusicSources
      };
    }),
    didUpdateSources: true
  };
}

export function buildQuickJsSourceSetupScript(
  engineKey: string,
  source: MusicSourceConfig,
  rawScript: string,
  preloadScript: string
): string {
  let scriptInfoObj: Record<string, string> = {
    'name': source.name || '',
    'description': source.description || '',
    'version': source.version || '',
    'author': source.author || '',
    'homepage': source.homepage || '',
    'rawScript': rawScript
  };
  let scriptInfoJson = JSON.stringify(scriptInfoObj);
  let escapedScriptInfoJson = scriptInfoJson.replace(/\\/g, '\\\\').replace(/'/g, "\\'");
  return `${preloadScript}\nlx_setup('${engineKey}', JSON.parse('${escapedScriptInfoJson}'));\n${rawScript}`;
}

function encodeQuickJsFormBody(data: Record<string, string>): string {
  let pairs: string[] = [];
  let keys = Object.keys(data);
  for (let index = 0; index < keys.length; index++) {
    let key = keys[index];
    pairs.push(`${encodeURIComponent(key)}=${encodeURIComponent(data[key])}`);
  }
  return pairs.join('&');
}

function normalizeQuickJsResponseHeaders(rawHeaders: Record<string, Object>): Record<string, Object> {
  let normalized: Record<string, Object> = {};
  let headerKeys = Object.keys(rawHeaders);
  for (let index = 0; index < headerKeys.length; index++) {
    let key = headerKeys[index];
    let value = rawHeaders[key];
    let normalizedValue: string[];
    if (Array.isArray(value)) {
      normalizedValue = value.map((item: Object): string => String(item));
    } else if (value === undefined || value === null) {
      normalizedValue = [''];
    } else {
      normalizedValue = [String(value)];
    }
    normalized[key] = normalizedValue as Object;
    let lowerKey = key.toLowerCase();
    if (!normalized[lowerKey]) {
      normalized[lowerKey] = normalizedValue as Object;
    }
  }
  return normalized;
}

function createQuickJsHttpErrorResponse(requestKey: string, errorMessage: string): string {
  return JSON.stringify({
    requestKey: requestKey,
    error: errorMessage
  });
}

export function createQuickJsHttpRequestTask(req: QuickJsHttpRequest): QuickJsHttpTask {
  let method = http.RequestMethod.GET;
  let m = (req.options.method || 'GET').toUpperCase();
  if (m === 'POST') {
    method = http.RequestMethod.POST;
  } else if (m === 'PUT') {
    method = http.RequestMethod.PUT;
  } else if (m === 'DELETE') {
    method = http.RequestMethod.DELETE;
  }

  let headers: Record<string, string> = {};
  let headerSource = req.options.headers || {};
  let headerKeys = Object.keys(headerSource);
  for (let index = 0; index < headerKeys.length; index++) {
    let key = headerKeys[index];
    headers[key] = headerSource[key];
  }
  if (!headers['Accept'] && !headers['accept']) {
    headers['Accept'] = 'application/json';
  }
  if (!headers['User-Agent'] && !headers['user-agent']) {
    headers['User-Agent'] = 'Mozilla/5.0 (Linux; HarmonyOS) AppleWebKit/537.36 Chrome/114.0.0.0 Mobile Safari/537.36';
  }
  let timeout = req.options.timeout || 15000;

  let extraData: string | undefined = undefined;
  if (typeof req.options.body === 'string' && req.options.body.length > 0) {
    extraData = req.options.body;
  } else if (req.options.form) {
    extraData = encodeQuickJsFormBody(req.options.form);
    if (!headers['Content-Type'] && !headers['content-type']) {
      headers['Content-Type'] = 'application/x-www-form-urlencoded';
    }
  } else if (req.options.formData) {
    extraData = encodeQuickJsFormBody(req.options.formData);
    if (!headers['Content-Type'] && !headers['content-type']) {
      headers['Content-Type'] = 'application/x-www-form-urlencoded';
    }
  }

  let canceled = false;
  let activeClient: http.HttpRequest | null = null;
  let responsePromise = (async (): Promise<string> => {
    let proxyAttempts: (boolean | undefined)[] = [undefined, false];
    for (let pi = 0; pi < proxyAttempts.length; pi++) {
      if (canceled) {
        return createQuickJsHttpErrorResponse(req.requestKey, 'request canceled');
      }

      let httpClient = http.createHttp();
      activeClient = httpClient;
      try {
        let requestOpts: Record<string, Object> = {
          'method': method as Object,
          'expectDataType': (req.options.binary ? http.HttpDataType.ARRAY_BUFFER : http.HttpDataType.STRING) as Object,
          'readTimeout': timeout as Object,
          'connectTimeout': Math.min(timeout, 10000) as Object,
          'header': headers as Object
        };
        if (extraData !== undefined) {
          requestOpts['extraData'] = extraData as Object;
        }
        if (proxyAttempts[pi] !== undefined) {
          requestOpts['usingProxy'] = proxyAttempts[pi] as Object;
        }

        let response = await httpClient.request(req.url, requestOpts as http.HttpRequestOptions);
        if (canceled) {
          return createQuickJsHttpErrorResponse(req.requestKey, 'request canceled');
        }

        let respBody: Object;
        if (req.options.binary) {
          let respBodyBuffer = response.result as ArrayBuffer;
          respBody = Array.from(new Uint8Array(respBodyBuffer)) as Object;
        } else {
          let respBodyStr = response.result as string;
          if (respBodyStr.length > 0 && respBodyStr.charCodeAt(0) === 0xFEFF) {
            respBodyStr = respBodyStr.substring(1);
          }
          try {
            respBody = JSON.parse(respBodyStr) as Object;
          } catch (_) {
            respBody = respBodyStr as Object;
          }
        }

        let innerResp: Record<string, Object> = {
          'statusCode': response.responseCode as Object,
          'statusMessage': '' as Object,
          'headers': normalizeQuickJsResponseHeaders(response.header as Record<string, Object>) as Object,
          'body': respBody
        };
        let outerResp: Record<string, Object> = {
          'requestKey': req.requestKey as Object,
          'error': '' as Object,
          'response': innerResp as Object
        };
        return JSON.stringify(outerResp);
      } catch (error) {
        if (canceled) {
          return createQuickJsHttpErrorResponse(req.requestKey, 'request canceled');
        }

        let errObj = error as Record<string, Object>;
        let errCode = errObj['code'] as number;
        let errMsg = (error instanceof Error) ? error.message : (errObj['message'] as string || String(errCode) || String(error));

        let isProxyError = errCode === 2300035 || errCode === 2300052 || errCode === 2300056 || errCode === 2300007 || errCode === 2300999;
        if (isProxyError && pi < proxyAttempts.length - 1) {
          console.info(`handleJsHttpRequest proxy error (code=${errCode}), retrying without proxy: ${req.url}`);
          continue;
        }

        console.error(`handleJsHttpRequest error: url=${req.url}, err=${errMsg}, code=${errCode}, proxy=${String(proxyAttempts[pi])}`);
        return createQuickJsHttpErrorResponse(req.requestKey, errMsg);
      } finally {
        if (activeClient === httpClient) {
          activeClient = null;
        }
        httpClient.destroy();
      }
    }
    return createQuickJsHttpErrorResponse(req.requestKey, 'no HTTP response');
  })();

  return {
    response: responsePromise,
    abort: (): void => {
      canceled = true;
      if (activeClient !== null) {
        try {
          activeClient.destroy();
        } catch (error) {
          console.error(`abort QuickJS HTTP request failed: ${JSON.stringify(error)}`);
        } finally {
          activeClient = null;
        }
      }
    }
  };
}

export function buildQuickJsMusicUrlRequest(requestKey: string, track: MusicSourceTrack, quality: string): string {
  let typesArr: Record<string, Object>[] = [];
  for (let index = 0; index < track.types.length; index++) {
    let qt = track.types[index];
    let typeObj: Record<string, Object> = { 'type': qt.type as Object, 'size': qt.size as Object };
    if (qt.hash.length > 0) {
      typeObj['hash'] = qt.hash as Object;
    }
    typesArr.push(typeObj);
  }

  let typesMap: Record<string, Object> = {};
  let typeKeys = Object.keys(track._types);
  for (let index = 0; index < typeKeys.length; index++) {
    let typeKey = typeKeys[index];
    let typeValue = track._types[typeKey];
    let entry: Record<string, Object> = { 'size': typeValue.size as Object };
    if (typeValue.hash.length > 0) {
      entry['hash'] = typeValue.hash as Object;
    }
    typesMap[typeKey] = entry as Object;
  }

  let emptyTypeUrl: Record<string, Object> = {};
  let musicInfo: Record<string, Object> = {
    'name': track.name as Object,
    'singer': track.singer as Object,
    'source': track.source as Object,
    'songmid': track.songmid as Object,
    'interval': track.interval as Object,
    'albumName': track.album as Object,
    'albumId': track.albumId as Object,
    'img': track.pic as Object,
    'hash': track.hash as Object,
    'types': typesArr as Object,
    '_types': typesMap as Object,
    'typeUrl': emptyTypeUrl as Object,
    'copyrightId': track.copyrightId as Object
  };

  let infoObj: Record<string, Object> = {
    'type': quality as Object,
    'musicInfo': musicInfo as Object
  };
  let dataObj: Record<string, Object> = {
    'source': track.source as Object,
    'action': 'musicUrl' as Object,
    'info': infoObj as Object
  };
  let requestData: Record<string, Object> = {
    'requestKey': requestKey as Object,
    'data': dataObj as Object
  };
  return JSON.stringify(requestData);
}

export function parseQuickJsMusicUrlResponse(responsePayloadJson: string): string {
  let responseData = JSON.parse(responsePayloadJson) as Record<string, Object>;
  let status = responseData['status'] as boolean;
  if (!status) {
    throw new Error((responseData['errorMessage'] as string) || 'request failed');
  }
  let result = responseData['result'] as Record<string, Object>;
  if (!result) {
    throw new Error('no result');
  }
  let resultData = result['data'] as Record<string, Object>;
  let url = resultData && resultData['url'] ? resultData['url'] as string : '';
  if (url.length === 0) {
    throw new Error('no url in response');
  }
  return url;
}

export function resolveSourceTrackQuality(source: MusicSourceConfig, track: MusicSourceTrack): string {
  let sourceQuality = source.musicSources.find((item: MusicSourceQuality) => item.source === track.source);
  if (!sourceQuality || sourceQuality.qualitys.length === 0) {
    return '128k';
  }

  let candidateQualities: string[] = [];
  let selectedQuality = resolvePreferredSourceQuality(sourceQuality);
  candidateQualities.push(selectedQuality);
  for (let index = 0; index < sourceQuality.qualitys.length; index++) {
    let quality = sourceQuality.qualitys[index];
    if (candidateQualities.indexOf(quality) >= 0) {
      continue;
    }
    candidateQualities.push(quality);
  }

  for (let index = 0; index < candidateQualities.length; index++) {
    let preferredQuality = candidateQualities[index];
    if (track.types.length === 0 || track.types.some((qt: MusicQualityType) => qt.type === preferredQuality)) {
      return preferredQuality;
    }
  }

  return selectedQuality;
}
