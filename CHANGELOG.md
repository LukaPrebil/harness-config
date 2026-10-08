# [0.8.0](https://github.com/LukaPrebil/harness-config/compare/v0.7.0...v0.8.0) (2026-10-08)


### Bug Fixes

* **hooks:** drop the stale herdr SessionStart entry ([8cf6e44](https://github.com/LukaPrebil/harness-config/commit/8cf6e44e4d69d26ca9eb7b9810344c2eaf3b6674))
* **tests:** scan tracked files in the shared-paths check ([9810d23](https://github.com/LukaPrebil/harness-config/commit/9810d236c8c08e96d9b52df2e6577e450422b37c))


### Features

* **shims:** track the account shims and link them from the bootstrap ([48e3b43](https://github.com/LukaPrebil/harness-config/commit/48e3b432ca5071dd45d529295f3c1097d1006f0d))

# [0.7.0](https://github.com/LukaPrebil/harness-config/compare/v0.6.0...v0.7.0) (2026-10-08)


### Bug Fixes

* **ci,hooks:** point repo gate and fallback paths at agent-config ([#133](https://github.com/LukaPrebil/harness-config/issues/133)) ([e1979bb](https://github.com/LukaPrebil/harness-config/commit/e1979bb835fd7eb56fbf2471c44e4a69ef8e03a2))
* **ci:** keep the notify guard on the upstream repo ([b2b540b](https://github.com/LukaPrebil/harness-config/commit/b2b540bc5866f4d693ed026b6e9b804b1a7b430f))
* **hooks:** ask gh about the payload repo in the PR state probe ([#178](https://github.com/LukaPrebil/harness-config/issues/178)) ([03c97da](https://github.com/LukaPrebil/harness-config/commit/03c97da3029c1bd95b922f7d6a4c5f4e715d259d))
* **hooks:** audit Bun repos with bun audit in the push gate ([#177](https://github.com/LukaPrebil/harness-config/issues/177)) ([dc512f7](https://github.com/LukaPrebil/harness-config/commit/dc512f7912ca0f0f0628d62f01ec5ed0613e3ac9))
* **hooks:** build a worktree without .env using the committed template ([#145](https://github.com/LukaPrebil/harness-config/issues/145)) ([3f2fefb](https://github.com/LukaPrebil/harness-config/commit/3f2fefb3c8ef74ec020402cd1f242187dfd6a137))
* **hooks:** find a monorepo's root Biome config in the per-edit hooks ([#181](https://github.com/LukaPrebil/harness-config/issues/181)) ([f104a46](https://github.com/LukaPrebil/harness-config/commit/f104a46dab1a3e08238309bea850b04e3708281f))
* **hooks:** four silent failures in the edit and commit gates ([#139](https://github.com/LukaPrebil/harness-config/issues/139)) ([61ae5d6](https://github.com/LukaPrebil/harness-config/commit/61ae5d65f9fcfc5342c74d3c0590d106625ebe2a))
* **hooks:** let a repo's own pre-push hook gate the push instead of running both ([#164](https://github.com/LukaPrebil/harness-config/issues/164)) ([64d3791](https://github.com/LukaPrebil/harness-config/commit/64d379154bb91c80fad85c8b9d384de99198807b))
* **hooks:** read bold and suffixed criterion ids in the evidence gate ([#192](https://github.com/LukaPrebil/harness-config/issues/192)) ([29549d8](https://github.com/LukaPrebil/harness-config/commit/29549d860f6f7b2398fb42e76956c54656599ba1))
* **hooks:** repair the PR state probe ([#138](https://github.com/LukaPrebil/harness-config/issues/138)) ([836d023](https://github.com/LukaPrebil/harness-config/commit/836d0233bc94e2c8936f51be06594cd1cb3945e8))
* **hooks:** require the agent footer on its own line ([#173](https://github.com/LukaPrebil/harness-config/issues/173)) ([6820edf](https://github.com/LukaPrebil/harness-config/commit/6820edfae94a7b426ec6d2b46bf3c1b094e172ca))
* **hooks:** run the drift check wherever the checkout lives ([#179](https://github.com/LukaPrebil/harness-config/issues/179)) ([43d6205](https://github.com/LukaPrebil/harness-config/commit/43d6205e24c109231ecbf80690cb8c02c3a1f5a7))
* **hooks:** run the push gate through the repo's package manager ([#180](https://github.com/LukaPrebil/harness-config/issues/180)) ([add2e5b](https://github.com/LukaPrebil/harness-config/commit/add2e5b10dccdb0f6d2b5e3c03626eec08783294))
* one link manifest, and shell tests that run ([#135](https://github.com/LukaPrebil/harness-config/issues/135)) ([bcde4d2](https://github.com/LukaPrebil/harness-config/commit/bcde4d222064fd1fda46933561117babe3ce8942))
* **pi:** allow package-manager lockfile writes ([#143](https://github.com/LukaPrebil/harness-config/issues/143)) ([125890b](https://github.com/LukaPrebil/harness-config/commit/125890b6dbd189ce541e994a6419e49bb3e4a1af))
* **pi:** state the bash catch-all so the permission warning clears ([f260f9a](https://github.com/LukaPrebil/harness-config/commit/f260f9ae0b1a837b1c337ec9d6d2af53c65a1e42))
* repair broken shared paths and two silent hook failures ([#134](https://github.com/LukaPrebil/harness-config/issues/134)) ([15c9246](https://github.com/LukaPrebil/harness-config/commit/15c92462210dfd16cb8b65d97477532d6fc3ba64))
* **worktree-prune:** keep fresh worktrees and harden row parsing ([#165](https://github.com/LukaPrebil/harness-config/issues/165)) ([1bc8715](https://github.com/LukaPrebil/harness-config/commit/1bc87157accb3e38e0245dd7997e5f14b055e1df))


### Features

* **config:** enable 1M context for all gpt-6 codex models ([7e95de3](https://github.com/LukaPrebil/harness-config/commit/7e95de35c9579cc58215c2fefa3a93f3e6c4ac52))
* detect squash-merged worktrees and add a shell-command rule ([#163](https://github.com/LukaPrebil/harness-config/issues/163)) ([3c36b76](https://github.com/LukaPrebil/harness-config/commit/3c36b76769aac3d86ac7ad5f71f4c88114adcbe2))
* **document:** keep repo docs accurate with check, audit and review ([#186](https://github.com/LukaPrebil/harness-config/issues/186)) ([7b71b98](https://github.com/LukaPrebil/harness-config/commit/7b71b98a9b29b69a5a801410aa41c5fcf1d169ef))
* enforce the same hooks on Claude Code, Codex, and Pi ([#159](https://github.com/LukaPrebil/harness-config/issues/159)) ([94c6034](https://github.com/LukaPrebil/harness-config/commit/94c6034a1ec9e5f451c85d2fb948f0bf8bd6c130))
* **hooks:** defer push and PR gates to a repo's declared verify contract ([#167](https://github.com/LukaPrebil/harness-config/issues/167)) ([be2e930](https://github.com/LukaPrebil/harness-config/commit/be2e930b3475e9da56be90ffb7cb589e13733b40))
* **hooks:** enforce the deny list on Codex and on shell reads everywhere ([#161](https://github.com/LukaPrebil/harness-config/issues/161)) ([b878f10](https://github.com/LukaPrebil/harness-config/commit/b878f10e364d5556e834963b15d02e62a884fe44))
* **hooks:** gate PR descriptions and route creation through /mr ([#144](https://github.com/LukaPrebil/harness-config/issues/144)) ([569b383](https://github.com/LukaPrebil/harness-config/commit/569b383216f77a41c6422d98f0f5261400c60514))
* **hooks:** mark comments the agent posts under the user's account ([#169](https://github.com/LukaPrebil/harness-config/issues/169)) ([59c5547](https://github.com/LukaPrebil/harness-config/commit/59c5547e2a2c0a3030c2f17b0784de60e100337c))
* link the user CLAUDE.md to AGENTS.md and follow recent Claude Code changes ([#146](https://github.com/LukaPrebil/harness-config/issues/146)) ([fb6ffd1](https://github.com/LukaPrebil/harness-config/commit/fb6ffd149e68e2b9ba40da5e85d3461cbb5150f9))
* make ~/.agents the host-neutral shared root ([#137](https://github.com/LukaPrebil/harness-config/issues/137)) ([9ad9d9d](https://github.com/LukaPrebil/harness-config/commit/9ad9d9d4f8dcaa5c3b5be86408bf2475cbee5957))
* open PRs without confirmation and never push to main ([#152](https://github.com/LukaPrebil/harness-config/issues/152)) ([980bf25](https://github.com/LukaPrebil/harness-config/commit/980bf2568cf2a4cd2a978a7d039761d5a60090ee))
* **pi:** default the work profile to gpt-6.1-sol with 1M context ([4cdd435](https://github.com/LukaPrebil/harness-config/commit/4cdd4352deb5a416213025b59dab7cce6b31ea73))
* **pi:** enable codemode and name the MCP surface owner ([d70ebd0](https://github.com/LukaPrebil/harness-config/commit/d70ebd0020ae2a9aa20202359f3e89508c9458e6))
* **pi:** load the hook bridge into native children ([72484a6](https://github.com/LukaPrebil/harness-config/commit/72484a6e7f998f1a270d6aecee9d542148020aaa))
* **pi:** manage MCP servers and correct Codex quota labels ([#142](https://github.com/LukaPrebil/harness-config/issues/142)) ([ea5e95a](https://github.com/LukaPrebil/harness-config/commit/ea5e95ab86d1caa25d1716dbfbf0357c31edeabe))
* **pi:** pin pi-mcp-adapter to 3.3.0 with its own config file ([422fb5c](https://github.com/LukaPrebil/harness-config/commit/422fb5ce0af0bfe515e88abf5c39f34c29be6eab))
* **pi:** upgrade pi-intercom to 0.16.0 ([8c3d0c0](https://github.com/LukaPrebil/harness-config/commit/8c3d0c004b328cc0b82b6423d54ad7ad4e8b194b))
* **pi:** upgrade pi-mcp-adapter to 5.0.0 and restore mcpScript ([6735f11](https://github.com/LukaPrebil/harness-config/commit/6735f11b24a3b0c33ca4436d927393b1f64d08ad))
* **pi:** upgrade pi-permission-system to 37.0.0 ([df29fe7](https://github.com/LukaPrebil/harness-config/commit/df29fe7a708525ebf3735e21bf5382e80bc85b5e))
* **skills:** add deliver, which runs a feature end to end with one human gate ([#157](https://github.com/LukaPrebil/harness-config/issues/157)) ([75d78bb](https://github.com/LukaPrebil/harness-config/commit/75d78bbdf8be5d7b828c771922efb2457e1bf239))
* **skills:** add the plan skill that turns a spec into vertical slices ([#155](https://github.com/LukaPrebil/harness-config/issues/155)) ([42e61d5](https://github.com/LukaPrebil/harness-config/commit/42e61d5ccf485867087d6276f068c6b9c8c72e7f))
* **skills:** address PR review comments, replying inline only to bots ([#153](https://github.com/LukaPrebil/harness-config/issues/153)) ([e13c668](https://github.com/LukaPrebil/harness-config/commit/e13c668fef1f7ffdbaa20e52a08fcdfad0740705))
* **statusline:** show the current model and effort level ([#193](https://github.com/LukaPrebil/harness-config/issues/193)) ([dd42982](https://github.com/LukaPrebil/harness-config/commit/dd42982fa2d3297b45c3c758834cf3fb0fe325a2))
* tests-first slice loop with a test lock and review panel ([#156](https://github.com/LukaPrebil/harness-config/issues/156)) ([4840f03](https://github.com/LukaPrebil/harness-config/commit/4840f03be3804a7aeb396690c5c41cfdeb6cec99))
* verify spec acceptance criteria before opening a PR ([#154](https://github.com/LukaPrebil/harness-config/issues/154)) ([414b9c7](https://github.com/LukaPrebil/harness-config/commit/414b9c736c56f66ed9fc1ac27281d65450de501e))
* **worktrees:** detect squash-merged branches in worktree-prune ([d01df9d](https://github.com/LukaPrebil/harness-config/commit/d01df9d254413e4ad2f0824581c18f7697ff9666))

# [0.6.0](https://github.com/LukaPrebil/harness-config/compare/v0.5.0...v0.6.0) (2026-09-13)


### Features

* **pi:** install pi-web-access and set personal model to deepseek-v4.1-flash ([4b551a2](https://github.com/LukaPrebil/harness-config/commit/4b551a26245a1373854f3c3d8836a788bea15f7c))
* **pi:** split startup settings per profile ([5ed501d](https://github.com/LukaPrebil/harness-config/commit/5ed501d63c5a4bfad4d3466902509745078afbad))

# [0.5.0](https://github.com/LukaPrebil/harness-config/compare/v0.4.0...v0.5.0) (2026-09-10)


### Bug Fixes

* **pi:** derive Codex header labels from window duration ([f428e6e](https://github.com/LukaPrebil/harness-config/commit/f428e6e56f06e7c1dc3e784ab738cf6dda6a073e))
* **release:** commit package-lock.json with release bumps ([f8e3e74](https://github.com/LukaPrebil/harness-config/commit/f8e3e74b307760159d44ee0ce2996cc23e552f51)), closes [#130](https://github.com/LukaPrebil/harness-config/issues/130)
* **release:** push the bot commit with an admin credential ([#14](https://github.com/LukaPrebil/harness-config/issues/14)) ([c1872b9](https://github.com/LukaPrebil/harness-config/commit/c1872b9e25967a49e15864749f0b934929c0266d))
* **release:** run semantic-release via npx instead of the docker image ([#3](https://github.com/LukaPrebil/harness-config/issues/3)) ([adcf85f](https://github.com/LukaPrebil/harness-config/commit/adcf85fe8948501488b21b69f6da9fed67217fd6))


### Features

* **claude:** promote session runtime settings to the tracked config ([#11](https://github.com/LukaPrebil/harness-config/issues/11)) ([2a8976e](https://github.com/LukaPrebil/harness-config/commit/2a8976ed7b1e0a2e77bc3d886aaf64e064982a60))
* **config:** integrate multi-host layer and Pi adapter from harness-config ([#130](https://github.com/LukaPrebil/harness-config/issues/130)) ([ee64b5e](https://github.com/LukaPrebil/harness-config/commit/ee64b5e8240dc138944321426a79777fddacfa6f))
* **pi:** manage Notion and Playwright MCP configuration ([5c78282](https://github.com/LukaPrebil/harness-config/commit/5c7828210e84f4c8b48ec57600a73177e4291631))
* **pi:** package manifest and manual semantic releases ([#1](https://github.com/LukaPrebil/harness-config/issues/1)) ([2f26b9c](https://github.com/LukaPrebil/harness-config/commit/2f26b9c9ba9c81d26254d20dc651f0d51140826a))

# [0.4.0](https://github.com/LukaPrebil/harness-config/compare/v0.3.0...v0.4.0) (2026-09-04)


### Bug Fixes

* **pi:** derive quota labels from window duration ([#17](https://github.com/LukaPrebil/harness-config/issues/17)) ([fbe7fa7](https://github.com/LukaPrebil/harness-config/commit/fbe7fa7e7a120cdb88890c04129460848291b223))
* **pi:** keep statusline helper in extension tree ([#16](https://github.com/LukaPrebil/harness-config/issues/16)) ([44beafd](https://github.com/LukaPrebil/harness-config/commit/44beafdf44d916fb56cc91009f008805e0704174))


### Features

* **config:** enable OpenAI long context ([#18](https://github.com/LukaPrebil/harness-config/issues/18)) ([8036a0e](https://github.com/LukaPrebil/harness-config/commit/8036a0e156b2df44bf800e6ce2fecf464034ac97))
* **pi:** show OpenAI Codex usage limits ([#15](https://github.com/LukaPrebil/harness-config/issues/15)) ([eb5ff00](https://github.com/LukaPrebil/harness-config/commit/eb5ff008f25a512f77379650501c6a053839120e))

# [0.3.0](https://github.com/LukaPrebil/harness-config/compare/v0.2.0...v0.3.0) (2026-09-01)


### Bug Fixes

* **release:** push the bot commit with an admin credential ([#14](https://github.com/LukaPrebil/harness-config/issues/14)) ([ee00903](https://github.com/LukaPrebil/harness-config/commit/ee009038f59bfad449606472557d882f8df270eb))


### Features

* **claude:** promote session runtime settings to the tracked config ([#11](https://github.com/LukaPrebil/harness-config/issues/11)) ([8c0686d](https://github.com/LukaPrebil/harness-config/commit/8c0686d27ccf5de35b28d82327f2d116a6e4e0c6))
* **hosts:** record machine host scope so bare --check stays correct ([#12](https://github.com/LukaPrebil/harness-config/issues/12)) ([2e60459](https://github.com/LukaPrebil/harness-config/commit/2e604592f4bf14e4e1e3724235b7b16b0b3468cc))
* **pi:** adopt pi-subagents and retire the teammates prototype ([#10](https://github.com/LukaPrebil/harness-config/issues/10)) ([fc6d0b5](https://github.com/LukaPrebil/harness-config/commit/fc6d0b558251b46646141d9f1e07199f1fbc8ce8))
* **pi:** adopt the permission-system, mcp-adapter, and intercom packages ([#13](https://github.com/LukaPrebil/harness-config/issues/13)) ([0c10df0](https://github.com/LukaPrebil/harness-config/commit/0c10df019fcd1f28ba200c1046f23673766d6a1d))
* **pi:** drift-check extension surfacing bootstrap drift ([#7](https://github.com/LukaPrebil/harness-config/issues/7)) ([ad65a9c](https://github.com/LukaPrebil/harness-config/commit/ad65a9c37685460950e6c889ff4c2d58bc5e08cd))
* **pi:** permission gate enforcing the deny list in pi ([#5](https://github.com/LukaPrebil/harness-config/issues/5)) ([91d5276](https://github.com/LukaPrebil/harness-config/commit/91d5276adc98a0f0ab7f6ed9511130dc9cce8ede))
* **pi:** teammates extension for lane-mode agent parity ([#9](https://github.com/LukaPrebil/harness-config/issues/9)) ([78143f3](https://github.com/LukaPrebil/harness-config/commit/78143f3769598e4f0cc1963c08441749ff9f2c0c))
* **pi:** worktree cleanup on session end ([#8](https://github.com/LukaPrebil/harness-config/issues/8)) ([e0d5d5a](https://github.com/LukaPrebil/harness-config/commit/e0d5d5ab6ca216218935d0b2e6675ea6ac388171))

# [0.2.0](https://github.com/LukaPrebil/harness-config/compare/v0.1.0...v0.2.0) (2026-08-31)


### Bug Fixes

* **release:** run semantic-release via npx instead of the docker image ([#3](https://github.com/LukaPrebil/harness-config/issues/3)) ([eddcdfb](https://github.com/LukaPrebil/harness-config/commit/eddcdfb4c2d47f7944cea20082343034ab76a0d9))


### Features

* **pi:** package manifest and manual semantic releases ([#1](https://github.com/LukaPrebil/harness-config/issues/1)) ([b65b983](https://github.com/LukaPrebil/harness-config/commit/b65b9831a5af7484df260c1f6561f31005e83e16))
