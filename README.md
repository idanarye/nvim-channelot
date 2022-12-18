[![CI Status](https://github.com/idanarye/nvim-channelot/workflows/CI/badge.svg)](https://github.com/idanarye/channelot/actions)

INTRODUCTION
============

Channelot is a library plugin for operating Neovim jobs from a Lua coroutine. It supports:

* Starting jobs, with and without terminals.
* Starting multiple jobs on the same Neovim terminal.
* Job control is done via Lua coroutines - Channelot will resume the coroutine once the job is finished and/or when it outputs new data.

Channelot was created as a supplemental plugin for [Moonicipal](https://github.com/idanarye/nvim-moonicipal), but can be used independent of it.

FUTURES (IMPLEMENTED/PLANNED)
=============================

- [x] Control jobs from coroutines.
- [x] Run jobs in automatic terminal, manually managed terminal, or no terminal.
- [x] Environment variables.
- [x] Waiting for a job to finish.
- [x] Iterating over job output.
- [x] Writing to job's stdin.
- [ ] Setting job parameters.

CONTRIBUTION GUIDELINES
=======================

* If your contribution can be reasonably tested with automation tests, add tests. The tests run with [a specific branch in a fork of Plenary](https://github.com/idanarye/plenary.nvim/tree/async-testing) that allows async testing ([there is a PR to include it in the main repo](https://github.com/nvim-lua/plenary.nvim/pull/426)) 
* Documentation comments must be compatible with both [Sumneko Language Server](https://github.com/sumneko/lua-language-server/wiki/Annotations) and [lemmy-help](https://github.com/numToStr/lemmy-help/blob/master/emmylua.md). If you do something that changes the documentation, please run `make docs` to update the vimdoc.
* Update the changelog according to the [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) format.
