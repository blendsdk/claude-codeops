# snapshot-store

Writes analysis snapshots to disk. Snapshots written by any earlier release must
remain readable by every later one; the on-disk layout is versioned in its header.
