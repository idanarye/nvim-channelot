# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

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
