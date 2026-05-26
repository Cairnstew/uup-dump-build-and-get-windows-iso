# Windows ISO

Assembles a Windows ISO from a split zip archive (`.zip.001`, `.zip.002`, …)
published by UUP dump as a GitHub release asset.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.iso.windows.enable` | `false` | Enable Windows ISO derivation |
| `my.iso.windows.release.tag` | *required* | Release tag (e.g. `22631.7079.23H2.PRO.X64.EN`) |
| `my.iso.windows.release.parts` | *required* | List of `{ url, sha256 }` for each split archive part |
| `my.iso.windows.release.isoName` | *required* | Filename of the reassembled ISO |
| `my.iso.windows.release.isoHash` | *required* | SRI hash (`sha256-…`) of the reassembled ISO |
| `my.iso.windows.package` | read-only | The assembled ISO derivation |

## Usage Example

```nix
my.iso.windows = {
  enable = true;
  release = {
    tag = "22631.7079.23H2.PRO.X64.EN";
    parts = [
      {
        url = "https://github.com/example/repo/releases/download/tag/windows.iso.zip.001";
        sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      }
      {
        url = "https://github.com/example/repo/releases/download/tag/windows.iso.zip.002";
        sha256 = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
      }
    ];
    isoName = "22631.7079.23H2.PRO.X64.EN.iso";
    isoHash = "sha256-CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=";
  };
};
```

## Notes

- The derivation is fixed-output; the `isoHash` must match the SHA-256 of the final ISO.
- Parts are symlinked as `.zip.001`, `.zip.002`, … in the build sandbox.
- `allowUnfree` must be set by the consumer.
