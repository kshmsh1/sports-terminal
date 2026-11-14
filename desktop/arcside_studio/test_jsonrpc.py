"""Local LSP framing regression tests, independent of PySide6 installation."""
import unittest

try:
    from .jsonrpc import encode, extract
except ImportError:
    from jsonrpc import encode, extract


class LspFramingTests(unittest.TestCase):
    def test_roundtrip(self):
        payload = {'jsonrpc': '2.0', 'id': 1, 'method': 'initialize', 'params': {'x': 5}}
        data = bytearray(encode(payload))
        self.assertEqual(extract(data), [payload])
        self.assertEqual(data, bytearray())

    def test_fragmented_frames_and_multiple_messages(self):
        first = {'jsonrpc': '2.0', 'method': 'textDocument/didOpen'}
        second = {'jsonrpc': '2.0', 'id': 2, 'result': [1, 2]}
        stream = encode(first) + encode(second)
        buf = bytearray(stream[:12])
        self.assertEqual(extract(buf), [])
        buf.extend(stream[12:32])
        self.assertEqual(extract(buf), [])
        buf.extend(stream[32:])
        self.assertEqual(extract(buf), [first, second])

    def test_utf8_lengths_use_bytes(self):
        message = {'jsonrpc': '2.0', 'method': 'test', 'params': {'text': 'José Dončić'}}
        encoded = encode(message)
        self.assertEqual(extract(bytearray(encoded))[0], message)

    def test_reject_unbounded_payload(self):
        with self.assertRaises(ValueError):
            extract(bytearray(b'Content-Length: 90000000\r\n\r\n'))
        with self.assertRaises(ValueError):
            extract(bytearray(b'Content-Length: -1\r\n\r\n'))

    def test_reject_malformed_header(self):
        with self.assertRaises(ValueError):
            extract(bytearray(b'Nothing: 1\r\n\r\n{}'))

    def test_concatenated_frame_stream_retains_incomplete_tail(self):
        payload = {'jsonrpc': '2.0', 'method': 'test'}
        frame = encode(payload)
        buffer = bytearray(frame + frame[:14])
        self.assertEqual(extract(buffer), [payload])
        self.assertEqual(buffer, bytearray(frame[:14]))


if __name__ == '__main__':
    unittest.main()
