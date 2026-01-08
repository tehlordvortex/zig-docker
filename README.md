```sh
# ZIG_COMMIT defaults to master
# build an image
docker buildx build --platform=linux/amd64,linux/arm64 --build-arg ZIG_COMMIT=xxxx -t zig:xxxx .
# save build result to ./out
docker buildx build --platform=linux/amd64,linux/arm64 --build-arg ZIG_COMMIT=xxxx --output=out .
```

Uses [mise](https://mise.jdx.dev) to download Zig & [sccache](https://github.com/mozilla/sccache), then builds Zig at the specified commit for the chosen `TARGET` (defaults to trying to map the provided Docker `--platform`s to targets) via cross-compilation.

The build scripts are based off [zig-bootstrap](https://codeberg.org/ziglang/zig-bootstrap), with a few tweaks since we already have an existing Zig install to use as a cross-compiler.
Only supports Linux as a build host, only tested with Linux as a build target, but should be able to build for any supported zig-bootstrap target with some tweaks.

See the [Dockerfile](./Dockerfile) for build args to tweak.
For example, you can directly use the Zig version downloaded by mise to build the chosen commit by setting `USE_ZIG_BUILD` to a non-empty value. There are two additional targets that you may find useful: `host-llvm` and `target-llvm`. For exmaple, you can use `target-llvm` with `--output` to get LLVM libs compiled with Zig, and then use that for iterating on Zig itself on your host.
