"""Dependency-free PNG read/write (8-bit RGBA / RGB / grey / palette in; RGBA out)."""
import struct
import zlib


def _paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def read_png(path):
    """Return (width, height, bytearray RGBA row-major)."""
    with open(path, "rb") as fh:
        data = fh.read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", path
    pos, idat, plte, trns = 8, bytearray(), None, None
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            w, h, depth, ctype, _, _, interlace = struct.unpack(">IIBBBBB", body)
            assert depth == 8 and interlace == 0, (depth, interlace)
        elif kind == b"PLTE":
            plte = body
        elif kind == b"tRNS":
            trns = body
        elif kind == b"IDAT":
            idat.extend(body)
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    raw = zlib.decompress(bytes(idat))
    stride = w * channels
    out = bytearray(stride * h)
    prev = bytearray(stride)
    i = 0
    for y in range(h):
        ft = raw[i]
        i += 1
        line = bytearray(raw[i:i + stride])
        i += stride
        if ft == 1:
            for x in range(channels, stride):
                line[x] = (line[x] + line[x - channels]) & 255
        elif ft == 2:
            for x in range(stride):
                line[x] = (line[x] + prev[x]) & 255
        elif ft == 3:
            for x in range(stride):
                left = line[x - channels] if x >= channels else 0
                line[x] = (line[x] + ((left + prev[x]) >> 1)) & 255
        elif ft == 4:
            for x in range(stride):
                left = line[x - channels] if x >= channels else 0
                ul = prev[x - channels] if x >= channels else 0
                line[x] = (line[x] + _paeth(left, prev[x], ul)) & 255
        out[y * stride:(y + 1) * stride] = line
        prev = line
    if ctype == 6:
        return w, h, out
    rgba = bytearray(w * h * 4)
    for p in range(w * h):
        if ctype == 2:
            r, g, b = out[p * 3:p * 3 + 3]
            a = 255
        elif ctype == 0:
            r = g = b = out[p]
            a = 255
        elif ctype == 4:
            r = g = b = out[p * 2]
            a = out[p * 2 + 1]
        else:
            k = out[p]
            r, g, b = plte[k * 3:k * 3 + 3]
            a = trns[k] if trns and k < len(trns) else 255
        rgba[p * 4:p * 4 + 4] = bytes((r, g, b, a))
    return w, h, rgba


def write_png(path, w, h, rgba):
    """Write 8-bit RGBA (filter: Sub per row for size)."""
    stride = w * 4
    raw = bytearray()
    for y in range(h):
        row = rgba[y * stride:(y + 1) * stride]
        raw.append(1)
        sub = bytearray(stride)
        sub[:4] = row[:4]
        for x in range(4, stride):
            sub[x] = (row[x] - row[x - 4]) & 255
        raw.extend(sub)

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    with open(path, "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n")
        fh.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)))
        fh.write(chunk(b"IDAT", zlib.compress(bytes(raw), 9)))
        fh.write(chunk(b"IEND", b""))
