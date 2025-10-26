# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [0.5.0](https://github.com/idanarye/nvim-channelot/compare/v0.4.0...v0.5.0) (2025-10-26)


### ⚠ BREAKING CHANGES

* channel buffering. `unbuffered` mode will now send the `\n`s

### Bug Fixes

* channel buffering. `unbuffered` mode will now send the `\n`s ([45c5dff](https://github.com/idanarye/nvim-channelot/commit/45c5dff8ce369a4dc6d0c6b512ef20c80e6960bc))

## [0.4.0](https://github.com/idanarye/nvim-channelot/compare/v0.3.0...v0.4.0) (2025-08-27)


### Features

* Add `cwd` parameter to job options ([c6f23e5](https://github.com/idanarye/nvim-channelot/commit/c6f23e52e0e4a7e9f99a2747a14dc6f5aee05621))
* Add `cwd` parameter to terminal creation options ([470199a](https://github.com/idanarye/nvim-channelot/commit/470199a971d0ab59c1e9feae7202c95740cbb069))
* Add `require'channelot'.defer_to_coroutine` ([defb525](https://github.com/idanarye/nvim-channelot/commit/defb52549bbe685e2379517b4107d2eb882ad91a))


### Bug Fixes

* `vim.tbl_islist` -&gt; `vim.islist` ([e0464e6](https://github.com/idanarye/nvim-channelot/commit/e0464e626bcc5289ccafc3c315e69f0e27b7144a))

## [0.3.0](https://github.com/idanarye/nvim-channelot/compare/v0.2.0...v0.3.0) (2023-11-07)


### ⚠ BREAKING CHANGES

* Previously hidden terminals will silently prompt the user (which could not see the prompt)

### Features

* `channelot.terminal` can open terminal on a non-current buffer ([915964e](https://github.com/idanarye/nvim-channelot/commit/915964e0df5e86874322da245f91ef2c563f366e))
* `ChannelotTerminal:with` automatically closes/exposes hidden terminal ([23eb517](https://github.com/idanarye/nvim-channelot/commit/23eb517168e29fe5c56ccb854a7309df53c4676b))
* Add functions for better working with windows ([758bd22](https://github.com/idanarye/nvim-channelot/commit/758bd221fcc9704010a5db84e4004e2173e075e0))

## [0.2.0](https://github.com/idanarye/nvim-channelot/compare/v0.1.0...v0.2.0) (2023-10-25)


### Features

* Add `ChannelotJob:check` and `ChannelotTerminal:with` ([921e8ea](https://github.com/idanarye/nvim-channelot/commit/921e8eaf3f6552479236927da2b8de22fd43a8eb))
* Add `ChannelotJob:using` ([3828e90](https://github.com/idanarye/nvim-channelot/commit/3828e90ead6aa9e44390b8b489bca41ccd4ce62f))
* Add job options (ability to enforce PTY) ([97b9672](https://github.com/idanarye/nvim-channelot/commit/97b9672aff5b94f18712fddfa2ee99d850f1f4ec))

## 0.1.0 - 2023-01-02
### Added
- Terminal object.
- Launching jobs on the terminal object.
- Launching standalone jobs, with or without a terminal.
- Waiting for a job to finish.
- Prompting the user for closing the terminal.
- Iterating output.
- Writing data to a job.
- Setting environment variables for jobs.
