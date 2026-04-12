import { http } from '@kit.NetworkKit';

import { MusicQualityType, MusicSourceTrack } from '../models/AppModels';
import {
  buildKgQualityTypes,
  buildKgSearchQualityTypes,
  buildTxQualityTypes,
  buildWyQualityTypes,
  formatPlayTime,
  parseKwNMinfo,
  parseMgQualityTypes
} from '../utils/MusicSourceUtils';

export interface MusicSourceTrackPage {
  tracks: MusicSourceTrack[];
  total: number;
  page: number;
}

function buildKwDefaultTypes(): [MusicQualityType[], Record<string, MusicQualityType>] {
  let defaultTypes: MusicQualityType[] = [
    { type: '128k', size: '', hash: '' },
    { type: '320k', size: '', hash: '' }
  ];
  let defaultTypeMap: Record<string, MusicQualityType> = {
    '128k': { type: '128k', size: '', hash: '' },
    '320k': { type: '320k', size: '', hash: '' }
  };
  return [defaultTypes, defaultTypeMap];
}

export async function fetchBoardTrackPage(subSource: string, bangid: string, page: number): Promise<MusicSourceTrackPage> {
  let httpRequest = http.createHttp();
  try {
    if (subSource === 'kg') {
      let limit = 30;
      let url = `http://mobilecdnbj.kugou.com/api/v3/rank/song?version=9108&ranktype=1&plat=0&pagesize=${limit}&area_code=1&page=${page}&rankid=${bangid}&with_res_tag=0&show_portrait_mv=1`;
      let response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        readTimeout: 15000,
        connectTimeout: 10000,
        header: { 'User-Agent': 'Android712/9108/332' } as Record<string, string>
      });
      if (response.responseCode !== 200) {
        throw new Error(`http ${response.responseCode}`);
      }
      let body = JSON.parse(response.result as string) as Record<string, Object>;
      let errcode = body['errcode'] as number;
      if (errcode !== 0) {
        throw new Error(`errcode ${errcode}`);
      }
      let data = body['data'] as Record<string, Object>;
      let total = data['total'] as number;
      let info = data['info'] as Record<string, Object>[];
      let tracks: MusicSourceTrack[] = [];
      for (let index = 0; index < info.length; index++) {
        let item = info[index];
        let authors = item['authors'] as Record<string, Object>[];
        let singerNames: string[] = [];
        if (authors) {
          for (let authorIndex = 0; authorIndex < authors.length; authorIndex++) {
            singerNames.push(authors[authorIndex]['author_name'] as string || '');
          }
        }
        let duration = item['duration'] as number || 0;
        let quality = buildKgQualityTypes(item);
        tracks.push({
          id: `${item['audio_id'] as number || 0}`,
          name: item['songname'] as string || '',
          singer: singerNames.join('、'),
          album: item['remark'] as string || '',
          albumId: `${item['album_id'] as number || 0}`,
          duration: duration,
          interval: formatPlayTime(duration),
          pic: '',
          source: 'kg',
          songmid: `${item['audio_id'] as number || 0}`,
          hash: item['hash'] as string || '',
          types: quality[0],
          _types: quality[1],
          copyrightId: ''
        });
      }
      return { tracks: tracks, total: total || tracks.length, page: page };
    }

    if (subSource === 'kw') {
      let limit = 30;
      let pn = page - 1;
      let url = `https://kbangserver.kuwo.cn/ksong.s?from=pc&fmt=json&pn=${pn}&rn=${limit}&type=bang&data=content&id=${bangid}&show_copyright_off=0&pcmp4=1&isbang=1`;
      let response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        readTimeout: 15000,
        connectTimeout: 10000,
        header: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        } as Record<string, string>
      });
      if (response.responseCode !== 200) {
        throw new Error(`http ${response.responseCode}`);
      }
      let body = JSON.parse(response.result as string) as Record<string, Object>;
      let musicList = body['musiclist'] as Record<string, Object>[];
      let total = parseInt(body['num'] as string || '0');
      let tracks: MusicSourceTrack[] = [];
      if (musicList) {
        for (let index = 0; index < musicList.length; index++) {
          let item = musicList[index];
          let duration = parseInt(item['song_duration'] as string || item['duration'] as string || '0');
          if (Number.isNaN(duration)) {
            duration = 0;
          }
          let kwTypes = buildKwDefaultTypes();
          tracks.push({
            id: item['id'] as string || `${item['rid'] as number || 0}`,
            name: item['name'] as string || '',
            singer: item['artist'] as string || '',
            album: item['album'] as string || '',
            albumId: item['albumid'] as string || `${item['albumid'] as number || 0}`,
            duration: duration,
            interval: formatPlayTime(duration),
            pic: item['pic'] as string || body['v9_pic2'] as string || '',
            source: 'kw',
            songmid: item['id'] as string || `${item['rid'] as number || 0}`,
            hash: '',
            types: kwTypes[0],
            _types: kwTypes[1],
            copyrightId: ''
          });
        }
      }
      return { tracks: tracks, total: total || tracks.length, page: page };
    }

    if (subSource === 'mg') {
      let url = `https://app.c.nf.migu.cn/MIGUM2.0/v1.0/content/querycontentbyId.do?columnId=${bangid}&needAll=0`;
      let response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        readTimeout: 15000,
        connectTimeout: 10000
      });
      if (response.responseCode !== 200) {
        throw new Error(`http ${response.responseCode}`);
      }
      let body = JSON.parse(response.result as string) as Record<string, Object>;
      let code = body['code'] as string;
      if (code !== '000000') {
        throw new Error(`code ${code}`);
      }
      let columnInfo = body['columnInfo'] as Record<string, Object>;
      let contents = columnInfo ? columnInfo['contents'] as Record<string, Object>[] : [];
      let tracks: MusicSourceTrack[] = [];
      let seenIds = new Set<string>();
      if (contents) {
        for (let index = 0; index < contents.length; index++) {
          let content = contents[index];
          let objectInfo = content['objectInfo'] as Record<string, Object>;
          if (!objectInfo) {
            continue;
          }
          let songId = objectInfo['songId'] as string || '';
          if (seenIds.has(songId)) {
            continue;
          }
          seenIds.add(songId);
          let artists = objectInfo['artists'] as Record<string, Object>[];
          let singerNames: string[] = [];
          if (artists) {
            for (let artistIndex = 0; artistIndex < artists.length; artistIndex++) {
              singerNames.push(artists[artistIndex]['name'] as string || '');
            }
          }
          let lengthText = objectInfo['length'] as string || '00:00';
          let durationParts = lengthText.split(':');
          let duration = 0;
          if (durationParts.length >= 2) {
            duration = parseInt(durationParts[0]) * 60 + parseInt(durationParts[1]);
          }
          let albumImages = objectInfo['albumImgs'] as Record<string, Object>[];
          let picture = '';
          if (albumImages && albumImages.length > 0) {
            picture = albumImages[0]['img'] as string || '';
          }
          let formats = objectInfo['newRateFormats'] as Record<string, Object>[];
          let quality = parseMgQualityTypes(formats);
          tracks.push({
            id: objectInfo['copyrightId'] as string || songId,
            name: objectInfo['songName'] as string || '',
            singer: singerNames.join('、'),
            album: objectInfo['album'] as string || '',
            albumId: objectInfo['albumId'] as string || '',
            duration: duration,
            interval: formatPlayTime(duration),
            pic: picture,
            source: 'mg',
            songmid: songId,
            hash: '',
            types: quality[0],
            _types: quality[1],
            copyrightId: objectInfo['copyrightId'] as string || ''
          });
        }
      }
      return { tracks: tracks, total: tracks.length, page: 1 };
    }

    if (subSource === 'tx') {
      let topid = parseInt(bangid);
      let requestBody = `{"toplist":{"module":"musicToplist.ToplistInfoServer","method":"GetDetail","param":{"topid":${topid},"num":100,"period":""}},"comm":{"uin":0,"format":"json","ct":20,"cv":1859}}`;
      let response = await httpRequest.request('https://u.y.qq.com/cgi-bin/musicu.fcg', {
        method: http.RequestMethod.POST,
        expectDataType: http.HttpDataType.STRING,
        readTimeout: 15000,
        connectTimeout: 10000,
        header: { 'Content-Type': 'application/json' } as Record<string, string>,
        extraData: requestBody
      });
      if (response.responseCode !== 200) {
        throw new Error(`http ${response.responseCode}`);
      }
      let body = JSON.parse(response.result as string) as Record<string, Object>;
      let toplist = body['toplist'] as Record<string, Object>;
      let data = toplist ? toplist['data'] as Record<string, Object> : null;
      let songInfoList = data ? data['songInfoList'] as Record<string, Object>[] : [];
      let tracks: MusicSourceTrack[] = [];
      if (songInfoList) {
        for (let index = 0; index < songInfoList.length; index++) {
          let item = songInfoList[index];
          let singers = item['singer'] as Record<string, Object>[];
          let singerNames: string[] = [];
          if (singers) {
            for (let singerIndex = 0; singerIndex < singers.length; singerIndex++) {
              singerNames.push(singers[singerIndex]['name'] as string || '');
            }
          }
          let album = item['album'] as Record<string, Object>;
          let albumName = album ? album['name'] as string || '' : '';
          let albumMid = album ? album['mid'] as string || '' : '';
          let interval = item['interval'] as number || 0;
          let file = item['file'] as Record<string, Object>;
          let quality = file ? buildTxQualityTypes(file) : [[] as MusicQualityType[], {} as Record<string, MusicQualityType>] as [MusicQualityType[], Record<string, MusicQualityType>];
          let songmid = item['mid'] as string || '';
          let mediaMid = file ? file['media_mid'] as string || '' : '';
          tracks.push({
            id: `${item['id'] as number || 0}`,
            name: item['title'] as string || '',
            singer: singerNames.join('、'),
            album: albumName,
            albumId: albumMid,
            duration: interval,
            interval: formatPlayTime(interval),
            pic: albumMid.length > 0 ? `https://y.gtimg.cn/music/photo_new/T002R500x500M000${albumMid}.jpg` : '',
            source: 'tx',
            songmid: songmid,
            hash: mediaMid,
            types: quality[0],
            _types: quality[1],
            copyrightId: ''
          });
        }
      }
      return { tracks: tracks, total: tracks.length, page: 1 };
    }

    if (subSource === 'wy') {
      let url = `https://music.163.com/api/playlist/detail?id=${bangid}&n=100000`;
      let response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        readTimeout: 15000,
        connectTimeout: 10000,
        header: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10)',
          'Referer': 'https://music.163.com/'
        } as Record<string, string>
      });
      if (response.responseCode !== 200) {
        throw new Error(`http ${response.responseCode}`);
      }
      let body = JSON.parse(response.result as string) as Record<string, Object>;
      let resultObj = body['result'] as Record<string, Object>;
      let trackItems = resultObj ? resultObj['tracks'] as Record<string, Object>[] : [];
      let tracks: MusicSourceTrack[] = [];
      if (trackItems) {
        for (let index = 0; index < trackItems.length; index++) {
          let item = trackItems[index];
          let artists = item['ar'] as Record<string, Object>[] || item['artists'] as Record<string, Object>[];
          let singerNames: string[] = [];
          if (artists) {
            for (let artistIndex = 0; artistIndex < artists.length; artistIndex++) {
              singerNames.push(artists[artistIndex]['name'] as string || '');
            }
          }
          let al = item['al'] as Record<string, Object> || item['album'] as Record<string, Object>;
          let albumName = al ? al['name'] as string || '' : '';
          let albumId = al ? `${al['id'] as number || 0}` : '';
          let picUrl = al ? al['picUrl'] as string || '' : '';
          let dt = item['dt'] as number || item['duration'] as number || 0;
          let durationSec = Math.floor(dt / 1000);
          let privilege = item['privilege'] as Record<string, Object> | null;
          let quality = buildWyQualityTypes(item, privilege);
          let songId = `${item['id'] as number || 0}`;
          tracks.push({
            id: songId,
            name: item['name'] as string || '',
            singer: singerNames.join('、'),
            album: albumName,
            albumId: albumId,
            duration: durationSec,
            interval: formatPlayTime(durationSec),
            pic: picUrl,
            source: 'wy',
            songmid: songId,
            hash: '',
            types: quality[0],
            _types: quality[1],
            copyrightId: ''
          });
        }
      }
      return { tracks: tracks, total: tracks.length, page: 1 };
    }

    throw new Error(`unsupported board source ${subSource}`);
  } finally {
    httpRequest.destroy();
  }
}

