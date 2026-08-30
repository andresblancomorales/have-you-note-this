#!/usr/bin/env python3
"""RFC 8439 test vectors for the bundled ChaCha20-Poly1305."""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "bin"))
import notethis_crypto as crypto


class ChaCha20(unittest.TestCase):
    def test_block_function(self):
        # RFC 8439 section 2.3.2
        key = bytes(range(32))
        nonce = bytes.fromhex("000000090000004a00000000")
        block = crypto.chacha20_block(key, 1, nonce)
        self.assertEqual(block[:16].hex(), "10f1e7e4d13b5915500fdd1fa32071c4")

    def test_encryption_vector(self):
        # RFC 8439 section 2.4.2
        key = bytes(range(32))
        nonce = bytes.fromhex("000000000000004a00000000")
        plaintext = (b"Ladies and Gentlemen of the class of '99: If I could offer you "
                     b"only one tip for the future, sunscreen would be it.")
        out = crypto.chacha20(key, 1, nonce, plaintext)
        self.assertEqual(out[:16].hex(), "6e2e359a2568f98041ba0728dd0d6981")
        self.assertEqual(crypto.chacha20(key, 1, nonce, out), plaintext)


class Poly1305(unittest.TestCase):
    def test_mac_vector(self):
        # RFC 8439 section 2.5.2
        key = bytes.fromhex("85d6be7857556d337f4452fe42d506a8"
                            "0103808afb0db2fd4abff6af4149f51b")
        tag = crypto.poly1305(key, b"Cryptographic Forum Research Group")
        self.assertEqual(tag.hex(), "a8061dc1305136c6c22b8baf0c0127a9")


class Aead(unittest.TestCase):
    KEY = bytes(range(0x80, 0xa0))
    NONCE = bytes.fromhex("070000004041424344454647")
    AAD = bytes.fromhex("50515253c0c1c2c3c4c5c6c7")
    PLAINTEXT = (b"Ladies and Gentlemen of the class of '99: If I could offer you "
                 b"only one tip for the future, sunscreen would be it.")

    def test_seal_matches_rfc(self):
        # RFC 8439 section 2.8.2
        sealed = crypto.seal(self.KEY, self.PLAINTEXT, self.AAD, self.NONCE)
        self.assertEqual(sealed[12:-16].hex()[:32], "d31a8d34648e60db7b86afbc53ef7ec2")
        self.assertEqual(sealed[-16:].hex(), "1ae10b594f09e26a7e902ecbd0600691")

    def test_roundtrip(self):
        sealed = crypto.seal(self.KEY, self.PLAINTEXT, self.AAD)
        self.assertEqual(crypto.open_sealed(self.KEY, sealed, self.AAD), self.PLAINTEXT)

    def test_empty_plaintext(self):
        sealed = crypto.seal(self.KEY, b"", self.AAD)
        self.assertEqual(crypto.open_sealed(self.KEY, sealed, self.AAD), b"")

    def test_long_plaintext_spans_blocks(self):
        plaintext = os.urandom(5000)
        sealed = crypto.seal(self.KEY, plaintext)
        self.assertEqual(crypto.open_sealed(self.KEY, sealed), plaintext)

    def test_tampered_ciphertext_is_rejected(self):
        sealed = bytearray(crypto.seal(self.KEY, self.PLAINTEXT, self.AAD))
        sealed[20] ^= 0x01
        with self.assertRaises(ValueError):
            crypto.open_sealed(self.KEY, bytes(sealed), self.AAD)

    def test_wrong_aad_is_rejected(self):
        sealed = crypto.seal(self.KEY, self.PLAINTEXT, self.AAD)
        with self.assertRaises(ValueError):
            crypto.open_sealed(self.KEY, sealed, b"other")

    def test_wrong_key_is_rejected(self):
        sealed = crypto.seal(self.KEY, self.PLAINTEXT)
        with self.assertRaises(ValueError):
            crypto.open_sealed(os.urandom(32), sealed)


if __name__ == "__main__":
    unittest.main()
