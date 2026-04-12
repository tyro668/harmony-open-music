export const LX_PRELOAD_SCRIPT: string = String.raw`'use strict';

globalThis.lx_setup = function(engineKey, scriptInfo) {
  delete globalThis.lx_setup;

  var checkLength = function(input, maxLength) {
    var text = typeof input === 'string' ? input : '';
    var limit = typeof maxLength === 'number' ? maxLength : 1048576;
    if (text.length > limit) {
      throw new Error('Input too long');
    }
    return text;
  };

  var nativeCall = function(action, data) {
    var payload = JSON.stringify(data == null ? null : data);
    checkLength(payload, 2097152);
    __quickjs_bridge__(engineKey, action, payload);
  };

  var EVENT_NAMES = {
    request: 'request',
    inited: 'inited',
    updateAlert: 'updateAlert'
  };
  var KEY_PREFIX = {
    publicKeyStart: '-----BEGIN PUBLIC KEY-----',
    publicKeyEnd: '-----END PUBLIC KEY-----'
  };
  var events = {
    request: null
  };
  var allSources = ['kw', 'kg', 'tx', 'wy', 'mg', 'local'];
  var supportQualitys = {
    kw: ['128k', '320k', 'flac', 'flac24bit'],
    kg: ['128k', '320k', 'flac', 'flac24bit'],
    tx: ['128k', '320k', 'flac', 'flac24bit'],
    wy: ['128k', '320k', 'flac', 'flac24bit'],
    mg: ['128k', '320k', 'flac', 'flac24bit'],
    local: []
  };
  var supportActions = {
    kw: ['musicUrl', 'lyric'],
    kg: ['musicUrl', 'lyric'],
    tx: ['musicUrl', 'lyric'],
    wy: ['musicUrl', 'lyric'],
    mg: ['musicUrl', 'lyric'],
    local: ['musicUrl', 'lyric', 'pic']
  };

  var safeSerialize = function(value) {
    if (typeof value === 'string') {
      return value;
    }
    if (value instanceof Error) {
      return value.stack || value.message || String(value);
    }
    try {
      return JSON.stringify(value);
    } catch (_) {
      try {
        return String(value);
      } catch (error) {
        return '[unserializable:' + String(error) + ']';
      }
    }
  };
  var createConsoleMethod = function(type) {
    return function() {
      if (!isInitedApi) {
        return;
      }
      var args = Array.prototype.slice.call(arguments);
      var parts = [];
      for (var i = 0; i < args.length; i++) {
        parts.push(safeSerialize(args[i]));
      }
      nativeCall('log', {
        type: type,
        log: parts.join(' ')
      });
    };
  };
  globalThis.console = {
    log: createConsoleMethod('log'),
    info: createConsoleMethod('info'),
    warn: createConsoleMethod('warn'),
    error: createConsoleMethod('error')
  };
  globalThis.window = globalThis;
  globalThis.self = globalThis;

  function bytesToString(bytes) {
    var result = '';
    var i = 0;
    while (i < bytes.length) {
      var byte = bytes[i];
      if (byte < 128) {
        result += String.fromCharCode(byte);
        i += 1;
      } else if (byte >= 192 && byte < 224) {
        result += String.fromCharCode(((byte & 31) << 6) | (bytes[i + 1] & 63));
        i += 2;
      } else {
        result += String.fromCharCode(((byte & 15) << 12) | ((bytes[i + 1] & 63) << 6) | (bytes[i + 2] & 63));
        i += 3;
      }
    }
    return result;
  }

  function stringToBytes(inputString) {
    var bytes = [];
    for (var i = 0; i < inputString.length; i++) {
      var charCode = inputString.charCodeAt(i);
      if (charCode < 128) {
        bytes.push(charCode);
      } else if (charCode < 2048) {
        bytes.push((charCode >> 6) | 192);
        bytes.push((charCode & 63) | 128);
      } else {
        bytes.push((charCode >> 12) | 224);
        bytes.push(((charCode >> 6) & 63) | 128);
        bytes.push((charCode & 63) | 128);
      }
    }
    return bytes;
  }

  var BASE64_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
  function base64ToBytes(input) {
    var str = String(input || '').replace(/=+$/, '');
    var output = [];
    if (str.length % 4 === 1) {
      throw new Error('Invalid base64 input');
    }
    var bs = 0;
    var buffer;
    for (var bc = 0, idx = 0; idx < str.length; idx++) {
      buffer = BASE64_CHARS.indexOf(str.charAt(idx));
      if (buffer < 0) {
        continue;
      }
      bs = bc % 4 ? bs * 64 + buffer : buffer;
      if (bc++ % 4) {
        output.push(255 & (bs >> ((-2 * bc) & 6)));
      }
    }
    return new Uint8Array(output);
  }
  function bytesToBase64(buf) {
    var bytes = Array.from(buf || []);
    var result = '';
    for (var i = 0; i < bytes.length; i += 3) {
      var b0 = bytes[i];
      var b1 = i + 1 < bytes.length ? bytes[i + 1] : 0;
      var b2 = i + 2 < bytes.length ? bytes[i + 2] : 0;
      var triplet = (b0 << 16) | (b1 << 8) | b2;
      result += BASE64_CHARS[(triplet >> 18) & 63];
      result += BASE64_CHARS[(triplet >> 12) & 63];
      result += i + 1 < bytes.length ? BASE64_CHARS[(triplet >> 6) & 63] : '=';
      result += i + 2 < bytes.length ? BASE64_CHARS[triplet & 63] : '=';
    }
    return result;
  }
  globalThis.atob = globalThis.atob || function(input) {
    return bytesToString(Array.from(base64ToBytes(input)));
  };
  globalThis.btoa = globalThis.btoa || function(input) {
    return bytesToBase64(stringToBytes(String(input)));
  };

  function normalizeBufferInput(input, encoding) {
    if (typeof input === 'string') {
      switch (encoding) {
        case 'binary':
          throw new Error('Binary encoding is not supported for input strings');
        case 'base64':
          return new Uint8Array(base64ToBytes(input));
        case 'hex':
          return new Uint8Array((input.match(/.{1,2}/g) || []).map(function(byte) {
            return parseInt(byte, 16);
          }));
        case 'utf8':
        case 'utf-8':
        case undefined:
        case null:
          return new Uint8Array(stringToBytes(input));
        default:
          throw new Error('Unsupported encoding: ' + String(encoding));
      }
    }
    if (Array.isArray(input)) {
      return new Uint8Array(input);
    }
    if (input instanceof ArrayBuffer) {
      return new Uint8Array(input.slice(0));
    }
    if (ArrayBuffer.isView(input)) {
      return new Uint8Array(input.buffer.slice(input.byteOffset, input.byteOffset + input.byteLength));
    }
    throw new Error('Unsupported input type: ' + String(input));
  }

  function decorateBuffer(bytes) {
    var buf = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes || []);
    if (buf.__lx_is_buffer__ === true) {
      return buf;
    }
    Object.defineProperty(buf, '__lx_is_buffer__', {
      enumerable: false,
      configurable: false,
      writable: false,
      value: true
    });
    Object.defineProperty(buf, 'toString', {
      enumerable: false,
      configurable: true,
      writable: true,
      value: function(encoding) {
        return utils.buffer.bufToString(this, encoding);
      }
    });
    Object.defineProperty(buf, 'slice', {
      enumerable: false,
      configurable: true,
      writable: true,
      value: function(start, end) {
        return decorateBuffer(Uint8Array.prototype.slice.call(this, start, end));
      }
    });
    Object.defineProperty(buf, 'subarray', {
      enumerable: false,
      configurable: true,
      writable: true,
      value: function(start, end) {
        return decorateBuffer(Uint8Array.prototype.subarray.call(this, start, end));
      }
    });
    return buf;
  }

  function toUint8Array(input, encoding) {
    return normalizeBufferInput(input, encoding);
  }

  function copyBytes(input, encoding) {
    return new Uint8Array(toUint8Array(input, encoding));
  }

  var AES_BLOCK_SIZE = 16;
  var AES_SBOX = new Uint8Array(256);
  var AES_RCON = new Uint8Array([0, 1, 2, 4, 8, 16, 32, 64, 128, 27, 54]);

  function rotl8(value, bits) {
    return ((value << bits) | (value >> (8 - bits))) & 255;
  }

  function gfMul(a, b) {
    var left = a & 255;
    var right = b & 255;
    var result = 0;
    while (right > 0) {
      if ((right & 1) !== 0) {
        result ^= left;
      }
      left <<= 1;
      if ((left & 256) !== 0) {
        left ^= 0x11b;
      }
      right >>= 1;
    }
    return result & 255;
  }

  function gfPow(base, power) {
    var result = 1;
    var current = base & 255;
    var exponent = power >>> 0;
    while (exponent > 0) {
      if ((exponent & 1) !== 0) {
        result = gfMul(result, current);
      }
      current = gfMul(current, current);
      exponent >>>= 1;
    }
    return result & 255;
  }

  function gfInv(value) {
    return value === 0 ? 0 : gfPow(value, 254);
  }

  (function initializeAesTables() {
    for (var i = 0; i < 256; i++) {
      var inv = gfInv(i);
      AES_SBOX[i] = inv ^ rotl8(inv, 1) ^ rotl8(inv, 2) ^ rotl8(inv, 3) ^ rotl8(inv, 4) ^ 0x63;
    }
  })();

  function normalizeAesKey(key) {
    var keyBytes = copyBytes(key);
    if (keyBytes.length !== AES_BLOCK_SIZE) {
      throw new Error('AES-128 key length must be 16 bytes');
    }
    return keyBytes;
  }

  function normalizeAesIv(iv) {
    var rawIv = copyBytes(iv == null ? [] : iv);
    var normalized = new Uint8Array(AES_BLOCK_SIZE);
    var len = Math.min(rawIv.length, AES_BLOCK_SIZE);
    for (var i = 0; i < len; i++) {
      normalized[i] = rawIv[i];
    }
    return normalized;
  }

  function expandAes128Key(keyBytes) {
    var expanded = new Uint8Array(176);
    for (var i = 0; i < AES_BLOCK_SIZE; i++) {
      expanded[i] = keyBytes[i];
    }
    var bytesGenerated = AES_BLOCK_SIZE;
    var rconIndex = 1;
    var temp = new Uint8Array(4);
    while (bytesGenerated < expanded.length) {
      for (var j = 0; j < 4; j++) {
        temp[j] = expanded[bytesGenerated - 4 + j];
      }
      if ((bytesGenerated % AES_BLOCK_SIZE) === 0) {
        var first = temp[0];
        temp[0] = AES_SBOX[temp[1]] ^ AES_RCON[rconIndex];
        temp[1] = AES_SBOX[temp[2]];
        temp[2] = AES_SBOX[temp[3]];
        temp[3] = AES_SBOX[first];
        rconIndex += 1;
      }
      for (var k = 0; k < 4; k++) {
        expanded[bytesGenerated] = expanded[bytesGenerated - AES_BLOCK_SIZE] ^ temp[k];
        bytesGenerated += 1;
      }
    }
    return expanded;
  }

  function addRoundKey(state, expandedKey, round) {
    var offset = round * AES_BLOCK_SIZE;
    for (var i = 0; i < AES_BLOCK_SIZE; i++) {
      state[i] ^= expandedKey[offset + i];
    }
  }

  function subBytes(state) {
    for (var i = 0; i < AES_BLOCK_SIZE; i++) {
      state[i] = AES_SBOX[state[i]];
    }
  }

  function shiftRows(state) {
    var copy = new Uint8Array(state);
    state[1] = copy[5];
    state[5] = copy[9];
    state[9] = copy[13];
    state[13] = copy[1];

    state[2] = copy[10];
    state[6] = copy[14];
    state[10] = copy[2];
    state[14] = copy[6];

    state[3] = copy[15];
    state[7] = copy[3];
    state[11] = copy[7];
    state[15] = copy[11];
  }

  function mixColumns(state) {
    for (var column = 0; column < 4; column++) {
      var offset = column * 4;
      var a0 = state[offset];
      var a1 = state[offset + 1];
      var a2 = state[offset + 2];
      var a3 = state[offset + 3];
      state[offset] = gfMul(a0, 2) ^ gfMul(a1, 3) ^ a2 ^ a3;
      state[offset + 1] = a0 ^ gfMul(a1, 2) ^ gfMul(a2, 3) ^ a3;
      state[offset + 2] = a0 ^ a1 ^ gfMul(a2, 2) ^ gfMul(a3, 3);
      state[offset + 3] = gfMul(a0, 3) ^ a1 ^ a2 ^ gfMul(a3, 2);
    }
  }

  function encryptAesBlock(block, expandedKey) {
    var state = new Uint8Array(block);
    addRoundKey(state, expandedKey, 0);
    for (var round = 1; round < 10; round++) {
      subBytes(state);
      shiftRows(state);
      mixColumns(state);
      addRoundKey(state, expandedKey, round);
    }
    subBytes(state);
    shiftRows(state);
    addRoundKey(state, expandedKey, 10);
    return state;
  }

  function pkcs7Pad(bytes, blockSize) {
    var remainder = bytes.length % blockSize;
    var padValue = remainder === 0 ? blockSize : (blockSize - remainder);
    var output = new Uint8Array(bytes.length + padValue);
    output.set(bytes, 0);
    for (var i = bytes.length; i < output.length; i++) {
      output[i] = padValue;
    }
    return output;
  }

  function aesEncryptCbc(data, key, iv) {
    var expandedKey = expandAes128Key(normalizeAesKey(key));
    var input = pkcs7Pad(copyBytes(data), AES_BLOCK_SIZE);
    var previous = normalizeAesIv(iv);
    var output = new Uint8Array(input.length);
    for (var offset = 0; offset < input.length; offset += AES_BLOCK_SIZE) {
      var block = input.slice(offset, offset + AES_BLOCK_SIZE);
      for (var i = 0; i < AES_BLOCK_SIZE; i++) {
        block[i] ^= previous[i];
      }
      var encrypted = encryptAesBlock(block, expandedKey);
      output.set(encrypted, offset);
      previous = encrypted;
    }
    return decorateBuffer(output);
  }

  function aesEncryptEcb(data, key) {
    var expandedKey = expandAes128Key(normalizeAesKey(key));
    var input = pkcs7Pad(copyBytes(data), AES_BLOCK_SIZE);
    var output = new Uint8Array(input.length);
    for (var offset = 0; offset < input.length; offset += AES_BLOCK_SIZE) {
      output.set(encryptAesBlock(input.slice(offset, offset + AES_BLOCK_SIZE), expandedKey), offset);
    }
    return decorateBuffer(output);
  }

  function bytesToBigInt(bytes) {
    var value = 0n;
    for (var i = 0; i < bytes.length; i++) {
      value = (value << 8n) | BigInt(bytes[i]);
    }
    return value;
  }

  function bigIntToBytes(value, length) {
    var bytes = [];
    var current = value;
    if (current === 0n) {
      bytes.push(0);
    } else {
      while (current > 0n) {
        bytes.push(Number(current & 255n));
        current >>= 8n;
      }
      bytes.reverse();
    }
    var size = typeof length === 'number' && length > 0 ? length : bytes.length;
    if (bytes.length > size) {
      bytes = bytes.slice(bytes.length - size);
    }
    var output = new Uint8Array(size);
    var offset = size - bytes.length;
    for (var i = 0; i < bytes.length; i++) {
      output[offset + i] = bytes[i];
    }
    return output;
  }

  function modPow(base, exponent, modulus) {
    var result = 1n;
    var factor = base % modulus;
    var power = exponent;
    while (power > 0n) {
      if ((power & 1n) === 1n) {
        result = (result * factor) % modulus;
      }
      power >>= 1n;
      factor = (factor * factor) % modulus;
    }
    return result;
  }

  function readDerLength(bytes, state) {
    if (state.offset >= bytes.length) {
      throw new Error('Invalid DER length');
    }
    var first = bytes[state.offset++];
    if ((first & 128) === 0) {
      return first;
    }
    var count = first & 127;
    if (count <= 0 || count > 4 || state.offset + count > bytes.length) {
      throw new Error('Invalid DER length');
    }
    var length = 0;
    for (var i = 0; i < count; i++) {
      length = (length << 8) | bytes[state.offset++];
    }
    return length;
  }

  function readDerElement(bytes, state, expectedTag) {
    if (state.offset >= bytes.length) {
      throw new Error('Unexpected end of DER input');
    }
    var tag = bytes[state.offset++];
    if (typeof expectedTag === 'number' && tag !== expectedTag) {
      throw new Error('Unexpected DER tag: ' + tag);
    }
    var length = readDerLength(bytes, state);
    var start = state.offset;
    var end = start + length;
    if (end > bytes.length) {
      throw new Error('Invalid DER element length');
    }
    state.offset = end;
    return {
      tag: tag,
      start: start,
      end: end
    };
  }

  function readDerInteger(bytes, state) {
    var integerElement = readDerElement(bytes, state, 0x02);
    var value = bytes.slice(integerElement.start, integerElement.end);
    while (value.length > 1 && value[0] === 0) {
      value = value.slice(1);
    }
    return value;
  }

  var rsaPublicKeyCache = new Map();
  function parseRsaPublicKey(key) {
    var cleaned = String(key || '')
      .replace(KEY_PREFIX.publicKeyStart, '')
      .replace(KEY_PREFIX.publicKeyEnd, '')
      .replace(/\s+/g, '');
    if (cleaned.length === 0) {
      throw new Error('Invalid RSA key');
    }
    if (rsaPublicKeyCache.has(cleaned)) {
      return rsaPublicKeyCache.get(cleaned);
    }

    var der = base64ToBytes(cleaned);
    var rootState = { offset: 0 };
    var root = readDerElement(der, rootState, 0x30);
    var rootBytes = der.slice(root.start, root.end);
    var spkiState = { offset: 0 };
    readDerElement(rootBytes, spkiState, 0x30);
    var bitString = readDerElement(rootBytes, spkiState, 0x03);
    var bitStringBytes = rootBytes.slice(bitString.start, bitString.end);
    if (bitStringBytes.length === 0 || bitStringBytes[0] !== 0) {
      throw new Error('Invalid RSA public key');
    }

    var rsaBytes = bitStringBytes.slice(1);
    var rsaRootState = { offset: 0 };
    var rsaRoot = readDerElement(rsaBytes, rsaRootState, 0x30);
    var rsaContent = rsaBytes.slice(rsaRoot.start, rsaRoot.end);
    var rsaContentState = { offset: 0 };
    var modulusBytes = readDerInteger(rsaContent, rsaContentState);
    var exponentBytes = readDerInteger(rsaContent, rsaContentState);
    var parsed = {
      modulus: bytesToBigInt(modulusBytes),
      exponent: bytesToBigInt(exponentBytes),
      length: modulusBytes.length
    };
    rsaPublicKeyCache.set(cleaned, parsed);
    return parsed;
  }

  function rsaEncryptNoPadding(data, key) {
    var input = copyBytes(data);
    var parsedKey = parseRsaPublicKey(key);
    if (input.length > parsedKey.length) {
      throw new Error('RSA input is too long');
    }
    var message = bytesToBigInt(input);
    if (message >= parsedKey.modulus) {
      throw new Error('RSA input is out of range');
    }
    var encrypted = modPow(message, parsedKey.exponent, parsedKey.modulus);
    return decorateBuffer(bigIntToBytes(encrypted, parsedKey.length));
  }

  var _md5 = function() {
    function h(a, b) {
      var c;
      var d;
      var e;
      var f;
      var g;
      e = a & 2147483648;
      f = b & 2147483648;
      c = a & 1073741824;
      d = b & 1073741824;
      g = (a & 1073741823) + (b & 1073741823);
      if (c & d) return g ^ 2147483648 ^ e ^ f;
      if (c | d) {
        if (g & 1073741824) return g ^ 3221225472 ^ e ^ f;
        return g ^ 1073741824 ^ e ^ f;
      }
      return g ^ e ^ f;
    }
    function k(a, b, c, d, e, f, g) {
      a = h(a, h(h(b & c | ~b & d, e), g));
      return h(a << f | a >>> 32 - f, b);
    }
    function l(a, b, c, d, e, f, g) {
      a = h(a, h(h(b & d | c & ~d, e), g));
      return h(a << f | a >>> 32 - f, b);
    }
    function m(a, b, c, d, e, f, g) {
      a = h(a, h(h(b ^ c ^ d, e), g));
      return h(a << f | a >>> 32 - f, b);
    }
    function n(a, b, c, d, e, f, g) {
      a = h(a, h(h(c ^ (b | ~d), e), g));
      return h(a << f | a >>> 32 - f, b);
    }
    function o(a) {
      var b = '';
      var c = '';
      var d;
      for (d = 0; d <= 3; d++) {
        c = a >>> d * 8 & 255;
        c = '0' + c.toString(16);
        b = b + c.substr(c.length - 2, 2);
      }
      return b;
    }
    return function(p) {
      var a;
      var b;
      var c;
      var d;
      var q;
      var r;
      var s;
      var t;
      var u;
      var x = [];
      p = function(input) {
        input = input.replace(/\r\n/g, '\n');
        var output = '';
        for (var i = 0; i < input.length; i++) {
          var ch = input.charCodeAt(i);
          if (ch < 128) output += String.fromCharCode(ch);
          else if (ch > 127 && ch < 2048) {
            output += String.fromCharCode(ch >> 6 | 192);
            output += String.fromCharCode(ch & 63 | 128);
          } else {
            output += String.fromCharCode(ch >> 12 | 224);
            output += String.fromCharCode(ch >> 6 & 63 | 128);
            output += String.fromCharCode(ch & 63 | 128);
          }
        }
        return output;
      }(p);
      x = function(input) {
        var wordCount;
        var length = input.length;
        var totalLength = length + 8;
        var blocks = (totalLength - totalLength % 64) / 64;
        var arrayLength = 16 * (blocks + 1);
        var words = [];
        for (wordCount = 0; wordCount < arrayLength; wordCount++) {
          words[wordCount] = 0;
        }
        for (wordCount = 0; wordCount < length; wordCount++) {
          words[(wordCount - wordCount % 4) / 4] |= input.charCodeAt(wordCount) << wordCount % 4 * 8;
        }
        words[(wordCount - wordCount % 4) / 4] |= 128 << wordCount % 4 * 8;
        words[arrayLength - 2] = length << 3;
        words[arrayLength - 1] = length >>> 29;
        return words;
      }(p);
      a = 1732584193;
      b = 4023233417;
      c = 2562383102;
      d = 271733878;
      for (u = 0; u < x.length; u += 16) {
        q = a;
        r = b;
        s = c;
        t = d;
        a = k(a, b, c, d, x[u + 0], 7, 3614090360);
        d = k(d, a, b, c, x[u + 1], 12, 3905402710);
        c = k(c, d, a, b, x[u + 2], 17, 606105819);
        b = k(b, c, d, a, x[u + 3], 22, 3250441966);
        a = k(a, b, c, d, x[u + 4], 7, 4118548399);
        d = k(d, a, b, c, x[u + 5], 12, 1200080426);
        c = k(c, d, a, b, x[u + 6], 17, 2821735955);
        b = k(b, c, d, a, x[u + 7], 22, 4249261313);
        a = k(a, b, c, d, x[u + 8], 7, 1770035416);
        d = k(d, a, b, c, x[u + 9], 12, 2336552879);
        c = k(c, d, a, b, x[u + 10], 17, 4294925233);
        b = k(b, c, d, a, x[u + 11], 22, 2304563134);
        a = k(a, b, c, d, x[u + 12], 7, 1804603682);
        d = k(d, a, b, c, x[u + 13], 12, 4254626195);
        c = k(c, d, a, b, x[u + 14], 17, 2792965006);
        b = k(b, c, d, a, x[u + 15], 22, 1236535329);
        a = l(a, b, c, d, x[u + 1], 5, 4129170786);
        d = l(d, a, b, c, x[u + 6], 9, 3225465664);
        c = l(c, d, a, b, x[u + 11], 14, 643717713);
        b = l(b, c, d, a, x[u + 0], 20, 3921069994);
        a = l(a, b, c, d, x[u + 5], 5, 3593408605);
        d = l(d, a, b, c, x[u + 10], 9, 38016083);
        c = l(c, d, a, b, x[u + 15], 14, 3634488961);
        b = l(b, c, d, a, x[u + 4], 20, 3889429448);
        a = l(a, b, c, d, x[u + 9], 5, 568446438);
        d = l(d, a, b, c, x[u + 14], 9, 3275163606);
        c = l(c, d, a, b, x[u + 3], 14, 4107603335);
        b = l(b, c, d, a, x[u + 8], 20, 1163531501);
        a = l(a, b, c, d, x[u + 13], 5, 2850285829);
        d = l(d, a, b, c, x[u + 2], 9, 4243563512);
        c = l(c, d, a, b, x[u + 7], 14, 1735328473);
        b = l(b, c, d, a, x[u + 12], 20, 2368359562);
        a = m(a, b, c, d, x[u + 5], 4, 4294588738);
        d = m(d, a, b, c, x[u + 8], 11, 2272392833);
        c = m(c, d, a, b, x[u + 11], 16, 1839030562);
        b = m(b, c, d, a, x[u + 14], 23, 4259657740);
        a = m(a, b, c, d, x[u + 1], 4, 2763975236);
        d = m(d, a, b, c, x[u + 4], 11, 1272893353);
        c = m(c, d, a, b, x[u + 7], 16, 4139469664);
        b = m(b, c, d, a, x[u + 10], 23, 3200236656);
        a = m(a, b, c, d, x[u + 13], 4, 681279174);
        d = m(d, a, b, c, x[u + 0], 11, 3936430074);
        c = m(c, d, a, b, x[u + 3], 16, 3572445317);
        b = m(b, c, d, a, x[u + 6], 23, 76029189);
        a = m(a, b, c, d, x[u + 9], 4, 3654602809);
        d = m(d, a, b, c, x[u + 12], 11, 3873151461);
        c = m(c, d, a, b, x[u + 15], 16, 530742520);
        b = m(b, c, d, a, x[u + 2], 23, 3299628645);
        a = n(a, b, c, d, x[u + 0], 6, 4096336452);
        d = n(d, a, b, c, x[u + 7], 10, 1126891415);
        c = n(c, d, a, b, x[u + 14], 15, 2878612391);
        b = n(b, c, d, a, x[u + 5], 21, 4237533241);
        a = n(a, b, c, d, x[u + 12], 6, 1700485571);
        d = n(d, a, b, c, x[u + 3], 10, 2399980690);
        c = n(c, d, a, b, x[u + 10], 15, 4293915773);
        b = n(b, c, d, a, x[u + 1], 21, 2240044497);
        a = n(a, b, c, d, x[u + 8], 6, 1873313359);
        d = n(d, a, b, c, x[u + 15], 10, 4264355552);
        c = n(c, d, a, b, x[u + 6], 15, 2734768916);
        b = n(b, c, d, a, x[u + 13], 21, 1309151649);
        a = n(a, b, c, d, x[u + 4], 6, 4149444226);
        d = n(d, a, b, c, x[u + 11], 10, 3174756917);
        c = n(c, d, a, b, x[u + 2], 15, 718787259);
        b = n(b, c, d, a, x[u + 9], 21, 3951481745);
        a = h(a, q);
        b = h(b, r);
        c = h(c, s);
        d = h(d, t);
      }
      return (o(a) + o(b) + o(c) + o(d)).toLowerCase();
    };
  }();

  var callbacks = new Map();
  var intervals = new Map();
  var timeoutId = 0;
  globalThis.setTimeout = function(callback, timeout) {
    if (typeof callback !== 'function') {
      throw new Error('callback required a function');
    }
    var params = Array.prototype.slice.call(arguments, 2);
    var id = timeoutId++;
    callbacks.set(id, {
      callback: callback,
      params: params
    });
    __quickjs_set_timeout__(engineKey, id, parseInt(timeout || 0, 10));
    return id;
  };
  globalThis.clearTimeout = function(id) {
    callbacks.delete(id);
  };
  globalThis.setInterval = function(callback, timeout) {
    if (typeof callback !== 'function') {
      throw new Error('callback required a function');
    }
    var params = Array.prototype.slice.call(arguments, 2);
    var intervalMs = parseInt(timeout || 0, 10);
    var id = timeoutId++;
    var scheduleNext = function() {
      if (!intervals.has(id)) {
        return;
      }
      var timerId = globalThis.setTimeout(function() {
        var target = intervals.get(id);
        if (!target) {
          return;
        }
        try {
          target.callback.apply(null, target.params);
        } catch (_) {}
        scheduleNext();
      }, intervalMs);
      intervals.set(id, {
        callback: callback,
        params: params,
        timerId: timerId
      });
    };
    intervals.set(id, {
      callback: callback,
      params: params,
      timerId: -1
    });
    scheduleNext();
    return id;
  };
  globalThis.clearInterval = function(id) {
    var intervalInfo = intervals.get(id);
    if (!intervalInfo) {
      return;
    }
    intervals.delete(id);
    if (intervalInfo.timerId >= 0) {
      globalThis.clearTimeout(intervalInfo.timerId);
    }
  };
  var handleSetTimeout = function(id) {
    var target = callbacks.get(id);
    if (!target) {
      return;
    }
    callbacks.delete(id);
    target.callback.apply(null, target.params);
  };

  var requestQueue = new Map();
  var isInitedApi = false;
  var isShowedUpdateAlert = false;

  var sendNativeRequest = function(url, options, callback) {
    var requestKey = 'request__' + Math.random().toString(36).slice(2) + '_' + Date.now();
    var requestInfo = {
      aborted: false,
      abort: function() {
        requestInfo.aborted = true;
        nativeCall('cancelRequest', requestKey);
      }
    };
    requestQueue.set(requestKey, {
      url: url,
      options: options,
      callback: callback,
      requestInfo: requestInfo
    });
    nativeCall('request', {
      requestKey: requestKey,
      url: url,
      options: options
    });
    return requestInfo;
  };

  var handleNativeResponse = function(responseData) {
    var targetRequest = requestQueue.get(responseData.requestKey);
    if (!targetRequest) {
      return;
    }
    requestQueue.delete(responseData.requestKey);
    targetRequest.requestInfo.aborted = true;
    try {
      if (responseData.error == null || responseData.error === '') {
        targetRequest.callback(null, responseData.response);
      } else {
        targetRequest.callback(new Error(responseData.error), null);
      }
    } catch (error) {
      var responseBodyPreview = '';
      if (responseData.response && responseData.response.body != null) {
        try {
          if (typeof responseData.response.body === 'string') {
            responseBodyPreview = responseData.response.body;
          } else {
            responseBodyPreview = JSON.stringify(responseData.response.body);
          }
        } catch (_) {
          responseBodyPreview = String(responseData.response.body);
        }
      }
      if (responseBodyPreview.length > 256) {
        responseBodyPreview = responseBodyPreview.substring(0, 256) + '...';
      }
      var statusCode = responseData.response && responseData.response.statusCode != null ? String(responseData.response.statusCode) : 'unknown';
      var errorMessage = error && error.message ? error.message : String(error);
      throw new Error(errorMessage + ' [requestUrl=' + String(targetRequest.url || '') + ', statusCode=' + statusCode + ', bodyPreview=' + responseBodyPreview + ']');
    }
  };

  var verifyLyricInfo = function(info) {
    if (typeof info !== 'object' || info == null || typeof info.lyric !== 'string') {
      throw new Error('failed');
    }
    if (info.lyric.length > 51200) {
      throw new Error('failed');
    }
    return {
      lyric: info.lyric,
      tlyric: typeof info.tlyric === 'string' && info.tlyric.length < 5120 ? info.tlyric : null,
      rlyric: typeof info.rlyric === 'string' && info.rlyric.length < 5120 ? info.rlyric : null,
      lxlyric: typeof info.lxlyric === 'string' && info.lxlyric.length < 8192 ? info.lxlyric : null
    };
  };

  var handleRequest = function(requestInfo) {
    if (!events.request) {
      nativeCall('response', {
        requestKey: requestInfo.requestKey,
        status: false,
        errorMessage: 'Request event is not defined'
      });
      return;
    }
    try {
      events.request.call(globalThis.lx, {
        source: requestInfo.data.source,
        action: requestInfo.data.action,
        info: requestInfo.data.info
      }).then(function(response) {
        var result;
        switch (requestInfo.data.action) {
          case 'musicUrl':
            if (typeof response !== 'string' || response.length > 2048 || !/^https?:/.test(response)) {
              throw new Error('failed');
            }
            result = {
              source: requestInfo.data.source,
              action: requestInfo.data.action,
              data: {
                type: requestInfo.data.info.type,
                url: response
              }
            };
            break;
          case 'lyric':
            result = {
              source: requestInfo.data.source,
              action: requestInfo.data.action,
              data: verifyLyricInfo(response)
            };
            break;
          case 'pic':
            if (typeof response !== 'string' || response.length > 2048 || !/^https?:/.test(response)) {
              throw new Error('failed');
            }
            result = {
              source: requestInfo.data.source,
              action: requestInfo.data.action,
              data: response
            };
            break;
          default:
            throw new Error('Unsupported action: ' + requestInfo.data.action);
        }
        nativeCall('response', {
          requestKey: requestInfo.requestKey,
          status: true,
          result: result
        });
      }).catch(function(error) {
        nativeCall('response', {
          requestKey: requestInfo.requestKey,
          status: false,
          errorMessage: error && error.message ? error.message : 'request failed'
        });
      });
    } catch (error) {
      nativeCall('response', {
        requestKey: requestInfo.requestKey,
        status: false,
        errorMessage: error && error.message ? error.message : 'request failed'
      });
    }
  };

  var handleInit = function(info) {
    if (!info || typeof info !== 'object' || !info.sources) {
      nativeCall('init', {
        info: null,
        status: false,
        errorMessage: 'Missing required parameter init info'
      });
      return;
    }

    var sourceInfo = {
      sources: {}
    };
    try {
      for (var i = 0; i < allSources.length; i++) {
        var source = allSources[i];
        var userSource = info.sources[source];
        if (!userSource || userSource.type !== 'music') {
          continue;
        }
        var sourceActions = Array.isArray(userSource.actions) ? userSource.actions : [];
        var sourceQualityList = Array.isArray(userSource.qualitys) ? userSource.qualitys : [];
        sourceInfo.sources[source] = {
          type: 'music',
          actions: (supportActions[source] || ['musicUrl']).filter(function(action) {
            return sourceActions.indexOf(action) >= 0;
          }),
          qualitys: (supportQualitys[source] || []).filter(function(quality) {
            return sourceQualityList.indexOf(quality) >= 0;
          })
        };
      }
    } catch (error) {
      nativeCall('init', {
        info: null,
        status: false,
        errorMessage: error && error.message ? error.message : 'init failed'
      });
      return;
    }

    nativeCall('init', {
      info: sourceInfo,
      status: true
    });
  };

  var handleShowUpdateAlert = function(data, resolve, reject) {
    if (!data || typeof data !== 'object') {
      reject(new Error('parameter format error.'));
      return;
    }
    if (!data.log || typeof data.log !== 'string') {
      reject(new Error('log is required.'));
      return;
    }
    var updateUrl = '';
    if (typeof data.updateUrl === 'string' && data.updateUrl.length <= 1024 && /^https?:\/\/[^\s]+$/.test(data.updateUrl)) {
      updateUrl = data.updateUrl;
    }
    var updateLog = data.log.length > 1024 ? data.log.substring(0, 1024) + '...' : data.log;
    nativeCall('showUpdateAlert', {
      name: scriptInfo && typeof scriptInfo.name === 'string' ? scriptInfo.name : '',
      log: updateLog,
      updateUrl: updateUrl
    });
    resolve();
  };

  var jsCall = function(action, data) {
    switch (action) {
      case '__run_error__':
        if (!isInitedApi) {
          isInitedApi = true;
        }
        return;
      case '__set_timeout__':
        handleSetTimeout(data);
        return;
      case 'request':
        handleRequest(data);
        return;
      case 'response':
        handleNativeResponse(data);
        return;
      case '__continue__':
        return;
      default:
        return 'Unknown action: ' + action;
    }
  };

  Object.defineProperty(globalThis, '__lx_native__', {
    enumerable: false,
    configurable: false,
    writable: false,
    value: function(key, action, data) {
      if (engineKey !== key) {
        return 'Invalid key';
      }
      return data == null ? jsCall(action) : jsCall(action, JSON.parse(data));
    }
  });

  var utils = {
    crypto: {
      aesEncrypt: function(buffer, mode, key, iv) {
        switch (mode) {
          case 'aes-128-cbc':
            return aesEncryptCbc(buffer, key, iv);
          case 'aes-128-ecb':
            return aesEncryptEcb(buffer, key);
          default:
            throw new Error('Unsupported AES mode: ' + String(mode));
        }
      },
      rsaEncrypt: function(buffer, key) {
        if (typeof key !== 'string') {
          throw new Error('Invalid RSA key');
        }
        return rsaEncryptNoPadding(buffer, key);
      },
      randomBytes: function(size) {
        var byteArray = new Uint8Array(size);
        for (var i = 0; i < size; i++) {
          byteArray[i] = Math.floor(Math.random() * 256);
        }
        return decorateBuffer(byteArray);
      },
      md5: function(str) {
        if (typeof str !== 'string') {
          throw new Error('param required a string');
        }
        return _md5(str);
      }
    },
    buffer: {
      from: function(input, encoding) {
        return decorateBuffer(normalizeBufferInput(input, encoding));
      },
      alloc: function(size, fill) {
        var length = Math.max(0, Number(size) || 0);
        var output = new Uint8Array(length);
        if (fill !== undefined) {
          if (typeof fill === 'number') {
            output.fill(fill & 255);
          } else {
            var fillBytes = normalizeBufferInput(fill);
            if (fillBytes.length > 0) {
              for (var i = 0; i < output.length; i++) {
                output[i] = fillBytes[i % fillBytes.length];
              }
            }
          }
        }
        return decorateBuffer(output);
      },
      concat: function(list, totalLength) {
        if (!Array.isArray(list)) {
          throw new Error('Buffer.concat requires an array');
        }
        var length = typeof totalLength === 'number' ? totalLength : 0;
        if (length <= 0) {
          for (var i = 0; i < list.length; i++) {
            length += normalizeBufferInput(list[i]).length;
          }
        }
        var output = new Uint8Array(length);
        var offset = 0;
        for (var index = 0; index < list.length; index++) {
          var chunk = normalizeBufferInput(list[index]);
          output.set(chunk, offset);
          offset += chunk.length;
        }
        return decorateBuffer(output);
      },
      bufToString: function(buf, format) {
        if (!Array.isArray(buf) && !ArrayBuffer.isView(buf)) {
          throw new Error('Input is not a valid buffer');
        }
        var bytes = Array.isArray(buf) ? new Uint8Array(buf) : new Uint8Array(buf.buffer, buf.byteOffset, buf.byteLength);
        switch (format) {
          case 'binary':
            return decorateBuffer(bytes);
          case 'hex':
            return bytes.reduce(function(str, byte) {
              return str + byte.toString(16).padStart(2, '0');
            }, '');
          case 'base64':
            return bytesToBase64(bytes);
          case 'utf8':
          case 'utf-8':
            return bytesToString(Array.from(bytes));
          default:
            return bytesToString(Array.from(bytes));
        }
      }
    }
  };

  globalThis.lx = {
    EVENT_NAMES: EVENT_NAMES,
    request: function(url, options, callback) {
      var requestOptions = {
        method: options && options.method ? options.method : 'get',
        headers: options && options.headers ? options.headers : {},
        binary: options && options.binary === true
      };
      var method = String(requestOptions.method || 'get').toLowerCase();
      if (options && typeof options.timeout === 'number' && options.timeout > 0) {
        requestOptions.timeout = Math.min(options.timeout, 60000);
      }
      if (options && options.body != null) {
        if (typeof options.body === 'object' && options.body !== null) {
          if (!requestOptions.headers['Content-Type'] && !requestOptions.headers['content-type']) {
            requestOptions.headers['Content-Type'] = 'application/json';
          }
          requestOptions.body = JSON.stringify(options.body);
        } else {
          requestOptions.body = options.body;
        }
      } else if (options && options.form != null) {
        requestOptions.form = options.form;
        if (method === 'post' && !requestOptions.headers['Content-Type'] && !requestOptions.headers['content-type']) {
          requestOptions.headers['Content-Type'] = 'application/x-www-form-urlencoded';
        }
      } else if (options && options.formData != null) {
        requestOptions.formData = options.formData;
        if (method === 'post' && !requestOptions.headers['Content-Type'] && !requestOptions.headers['content-type']) {
          requestOptions.headers['Content-Type'] = 'application/x-www-form-urlencoded';
        }
      }

      var request = sendNativeRequest(url, requestOptions, function(error, response) {
        if (error) {
          callback(error, null, null);
        } else {
          callback(null, {
            statusCode: response.statusCode,
            statusMessage: response.statusMessage,
            headers: response.headers,
            body: response.body
          }, response.body);
        }
      });

      return function() {
        if (request && !request.aborted) {
          request.abort();
        }
        request = null;
      };
    },
    send: function(eventName, data) {
      return new Promise(function(resolve, reject) {
        switch (eventName) {
          case EVENT_NAMES.inited:
            if (isInitedApi) {
              reject(new Error('Script is inited'));
              return;
            }
            isInitedApi = true;
            handleInit(data);
            resolve();
            return;
          case EVENT_NAMES.updateAlert:
            if (isShowedUpdateAlert) {
              reject(new Error('The update alert can only be called once.'));
              return;
            }
            isShowedUpdateAlert = true;
            handleShowUpdateAlert(data, resolve, reject);
            return;
          default:
            reject(new Error('The event is not supported: ' + eventName));
        }
      });
    },
    on: function(eventName, handler) {
      if (eventName !== EVENT_NAMES.request) {
        return Promise.reject(new Error('The event is not supported: ' + eventName));
      }
      events.request = handler;
      return Promise.resolve();
    },
    utils: utils,
    version: '2.0.0',
    env: 'mobile',
    currentScriptInfo: {
      name: scriptInfo && typeof scriptInfo.name === 'string' ? scriptInfo.name : '',
      description: scriptInfo && typeof scriptInfo.description === 'string' ? scriptInfo.description : '',
      version: scriptInfo && typeof scriptInfo.version === 'string' ? scriptInfo.version : '',
      author: scriptInfo && typeof scriptInfo.author === 'string' ? scriptInfo.author : '',
      homepage: scriptInfo && typeof scriptInfo.homepage === 'string' ? scriptInfo.homepage : '',
      rawScript: scriptInfo && typeof scriptInfo.rawScript === 'string' ? scriptInfo.rawScript : ''
    }
  };

  globalThis.Buffer = globalThis.Buffer || {
    from: function(input, encoding) {
      return utils.buffer.from(input, encoding);
    },
    alloc: function(size, fill) {
      return utils.buffer.alloc(size, fill);
    },
    concat: function(list, totalLength) {
      return utils.buffer.concat(list, totalLength);
    },
    isBuffer: function(value) {
      return value instanceof Uint8Array || ArrayBuffer.isView(value);
    }
  };

  try {
    var protectedNames = ['lx', '__lx_native__', '__quickjs_bridge__', '__quickjs_set_timeout__'];
    for (var protectedIndex = 0; protectedIndex < protectedNames.length; protectedIndex++) {
      var protectedName = protectedNames[protectedIndex];
      if (!(protectedName in globalThis)) {
        continue;
      }
      Object.defineProperty(globalThis, protectedName, {
        configurable: false,
        writable: false,
        value: globalThis[protectedName]
      });
    }
  } catch (_) {}

  try {
    var OriginalFunction = Function;
    if (typeof Proxy === 'function') {
      globalThis.Function = new Proxy(OriginalFunction, {
        construct: function() {
          throw new Error('Function constructor is disabled');
        },
        apply: function() {
          throw new Error('Function constructor is disabled');
        }
      });
    }
  } catch (_) {}

  globalThis.eval = undefined;
};`;
