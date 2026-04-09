import { MusicSourceConfig, MusicSourceQuality } from '../models/AppModels';
import {
  defaultMusicSources,
  filterSupportedExploreSources,
  parseLxSourceScriptInfo,
  simpleHash
} from '../utils/MusicSourceUtils';

export interface PendingMusicSourceResult {
  source: MusicSourceConfig | null;
  errorMessage: string;
}

export interface UpdatedSourceCollectionResult {
  sources: MusicSourceConfig[];
  updated: boolean;
}

export function createPendingMusicSource(
  scriptContent: string,
  existingSources: MusicSourceConfig[]
): PendingMusicSourceResult {
  let normalizedScript = scriptContent.trim();
  if (normalizedScript.length === 0) {
    return {
      source: null,
      errorMessage: '脚本内容为空'
    };
  }

  let info = parseLxSourceScriptInfo(scriptContent);
  let scriptApiUrl = `script_${simpleHash(scriptContent)}`;
  let duplicated = existingSources.some((source: MusicSourceConfig) => source.apiUrl === scriptApiUrl);
  if (duplicated) {
    return {
      source: null,
      errorMessage: '该音源已添加'
    };
  }

  return {
    source: {
      id: `source_${Date.now()}_${Math.floor(Math.random() * 10000)}`,
      name: info['name'].length > 0 ? info['name'] : `user_api_${new Date().toLocaleString()}`,
      description: info['description'],
      author: info['author'],
      homepage: info['homepage'],
      version: info['version'].length > 0 ? info['version'] : '1.0.0',
      allowShowUpdateAlert: true,
      apiUrl: scriptApiUrl,
      apiKey: '',
      musicSources: defaultMusicSources()
    },
    errorMessage: ''
  };
}

export function toggleSourceUpdateAlert(
  sources: MusicSourceConfig[],
  sourceId: string
): UpdatedSourceCollectionResult {
  let updated = false;
  return {
    sources: sources.map((source: MusicSourceConfig) => {
      if (source.id !== sourceId) {
        return source;
      }
      updated = true;
      return {
        id: source.id,
        name: source.name,
        description: source.description,
        author: source.author,
        homepage: source.homepage,
        version: source.version,
        allowShowUpdateAlert: !source.allowShowUpdateAlert,
        apiUrl: source.apiUrl,
        apiKey: source.apiKey,
        musicSources: source.musicSources
      };
    }),
    updated: updated
  };
}

export function removeSourceById(
  sources: MusicSourceConfig[],
  sourceId: string
): UpdatedSourceCollectionResult {
  let nextSources = sources.filter((source: MusicSourceConfig) => source.id !== sourceId);
  return {
    sources: nextSources,
    updated: nextSources.length !== sources.length
  };
}

export function resolvePreferredSubSource(
  source: MusicSourceConfig,
  fallbackSource: string
): string {
  let supportedSources = filterSupportedExploreSources(source.musicSources);
  if (fallbackSource.length > 0 && supportedSources.some((item: MusicSourceQuality) => item.source === fallbackSource)) {
    return fallbackSource;
  }
  if (supportedSources.length > 0) {
    return supportedSources[0].source;
  }
  let nonLocalSources = source.musicSources.filter((item: MusicSourceQuality) => item.source !== 'local');
  if (fallbackSource.length > 0 && nonLocalSources.some((item: MusicSourceQuality) => item.source === fallbackSource)) {
    return fallbackSource;
  }
  if (nonLocalSources.length > 0) {
    return nonLocalSources[0].source;
  }
  return fallbackSource;
}
