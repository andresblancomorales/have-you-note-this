"""ChaCha20-Poly1305 (RFC 8439) in pure Python.

The note store needs authenticated encryption and Arch ships no AEAD-capable
CLI: `openssl enc` refuses AEAD ciphers, python3 has no cipher in its stdlib,
and pulling `python-cryptography` in would make the plugin fail to load on a
machine that lacks it. ChaCha20-Poly1305 is small enough to carry ourselves --
ARX rounds and modular arithmetic, no tables, no timing-sensitive S-boxes --
and `tests/test_crypto.py` checks this against the RFC's own vectors.

Note bodies are a few kilobytes at most, so pure-Python speed is a non-issue.
"""

import hmac
import os
import struct

_MASK = 0xFFFFFFFF


def _rotl(v, n):
    return ((v << n) | (v >> (32 - n))) & _MASK


def _quarter_round(s, a, b, c, d):
    s[a] = (s[a] + s[b]) & _MASK; s[d] = _rotl(s[d] ^ s[a], 16)
    s[c] = (s[c] + s[d]) & _MASK; s[b] = _rotl(s[b] ^ s[c], 12)
    s[a] = (s[a] + s[b]) & _MASK; s[d] = _rotl(s[d] ^ s[a], 8)
    s[c] = (s[c] + s[d]) & _MASK; s[b] = _rotl(s[b] ^ s[c], 7)


def chacha20_block(key, counter, nonce):
    """One 64-byte keystream block. key: 32 bytes, nonce: 12 bytes."""
    state = [0x61707865, 0x3320646E, 0x79622D32, 0x6B206574]
    state += list(struct.unpack("<8I", key))
    state.append(counter & _MASK)
    state += list(struct.unpack("<3I", nonce))

    work = state[:]
    for _ in range(10):  # 20 rounds = 10 column+diagonal double rounds
        _quarter_round(work, 0, 4, 8, 12)
        _quarter_round(work, 1, 5, 9, 13)
        _quarter_round(work, 2, 6, 10, 14)
        _quarter_round(work, 3, 7, 11, 15)
        _quarter_round(work, 0, 5, 10, 15)
        _quarter_round(work, 1, 6, 11, 12)
        _quarter_round(work, 2, 7, 8, 13)
        _quarter_round(work, 3, 4, 9, 14)
    return struct.pack("<16I", *[(work[i] + state[i]) & _MASK for i in range(16)])


def chacha20(key, counter, nonce, data):
    out = bytearray(len(data))
    for offset in range(0, len(data), 64):
        stream = chacha20_block(key, counter + offset // 64, nonce)
        chunk = data[offset:offset + 64]
        for i, byte in enumerate(chunk):
            out[offset + i] = byte ^ stream[i]
    return bytes(out)


_P = (1 << 130) - 5


def poly1305(key, msg):
    r = int.from_bytes(key[:16], "little") & 0x0FFFFFFC0FFFFFFC0FFFFFFC0FFFFFFF
    s = int.from_bytes(key[16:32], "little")
    acc = 0
    for offset in range(0, len(msg), 16):
        block = msg[offset:offset + 16]
        acc = (acc + int.from_bytes(block + b"\x01", "little")) % _P
        acc = (acc * r) % _P
    return ((acc + s) & ((1 << 128) - 1)).to_bytes(16, "little")


def _pad16(data):
    return b"\x00" * (-len(data) % 16)


def _tag(key, nonce, aad, ciphertext):
    poly_key = chacha20_block(key, 0, nonce)[:32]
    mac_data = (aad + _pad16(aad) + ciphertext + _pad16(ciphertext)
                + struct.pack("<QQ", len(aad), len(ciphertext)))
    return poly1305(poly_key, mac_data)


def seal(key, plaintext, aad=b"", nonce=None):
    """Encrypt, returning nonce || ciphertext || tag."""
    if nonce is None:
        nonce = os.urandom(12)
    ciphertext = chacha20(key, 1, nonce, plaintext)
    return nonce + ciphertext + _tag(key, nonce, aad, ciphertext)


def open_sealed(key, sealed, aad=b""):
    """Decrypt a nonce || ciphertext || tag blob. Raises ValueError if forged."""
    if len(sealed) < 28:
        raise ValueError("sealed blob too short")
    nonce, ciphertext, tag = sealed[:12], sealed[12:-16], sealed[-16:]
    if not hmac.compare_digest(_tag(key, nonce, aad, ciphertext), tag):
        raise ValueError("authentication failed")
    return chacha20(key, 1, nonce, ciphertext)