export async function searchSourceTrackPage(keyword: string, searchSource: string, page: number): Promise<MusicSourceTrackPage> {
  let httpRequest = http.createHttp();
  try {
    if (searchSource === 'kg') {
      let limit = 30;
      let url = `https://songsearch.kugou.com/song_search_v2?keyword=${encodeURIComponent(keyword)}&page=${page}&pagesize=${limit}&userid=0&clientver=&platform=WebFilter&filter=2&iscorrection=1&privilege_filter=0&area_code=1`;
      let response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        readTimeout: 15000,
        connectTimeout: 10000
      });
      if (response.responseCode !== 200) {
        throw new Error(`http ${response.responseCode}`);
      }
      let body = JSON.parse(response.result as string) as Record<string, Object>;
      let errorCode = body['error_code'] as number;
      if (errorCode !== 0) {
        throw new Error(`error_code ${errorCode}`);
      }
      let data = body['data'] as Record<string, Object>;
      let total = data['total'] as number || 0;
      let lists = data['lists'] as Record<string, Object>[];
      let tracks: MusicSourceTrack[] = [];
      if (lists) {
        for (let index = 0; index < lists.length; index++) {
          let item = lists[index];
          let singers = item['Singers'] as Record<string, Object>[];
          let singerNames: string[] = [];
          if (singers) {
            for (let singerIndex = 0; singerIndex < singers.length; singerIndex++) {
              singerNames.push(singers[singerIndex]['name'] as string || '');
            }
          }
          let duration = item['Duration'] as number || 0;
          let quality = buildKgSearchQualityTypes(item);
          tracks.push({
            id: `${item['Audioid'] as number || 0}`,
            name: item['SongName'] as string || '',
            singer: singerNames.join('、'),
            album: item['AlbumName'] as string || '',
            albumId: `${item['AlbumID'] as string || ''}`,
            duration: duration,
            interval: formatPlayTime(duration),
            pic: '',
            source: 'kg',
            songmid: `${item['Audioid'] as number || 0}`,
            hash: item['FileHash'] as string || '',
            types: quality[0],
            _types: quality[1],
            copyrightId: ''
          });
        }
      }
      return { tracks: tracks, total: total, page: page };
    }

    if (searchSource === 'kw') {
      let limit = 30;
      let url = `https://search.kuwo.cn/r.s?client=kt&all=${encodeURIComponent(keyword)}&pn=${page - 1}&rn=${limit}&uid=794762570&ver=kwplayer_ar_9.2.2.1&vipver=1&show_copyright_off=1&newver=1&ft=music&cluster=0&strategy=2012&encoding=utf8&rformat=json&vermerge=1&mobi=1&issubtitle=1`;
      let response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        readTimeout: 15000,
        connectTimeout: 10000
      });
      if (response.responseCode !== 200) {
        throw new Error(`http ${response.responseCode}`);
      }
      let body = JSON.parse(response.result as string) as Record<string, Object>;
      let total = parseInt(body['TOTAL'] as string || '0');
      let abslist = body['abslist'] as Record<string, Object>[];
      let tracks: MusicSourceTrack[] = [];
      if (abslist) {
        for (let index = 0; index < abslist.length; index++) {
          let item = abslist[index];
          let songId = (item['MUSICRID'] as string || '').replace('MUSIC_', '');
          let duration = parseInt(item['DURATION'] as string || '0');
          let quality = parseKwNMinfo(item['N_MINFO'] as string || '');
          tracks.push({
            id: songId,
            name: item['SONGNAME'] as string || '',
            singer: item['ARTIST'] as string || '',
            album: item['ALBUM'] as string || '',
            albumId: item['ALBUMID'] as string || '',
            duration: Number.isNaN(duration) ? 0 : duration,
            interval: Number.isNaN(duration) ? '00:00' : formatPlayTime(duration),
            pic: '',
            source: 'kw',
            songmid: songId,
            hash: '',
            types: quality[0],
            _types: quality[1],
            copyrightId: ''
          });
        }
      }
      return { tracks: tracks, total: total, page: page };
    }

    if (searchSource === 'mg') {
      let limit = 30;
      let url = `https://jadeite.migu.cn/music_search/v3/search/searchAll?isCorrect=0&isCopyright=1&searchSwitch=%7B%22song%22%3A1%2C%22album%22%3A0%2C%22singer%22%3A0%2C%22tagSong%22%3A1%2C%22mvSong%22%3A0%2C%22bestShow%22%3A1%2C%22songlist%22%3A0%2C%22lyricSong%22%3A0%7D&pageSize=${limit}&text=${encodeURIComponent(keyword)}&pageNo=${page}&sort=0&sid=USS`;
      let response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        readTimeout: 15000,
        connectTimeout: 10000,
        header: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10)',
          'Referer': 'https://m.music.migu.cn/'
        } as Record<string, string>
      });
      if (response.responseCode !== 200) {
        throw new Error(`http ${response.responseCode}`);
      }
      let body = JSON.parse(response.result as string) as Record<string, Object>;
      let songResultData = body['songResultData'] as Record<string, Object>;
      let total = 0;
      let tracks: MusicSourceTrack[] = [];
      if (songResultData) {
        total = songResultData['totalCount'] as number || 0;
        let resultList = songResultData['resultList'] as Record<string, Object>[][];
        if (resultList) {
          for (let groupIndex = 0; groupIndex < resultList.length; groupIndex++) {
            let group = resultList[groupIndex];
            if (!group || group.length === 0) {
              continue;
            }
            let item = group[0];
            let singerList = item['singers'] as Record<string, Object>[];
            let singerNames: string[] = [];
            if (singerList) {
              for (let singerIndex = 0; singerIndex < singerList.length; singerIndex++) {
                singerNames.push(singerList[singerIndex]['name'] as string || '');
              }
            }
            let albums = item['albums'] as Record<string, Object>[];
            let albumName = '';
            let albumId = '';
            if (albums && albums.length > 0) {
              albumName = albums[0]['name'] as string || '';
              albumId = albums[0]['id'] as string || '';
            }
            let copyrightId = item['copyrightId'] as string || item['id'] as string || '';
            let mgImg = item['img3'] as string || item['img2'] as string || item['img1'] as string || '';
            if (mgImg.length > 0 && !mgImg.startsWith('http')) {
              mgImg = `http://d.musicapp.migu.cn${mgImg}`;
            }
            tracks.push({
              id: copyrightId,
              name: item['name'] as string || '',
              singer: singerNames.join('、'),
              album: albumName,
              albumId: albumId,
              duration: 0,
              interval: '',
              pic: mgImg,
              source: 'mg',
              songmid: copyrightId,
              hash: '',
              types: [],
              _types: {},
              copyrightId: copyrightId
            });
          }
        }
      }
      return { tracks: tracks, total: total || tracks.length, page: page };
    }

    if (searchSource === 'tx') {
      let limit = 30;
      let escapedKeyword = keyword.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
      let requestBody = `{"comm":{"ct":11,"cv":1003,"format":"json","uin":0},"req":{"module":"music.search.SearchCgiService","method":"DoSearchForQQMusicDesktop","param":{"search_type":0,"query":"${escapedKeyword}","page_num":${page},"num_per_page":${limit},"highlight":0,"nqc_flag":0,"grp":1}}}`;
      let response = await httpRequest.request('https://u.y.qq.com/cgi-bin/musicu.fcg', {
        method: http.RequestMethod.POST,
        expectDataType: http.HttpDataType.STRING,
        readTimeout: 15000,
        connectTimeout: 10000,
        header: { 'Content-Type': 'application/json' } as Record<string, string>,
        extraData: requestBody
      });
      if (response.responseCode !== 200) {
        throw new Error(`http ${response.responseCode}`);
      }
      let body = JSON.parse(response.result as string) as Record<string, Object>;
      let req = body['req'] as Record<string, Object>;
      let data = req ? req['data'] as Record<string, Object> : null;
      let bodyData = data ? data['body'] as Record<string, Object> : null;
      let meta = data ? data['meta'] as Record<string, Object> : null;
      let total = meta ? meta['estimate_sum'] as number || meta['sum'] as number || 0 : 0;
      let songList = bodyData ? bodyData['item_song'] as Record<string, Object>[] || bodyData['song'] as Record<string, Object>[] : null;
      if (!songList) {
        let songData = bodyData ? bodyData['song'] as Record<string, Object> : null;
        songList = songData ? songData['list'] as Record<string, Object>[] : [];
      }
      let tracks: MusicSourceTrack[] = [];
      if (songList) {
        for (let index = 0; index < songList.length; index++) {
          let item = songList[index];
          let singers = item['singer'] as Record<string, Object>[];
          let singerNames: string[] = [];
          if (singers) {
            for (let singerIndex = 0; singerIndex < singers.length; singerIndex++) {
              singerNames.push(singers[singerIndex]['name'] as string || '');
            }
          }
          let album = item['album'] as Record<string, Object>;
          let albumName = album ? album['name'] as string || '' : '';
          let albumMid = album ? album['mid'] as string || '' : '';
          let interval = item['interval'] as number || 0;
          let file = item['file'] as Record<string, Object>;
          let quality = file ? buildTxQualityTypes(file) : [[] as MusicQualityType[], {} as Record<string, MusicQualityType>] as [MusicQualityType[], Record<string, MusicQualityType>];
          let songmid = item['mid'] as string || '';
          let mediaMid = file ? file['media_mid'] as string || '' : '';
          tracks.push({
            id: `${item['id'] as number || 0}`,
            name: item['name'] as string || item['title'] as string || '',
            singer: singerNames.join('、'),
            album: albumName,
            albumId: albumMid,
            duration: interval,
            interval: formatPlayTime(interval),
            pic: albumMid.length > 0 ? `https://y.gtimg.cn/music/photo_new/T002R500x500M000${albumMid}.jpg` : '',
            source: 'tx',
            songmid: songmid,
            hash: mediaMid,
            types: quality[0],
            _types: quality[1],
            copyrightId: ''
          });
        }
      }
      return { tracks: tracks, total: total, page: page };
    }

    if (searchSource === 'wy') {
      let limit = 30;
      let offset = limit * (page - 1);
      let url = `https://music.163.com/api/cloudsearch/pc?s=${encodeURIComponent(keyword)}&type=1&limit=${limit}&offset=${offset}`;
      let response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        expectDataType: http.HttpDataType.STRING,
        readTimeout: 15000,
        connectTimeout: 10000,
        header: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10)',
          'Referer': 'https://music.163.com/',
          'Content-Type': 'application/x-www-form-urlencoded'
        } as Record<string, string>
      });
      if (response.responseCode !== 200) {
        throw new Error(`http ${response.responseCode}`);
      }
      let body = JSON.parse(response.result as string) as Record<string, Object>;
      let result = body['result'] as Record<string, Object>;
      let total = result ? result['songCount'] as number || 0 : 0;
      let songs = result ? result['songs'] as Record<string, Object>[] : [];
      let tracks: MusicSourceTrack[] = [];
      if (songs) {
        for (let index = 0; index < songs.length; index++) {
          let item = songs[index];
          let artists = item['ar'] as Record<string, Object>[];
          let singerNames: string[] = [];
          if (artists) {
            for (let artistIndex = 0; artistIndex < artists.length; artistIndex++) {
              singerNames.push(artists[artistIndex]['name'] as string || '');
            }
          }
          let al = item['al'] as Record<string, Object>;
          let albumName = al ? al['name'] as string || '' : '';
          let albumId = al ? `${al['id'] as number || 0}` : '';
          let picUrl = al ? al['picUrl'] as string || '' : '';
          let dt = item['dt'] as number || 0;
          let durationSec = Math.floor(dt / 1000);
          let privilege = item['privilege'] as Record<string, Object> | null;
          let quality = buildWyQualityTypes(item, privilege);
          let songId = `${item['id'] as number || 0}`;
          tracks.push({
            id: songId,
            name: item['name'] as string || '',
            singer: singerNames.join('、'),
            album: albumName,
            albumId: albumId,
            duration: durationSec,
            interval: formatPlayTime(durationSec),
            pic: picUrl,
            source: 'wy',
            songmid: songId,
            hash: '',
            types: quality[0],
            _types: quality[1],
            copyrightId: ''
          });
        }
      }
      return { tracks: tracks, total: total, page: page };
    }

    throw new Error(`unsupported search source ${searchSource}`);
  } finally {
    httpRequest.destroy();
  }
}
