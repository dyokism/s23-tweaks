# S23 Performance Tweaks Changelog

## v1.1
- Replaced `cat` subshell forks with fast `read -r` redirects.
- Cached dynamic `date` command outputs to eliminate duplicate subshell forks.
- Wrapped ZRAM setup in a function and converted global exits to returns.
- Aligned UFS request limit to 128 unconditionally.
- Added SC3043 shellcheck flags for local variables.
- Added safety comments for `update-binary` exits.
- Cleaned up README.md style, tone, and warnings.

## v1.0
- Initial release.
- Added CPU WALT, VM, GPU, network, and I/O scheduler tuning.
- Configured ZRAM lz4 compression on early boot.
- Added SM-S911* device safety guard.
