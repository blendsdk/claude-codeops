"""On-disk snapshot encoding.

The header carries a format version. Readers must accept every version ever
written; writers emit the current one.
"""
FORMAT_VERSION = 4

def encode_snapshot(records): ...
def decode_snapshot(blob): ...
