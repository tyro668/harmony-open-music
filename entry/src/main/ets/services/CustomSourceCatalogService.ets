import { t } from '../utils/I18nUtil';
import { MusicSourceConfig, MusicSourceQuality } from '../models/AppModels';
import {
  defaultMusicSources,
  filterSupportedExploreSources,
  normalizeMusicSourceQuality,
  parseLxSourceScriptInfo,
  resolvePreferredSourceQuality,
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
      errorMessage: t('source.empty_content')
    };
  }

  let info = parseLxSourceScriptInfo(scriptContent);
  let scriptApiUrl = `script_${simpleHash(scriptContent)}`;
  let duplicated = existingSources.some((source: MusicSourceConfig) => source.apiUrl === scriptApiUrl);
  if (duplicated) {
    return {
      source: null,
      errorMessage: t('source.already_added')
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

export function updateSourcePreferredQuality(
  sources: MusicSourceConfig[],
  sourceId: string,
  sourceCode: string,
  quality: string
): UpdatedSourceCollectionResult {
  let updated = false;
  return {
    sources: sources.map((source: MusicSourceConfig) => {
      if (source.id !== sourceId) {
        return source;
      }

      let nextMusicSources = source.musicSources.map((item: MusicSourceQuality) => {
        if (item.source !== sourceCode || item.qualitys.indexOf(quality) < 0) {
          return item;
        }
        let normalized = normalizeMusicSourceQuality({
          source: item.source,
          qualitys: item.qualitys,
          preferredQuality: quality
        });
        if (resolvePreferredSourceQuality(item) !== normalized.preferredQuality) {
          updated = true;
        }
        return normalized;
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
        musicSources: nextMusicSources
      };
    }),
    updated: updated
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
