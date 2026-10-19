#!/usr/bin/env python3
"""Apply a PPF (1.0 / 2.0 / 3.0) patch to a file.

Used to build G-Diffuser's baserom.translated.ek.ndd from the retail Japanese F-Zero X Expansion
Kit disk image and the English translation patch (Zoinkity / LuigiBlood):

    python scripts/apply-ppf.py "F-Zero X Expansion Kit (Japan).ndd" "F-Zero X Expansion Kit ENG.ppf" baserom.translated.ek.ndd

The input and output are checked against the SHA-1s G-Diffuser's first-boot setup knows
(port/gdx_firstboot.cpp, kKnownDiskDumps); a mismatch is reported but the output is still written.
"""
import hashlib
import struct
import sys

JP_DISK_SHA1 = "7e8badf857f1fce8aa59307c0fd318128c44418b"  # retail Japanese Expansion Kit disk
EN_DISK_SHA1 = "fde9fa6f29a52be0144bda74caf8583c036c20ce"  # translated Expansion Kit disk
DIZ_BEGIN = b"@BEGIN_FILE_ID.DIZ"


def records_end(ppf):
    """End of the patch records: the optional FILE_ID.DIZ block comes after them."""
    at = ppf.rfind(DIZ_BEGIN)
    return len(ppf) if at < 0 else at


def apply(image, ppf):
    if ppf[:3] != b"PPF":
        raise ValueError("not a PPF file")
    version = ppf[5] + 1  # encoding byte: 0 = PPF1, 1 = PPF2, 2 = PPF3
    desc = ppf[6:56].rstrip(b"\0 ").decode("latin-1")
    if version == 1:
        pos, offset_size = 56, 4
    elif version == 2:
        pos, offset_size = 56 + 4 + 1024, 4  # input size + 1024-byte block check
    elif version == 3:
        image_type, block_check, undo = ppf[56], ppf[57], ppf[58]
        pos, offset_size = 60 + (1024 if block_check else 0), 8
        if block_check and image_type == 0:
            # PPF3 BIN block check: 1024 bytes of the input at 0x9320.
            if bytes(image[0x9320:0x9320 + 1024]) != ppf[60:60 + 1024]:
                raise ValueError("block check failed: this patch is for a different input file")
    else:
        raise ValueError(f"unsupported PPF encoding {ppf[5]}")
    end = records_end(ppf)
    count = 0
    while pos < end:
        (offset,) = struct.unpack_from("<Q" if offset_size == 8 else "<I", ppf, pos)
        pos += offset_size
        length = ppf[pos]
        pos += 1
        data = ppf[pos:pos + length]
        pos += length
        if version == 3 and undo:
            pos += length  # undo bytes follow the patch bytes
        if offset + length > len(image):
            image.extend(b"\0" * (offset + length - len(image)))
        image[offset:offset + length] = data
        count += 1
    return version, desc, count


def main():
    if len(sys.argv) != 4:
        print(__doc__.strip().splitlines()[0])
        print("usage: apply-ppf.py <input> <patch.ppf> <output>")
        return 2
    src, patch, out = sys.argv[1:]
    with open(src, "rb") as f:
        image = bytearray(f.read())
    with open(patch, "rb") as f:
        ppf = f.read()

    in_sha = hashlib.sha1(image).hexdigest()
    print(f"input  {src}: {len(image)} bytes, SHA-1 {in_sha}")
    if in_sha == JP_DISK_SHA1:
        print("       = retail Japanese Expansion Kit disk (good)")
    elif in_sha == EN_DISK_SHA1:
        print("       = already the translated disk: nothing to do")
        return 0
    else:
        print("       WARNING: not the known retail Japanese disk dump; the result may not work")

    version, desc, count = apply(image, ppf)
    print(f"patch  {patch}: PPF{version}, '{desc}', {count} records")

    with open(out, "wb") as f:
        f.write(image)
    out_sha = hashlib.sha1(image).hexdigest()
    print(f"output {out}: {len(image)} bytes, SHA-1 {out_sha}")
    if out_sha == EN_DISK_SHA1:
        print("       = translated Expansion Kit disk G-Diffuser expects (good)")
        return 0
    print("       WARNING: does not match the translated disk G-Diffuser expects")
    return 1


if __name__ == "__main__":
    sys.exit(main())
